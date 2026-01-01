import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:measure_master/constants.dart';
import 'package:measure_master/widgets/custom_button.dart';
import 'package:measure_master/screens/dashboard_screen.dart';
import 'package:provider/provider.dart';
import 'package:measure_master/providers/inventory_provider.dart';
import 'package:measure_master/models/item.dart';
import 'package:measure_master/services/cloudflare_storage_service.dart';
import 'package:measure_master/services/image_cache_service.dart';
import 'package:measure_master/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'dart:io' show File;
import 'dart:convert';

class DetailScreen extends StatefulWidget {
  final String itemName;
  final String brand;
  final String category;
  final String condition;
  final String price;
  final String barcode;
  final String sku;
  final String size;
  final String color;
  final String productRank;
  final String material;
  final String description;
  final String? capturedImagePath;  // 📸 撮影した画像のパス（オプション・後方互換性）
  final List<String>? capturedImages;  // 📸 複数の撮影画像（新機能）

  DetailScreen({
    required this.itemName,
    required this.brand,
    required this.category,
    required this.condition,
    required this.price,
    required this.barcode,
    required this.sku,
    required this.size,
    required this.color,
    required this.productRank,
    required this.material,
    required this.description,
    this.capturedImagePath,  // オプション（後方互換性）
    this.capturedImages,  // オプション（複数画像）
  });

  @override
  _DetailScreenState createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late String _selectedMaterial;
  late String _selectedColor;
  Color _colorPreview = Colors.white;
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _skuController = TextEditingController();
  final TextEditingController _sizeController = TextEditingController();

  // 🚀 文字数カウンター用のValueNotifier（setState不要で効率的）
  final ValueNotifier<int> _charCount = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    // 初期値を設定
    _selectedMaterial = widget.material.isNotEmpty ? widget.material : 'コットン 100%';
    _selectedColor = widget.color.isNotEmpty ? widget.color : 'ホワイト';
    _barcodeController.text = widget.barcode;
    _skuController.text = widget.sku;
    _sizeController.text = widget.size;
    _descriptionController.text = widget.description;
    
