import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'dart:io';
import 'package:measure_master/constants.dart';
import 'package:measure_master/screens/camera_screen_v2.dart';
import 'package:measure_master/screens/detail_screen.dart';
import 'package:measure_master/widgets/custom_button.dart';
import 'package:measure_master/models/api_product.dart';
import 'package:measure_master/models/item.dart';
import 'package:measure_master/models/image_item.dart';
import 'package:measure_master/providers/inventory_provider.dart';
import 'package:measure_master/services/cloudflare_storage_service.dart';
import 'package:measure_master/services/image_cache_service.dart';
import 'package:measure_master/features/ocr/logic/ocr_service.dart';
import 'package:measure_master/features/ocr/domain/ocr_result.dart';
import 'package:measure_master/widgets/smart_image_viewer.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';

class AddItemScreen extends StatefulWidget {
  final ApiProduct? prefillData; // 🔍 検索結果からの自動入力データ
  final InventoryItem? existingItem; // 📝 既存商品データ（編集用）
  
  const AddItemScreen({Key? key, this.prefillData, this.existingItem}) : super(key: key);
  
  @override
  _AddItemScreenState createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  bool _aiMeasure = true;
  
  // 📸 画像アイテムのリスト（UUID管理）
  List<ImageItem> _images = [];
  
  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController(); // 🆕 商品の説明
  
  // 🆕 API連携用の追加コントローラー
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _skuController = TextEditingController();
  final TextEditingController _sizeController = TextEditingController();
  
  // 📏 実寸入力用コントローラー
  final TextEditingController _lengthController = TextEditingController(); // 着丈
  final TextEditingController _widthController = TextEditingController();  // 身幅
  final TextEditingController _shoulderController = TextEditingController(); // 肩幅
  final TextEditingController _sleeveController = TextEditingController();  // 袖丈
  
  String _selectedCategory = '選択してください';
  String _selectedCondition = '選択してください';
  String _selectedRank = '選択してください'; // 🆕 商品ランク
  String _selectedMaterial = '選択してください'; // 🆕 素材
  String _selectedColor = '選択してください'; // 🆕 カラー
  Color _colorPreview = Colors.grey[400]!; // 🆕 カラープレビュー（デフォルト：選択前）
  
  // 🆕 商品ランクのオプション (S, A, B, C, D, E, N)
  final List<String> _ranks = ['選択してください', 'S', 'A', 'B', 'C', 'D', 'E', 'N'];
  
  // 🆕 素材のオプション
  final List<String> _materials = [
    '選択してください',
    'コットン 100%',
    'ポリエステル 100%',
    'コットン 80% / ポリエステル 20%',
    'ウール 100%',
    'ナイロン 100%',
    'レザー',
    'デニム',
    'リネン 100%',
    'シルク 100%',
    'その他',
  ];
  
  // 🆕 カラーオプション
  final Map<String, Color> _colorOptions = {
    '選択してください': Colors.grey[400]!,
    'ホワイト': Colors.white,
    'ブラック': Colors.black,
    'グレー': Colors.grey,
    'ネイビー': Color(0xFF001f3f),
    'ブルー': Colors.blue,
    'レッド': Colors.red,
    'ピンク': Colors.pink,
    'イエロー': Colors.yellow,
    'グリーン': Colors.green,
    'ブラウン': Colors.brown,
    'ベージュ': Color(0xFFF5F5DC),
    'オレンジ': Colors.orange,
    'パープル': Colors.purple,
    'カーキ': Color(0xFF7C7C54),
    'ボルドー': Color(0xFF800020),
    'その他': Colors.grey[400]!,
  };
  
  // 🚀 文字数カウンター用のValueNotifier(setState不要で効率的)
  final ValueNotifier<int> _charCount = ValueNotifier<int>(0);
  
  // 🔍 自動入力フラグ
  bool _isAutofilled = false;
  
  @override
  void initState() {
    super.initState();
    
    // 🔍 初期化時の強制ログ
    print('========================================');
    print('AddItemScreen 初期化');
    print('AI自動採寸トグル初期値: $_aiMeasure');
    print('========================================');
    
    // 📝 既存商品データから読み込み（編集モード）
    if (widget.existingItem != null) {
      _loadExistingItem(widget.existingItem!);
    }
    // 🔍 検索結果から自動入力
    else if (widget.prefillData != null) {
      _autofillFromApiProduct(widget.prefillData!);
    }
    
    // 🚀 ValueNotifierで文字数のみ更新(画面全体の再描画を防止)
    _descriptionController.addListener(() {
      _charCount.value = _descriptionController.text.length;
    });
  }
  
