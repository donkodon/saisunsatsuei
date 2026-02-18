import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:measure_master/constants.dart';
import 'package:measure_master/core/widgets/custom_button.dart';
import 'package:measure_master/features/inventory/presentation/dashboard_screen.dart';
import 'package:provider/provider.dart';
import 'package:measure_master/features/inventory/logic/inventory_provider.dart';
import 'package:measure_master/features/inventory/domain/item.dart';
import 'package:measure_master/core/services/image_cache_service.dart';
import 'package:measure_master/features/auth/logic/company_service.dart';
import 'package:measure_master/features/inventory/data/white_background_service.dart';
import 'package:measure_master/features/inventory/domain/image_item.dart';
// 🆕 切り出したウィジェット・ヘルパー mixin
import 'package:measure_master/features/inventory/presentation/detail_image_widgets.dart';
import 'package:measure_master/features/inventory/presentation/detail_picker_helpers.dart';

// 🆕 新しいロジッククラスをインポート
import 'package:measure_master/features/inventory/logic/image_upload_coordinator.dart';
import 'package:measure_master/features/inventory/logic/image_diff_manager.dart';
import 'package:measure_master/features/inventory/logic/inventory_saver.dart';

// 📏 AI自動採寸機能をインポート
import 'package:measure_master/features/measurement/logic/measurement_service.dart';
import 'package:measure_master/features/measurement/data/measurement_api_client.dart';
import 'package:measure_master/features/measurement/data/measurement_repository.dart';
import 'package:measure_master/core/services/api_service.dart';

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
  final List<ImageItem>? images;  // 📸 画像アイテムリスト（UUID管理）
  
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
  
  // 📏 実寸データ
  final String? length;           // 着丈
  final String? width;            // 身幅
  final String? shoulder;         // 肩幅
  final String? sleeve;           // 袖丈
  
  // 📏 AI自動採寸フラグ
  final bool aiMeasureEnabled;    // AI自動採寸を実行するかどうか

  const DetailScreen({super.key, 
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
    this.images,  // オプション（画像アイテムリスト）
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
    // 📏 実寸データ（オプション）
    this.length,
    this.width,
    this.shoulder,
    this.sleeve,
    // 📏 AI自動採寸フラグ（デフォルト: false）
    this.aiMeasureEnabled = false,
  });

  @override
  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen>
    with DetailImageWidgets<DetailScreen>, DetailPickerHelpers<DetailScreen> {
  late String _selectedMaterial;
  late String _selectedColor;
  Color _colorPreview = Colors.white;
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _skuController = TextEditingController();
  final TextEditingController _sizeController = TextEditingController();

  // 🚀 文字数カウンター用のValueNotifier（setState不要で効率的）
  final ValueNotifier<int> _charCount = ValueNotifier<int>(0);
  
  // ✨ 白抜きサービス
  late final WhiteBackgroundService _whiteBackgroundService;
  late final InventoryProvider _inventoryProvider;
  final CompanyService _companyService = CompanyService();
  
  // 🆕 新しいロジッククラス
  late final ImageUploadCoordinator _uploadCoordinator;
  late final ImageDiffManager _diffManager;
  late final InventorySaver _inventorySaver;
  
  // 📏 AI自動採寸サービス
  late final MeasurementService _measurementService;
  
  // ✨ アップロード進捗
  int _uploadProgress = 0;
  int _uploadTotal = 0;
  
  // 🎨 Phase 5: 白抜き画像表示切替状態
  bool _showWhiteBackground = false;

  @override
  void initState() {
    super.initState();
    
    // ✨ サービス初期化
    _whiteBackgroundService = WhiteBackgroundService();
    _inventoryProvider = Provider.of<InventoryProvider>(context, listen: false);
    
    // 🆕 新しいロジッククラスの初期化
    _uploadCoordinator = ImageUploadCoordinator();
    _diffManager = ImageDiffManager();
    
    // 📏 AI自動採寸サービスの初期化
    _measurementService = MeasurementService(
      apiClient: MeasurementApiClient(
        d1ApiUrl: ApiService.d1ApiUrl,
      ),
      repository: MeasurementRepository(),
    );
    _inventorySaver = InventorySaver(inventoryProvider: _inventoryProvider);
    
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
    
    // 🎨 Phase 4: 白抜き画像のペアリング
    _initializeWhiteImages();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _barcodeController.dispose();
    _skuController.dispose();
    _sizeController.dispose();
    _charCount.dispose();
    _measurementService.dispose();  // 📏 AI自動採寸サービスのクリーンアップ
    super.dispose();
  }

  // ※ _materials / _colorOptions は DetailPickerHelpers mixin に移動

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
        title: Text("新規商品追加", style: AppConstants.subHeaderStyle),
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
            // 🎨 Phase 5: 画像カルーセル + 白抜き切替ボタン
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Carousel（複数画像対応）
                SizedBox(
                  height: 120,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      // 📸 画像アイテムがある場合はすべて表示
                      if (widget.images != null && widget.images!.isNotEmpty)
                        ...widget.images!.asMap().entries.map((entry) {
                          final index = entry.key;
                          final imageItem = entry.value;
                          return _buildImageItemThumbnail(
                            imageItem, 
                            isMain: index == 0,  // 最初の画像をメインとする
                            index: index,  // タップ時のプレビュー用
                          );
                        })
                      // プレースホルダー
                      else
                        _buildPlaceholder(isMain: true),
                    ],
                  ),
                ),
                
                // 🎨 Phase 5: 白抜き画像切替ボタン（白抜き画像がある場合のみ表示）
                if (widget.images != null && 
                    widget.images!.any((img) => img.whiteUrl != null))
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _showWhiteBackground = !_showWhiteBackground;
                              });
                              if (kDebugMode) {
                                debugPrint('🎨 Phase 5: 白抜き表示切替 → ${_showWhiteBackground ? "白抜き" : "元画像"}');
                              }
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: _showWhiteBackground 
                                    ? AppConstants.primaryCyan.withValues(alpha: 0.1)
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _showWhiteBackground 
                                      ? AppConstants.primaryCyan 
                                      : Colors.grey[400]!,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _showWhiteBackground 
                                        ? Icons.check_circle 
                                        : Icons.circle_outlined,
                                    size: 18,
                                    color: _showWhiteBackground 
                                        ? AppConstants.primaryCyan 
                                        : Colors.grey[600],
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    _showWhiteBackground ? "白抜き表示中" : "元画像表示中",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _showWhiteBackground 
                                          ? AppConstants.primaryCyan 
                                          : Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
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
                  Divider(height: 1),
                  ListTile(
                    title: Text("サイズ", style: TextStyle(fontSize: 12, color: AppConstants.primaryCyan)),
                    subtitle: Text(widget.size.isEmpty ? "未設定" : widget.size, style: TextStyle(fontWeight: FontWeight.bold, color: AppConstants.textDark)),
                    trailing: Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),

            // Size Measurement Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("サイズ (cm)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryCyan.withValues(alpha: 0.1),
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
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildMeasureCard("着丈", widget.length ?? "", widget.length != null && widget.length!.isNotEmpty)),
                SizedBox(width: 12),
                Expanded(child: _buildMeasureCard("身幅", widget.width ?? "", widget.width != null && widget.width!.isNotEmpty)),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildMeasureCard("肩幅", widget.shoulder ?? "", widget.shoulder != null && widget.shoulder!.isNotEmpty)),
                SizedBox(width: 12),
                Expanded(child: _buildMeasureCard("袖丈", widget.sleeve ?? "", widget.sleeve != null && widget.sleeve!.isNotEmpty)),
              ],
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
                debugPrint('');
                debugPrint('🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥');
                debugPrint('🔘 商品確定ボタンがタップされました');
                debugPrint('🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥');
                debugPrint('');
                await _saveProduct();
              }
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// 🎨 Phase 4: 白抜き画像のペアリング初期化
  Future<void> _initializeWhiteImages() async {
    if (widget.images == null || widget.images!.isEmpty) {
      return;
    }

    try {
      if (kDebugMode) {
        debugPrint('🎨 Phase 4: 白抜き画像の初期化開始');
        debugPrint('📸 widget.images の枚数: ${widget.images!.length}枚');
        
        // 🔍 重複チェック: 同じUUIDが複数存在するか確認
        final idCounts = <String, int>{};
        for (var img in widget.images!) {
          idCounts[img.id] = (idCounts[img.id] ?? 0) + 1;
        }
        final duplicates = idCounts.entries.where((e) => e.value > 1).toList();
        if (duplicates.isNotEmpty) {
          debugPrint('⚠️ 重複検出: ${duplicates.length}個のUUIDが重複しています');
          for (var dup in duplicates) {
            debugPrint('   - UUID: ${dup.key} (${dup.value}回)');
          }
        } else {
          debugPrint('✅ 重複なし: すべてのUUIDがユニーク');
        }
      }

      // 既存画像に白抜きURLをペアリング
      final pairedImages = await _whiteBackgroundService.pairWhiteImages(widget.images!);
      
      // 統計情報を出力
      final stats = _whiteBackgroundService.getWhiteImageStats(pairedImages);
      if (kDebugMode) {
        debugPrint('✅ Phase 4: 白抜き画像ペアリング完了');
        debugPrint('   📊 統計: 全${stats['total']}枚 / 白抜きあり${stats['withWhite']}枚 / カバー率${stats['coverage']}%');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Phase 4: 白抜き画像の初期化失敗: $e');
      }
    }
  }

  /// ✨ 商品保存処理（BatchImageUploadService使用）
  /// ✨ 商品保存処理（リファクタリング版）
  /// 
  /// 🎯 改善点:
  /// - ImageUploadCoordinator: 画像アップロード調整
  /// - ImageDiffManager: 差分削除管理
  /// - InventorySaver: Hive + D1保存
  /// - コード量を約400行 → 約200行に削減
  Future<void> _saveProduct() async {
    // 🔥 関数実行確認ログ（最優先）
    debugPrint('');
    debugPrint('🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥');
    debugPrint('🚀 _saveProduct() 関数が呼ばれました！');
    debugPrint('🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥');
    debugPrint('');
    
    try {
      // ========================================
      // Phase 1: 古い画像URLを取得（差分削除用）
      // ========================================
      List<String> oldImageUrls = [];
      List<String> oldWhiteUrls = [];
      List<String> oldMaskUrls = [];
      List<String> oldPImageUrls = [];
      List<String> oldFImageUrls = [];
      
      if (widget.sku.isNotEmpty) {
        final oldItem = _inventoryProvider.findBySku(widget.sku);
        if (oldItem != null && oldItem.imageUrls != null) {
          oldImageUrls = oldItem.imageUrls!;
          
          // 白抜き画像とマスク画像を分離
          oldWhiteUrls = oldImageUrls.where((url) => url.contains('_white.jpg')).toList();
          oldMaskUrls = oldImageUrls.where((url) => url.contains('_mask.png')).toList();
          
          debugPrint('📂 DBから取得した古い画像: ${oldImageUrls.length}件');
          debugPrint('   白抜き: ${oldWhiteUrls.length}件, マスク: ${oldMaskUrls.length}件');

          // ──────────────────────────────────────
          // 🔑 オリジナルURLからP/F画像URLを導出
          // ─────────────────────────────────────-
          // measure-master-api D1 の image_urls にはオリジナル画像のみ格納。
          // P画像 (_p.png) / F画像 (_f.png) は Web アプリが別途 R2 に保存しており
          // D1 の image_urls には含まれていない。
          // そのため、オリジナルURLのファイル名から UUID を抽出し
          // companyId + SKU + UUID で P/F URLを再構築して差分削除対象とする。
          final companyIdForDerived = (await _companyService.getCompanyId()) ?? '';
          final skuForDerived = widget.sku;

          // オリジナル画像 URL だけ絞り込み（白抜き・マスク・P/F を除外）
          final oldOriginalUrls = oldImageUrls.where((url) =>
              !url.contains('_white.jpg') &&
              !url.contains('_mask.png') &&
              !url.contains('_p.png') &&
              !url.contains('_P.jpg') &&
              !url.contains('_f.png') &&
              !url.contains('_F.jpg')).toList();

          oldPImageUrls = ImageDiffManager.buildPUrlsFromOriginals(
            originalUrls: oldOriginalUrls,
            companyId: companyIdForDerived,
            sku: skuForDerived,
          );
          oldFImageUrls = ImageDiffManager.buildFUrlsFromOriginals(
            originalUrls: oldOriginalUrls,
            companyId: companyIdForDerived,
            sku: skuForDerived,
          );

          debugPrint('🔑 導出した古いP画像URL: ${oldPImageUrls.length}件');
          debugPrint('🔑 導出した古いF画像URL: ${oldFImageUrls.length}件');
          if (kDebugMode) {
            for (final url in oldPImageUrls) {
              debugPrint('   P: $url');
            }
            for (final url in oldFImageUrls) {
              debugPrint('   F: $url');
            }
          }
        }
      }

      if (!mounted) return;
      // ========================================
      // Phase 2: プログレスダイアログ表示
      // ========================================
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

      // ========================================
      // Phase 3: 画像アップロード（新しいロジッククラス使用）
      // ========================================
      final images = widget.images ?? [];
      final companyId = await _companyService.getCompanyId();
      
      final uploadResult = await _uploadCoordinator.uploadImages(
        images: images,
        sku: widget.sku.isNotEmpty ? widget.sku : 'NOSKU',
        companyId: companyId,
        onProgress: (current, total) {
          setState(() {
            _uploadProgress = current;
            _uploadTotal = total;
          });
        },
      );

      // ========================================
      // Phase 4: 差分削除（新しいロジッククラス使用）
      // ========================================
      int deleteFailureCount = 0;
      
      // 通常画像の削除対象を検出
      final urlsToDelete = _diffManager.detectImagesToDelete(
        oldUrls: oldImageUrls.where((url) => !url.contains('_white.jpg') && !url.contains('_mask.png')).toList(),
        newUrls: uploadResult.allUrls,
      );
      
      // 白抜き・マスク・P画像・F画像の削除対象を検出
      final whiteMaskDiff = _diffManager.detectWhiteMaskImagesToDelete(
        allImageUrls: uploadResult.allUrls,
        oldWhiteUrls: oldWhiteUrls,
        oldMaskUrls: oldMaskUrls,
        oldPImageUrls: oldPImageUrls,   // 🔑 オリジナルURLから導出したP画像URLを渡す
        oldFImageUrls: oldFImageUrls,   // 🔑 オリジナルURLから導出したF画像URLを渡す
        companyId: await _companyService.getCompanyId(),
        sku: widget.sku,
      );
      
      // 削除実行
      if (urlsToDelete.isNotEmpty || whiteMaskDiff.hasImagesToDelete) {
        final deleteResult = await _diffManager.deleteAllImages(
          normalUrls: urlsToDelete,
          whiteUrls: whiteMaskDiff.whiteUrlsToDelete,
          maskUrls: whiteMaskDiff.maskUrlsToDelete,
          pImageUrls: whiteMaskDiff.pImageUrlsToDelete,  // 🔑 P画像を削除対象に追加
          fImageUrls: whiteMaskDiff.fImageUrlsToDelete,  // 🔑 F画像を削除対象に追加
          sku: widget.sku,
        );
        
        deleteFailureCount = deleteResult.totalFailed;
        
        // ローカルキャッシュから削除（P/F URLも含める）
        final allDeletedUrls = [
          ...urlsToDelete,
          ...whiteMaskDiff.whiteUrlsToDelete,
          ...whiteMaskDiff.maskUrlsToDelete,
          ...whiteMaskDiff.pImageUrlsToDelete,  // 🔑 P画像キャッシュも削除
          ...whiteMaskDiff.fImageUrlsToDelete,  // 🔑 F画像キャッシュも削除
        ];
        if (allDeletedUrls.isNotEmpty) {
          await ImageCacheService.invalidateCaches(allDeletedUrls);
        }
      }

      // ========================================
      // Phase 5: InventoryItem作成
      // ========================================
      final mainImageUrl = uploadResult.allUrls.isNotEmpty 
          ? uploadResult.allUrls.first 
          : 'https://via.placeholder.com/150';

      final uniqueId = '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';

      // 🎨 白抜き画像・マスク画像URLを imageUrls に追加（動いていた a5d17e8a と同じ形式に戻す）
      // リファクタリング前: allImageUrls = [...existingUrls, ...imageUrls] で白抜き・マスクも混在していた
      // リファクタリング後: uploadResult.allUrls は通常画像のみで白抜き・マスクが欠落していた
      final seen = <String>{};
      final allImageUrlsWithDerived = <String>[];
      // 1. 通常画像（アップロード済み）
      for (final url in uploadResult.allUrls) {
        if (seen.add(url)) allImageUrlsWithDerived.add(url);
      }
      // 2. 白抜き画像（ImageItem.whiteUrl から収集）
      if (widget.images != null) {
        for (final img in widget.images!) {
          if (img.whiteUrl != null && seen.add(img.whiteUrl!)) {
            allImageUrlsWithDerived.add(img.whiteUrl!);
          }
        }
      }
      debugPrint('📦 Phase 5: 保存URLリスト: ${allImageUrlsWithDerived.length}件（通常${uploadResult.allUrls.length}件 + 白抜き${allImageUrlsWithDerived.length - uploadResult.allUrls.length}件）');
      if (kDebugMode) {
        for (int i = 0; i < allImageUrlsWithDerived.length; i++) {
          final url = allImageUrlsWithDerived[i];
          final type = url.contains('_white.jpg') ? '白抜き' : url.contains('_mask.png') ? 'マスク' : '通常';
          debugPrint('   [$i] ($type) $url');
        }
      }
      
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
        imageUrls: allImageUrlsWithDerived,  // 通常 + 白抜き画像を含む完全リスト
      );

      // ========================================
      // Phase 6: Hive + D1 保存（新しいロジッククラス使用）
      // ========================================
      final saveResult = await _inventorySaver.saveToHiveAndD1(
        item: newItem,
        imageUrls: allImageUrlsWithDerived,  // 通常 + 白抜き画像を含む完全リスト
        additionalData: {
          // 実寸データなど追加情報があればここに
          'length': widget.length,
          'width': widget.width,
          'shoulder': widget.shoulder,
          'sleeve': widget.sleeve,
        },
      );

      if (!mounted) return;
      Navigator.pop(context); // プログレスダイアログを閉じる

      // ========================================
      // Phase 6.5: AI自動採寸（Fire & Forget - バックグラウンド実行）
      // ========================================
      
      // 🔍 強制デバッグログ（kDebugModeに関係なく必ず出力）
      debugPrint('');
      debugPrint('🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥');
      debugPrint('✅ 商品確定ボタンが押されました');
      debugPrint('🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥');
      debugPrint('📏 AI自動採寸トグル: ${widget.aiMeasureEnabled ? "✅ ON" : "❌ OFF"}');
      debugPrint('📸 アップロード済み画像: ${uploadResult.allUrls.isNotEmpty ? "✅ あり" : "❌ なし"}');
      debugPrint('📸 画像数: ${uploadResult.allUrls.length}枚');
      if (uploadResult.allUrls.isNotEmpty) {
        debugPrint('🎯 最初の画像URL: ${uploadResult.allUrls.first}');
      }
      debugPrint('🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥');
      debugPrint('');
      
      if (widget.aiMeasureEnabled && uploadResult.allUrls.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('🔍 ========== AI自動採寸デバッグ情報 ==========');
          debugPrint('📏 AI自動採寸トグル: ${widget.aiMeasureEnabled ? "ON" : "OFF"}');
          debugPrint('📸 アップロード済み画像数: ${uploadResult.allUrls.length}枚');
          debugPrint('🎯 採寸対象画像（シーケンス1）: ${uploadResult.allUrls.first}');
          debugPrint('📦 SKU: ${widget.sku.isNotEmpty ? widget.sku : "NOSKU"}');
          debugPrint('🏢 企業ID取得中...');
        }
        
        // 企業IDを取得（null時は空文字）
        final companyId = await _companyService.getCompanyId() ?? '';
        
        if (kDebugMode) {
          debugPrint('🏢 企業ID: $companyId');
          debugPrint('📂 カテゴリ: ${widget.category}');
          debugPrint('🚀 Replicate API呼び出し開始...');
        }
        
        // バックグラウンドで採寸実行（ユーザーを待たせない）
        try {
          await _measurementService.measureGarmentAsync(
            imageUrl: uploadResult.allUrls.first,  // 最初の画像を使用
            sku: widget.sku.isNotEmpty ? widget.sku : 'NOSKU',
            companyId: companyId,
            category: widget.category,
          );
          
          if (kDebugMode) {
            debugPrint('✅ AI採寸リクエスト送信成功');
            debugPrint('⏳ Webhook経由でD1に結果が保存されます');
            debugPrint('   - measurements (肩幅/袖丈/着丈/身幅)');
            debugPrint('   - ai_landmarks (ランドマーク座標)');
            debugPrint('   - reference_object (基準物体情報)');
            debugPrint('   - measurement_image_url (採寸画像URL)');
            debugPrint('   - mask_image_url (マスク画像URL)');
            debugPrint('==========================================');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('❌ AI採寸リクエスト送信エラー: $e');
            debugPrint('==========================================');
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ AI自動採寸スキップ:');
          if (!widget.aiMeasureEnabled) {
            debugPrint('   理由: AI自動採寸トグルがOFF');
          }
          if (uploadResult.allUrls.isEmpty) {
            debugPrint('   理由: アップロード済み画像が0枚');
          }
        }
      }

      // ========================================
      // Phase 7: 結果表示
      // ========================================
      if (saveResult.bothSuccess) {
        // 削除失敗がある場合は警告付き通知
        if (deleteFailureCount > 0) {
          _showWarning(
            '✅ 商品保存は完了しましたが、$deleteFailureCount件の古い画像削除に失敗しました。\n'
            '（画像は正常に保存されています）'
          );
        } else {
          _showSuccess('✅ 保存完了しました！');
        }
        
        if (!mounted) return;
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
      } else if (saveResult.hiveOnlySuccess) {
        _showWarningWithRetry(
          '⚠️ ローカル保存完了。クラウド同期は後で再試行できます。',
          newItem,
        );
      } else {
        _showError('❌ 保存に失敗しました');
      }

    } catch (e, stackTrace) {
      if (!mounted) return;
      Navigator.pop(context);
      
      // 🔥 強制エラーログ
      debugPrint('');
      debugPrint('❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌');
      debugPrint('❌ _saveProduct() でエラー発生！');
      debugPrint('❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌');
      debugPrint('エラー: $e');
      debugPrint('スタックトレース:');
      debugPrint('$stackTrace');
      debugPrint('❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌');
      debugPrint('');
      
      debugPrint('❌ 保存エラー: $e');
      debugPrint('スタックトレース: $stackTrace');
      _showError('保存エラー: $e');
    }
  }

  /// D1保存（リトライ機能付き）
  // ⚠️ このメソッドは削除されました
  // InventorySaver クラスに移行済み（lib/features/inventory/logic/inventory_saver.dart）

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

    // InventorySaver を使用してD1に再保存
    final saveResult = await _inventorySaver.saveToHiveAndD1(
      item: item,
      imageUrls: item.imageUrls ?? [],
      additionalData: {},
    );

    if (!mounted) return;
    Navigator.pop(context);

    if (saveResult.bothSuccess) {
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

  void _showWarning(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // ────────────────────────────────────────────────────────
  // mixin への委譲ラッパー（呼び出し側のコードを変えずに済む）
  // ────────────────────────────────────────────────────────

  Widget _buildImageItemThumbnail(ImageItem imageItem,
      {bool isMain = false, int? index}) {
    return buildImageItemThumbnail(
      imageItem: imageItem,
      allImages: widget.images,
      showWhiteBackground: _showWhiteBackground,
      isMain: isMain,
      index: index,
    );
  }

  Widget _buildPlaceholder({bool isMain = false}) =>
      buildPlaceholder(isMain: isMain);

  Widget _buildMeasureCard(String label, String value, bool isVerified) =>
      buildMeasureCard(label, value, isVerified);

  void _showMaterialPicker() {
    showMaterialPickerDialog(context, _selectedMaterial, (material) {
      setState(() => _selectedMaterial = material);
    });
  }

  void _showColorPicker() {
    showColorPickerDialog(context, _selectedColor, (colorName, color) {
      setState(() {
        _selectedColor = colorName;
        _colorPreview = color;
      });
    });
  }

  String _getConditionGrade(String condition) =>
      getConditionGrade(condition);
}