    // 🚀 ValueNotifierで文字数のみ更新（画面全体の再描画を防止）
    _descriptionController.addListener(() {
      _charCount.value = _descriptionController.text.length;
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _barcodeController.dispose();
    _skuController.dispose();
    _sizeController.dispose();
    _charCount.dispose();
    super.dispose();
  }

  // Material options
  final List<String> _materials = [
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

  // Color options with RGB values
  final Map<String, Color> _colorOptions = {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppConstants.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("商品詳細", style: AppConstants.subHeaderStyle),
        centerTitle: true,
        actions: [
          Container(
            margin: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            padding: EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppConstants.primaryCyan.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: Text("保存", style: TextStyle(color: AppConstants.primaryCyan, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Carousel（複数画像対応）
            Container(
              height: 120,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // 📸 複数画像がある場合はすべて表示
                  if (widget.capturedImages != null && widget.capturedImages!.isNotEmpty)
                    ...widget.capturedImages!.asMap().entries.map((entry) {
                      final index = entry.key;
                      final imagePath = entry.value;
                      return _buildCapturedImageThumbnail(
                        imagePath, 
                        isMain: index == 0,  // 最初の画像をメインとする
                      );
                    }).toList()
                  // 📸 単一画像の場合（後方互換性）
                  else if (widget.capturedImagePath != null)
                    _buildCapturedImageThumbnail(widget.capturedImagePath!, isMain: true)
                  // プレースホルダー
                  else
                    _buildPlaceholder(isMain: true),
                ],
              ),
            ),
            SizedBox(height: 24),

            // Title & Info
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("商品名", style: AppConstants.captionStyle),
                  SizedBox(height: 4),
                  Text(widget.itemName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 16),
                  Divider(),
                  SizedBox(height: 16),
                  // カテゴリーとブランド
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("カテゴリー", style: AppConstants.captionStyle),
                            SizedBox(height: 4),
                            Text(widget.category, style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("ブランド", style: AppConstants.captionStyle),
                            SizedBox(height: 4),
                            Text(widget.brand.isEmpty ? '未設定' : widget.brand, style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Divider(),
                  SizedBox(height: 16),
                  // バーコードとSKU
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("バーコード", style: AppConstants.captionStyle),
                            SizedBox(height: 4),
                            Text(_barcodeController.text.isEmpty ? '未設定' : _barcodeController.text, 
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("SKU", style: AppConstants.captionStyle),
                            SizedBox(height: 4),
                            Text(_skuController.text.isEmpty ? '未設定' : _skuController.text, 
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Divider(),
                  SizedBox(height: 16),
                  // 商品ランクとサイズ
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("商品ランク", style: AppConstants.captionStyle),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: AppConstants.primaryCyan.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    widget.productRank == '選択してください' ? '-' : widget.productRank,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppConstants.primaryCyan,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("サイズ", style: AppConstants.captionStyle),
                            SizedBox(height: 4),
                            Text(_sizeController.text.isEmpty ? '未設定' : _sizeController.text, 
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Divider(),
                  SizedBox(height: 16),
                  // カラーと販売価格
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("カラー", style: AppConstants.captionStyle),
                            SizedBox(height: 4),
                            Text(_selectedColor, 
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("販売価格", style: AppConstants.captionStyle),
                            SizedBox(height: 4),
                            Text(
                              widget.price.isEmpty ? '未設定' : '¥${widget.price}', 
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppConstants.primaryCyan,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),

            // Measurements
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("サイズ (cm)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryCyan.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
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
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildMeasureCard("着丈", "68", true)),
                SizedBox(width: 12),
                Expanded(child: _buildMeasureCard("身幅", "52", true)),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildMeasureCard("肩幅", "44", false)),
                SizedBox(width: 12),
                Expanded(child: _buildMeasureCard("袖丈", "21", false)),
              ],
            ),
            SizedBox(height: 24),

            // Details
            Text("商品の状態・詳細", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  ListTile(
                    title: Text("商品の状態", style: TextStyle(fontSize: 12, color: AppConstants.primaryCyan)),
                    subtitle: Text(widget.condition, style: TextStyle(fontWeight: FontWeight.bold, color: AppConstants.textDark)),
                    trailing: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppConstants.primaryCyan, shape: BoxShape.circle),
                      child: Text(_getConditionGrade(widget.condition), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  Divider(height: 1),
                  ListTile(
                    title: Text("素材", style: TextStyle(fontSize: 12, color: AppConstants.primaryCyan)),
                    subtitle: Text(_selectedMaterial, style: TextStyle(fontWeight: FontWeight.bold, color: AppConstants.textDark)),
                    trailing: Icon(Icons.chevron_right),
                    onTap: () => _showMaterialPicker(),
                  ),
                  Divider(height: 1),
                  ListTile(
                    title: Text("カラー", style: TextStyle(fontSize: 12, color: AppConstants.primaryCyan)),
                    subtitle: Text(_selectedColor, style: TextStyle(fontWeight: FontWeight.bold, color: AppConstants.textDark)),
                    trailing: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _colorPreview,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                    ),
                    onTap: () => _showColorPicker(),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),

            // Description
            Text("商品の説明", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
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
            SizedBox(height: 30),
            
            CustomButton(
              text: "商品確定", 
              onPressed: () async {
                // 📸 画像が撮影されていない場合は警告
                final hasImages = (widget.capturedImages != null && widget.capturedImages!.isNotEmpty) 
                                  || widget.capturedImagePath != null;
                if (!hasImages) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.white),
                          SizedBox(width: 8),
                          Text('商品画像を撮影してください'),
                        ],
                      ),
                      backgroundColor: AppConstants.warningOrange,
                    ),
                  );
                  return;
                }
                
                // 📸 すべての画像を取得
                final allImagePaths = widget.capturedImages != null && widget.capturedImages!.isNotEmpty
                  ? widget.capturedImages!
                  : (widget.capturedImagePath != null ? [widget.capturedImagePath!] : <String>[]);

                // Show Loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => Center(child: CircularProgressIndicator()),
                );

                // 📸 すべての画像をアップロード
                List<String> uploadedImageUrls = [];
                
                // 🔑 SKUコードを取得（ファイル名に使用）
                final skuCode = _skuController.text.isNotEmpty ? _skuController.text : 'NOSKU';
                
                // 📸 各画像を順番にアップロード
                for (int i = 0; i < allImagePaths.length; i++) {
                  String imagePath = allImagePaths[i];
                  
                  // 📸 既にCloudflare URLの場合はアップロードをスキップ（過去分は諦める）
                  if (imagePath.startsWith('https://pub-300562464768499b8fcaee903d0f9861.r2.dev') ||
                      imagePath.startsWith('https://image-upload-api.jinkedon2.workers.dev')) {
                    if (kDebugMode) {
                      debugPrint('✅ 既にアップロード済み（スキップ）: $imagePath');
                    }
                    uploadedImageUrls.add(imagePath);
                    continue;
                  }
                  
                  // 📸 Cloudflare Workers経由で画像をアップロード
                  try {
                    Uint8List imageBytes;
                    
                    if (kIsWeb) {
                      // Web環境：blob: URLから画像データを取得
                      if (kDebugMode) {
                        debugPrint('🌐 Web環境：blob URLから画像を読み込み: $imagePath');
                      }
                      
                      // blob: URLからHTTPリクエストで画像データを取得
                      final response = await http.get(Uri.parse(imagePath));
                      if (response.statusCode == 200) {
                        imageBytes = response.bodyBytes;
                        if (kDebugMode) {
                          debugPrint('✅ blob画像読み込み成功: ${imageBytes.length} bytes');
                        }
                      } else {
                        throw Exception('blob画像の読み込みに失敗しました: ${response.statusCode}');
                      }
                    } else {
                      // モバイル環境：ファイルパスから画像を読み込み
                      final imageFile = File(imagePath);
                      imageBytes = await imageFile.readAsBytes();
                      if (kDebugMode) {
                        debugPrint('📱 モバイル環境：ファイル読み込み成功: ${imageBytes.length} bytes');
                      }
                    }
                    
                    // 🔑 SKUコード + 連番でファイルIDを生成
                    // 注意: 撮影時に既に連番が付いているはずなので、ここでは単純にインデックスを使用
                    String fileId;
                    if (skuCode != 'NOSKU') {
                      // SKUがある場合：画像インデックス+1を連番として使用
                      final imageNumber = i + 1;
                      fileId = '${skuCode}_$imageNumber';
                      
                      if (kDebugMode) {
                        debugPrint('✅ SKUベースのファイル名: $fileId (連番: $imageNumber)');
                      }
                    } else {
                      // SKUがない場合：タイムスタンプベース
                      fileId = '${DateTime.now().millisecondsSinceEpoch}_${i + 1}';
                    }
                    
                    if (kDebugMode) {
                      debugPrint('📦 アップロード開始: $fileId (画像${i + 1}/${allImagePaths.length})');
                    }
                    
                    // Workers経由でアップロード
                    final uploadedUrl = await CloudflareWorkersStorageService.uploadImage(
                      imageBytes,
                      fileId,
                    );
                    
                    uploadedImageUrls.add(uploadedUrl);
                    
                    // 📸 アップロード成功時に画像をローカルキャッシュに保存（CORS対策）
                    await ImageCacheService.cacheImage(uploadedUrl, imageBytes);
                    
                    if (kDebugMode) {
                      debugPrint('✅ Cloudflare Workers Upload complete: $uploadedUrl');
                      debugPrint('✅ 画像キャッシュ保存完了');
                    }
                    
                  } catch (e) {
                    // アップロード失敗時はローカルパスを使用（モバイルのみ有効）
                    if (kDebugMode) {
                      debugPrint('❌ Cloudflare Upload error: $e');
                      debugPrint('📁 Using local path: $imagePath');
                    }
                    
                    // エラーメッセージを表示
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.warning, color: Colors.white),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(kIsWeb 
                                ? '画像${i + 1}のアップロードに失敗しました。もう一度お試しください。' 
                                : '画像${i + 1}のアップロードに失敗しました。ローカルに保存します。'),
                            ),
                          ],
                        ),
                        backgroundColor: AppConstants.warningOrange,
                        duration: Duration(seconds: 3),
                      ),
                    );
                    
                    // Web環境でアップロード失敗した場合は、保存処理を中断
                    if (kIsWeb) {
                      Navigator.pop(context);  // ローディングを閉じる
                      return;
                    }
                    
                    // モバイル環境ではローカルパスを追加
                    uploadedImageUrls.add(imagePath);
                  }
                }
                
                // 📸 メイン画像URLを設定（最初の画像）
                String imageUrl = uploadedImageUrls.isNotEmpty ? uploadedImageUrls.first : allImagePaths.first;

                // Hide Loading
                Navigator.pop(context);

                print('🔵 商品確定ボタン押下');
                print('📝 商品の状態: ${widget.condition}');
                print('📝 商品の説明: ${_descriptionController.text}');
                
                // 🔑 ユニークなID生成: タイムスタンプ + マイクロ秒
                final uniqueId = '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
                
                final newItem = InventoryItem(
                  id: uniqueId,
                  name: widget.itemName,
                  brand: widget.brand,
                  imageUrl: imageUrl,  // Uploaded URL or Local Path (メイン画像)
                  category: widget.category,
                  status: "Ready",
                  date: DateTime.now(),
                  length: 68,
                  width: 52,
                  size: _sizeController.text.isEmpty ? "M" : _sizeController.text,
                  barcode: _barcodeController.text,
                  sku: _skuController.text,
                  productRank: widget.productRank == '選択してください' ? '' : widget.productRank,
                  condition: widget.condition,  // 商品の状態を保存
                  description: _descriptionController.text,  // 商品の説明を保存
                  color: _selectedColor,  // カラーを保存
                  material: _selectedMaterial,  // 素材を保存
                  salePrice: widget.price.isNotEmpty ? int.tryParse(widget.price) : null,  // 販売価格を保存
                  imageUrls: uploadedImageUrls,  // 📸 すべての画像URLを保存
                );
                
                print('📦 作成したInventoryItem:');
                print('   condition: ${newItem.condition}');
                print('   description: ${newItem.description}');
                 
                // 💾 Hiveに保存 (オフラインキャッシュ)
                await Provider.of<InventoryProvider>(context, listen: false).addItem(newItem);
                
                // 🌐 Cloudflare D1に保存 (オンライン同期) - 現在は無効化
                // ⚠️ D1 APIが未設定のため、ローカル保存のみ実行
                // TODO: D1 APIが準備できたら有効化
                if (kDebugMode) {
                  debugPrint('ℹ️ D1 API保存はスキップ（ローカルHiveに保存済み）');
                }
                /*
                try {
                  final itemData = {
                    'sku': newItem.sku ?? '',
                    'imageUrls': uploadedImageUrls,
                    'actualMeasurements': {
                      'length': newItem.length,
                      'width': newItem.width,
                    },
                    'condition': newItem.condition ?? '',
                    'material': newItem.material ?? '',
                    'productRank': newItem.productRank ?? '',
                    'inspectionNotes': newItem.description ?? '',
                    'status': newItem.status,
                    'photographedBy': 'mobile_app_user',
                  };
                  
                  final apiService = ApiService();
                  final saved = await apiService.saveProductItemToD1(itemData);
                  
                  if (saved && kDebugMode) {
                    debugPrint('✅ D1に実物データ保存成功: ${newItem.sku}');
                  }
                } catch (e) {
                  if (kDebugMode) {
                    debugPrint('⚠️ D1保存エラー (Hiveには保存済み): $e');
                  }
                }
                */
                 
                // 🚀 高速遷移
                Navigator.pushAndRemoveUntil(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => const DashboardScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    transitionDuration: const Duration(milliseconds: 200),
                  ),
                  (route) => false,
                );
              }
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildImageThumbnail(String path, {bool isMain = false}) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(path, width: 100, height: 120, fit: BoxFit.cover),
        ),
        if (isMain)
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppConstants.primaryCyan,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text("メイン", style: TextStyle(color: Colors.white, fontSize: 10)),
            ),
          ),
      ],
    );
  }

  // 📸 撮影した画像のサムネイルを表示
  Widget _buildCapturedImageThumbnail(String imagePath, {bool isMain = false}) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: kIsWeb
            ? Image.network(
                imagePath,  // Web環境では blob: URL をそのまま使用
                width: 100, 
                height: 120, 
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  if (kDebugMode) {
                    debugPrint('❌ Web画像読み込みエラー: $error');
                  }
                  return Container(
                    width: 100,
                    height: 120,
                    color: Colors.grey[200],
                    child: Icon(Icons.image, size: 40, color: Colors.grey[400]),
                  );
                },
              )
            : Image.file(
                File(imagePath), 
                width: 100, 
                height: 120, 
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // エラー時はプレースホルダーを表示
                  return Container(
                    width: 100,
                    height: 120,
                    color: Colors.grey[200],
                    child: Icon(Icons.image, size: 40, color: Colors.grey[400]),
                  );
                },
              ),
        ),
        if (isMain)
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppConstants.primaryCyan,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text("メイン", style: TextStyle(color: Colors.white, fontSize: 10)),
            ),
          ),
      ],
    );
  }

  // 🖼️ 画像がない場合のプレースホルダー
  Widget _buildPlaceholder({bool isMain = false}) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 100,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border.all(color: Colors.grey[300]!, width: 2, strokeAlign: BorderSide.strokeAlignInside),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo, size: 32, color: Colors.grey[400]),
                SizedBox(height: 4),
                Text(
                  '写真を追加',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ),
        if (isMain)
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text("メイン", style: TextStyle(color: Colors.white, fontSize: 10)),
            ),
          ),
      ],
    );
  }

  Widget _buildMeasureCard(String label, String value, bool isVerified) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isVerified ? AppConstants.primaryCyan : Colors.grey[300]!, width: isVerified ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isVerified ? AppConstants.primaryCyan : AppConstants.textGrey)),
              Icon(
                isVerified ? Icons.check_circle : Icons.edit,
                size: 16,
                color: isVerified ? AppConstants.primaryCyan : Colors.grey[300],
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text("cm", style: TextStyle(fontSize: 12, color: AppConstants.textGrey)),
              ),
            ],
          ),
          if (isVerified) ...[
            SizedBox(height: 4),
            Container(height: 4, width: 40, color: AppConstants.primaryCyan),
          ] else ...[
            SizedBox(height: 4),
            Container(height: 4, width: 40, color: Colors.grey[300]),
          ],
        ],
      ),
    );
  }

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

  /// 🌐 外部WEBアプリに商品データを送信
  String _getConditionGrade(String condition) {
    switch (condition) {
      case '新品・未使用':
        return 'S';
      case '未使用に近い':
        return 'A';
      case '目立った傷や汚れなし':
        return 'B';
      case 'やや傷や汚れあり':
        return 'C';
      case '傷や汚れあり':
        return 'D';
      case '全体的に状態が悪い':
        return 'E';
      default:
        return 'N';
    }
  }
}