  /// 🔍 API商品データから自動入力
  void _autofillFromApiProduct(ApiProduct product) {
    setState(() {
      _isAutofilled = true;
      
      // 基本情報を自動入力
      _skuController.text = product.sku;
      _nameController.text = product.name; // E列: 品名 → 商品名
      
      if (product.brand != null && product.brand!.isNotEmpty) {
        _brandController.text = product.brand!;
      }
      
      if (product.size != null && product.size!.isNotEmpty) {
        _sizeController.text = product.size!;
      }
      
      // Y列: 現状売価 → 販売価格
      if (product.priceSale != null && product.priceSale! > 0) {
        _priceController.text = product.priceSale.toString();
      }
      
      // A列: バーコード → バーコード
      if (product.barcode != null && product.barcode!.isNotEmpty) {
        _barcodeController.text = product.barcode!;
      }
      
      // L列: 商品ランク → 商品ランク
      if (product.productRank != null && product.productRank!.isNotEmpty) {
        // 商品ランクが有効な値(S/A/B/C/D/E/N)であれば設定
        if (_ranks.contains(product.productRank!.toUpperCase())) {
          _selectedRank = product.productRank!.toUpperCase();
        }
      }
      
      // 🆕 カテゴリを自動入力
      if (product.category != null && product.category!.isNotEmpty) {
        if (_categories.contains(product.category!)) {
          _selectedCategory = product.category!;
        }
      }
      
      // 🆕 商品の状態を自動入力
      if (product.condition != null && product.condition!.isNotEmpty) {
        if (_conditions.contains(product.condition!)) {
          _selectedCondition = product.condition!;
        }
      }
      
      // 🆕 素材を自動入力
      if (product.material != null && product.material!.isNotEmpty) {
        if (_materials.contains(product.material!)) {
          _selectedMaterial = product.material!;
        }
      }
      
      // 🆕 カラーを自動入力（colorControllerではなく_selectedColorを使用）
      if (product.color != null && product.color!.isNotEmpty) {
        _selectedColor = product.color!;
        // カラーオプションに存在する場合はプレビューも設定
        if (_colorOptions.containsKey(product.color!)) {
          _colorPreview = _colorOptions[product.color!]!;
        }
      }
      
      // 🆕 商品の説明を自動入力
      if (product.description != null && product.description!.isNotEmpty) {
        _descriptionController.text = product.description!;
      }
      
      // 📸 画像をImageItemとして復元（ApiProductにimageUrlsがある場合）
      if (product.imageUrls != null && product.imageUrls!.isNotEmpty) {
        _images = product.imageUrls!.asMap().entries.map((entry) {
          return ImageItem.fromUrl(
            id: 'existing_${entry.key}',  // 仮のID
            url: entry.value,
            sequence: entry.key + 1,
            isMain: entry.key == 0,
          );
        }).toList();
      }
    });
  }
  
  /// 📝 既存商品データを読み込み（編集モード）
  void _loadExistingItem(InventoryItem item) {
    setState(() {
      _isAutofilled = true;
      
      // 基本情報
      _nameController.text = item.name;
      _brandController.text = item.brand;
      _priceController.text = item.salePrice?.toString() ?? '';
      
      // API連携フィールド
      if (item.barcode != null) _barcodeController.text = item.barcode!;
      if (item.sku != null) _skuController.text = item.sku!;
      if (item.size != null) _sizeController.text = item.size!;
      
      // 🔧 カテゴリを復元（重要！）
      if (item.category.isNotEmpty && _categories.contains(item.category)) {
        _selectedCategory = item.category;
      }
      
      // 選択項目
      if (item.condition != null && item.condition!.isNotEmpty) {
        // 🔧 条件リストに存在するか確認
        if (_conditions.contains(item.condition!)) {
          _selectedCondition = item.condition!;
        } else {
          // 存在しない場合はそのまま設定（カスタム値）
          _selectedCondition = item.condition!;
        }
      }
      if (item.productRank != null && _ranks.contains(item.productRank)) {
        _selectedRank = item.productRank!;
      }
      if (item.material != null && _materials.contains(item.material)) {
        _selectedMaterial = item.material!;
      }
      if (item.color != null) {
        _selectedColor = item.color!;
        if (_colorOptions.containsKey(item.color!)) {
          _colorPreview = _colorOptions[item.color!]!;
        }
      }
      
      // 商品の説明
      if (item.description != null) {
        _descriptionController.text = item.description!;
      }
      
      // 📸 画像リストを復元
      if (item.imageUrls != null && item.imageUrls!.isNotEmpty) {
        _images = item.imageUrls!.asMap().entries.map((entry) {
          return ImageItem.fromUrl(
            id: 'existing_${entry.key}',
            url: entry.value,
            sequence: entry.key + 1,
            isMain: entry.key == 0,
          );
        }).toList();
      }
    });
  }
  
  /// 📸 カメラ画面へ遷移
  /// 【削除】URL→XFile変換は不要（UUID方式）
  /*
  Future<List<XFile>> _convertUrlsToXFiles(List<String> urls) async {
    final List<XFile> xFiles = [];
    
    for (int i = 0; i < urls.length; i++) {
      try {
        final url = urls[i];
        
        // 🎯 ステップ1: キャッシュを確認（通信量削減）
        final cachedFile = await ImageCacheService.getCachedFile(url);
        if (cachedFile != null) {
          xFiles.add(XFile(cachedFile.path));
          if (kDebugMode) {
            print('✅ キャッシュから取得 (${i + 1}/${urls.length}): ${cachedFile.path}');
          }
          continue;
        }
        
        // 🎯 ステップ2: URLから画像をダウンロード
        if (kDebugMode) {
          print('⬇️ ダウンロード中 (${i + 1}/${urls.length}): $url');
        }
        
        final response = await http.get(Uri.parse(url));
        
        if (response.statusCode == 200) {
          // 一時ファイルとして保存
          final tempDir = await getTemporaryDirectory();
          final fileName = 'existing_${i + 1}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final file = File('${tempDir.path}/$fileName');
          
          await file.writeAsBytes(response.bodyBytes);
          xFiles.add(XFile(file.path));
          
          // キャッシュにも保存
          await ImageCacheService.cacheImage(url, response.bodyBytes);
          
          if (kDebugMode) {
            print('✅ 既存画像変換成功 (${i + 1}/${urls.length}): $fileName');
          }
        } else {
          if (kDebugMode) {
            print('❌ 画像ダウンロード失敗 (${i + 1}/${urls.length}): $url - Status ${response.statusCode}');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ 既存画像変換エラー (${i + 1}/${urls.length}): $e');
        }
      }
    }
    
    return xFiles;
  }
  */
  
