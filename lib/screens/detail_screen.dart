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
import 'package:measure_master/services/batch_image_upload_service.dart';
import 'package:measure_master/models/product_image.dart';
import 'package:measure_master/models/result.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'dart:io' show File;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';

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
  final List<String>? capturedImages;  // 📸 複数の撮影画像（既存URL）
  final List<XFile>? capturedImageFiles;  // 📸 新規撮影ファイル（XFile）
  
  // 🆕 product_masterから引き継ぐ追加フィールド
  final String? brandKana;        // ブランドカナ
  final String? categorySub;      // カテゴリサブ
  final int? priceCost;           // 価格_コスト
  final String? season;           // 季節
  final String? releaseDate;      // 発売日
  final String? buyer;            // 買い手
  final String? storeName;        // 店舗名
  final int? priceRef;            // 価格参照
  final int? priceSale;           // 価格_セール
  final int? priceList;           // 価格表
  final String? location;         // 位置
  final int? stockQuantity;       // 在庫数量

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
    this.capturedImages,  // オプション（複数画像URL）
    this.capturedImageFiles,  // オプション（新規撮影ファイル）
    // 🆕 追加フィールド（オプション）
    this.brandKana,
    this.categorySub,
    this.priceCost,
    this.season,
    this.releaseDate,
    this.buyer,
    this.storeName,
    this.priceRef,
    this.priceSale,
    this.priceList,
    this.location,
    this.stockQuantity,
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
  
  // ✨ 一括アップロードサービス
  late final BatchImageUploadService _batchUploadService;
  late final ApiService _apiService;
  late final InventoryProvider _inventoryProvider;
  
  // ✨ アップロード進捗
  int _uploadProgress = 0;
  int _uploadTotal = 0;

  @override
  void initState() {
    super.initState();
    
    // ✨ サービス初期化
    _batchUploadService = BatchImageUploadService();
    _apiService = ApiService();
    _inventoryProvider = Provider.of<InventoryProvider>(context, listen: false);
    
    // 初期値を設定（サンプルデータなし）
    _selectedMaterial = widget.material.isNotEmpty && widget.material != '選択してください' ? widget.material : '選択してください';
    _selectedColor = widget.color.isNotEmpty && widget.color != '選択してください' ? widget.color : '選択してください';
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

  // Color options with RGB values
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
                await _saveProduct();
              }
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// ✨ 商品保存処理（BatchImageUploadService使用）
  Future<void> _saveProduct() async {
    try {
      // 1) 画像データを整理
      final existingUrls = widget.capturedImages ?? [];
      final newFiles = widget.capturedImageFiles ?? [];
      
      debugPrint('📦 保存開始: 既存=${existingUrls.length}, 新規=${newFiles.length}');

      // 2) プログレスダイアログ表示（StatefulBuilder使用）
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    '画像アップロード中...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_uploadProgress / $_uploadTotal',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          },
        ),
      );

      // 3) 画像一括アップロード
      List<String> imageUrls = [];
      
      if (existingUrls.isNotEmpty || newFiles.isNotEmpty) {
        final uploadResult = await _batchUploadService.uploadMixedImages(
          existingUrls: existingUrls,
          newImageFiles: newFiles,
          sku: widget.sku.isNotEmpty ? widget.sku : 'NOSKU',
          onProgress: (current, total) {
            setState(() {
              _uploadProgress = current;
              _uploadTotal = total;
            });
          },
        );

        // 4) アップロード結果を処理
        final uploadedImages = uploadResult.fold(
          onSuccess: (images) {
            debugPrint('✅ 画像アップロード成功: ${images.length}枚');
            return images;
          },
          onFailure: (error) {
            Navigator.pop(context); // ダイアログを閉じる
            _showError('画像アップロード失敗: $error');
            return <ProductImage>[];
          },
        );

        if (uploadedImages.isEmpty && (existingUrls.isNotEmpty || newFiles.isNotEmpty)) {
          return; // アップロード失敗時は処理中断
        }

        imageUrls = uploadedImages.map((img) => img.url).toList();
      }
      
      final mainImageUrl = imageUrls.isNotEmpty 
          ? imageUrls.first 
          : 'https://via.placeholder.com/150';

      // 5) InventoryItem作成
      final uniqueId = '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
      
      final newItem = InventoryItem(
        id: uniqueId,
        name: widget.itemName,
        brand: widget.brand,
        imageUrl: mainImageUrl,
        category: (widget.category.isEmpty || widget.category == '選択してください') ? '' : widget.category,
        status: "Ready",
        date: DateTime.now(),
        length: 68,
        width: 52,
        size: _sizeController.text.isEmpty ? "M" : _sizeController.text,
        barcode: _barcodeController.text.isEmpty ? null : _barcodeController.text,
        sku: _skuController.text.isEmpty ? null : _skuController.text,
        productRank: (widget.productRank.isEmpty || widget.productRank == '選択してください') ? null : widget.productRank,
        condition: (widget.condition.isEmpty || widget.condition == '選択してください') ? null : widget.condition,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        color: (_selectedColor.isEmpty || _selectedColor == '選択してください') ? null : _selectedColor,
        material: (_selectedMaterial.isEmpty || _selectedMaterial == '選択してください') ? null : _selectedMaterial,
        salePrice: widget.price.isNotEmpty ? int.tryParse(widget.price) : null,
        imageUrls: imageUrls,
      );

      // 6) Hive保存（ローカル）
      await _inventoryProvider.addItem(newItem);
      debugPrint('✅ Hive保存完了');

      // 7) D1保存（クラウド）+ リトライ機能
      final d1Success = await _saveToD1WithRetry(
        sku: widget.sku.isNotEmpty ? widget.sku : 'NOSKU',
        imageUrls: imageUrls,
        newItem: newItem,
      );

      Navigator.pop(context); // プログレスダイアログを閉じる

      // 8) 結果表示
      if (d1Success) {
        _showSuccess('✅ 保存完了しました！');
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
      } else {
        _showWarningWithRetry(
          '⚠️ ローカル保存完了。クラウド同期は後で再試行できます。',
          newItem,
        );
      }

    } catch (e, stackTrace) {
      Navigator.pop(context);
      debugPrint('❌ 保存エラー: $e');
      debugPrint('スタックトレース: $stackTrace');
      _showError('保存エラー: $e');
    }
  }

  /// D1保存（リトライ機能付き）
  Future<bool> _saveToD1WithRetry({
    required String sku,
    required List<String> imageUrls,
    required InventoryItem newItem,
  }) async {
    const maxRetries = 3;
    
    for (int retryCount = 0; retryCount < maxRetries; retryCount++) {
      try {
        debugPrint('🌐 D1保存試行 ${retryCount + 1}/$maxRetries');
        
        final itemCode = '${newItem.sku}_${DateTime.now().millisecondsSinceEpoch}';
        final itemData = <String, dynamic>{
          'sku': newItem.sku ?? '',
          'itemCode': itemCode,
          'name': newItem.name,
          'barcode': newItem.barcode ?? _barcodeController.text,
          'brand': newItem.brand,
          'category': newItem.category,
          'color': newItem.color ?? _selectedColor,
          'size': newItem.size ?? _sizeController.text,
          'material': newItem.material ?? _selectedMaterial,
          'price': newItem.salePrice,
          'imageUrls': imageUrls,
          'actualMeasurements': {
            'length': newItem.length,
            'width': newItem.width,
          },
          'condition': newItem.condition ?? widget.condition,
          'productRank': newItem.productRank ?? widget.productRank,
          'inspectionNotes': newItem.description ?? _descriptionController.text,
          'photographedAt': DateTime.now().toIso8601String(),
          'photographedBy': 'mobile_app_user',
          'status': 'Ready',
          'upsert': true,
        };

        final d1Result = await _apiService.saveProductItemToD1(itemData);

        if (d1Result != null) {
          debugPrint('✅ D1保存成功');
          return true;
        }
        
      } catch (e) {
        debugPrint('❌ D1保存失敗（${retryCount + 1}/$maxRetries）: $e');
        
        if (retryCount < maxRetries - 1) {
          // 指数バックオフ: 1秒 → 2秒 → 4秒
          await Future.delayed(Duration(seconds: 1 << retryCount));
        }
      }
    }
    
    debugPrint('❌ D1保存: 最大リトライ回数に到達');
    return false;
  }

  /// リトライボタン付き警告表示
  void _showWarningWithRetry(String message, InventoryItem item) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'リトライ',
          textColor: Colors.white,
          onPressed: () => _retryD1Sync(item),
        ),
      ),
    );
  }

  /// D1再同期
  Future<void> _retryD1Sync(InventoryItem item) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final success = await _saveToD1WithRetry(
      sku: item.sku ?? 'NOSKU',
      imageUrls: item.imageUrls ?? [],
      newItem: item,
    );

    Navigator.pop(context);

    if (success) {
      _showSuccess('✅ クラウド同期完了');
    } else {
      _showError('❌ 同期失敗。後で再試行してください。');
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
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

  /// 📸 撮影した画像のサムネイルを表示
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
                  if (kDebugMode) {
                    debugPrint('❌ 画像読み込みエラー: $error');
                  }
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

  /// プレースホルダー画像
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

  /// 採寸カード
  Widget _buildMeasureCard(String label, String value, bool isVerified) {
    return Container(
      width: 110,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isVerified ? AppConstants.primaryCyan : Colors.grey[300]!,
          width: isVerified ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isVerified ? AppConstants.primaryCyan : AppConstants.textDark,
            ),
          ),
          if (isVerified) ...[
            SizedBox(height: 4),
            Icon(Icons.check_circle, size: 16, color: AppConstants.primaryCyan),
          ],
        ],
      ),
    );
  }

  /// 素材選択ダイアログ
  void _showMaterialPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('素材を選択'),
        content: Container(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _materials.length,
            itemBuilder: (context, index) {
              final material = _materials[index];
              return ListTile(
                title: Text(material),
                onTap: () {
                  setState(() {
                    _selectedMaterial = material;
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  /// カラー選択ダイアログ
  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('カラーを選択'),
        content: Container(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _colorOptions.length,
            itemBuilder: (context, index) {
              final colorName = _colorOptions.keys.elementAt(index);
              final color = _colorOptions[colorName]!;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedColor = colorName;
                    _colorPreview = color;
                  });
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _selectedColor == colorName 
                          ? AppConstants.primaryCyan 
                          : Colors.grey[300]!,
                      width: _selectedColor == colorName ? 3 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      colorName,
                      style: TextStyle(
                        fontSize: 10,
                        color: color.computeLuminance() > 0.5 
                            ? Colors.black 
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
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