  void _goToCameraScreen() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('商品名を入力してください')),
      );
      return;
    }
    
    // ✨ CameraScreenV2へ遷移（UUID方式）
    final result = await Navigator.push<List<ImageItem>>(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => CameraScreenV2(
          itemName: _nameController.text,
          brand: _brandController.text,
          category: _selectedCategory,
          condition: _selectedCondition,
          price: _priceController.text,
          barcode: _barcodeController.text,
          sku: _skuController.text,
          size: _sizeController.text,
          color: _selectedColor,
          productRank: _selectedRank,
          material: _selectedMaterial,
          description: _descriptionController.text,
          existingImages: _images.isNotEmpty ? _images : null,  // 🎯 既存の ImageItem リスト
          aiMeasure: _aiMeasure,  // 📏 AI自動採寸フラグを渡す
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
    
    // ✨ カメラ画面から戻ってきた時の処理（ImageItemリスト）
    if (result != null && result.isNotEmpty) {
      if (kDebugMode) {
        debugPrint('📸 カメラから戻った: ${result.length}枚');
        debugPrint('   前回の_images: ${_images.length}枚');
        
        // 🔍 重複チェック
        final idCounts = <String, int>{};
        for (var img in result) {
          idCounts[img.id] = (idCounts[img.id] ?? 0) + 1;
        }
        final duplicates = idCounts.entries.where((e) => e.value > 1).toList();
        if (duplicates.isNotEmpty) {
          debugPrint('⚠️ resultに重複検出: ${duplicates.length}個');
          for (var dup in duplicates) {
            debugPrint('   - UUID: ${dup.key} (${dup.value}回)');
          }
        } else {
          debugPrint('✅ resultに重複なし');
        }
      }
      
      setState(() {
        _images = result;  // ✨ ImageItemリストを保存
      });
      
      // 撮影完了のフィードバック
      final message = '📸 ${result.length}枚の画像を管理中';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppConstants.successGreen,
        ),
      );
    }
  }
  
  /// 🆕 OCRプロセスを開始（ボタンからの呼び出し）
  /// 
  /// カメラを起動 → 撮影 → OCR解析 → 結果ダイアログ
  Future<void> _startOcrProcess() async {
    // ステップ1: カメラ起動（画像ピッカーを使用してシンプルに）
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    
    if (photo == null) {
      if (kDebugMode) {
        debugPrint('❌ 撮影がキャンセルされました');
      }
      return;
    }
    
    // ステップ2: OCR解析開始
    try {
      // ローディング表示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 16),
              Text('🔍 タグを解析中...'),
            ],
          ),
          duration: Duration(hours: 1), // OCR完了まで表示
          backgroundColor: AppConstants.primaryCyan,
        ),
      );
      
      // 画像データ取得
      final imageBytes = await photo.readAsBytes();
      
      // OCR実行
      final ocrService = OcrService();
      final ocrResult = await ocrService.analyzeTag(imageBytes);
      
      // ローディング非表示
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      // ステップ3: 結果ダイアログ表示
      _showOcrResultDialog(ocrResult);
      
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ OCR解析エラー: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      if (kDebugMode) {
        debugPrint('❌ OCR解析エラー: $e');
      }
    }
  }
  
  /// 🆕 OCR結果ダイアログ表示
  /// 
  /// ユーザーが結果を確認して登録できるUI
  void _showOcrResultDialog(OcrResult ocrResult) {
    final brand = ocrResult.brand ?? '';
    final material = ocrResult.material ?? '';
    final country = ocrResult.country ?? '';
    final size = ocrResult.size ?? '';
    final confidence = ocrResult.confidence;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: AppConstants.successGreen),
            SizedBox(width: 8),
            Text("OCR解析結果"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (brand.isNotEmpty) _buildResultRow("ブランド", brand),
            if (material.isNotEmpty) _buildResultRow("素材", material),
            if (country.isNotEmpty) _buildResultRow("原産国", country),
            if (size.isNotEmpty) _buildResultRow("サイズ", size),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: confidence > 0.7 ? Colors.green[50] : Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    confidence > 0.7 ? Icons.check_circle : Icons.warning,
                    size: 16,
                    color: confidence > 0.7 ? Colors.green : Colors.orange,
                  ),
                  SizedBox(width: 8),
                  Text(
                    "信頼度: ${(confidence * 100).toStringAsFixed(0)}%",
                    style: TextStyle(
                      fontSize: 12,
                      color: confidence > 0.7 ? Colors.green[700] : Colors.orange[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("キャンセル", style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              // 結果を登録
              setState(() {
                if (brand.isNotEmpty) _brandController.text = brand;
                if (material.isNotEmpty) _selectedMaterial = material;
                if (size.isNotEmpty) _sizeController.text = size;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ タグ情報を登録しました'),
                  backgroundColor: AppConstants.successGreen,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryCyan,
            ),
            child: Text("登録する", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  
  /// 🆕 OCR結果行ウィジェット
  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppConstants.textGrey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: AppConstants.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// OCR文字認識処理（旧トグル方式 - 後方互換性のため残す）
  /// 
  /// タグ画像から素材・ブランド情報を自動抽出
  Future<void> _performOcrAnalysis(ImageItem imageItem) async {
    try {
      if (kDebugMode) {
        debugPrint('🔍 OCR解析開始: ${imageItem.id}');
      }
      
      // ローディング表示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 16),
              Text('🔍 タグを解析中...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );
      
      // 画像データを取得
      final imageBytes = await _getImageBytes(imageItem);
      if (imageBytes == null) {
        throw Exception('画像データの取得に失敗しました');
      }
      
      // OCR解析実行
      final ocrService = OcrService();
      final result = await ocrService.analyzeTag(imageBytes);
      
      // ローディングを閉じる
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      if (result.hasValidData) {
        // 結果を入力欄に反映
        setState(() {
          if (result.brand != null && result.brand!.isNotEmpty) {
            _brandController.text = result.brand!;
          }
          if (result.material != null && result.material!.isNotEmpty) {
            _selectedMaterial = result.material!;
          }
          if (result.size != null && result.size!.isNotEmpty) {
            _sizeController.text = result.size!;
          }
        });
        
        // 成功メッセージ
        String successMessage = '✅ タグ情報を自動入力しました';
        if (result.confidence < 0.7) {
          successMessage += '\n（信頼度: ${(result.confidence * 100).toStringAsFixed(0)}% - 内容を確認してください）';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: AppConstants.successGreen,
            duration: const Duration(seconds: 3),
          ),
        );
        
        if (kDebugMode) {
          debugPrint('✅ OCR解析成功: $result');
        }
      } else {
        // データが抽出できなかった
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ タグ情報を読み取れませんでした\n手動で入力してください'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // エラー処理
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ OCR解析エラー: $e\n手動で入力してください'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      
      if (kDebugMode) {
        debugPrint('❌ OCR解析エラー: $e');
      }
    }
  }
  
  /// 画像データをバイト配列で取得
  Future<Uint8List?> _getImageBytes(ImageItem imageItem) async {
    try {
      // bytesが直接ある場合はそれを使用
      if (imageItem.bytes != null) {
        return imageItem.bytes;
      }
      
      // Webの場合はURLから取得、モバイルの場合はファイルから取得
      if (kIsWeb) {
        // URLから画像データを取得
        if (imageItem.url != null) {
          final response = await http.get(Uri.parse(imageItem.url!));
          if (response.statusCode == 200) {
            return response.bodyBytes;
          }
        }
      } else {
        // ローカルファイルから取得
        if (imageItem.file != null) {
          final file = File(imageItem.file!.path);
          if (await file.exists()) {
            return await file.readAsBytes();
          }
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 画像データ取得エラー: $e');
      }
      return null;
    }
  }
  
  // Category options
  final List<String> _categories = [
    '選択してください',
    'トップス',
    'ジャケット/アウター',
    'パンツ',
    'スカート',
    'ワンピース',
    'シューズ',
    'バッグ',
    'アクセサリー',
    'その他',
  ];
  
  // Condition options
  final List<String> _conditions = [
    '選択してください',
    '新品・未使用',
    '未使用に近い',
    '目立った傷や汚れなし',
    'やや傷や汚れあり',
    '傷や汚れあり',
    '全体的に状態が悪い',
  ];
  
  // Brand options (popular brands)
  final List<String> _allBrands = [
    'Uniqlo',
    'GU',
    'ZARA',
    'H&M',
    'Nike',
    'Adidas',
    'Levi\'s',
    'Gap',
    'Muji',
    'Beams',
    'United Arrows',
    'Gucci',
    'Louis Vuitton',
    'Prada',
    'Chanel',
    'Hermès',
    'Burberry',
    'Ralph Lauren',
    'Tommy Hilfiger',
    'Calvin Klein',
    'The North Face',
    'Patagonia',
    'Columbia',
    'Champion',
    'New Balance',
    'Converse',
    'Vans',
    'Supreme',
    'Stussy',
    'Carhartt',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _priceController.dispose();
    _barcodeController.dispose();
    _skuController.dispose();
    _sizeController.dispose();
    _descriptionController.dispose();
    _charCount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: AppConstants.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("新規商品追加", style: AppConstants.subHeaderStyle),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('下書きを保存しました')),
              );
            },
            child: Text("保存", style: TextStyle(color: AppConstants.primaryCyan, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          // 🔍 自動入力バッジ
          if (_isAutofilled)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppConstants.successGreen.withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: AppConstants.successGreen, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '商品情報が自動入力されました。必要に応じて修正してください。',
                      style: TextStyle(
                        color: AppConstants.successGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photo Area
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 📸 画像サムネイル表示（UUID方式）
                      if (_images.isNotEmpty) ...[
                        Container(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _images.length,
                            itemBuilder: (context, index) {
                              final imageItem = _images[index];
                              return Container(
                                margin: EdgeInsets.only(right: 8),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: _buildImageWidget(imageItem),
                                    ),
                                    // 削除ボタン
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () async {
                                          setState(() {
                                            _images.removeAt(index);
                                          });
                                          
                                          if (kDebugMode) {
                                            debugPrint('🗑️ 画像を削除: ${imageItem.id}');
                                            debugPrint('📸 残りの画像数: ${_images.length}');
                                          }
                                          
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Row(
                                                children: [
                                                  Icon(Icons.delete, color: Colors.white, size: 18),
                                                  SizedBox(width: 8),
                                                  Text('画像を削除しました（サーバーからも削除中...）'),
                                                ],
                                              ),
                                              backgroundColor: Colors.red,
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          padding: EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: 16),
                      ],
                      
                      // 写真を追加ボタン
                      GestureDetector(
                        onTap: _goToCameraScreen,
                        child: Container(
                          width: double.infinity,
                          height: _images.isEmpty ? 200 : 60,
                          decoration: BoxDecoration(
                            color: _images.isEmpty ? Colors.transparent : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: _images.isEmpty ? null : Border.all(color: AppConstants.primaryCyan, width: 2),
                          ),
                          child: _images.isEmpty
                              ? Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.asset(
                                        'assets/images/denim_jacket.jpg',
                                        width: double.infinity,
                                        height: 200,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.camera_alt, color: AppConstants.primaryCyan, size: 18),
                                          SizedBox(width: 8),
                                          Text("写真を追加", style: TextStyle(fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_a_photo, color: AppConstants.primaryCyan, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        "さらに写真を追加",
                                        style: TextStyle(
                                          color: AppConstants.primaryCyan,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),

                  // Basic Info
                  Text("基本情報", style: TextStyle(fontWeight: FontWeight.bold, color: AppConstants.textGrey)),
                  SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildInputField("バーコード", _barcodeController, "バーコードを入力してください"),
                        Divider(),
                        _buildInputField("SKU (商品管理ID)", _skuController, "SKUを入力してください"),
                        Divider(),
                        _buildBrandField(),
                        Divider(),
                        _buildInputField("商品名", _nameController, "商品名を入力してください"),
                        Divider(),
                        _buildSelectTile("商品ランク", _selectedRank, () => _showRankPicker(), 
                          isPlaceholder: _selectedRank == '選択してください'),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),

                  // Details
                  Text("商品の詳細", style: TextStyle(fontWeight: FontWeight.bold, color: AppConstants.textGrey)),
                  SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildSelectTile("カテゴリ", _selectedCategory, () => _showCategoryPicker()),
                        Divider(),
                        _buildSelectTile("商品の状態", _selectedCondition, () => _showConditionPicker(), 
                          isPlaceholder: _selectedCondition == '選択してください'),
                        Divider(),
                        _buildSelectTile("素材", _selectedMaterial, () => _showMaterialPicker()),
                        Divider(),
                        _buildColorSelectTile(),
                        Divider(),
                        _buildInputField("サイズ", _sizeController, "サイズを入力してください (例: M, L, XL)"),
                        Divider(),
                        _buildSwitchTile("AI自動採寸", "撮影時に自動でサイズを計測します", _aiMeasure, (v) {
                          setState(() => _aiMeasure = v);
                          print('========================================');
                          print('AI自動採寸トグル変更: ${v ? "ON" : "OFF"}');
                          print('========================================');
                        }),
                        Divider(),
                        _buildOcrButton(),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  
                  // Description
                  Text("商品の説明", style: TextStyle(fontWeight: FontWeight.bold, color: AppConstants.textGrey)),
                  SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[300]!, width: 1),
                    ),
                    child: TextField(
                      controller: _descriptionController,
                      maxLines: 6,
                      minLines: 6,
                      maxLength: 1000,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: "傷や汚れ、特徴などを入力してください...\n\n例：\n・着用回数：3回程度\n・目立った傷や汚れなし\n・サイズ感：普通\n・素材感：柔らかめ",
                        hintStyle: TextStyle(color: AppConstants.textGrey, fontSize: 14),
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                        counterText: '',
                      ),
                      style: TextStyle(fontSize: 14, color: AppConstants.textDark, height: 1.5),
                    ),
                  ),
                  SizedBox(height: 8),
                  // 🚀 ValueListenableBuilderで文字数部分のみ再描画
                  Align(
                    alignment: Alignment.centerRight,
                    child: ValueListenableBuilder<int>(
                      valueListenable: _charCount,
                      builder: (context, count, _) => Text(
                        '$count/1000',
                        style: TextStyle(fontSize: 12, color: AppConstants.textGrey),
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  
                  // Measurements Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("サイズ (cm)", style: TextStyle(fontWeight: FontWeight.bold, color: AppConstants.textGrey)),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppConstants.primaryCyan.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.auto_awesome, size: 12, color: AppConstants.primaryCyan),
                            SizedBox(width: 4),
                            Text("AI自動採寸", style: TextStyle(fontSize: 10, color: AppConstants.primaryCyan, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildMeasurementField("着丈", _lengthController)),
                            SizedBox(width: 12),
                            Expanded(child: _buildMeasurementField("身幅", _widthController)),
                          ],
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _buildMeasurementField("肩幅", _shoulderController)),
                            SizedBox(width: 12),
                            Expanded(child: _buildMeasurementField("袖丈", _sleeveController)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  
                  // Price
                  Text("価格と配送", style: TextStyle(fontWeight: FontWeight.bold, color: AppConstants.textGrey)),
                  SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildPriceField("販売価格", _priceController),
                        Divider(),
                        _buildSelectTile("配送料の負担", "送料込み(出品者負担)", () {}),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Bottom CTA
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
            ),
            child: CustomButton(
              text: "次へ：商品詳細",
              icon: Icons.arrow_forward,
              onPressed: () {
                if (_nameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('商品名を入力してください')),
                  );
                  return;
                }
                if (_selectedCondition == '選択してください') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('商品の状態を選択してください')),
                  );
                  return;
                }
                
                // 🔍 AI自動採寸トグルの状態をデバッグ出力（強制出力）
                print('');
                print('🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥');
                print('📱 商品詳細画面への遷移');
                print('🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥');
                print('📏 AI自動採寸トグル: ${_aiMeasure ? "✅ ON" : "❌ OFF"}');
                print('📸 画像数: ${_images.length}枚');
                print('📦 商品名: ${_nameController.text}');
                print('🏷️  SKU: ${_skuController.text}');
                print('→ DetailScreen に aiMeasureEnabled=${_aiMeasure} を渡す');
                print('🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥');
                print('');
                
                // 🚀 商品詳細画面へ直接遷移
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => DetailScreen(
                      itemName: _nameController.text,
                      brand: _brandController.text.isEmpty ? '' : _brandController.text,
                      category: _selectedCategory,  // 🔧 そのまま渡す（DetailScreenで判定）
                      condition: _selectedCondition,
                      price: _priceController.text,
                      barcode: _barcodeController.text,
                      sku: _skuController.text,
                      size: _sizeController.text,
                      color: _selectedColor,  // 🔧 そのまま渡す（DetailScreenで判定）
                      productRank: _selectedRank,  // 🔧 そのまま渡す（DetailScreenで判定）
                      material: _selectedMaterial,  // 🔧 そのまま渡す（DetailScreenで判定）
                      description: _descriptionController.text,
                      images: _images.isEmpty ? null : _images,  // 📸 画像アイテムリスト（UUID管理）
                      // 🆕 product_masterから引き継ぐ追加フィールド
                      brandKana: widget.prefillData?.brandKana,
                      categorySub: widget.prefillData?.categorySub,
                      priceCost: widget.prefillData?.priceCost,
                      season: widget.prefillData?.season,
                      releaseDate: widget.prefillData?.releaseDate,
                      buyer: widget.prefillData?.buyer,
                      storeName: widget.prefillData?.storeName,
                      priceRef: widget.prefillData?.priceRef,
                      priceSale: widget.prefillData?.priceSale,
                      priceList: widget.prefillData?.priceList,
                      location: widget.prefillData?.location,
                      stockQuantity: widget.prefillData?.stockQuantity,
                      // 📏 実寸データ
                      length: _lengthController.text,
                      width: _widthController.text,
                      shoulder: _shoulderController.text,
                      sleeve: _sleeveController.text,
                      // 📏 AI自動採寸フラグ（ユーザーのスイッチ設定を反映）
                      aiMeasureEnabled: _aiMeasure,
                    ),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    transitionDuration: const Duration(milliseconds: 200),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 📸 ImageItemからWidgetを生成
  /// 
  /// 🔧 v2.0 改善点:
  /// - キャッシュバスティングを適用（古い画像が表示される問題を解決）
  Widget _buildImageWidget(ImageItem imageItem) {
    if (imageItem.bytes != null) {
      // 🔧 バイトデータがある場合（最優先）
      return Image.memory(
        imageItem.bytes!,
        width: 100,
        height: 120,
        fit: BoxFit.cover,
      );
    } else if (imageItem.file != null) {
      // XFileが存在する場合
      return kIsWeb
          ? Image.network(
              imageItem.file!.path,
              width: 100,
              height: 120,
              fit: BoxFit.cover,
            )
          : Image.file(
              File(imageItem.file!.path),
              width: 100,
              height: 120,
              fit: BoxFit.cover,
            );
    } else if (imageItem.url != null) {
      // URLが存在する場合 - 🔧 キャッシュバスティングを適用
      final cacheBustedUrl = ImageCacheService.getCacheBustedUrl(imageItem.url!);
      return Image.network(
        cacheBustedUrl,
        width: 100,
        height: 120,
        fit: BoxFit.cover,
        // ✅ Phase 1のUUID形式でキャッシュ衝突は回避済み
        // ✅ ?t=timestamp パラメータでキャッシュバスティング実現
        // ❌ Cache-Controlヘッダーは削除（CORS問題回避）
        errorBuilder: (context, error, stackTrace) {
          if (kDebugMode) {
            debugPrint('❌ 画像読み込みエラー: $error');
          }
          return Container(
            width: 100,
            height: 120,
            color: Colors.grey[200],
            child: Icon(Icons.broken_image, size: 40, color: Colors.grey[400]),
          );
        },
      );
    } else {
      // ファイルもURLもない場合
      return Container(
        width: 100,
        height: 120,
        color: Colors.grey[200],
        child: Icon(Icons.image, size: 40, color: Colors.grey[400]),
      );
    }
  }

  Widget _buildInputField(String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: AppConstants.textGrey)),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: TextFormField(
            controller: controller,
            style: TextStyle(fontSize: 16, color: AppConstants.textDark),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: AppConstants.textGrey, fontSize: 16),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBrandField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("ブランド", style: TextStyle(fontSize: 12, color: AppConstants.textGrey)),
        SizedBox(height: 8),
        InkWell(
          onTap: () => _showBrandPicker(),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _brandController.text.isEmpty ? 'ブランドを選択...' : _brandController.text,
                    style: TextStyle(
                      fontSize: 16,
                      color: _brandController.text.isEmpty ? AppConstants.textGrey : AppConstants.textDark,
                    ),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: AppConstants.textGrey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceField(String label, TextEditingController controller) {
    return InkWell(
      onTap: () => _showPricePicker(controller),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: AppConstants.textGrey)),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      "¥",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.textDark,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      controller.text.isEmpty ? "0" : controller.text,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: controller.text.isEmpty ? AppConstants.textGrey : AppConstants.textDark,
                      ),
                    ),
                  ],
                ),
                Icon(Icons.edit, color: AppConstants.textGrey, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPricePicker(TextEditingController controller) {
    final TextEditingController tempController = TextEditingController(text: controller.text);
    
    showDialog(
      context: context,
      builder: (context) {
        return _PricePickerDialog(
          controller: controller,
          tempController: tempController,
          onConfirm: () {
            setState(() {
              controller.text = tempController.text;
            });
          },
        );
      },
    );
  }

  Widget _buildSelectTile(String label, String value, VoidCallback onTap, {bool isPlaceholder = false}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Row(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: isPlaceholder ? AppConstants.textGrey : AppConstants.primaryCyan,
                    fontSize: 16,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.chevron_right, color: AppConstants.textGrey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, Function(bool) onChanged) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: AppConstants.textGrey)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppConstants.primaryCyan.withValues(alpha: 0.5),
            activeColor: AppConstants.primaryCyan,
          ),
        ],
      ),
    );
  }

  // 📏 実寸入力フィールド
  Widget _buildMeasurementField(String label, TextEditingController controller) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: controller.text.isNotEmpty 
              ? AppConstants.primaryCyan 
              : Colors.grey[300]!,
          width: controller.text.isNotEmpty ? 2 : 1,
        ),
      ),
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppConstants.textGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppConstants.primaryCyan,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: "0",
              hintStyle: TextStyle(color: Colors.grey[400]),
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            onChanged: (value) {
              setState(() {}); // 枠線の色を更新
            },
          ),
          SizedBox(height: 4),
          if (controller.text.isNotEmpty)
            Icon(
              Icons.check_circle,
              size: 16,
              color: AppConstants.primaryCyan,
            ),
        ],
      ),
    );
  }

  void _showBrandPicker() {
    String searchQuery = '';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredBrands = searchQuery.isEmpty
                ? _allBrands
                : _allBrands
                    .where((brand) => brand.toLowerCase().contains(searchQuery.toLowerCase()))
                    .toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text("ブランドを選択", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 16),
                  // Search field
                  TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'ブランド名で検索...',
                      prefixIcon: Icon(Icons.search, color: AppConstants.primaryCyan),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppConstants.borderGrey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppConstants.primaryCyan, width: 2),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (value) {
                      setModalState(() {
                        searchQuery = value;
                      });
                    },
                  ),
                  SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredBrands.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(filteredBrands[index]),
                          trailing: _brandController.text == filteredBrands[index]
                              ? Icon(Icons.check, color: AppConstants.primaryCyan)
                              : null,
                          onTap: () {
                            setState(() {
                              _brandController.text = filteredBrands[index];
                            });
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 16),
              Text("カテゴリを選択", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(_categories[index]),
                      trailing: _selectedCategory == _categories[index]
                          ? Icon(Icons.check, color: AppConstants.primaryCyan)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedCategory = _categories[index];
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRankPicker() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 16),
              Text("商品ランクを選択", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text("L列のデータに対応", style: TextStyle(fontSize: 12, color: AppConstants.textGrey)),
              SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _ranks.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(_ranks[index]),
                      trailing: _selectedRank == _ranks[index]
                          ? Icon(Icons.check, color: AppConstants.primaryCyan)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedRank = _ranks[index];
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showConditionPicker() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 16),
              Text("商品の状態を選択", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _conditions.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(_conditions[index]),
                      trailing: _selectedCondition == _conditions[index]
                          ? Icon(Icons.check, color: AppConstants.primaryCyan)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedCondition = _conditions[index];
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  // 🆕 OCR文字認識ボタン
  Widget _buildOcrButton() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: ElevatedButton.icon(
        onPressed: _startOcrProcess,
        icon: Icon(Icons.camera_alt, color: Colors.white),
        label: Text(
          "📷 タグを撮影してOCR読み取り",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.primaryCyan,
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }
  
  // 🆕 カラー選択タイル(カラープレビュー付き)
  Widget _buildColorSelectTile() {
    return InkWell(
      onTap: () => _showColorPicker(),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("カラー", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Row(
              children: [
                Text(
                  _selectedColor,
                  style: TextStyle(
                    color: AppConstants.primaryCyan,
                    fontSize: 16,
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _colorPreview,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.chevron_right, color: AppConstants.textGrey),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // 🆕 素材ピッカー
  void _showMaterialPicker() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 16),
              Text("素材を選択", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _materials.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(_materials[index]),
                      trailing: _selectedMaterial == _materials[index]
                          ? Icon(Icons.check, color: AppConstants.primaryCyan)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedMaterial = _materials[index];
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  // 🆕 カラーピッカー
  void _showColorPicker() {
    String searchQuery = '';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredColors = searchQuery.isEmpty
                ? _colorOptions.entries.toList()
                : _colorOptions.entries
                    .where((entry) => entry.key.toLowerCase().contains(searchQuery.toLowerCase()))
                    .toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text("カラーを選択", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 16),
                  // Search field
                  TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'カラー名で検索 or 自由入力...',
                      prefixIcon: Icon(Icons.search, color: AppConstants.primaryCyan),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppConstants.borderGrey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppConstants.primaryCyan, width: 2),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (value) {
                      setModalState(() {
                        searchQuery = value;
                      });
                    },
                    onSubmitted: (value) {
                      // Free input - use custom color
                      if (value.isNotEmpty && !_colorOptions.containsKey(value)) {
                        setState(() {
                          _selectedColor = value;
                          _colorPreview = Colors.grey[400]!; // Default color for custom input
                        });
                        Navigator.pop(context);
                      }
                    },
                  ),
                  SizedBox(height: 16),
                  // Show free input option if search doesn't match
                  if (searchQuery.isNotEmpty && filteredColors.isEmpty)
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppConstants.primaryCyan.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.add_circle_outline, color: AppConstants.primaryCyan),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '"$searchQuery" として追加',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: AppConstants.primaryCyan),
                                ),
                                Text(
                                  'タップまたはEnterで確定',
                                  style: TextStyle(fontSize: 12, color: AppConstants.textGrey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredColors.length,
                      itemBuilder: (context, index) {
                        final entry = filteredColors[index];
                        return ListTile(
                          leading: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: entry.value,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey[300]!, width: 2),
                            ),
                          ),
                          title: Text(entry.key),
                          trailing: _selectedColor == entry.key
                              ? Icon(Icons.check, color: AppConstants.primaryCyan)
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedColor = entry.key;
                              _colorPreview = entry.value;
                            });
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// 🔧 価格入力ダイアログ（StatefulWidget）
class _PricePickerDialog extends StatefulWidget {
  final TextEditingController controller;
  final TextEditingController tempController;
  final VoidCallback onConfirm;

  const _PricePickerDialog({
    required this.controller,
    required this.tempController,
    required this.onConfirm,
  });

  @override
  _PricePickerDialogState createState() => _PricePickerDialogState();
}

class _PricePickerDialogState extends State<_PricePickerDialog> {
  late FocusNode _focusNode;
  bool _hasFocused = false;  // 🔧 フォーカス済みフラグ

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    
    // 🔧 フォーカスリスナーを追加（デバッグ用）
    _focusNode.addListener(() {
      if (kDebugMode) {
        debugPrint('🔍 Price TextField focus: ${_focusNode.hasFocus}');
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🔧 ビルド後にフォーカスを設定（1回だけ）
    if (!_hasFocused) {
      _hasFocused = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_focusNode.hasFocus) {
          _focusNode.requestFocus();
          // 🔧 少し遅延させてから全選択
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted && widget.tempController.text.isNotEmpty) {
              widget.tempController.selection = TextSelection(
                baseOffset: 0,
                extentOffset: widget.tempController.text.length,
              );
            }
          });
        }
      });
    }
    
    return AlertDialog(
      title: Text("販売価格を入力"),
      content: SizedBox(
        width: 280,  // 🔧 固定幅を設定
        child: TextField(
          controller: widget.tempController,
          focusNode: _focusNode,
          keyboardType: kIsWeb ? TextInputType.text : TextInputType.number,  // 🔧 Web環境ではtextに変更
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autofocus: false,  // 🔧 autofocusを無効化（手動でフォーカス管理）
          enableInteractiveSelection: true,  // 🔧 選択を有効化
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          onChanged: (value) {
            // 🔧 入力変更をログ出力（デバッグ用）
            if (kDebugMode) {
              debugPrint('💰 Price input changed: $value');
            }
          },
          decoration: InputDecoration(
            prefixText: "¥ ",
            prefixStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppConstants.textDark),
            hintText: "0",
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.primaryCyan, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.primaryCyan, width: 2),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("キャンセル"),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onConfirm();
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.primaryCyan,
          ),
          child: Text("確定", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
