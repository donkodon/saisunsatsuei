import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:measure_master/constants.dart';
import 'package:measure_master/core/widgets/custom_button.dart';
import 'package:measure_master/features/inventory/presentation/dashboard_screen.dart';
import 'package:provider/provider.dart';
import 'package:measure_master/features/inventory/logic/inventory_provider.dart';
import 'package:measure_master/features/inventory/domain/item.dart';
import 'package:measure_master/features/inventory/domain/image_item.dart';
import 'package:measure_master/features/auth/logic/company_service.dart';
import 'package:measure_master/features/inventory/data/white_background_service.dart';
import 'package:measure_master/features/inventory/logic/image_upload_coordinator.dart';
import 'package:measure_master/features/inventory/logic/image_diff_manager.dart';
import 'package:measure_master/features/inventory/logic/inventory_saver.dart';
import 'package:measure_master/features/measurement/logic/measurement_service.dart';
import 'package:measure_master/features/measurement/data/measurement_api_client.dart';
import 'package:measure_master/features/measurement/data/measurement_repository.dart';
import 'package:measure_master/core/utils/app_feedback.dart';
import 'package:measure_master/core/services/api_service.dart';
// 🆕 切り出したウィジェット・ヘルパー
import 'package:measure_master/features/inventory/presentation/detail_picker_helpers.dart';
// 🆕 UI セクション
import 'package:measure_master/features/inventory/presentation/detail_screen_image_section.dart';
import 'package:measure_master/features/inventory/presentation/detail_screen_info_section.dart';
// 🆕 保存ロジック mixin
import 'package:measure_master/features/inventory/presentation/detail_save_mixin.dart';

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
  final List<ImageItem>? images;

  // 🆕 product_master から引き継ぐ追加フィールド
  final String? brandKana;
  final String? categorySub;
  final int? priceCost;
  final String? season;
  final String? releaseDate;
  final String? buyer;
  final String? storeName;
  final int? priceRef;
  final int? priceSale;
  final int? priceList;
  final String? location;
  final int? stockQuantity;

  // 📏 実寸データ
  final String? length;
  final String? width;
  final String? shoulder;
  final String? sleeve;

  // 📏 AI自動採寸フラグ
  final bool aiMeasureEnabled;

  // 👤 ユーザー表示名（photographed_by用）
  final String? userDisplayName;

  const DetailScreen({
    super.key,
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
    this.images,
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
    this.length,
    this.width,
    this.shoulder,
    this.sleeve,
    this.aiMeasureEnabled = false,
    this.userDisplayName,
  });

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen>
    with
        DetailPickerHelpers<DetailScreen>,
        DetailSaveMixin<DetailScreen> {

  // ─── 状態変数 ────────────────────────────────────────────────
  late String _selectedMaterial;
  late String _selectedColor;
  Color _colorPreview = Colors.white;
  late List<ImageItem> _currentImages; // 🆕 画像リスト（並び替え対応）

  final TextEditingController _descriptionController =
      TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _skuController = TextEditingController();
  final TextEditingController _sizeController = TextEditingController();
  final ValueNotifier<int> _charCount = ValueNotifier<int>(0);

  // ─── サービス（遅延初期化: 使用直前に生成してinitStateを軽量化）───
  // Provider から直接取得するサービス（initStateで確定）
  late final InventoryProvider _inventoryProvider;
  late final CompanyService _companyService;

  // 💡 Lazy init: 保存ボタン押下時まで生成を遅らせるサービス群
  WhiteBackgroundService? _whiteBackgroundServiceInstance;
  ImageUploadCoordinator? _uploadCoordinatorInstance;
  ImageDiffManager? _diffManagerInstance;
  InventorySaver? _inventorySaverInstance;
  MeasurementService? _measurementServiceInstance;

  // ─── DetailSaveMixin が要求する getter（lazy init） ────────
  @override CompanyService get companyService => _companyService;
  @override InventoryProvider get inventoryProvider => _inventoryProvider;

  @override
  ImageUploadCoordinator get uploadCoordinator {
    _uploadCoordinatorInstance ??= ImageUploadCoordinator();
    return _uploadCoordinatorInstance!;
  }

  @override
  ImageDiffManager get diffManager {
    _diffManagerInstance ??= ImageDiffManager();
    return _diffManagerInstance!;
  }

  @override
  InventorySaver get inventorySaver {
    _inventorySaverInstance ??= InventorySaver(
      inventoryProvider: _inventoryProvider,
      companyService: _companyService,
    );
    return _inventorySaverInstance!;
  }

  @override
  MeasurementService get measurementService {
    _measurementServiceInstance ??= MeasurementService(
      apiClient: MeasurementApiClient(d1ApiUrl: ApiService.d1ApiUrl),
      repository: MeasurementRepository(),
    );
    return _measurementServiceInstance!;
  }

  // WhiteBackgroundService は _initializeWhiteImages でのみ使用
  WhiteBackgroundService get _whiteBackgroundService {
    _whiteBackgroundServiceInstance ??= WhiteBackgroundService();
    return _whiteBackgroundServiceInstance!;
  }

  @override String get widgetSku => widget.sku;
  @override String get widgetItemName => widget.itemName;
  @override String get widgetBrand => widget.brand;
  @override String get widgetCategory => widget.category;
  @override String get widgetCondition => widget.condition;
  @override String get widgetPrice => widget.price;
  @override String get widgetProductRank => widget.productRank;
  @override String? get widgetLength => widget.length;
  @override String? get widgetWidth => widget.width;
  @override String? get widgetShoulder => widget.shoulder;
  @override String? get widgetSleeve => widget.sleeve;
  @override bool get widgetAiMeasureEnabled => widget.aiMeasureEnabled;
  @override List<ImageItem>? get widgetImages => _currentImages; // 🆕 並び替え後の画像を使用
  @override String? get widgetUserDisplayName => widget.userDisplayName;  // 👤 ユーザー表示名

  @override TextEditingController get skuController => _skuController;
  @override TextEditingController get sizeController => _sizeController;
  @override TextEditingController get barcodeController => _barcodeController;
  @override TextEditingController get descriptionController =>
      _descriptionController;

  @override String get selectedMaterial => _selectedMaterial;
  @override String get selectedColor => _selectedColor;

  @override
  void onUploadProgress(int current, int total) =>
      updateUploadProgress(current, total);

  // ─── onSaveComplete（画面遷移） ──────────────────────────────
  @override
  void onSaveComplete(
    BuildContext context,
    dynamic saveResult,
    int deleteFailureCount,
    InventoryItem newItem,
  ) {
    if (saveResult.bothSuccess) {
      if (deleteFailureCount > 0) {
        AppFeedback.showWarning(
          context,
          '✅ 商品保存は完了しましたが、$deleteFailureCount件の古い画像削除に失敗しました。\n'
          '（画像は正常に保存されています）',
        );
      } else {
        AppFeedback.showSuccess(context, '✅ 保存完了しました！');
      }
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const DashboardScreen(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 200),
        ),
        (route) => false,
      );
    } else if (saveResult.hiveOnlySuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ ローカル保存完了。クラウド同期は後で再試行できます。'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'リトライ',
            textColor: Colors.white,
            onPressed: () => retryD1Sync(context, newItem),
          ),
        ),
      );
    } else {
      AppFeedback.showError(context, '❌ 保存に失敗しました');
    }
  }

  // ─── ライフサイクル ──────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    // ✅ Provider 経由のサービスのみ initState で確定（軽量）
    _inventoryProvider =
        Provider.of<InventoryProvider>(context, listen: false);
    _companyService = Provider.of<CompanyService>(context, listen: false);
    // 残りのサービス（Coordinator/DiffManager/Saver/MeasurementService）は
    // 実際に保存ボタンが押されたときに lazy init される

    _selectedMaterial = widget.material.isNotEmpty &&
            widget.material != '選択してください'
        ? widget.material
        : '選択してください';
    _selectedColor =
        widget.color.isNotEmpty && widget.color != '選択してください'
            ? widget.color
            : '選択してください';

    _barcodeController.text = widget.barcode;
    _skuController.text = widget.sku;
    _sizeController.text = widget.size;
    _descriptionController.text = widget.description;
    _descriptionController
        .addListener(() => _charCount.value = _descriptionController.text.length);

    // 🆕 画像リストの初期化
    _currentImages = widget.images != null ? List.from(widget.images!) : [];

    _initializeWhiteImages();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _barcodeController.dispose();
    _skuController.dispose();
    _sizeController.dispose();
    _charCount.dispose();
    // 生成済みの場合のみ dispose
    _measurementServiceInstance?.dispose();
    super.dispose();
  }

  // ─── 白抜き初期化 ────────────────────────────────────────────
  Future<void> _initializeWhiteImages() async {
    if (widget.images == null || widget.images!.isEmpty) return;
    try {
      await _whiteBackgroundService.pairWhiteImages(widget.images!);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ 白抜き初期化失敗: $e');
    }
  }

  // ─── ピッカー ─────────────────────────────────────────────────
  void _showMaterialPicker() {
    showMaterialPickerDialog(context, _selectedMaterial,
        (material) => setState(() => _selectedMaterial = material));
  }

  void _showColorPicker() {
    showColorPickerDialog(context, _selectedColor, (colorName, color) {
      setState(() {
        _selectedColor = colorName;
        _colorPreview = color;
      });
    });
  }

  // ─── build ───────────────────────────────────────────────────
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
        title: Text('新規商品追加', style: AppConstants.subHeaderStyle),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppConstants.primaryCyan.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: Text(
              '保存',
              style: TextStyle(
                  color: AppConstants.primaryCyan,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🎨 画像カルーセル + 白抜き切替
            DetailScreenImageSection(
              images: _currentImages,
            ),
            const SizedBox(height: 24),

            // 📋 商品情報・詳細・実寸・説明
            DetailScreenInfoSection(
              itemName: widget.itemName,
              brand: widget.brand,
              category: widget.category,
              condition: widget.condition,
              price: widget.price,
              productRank: widget.productRank,
              barcodeController: _barcodeController,
              skuController: _skuController,
              sizeController: _sizeController,
              descriptionController: _descriptionController,
              charCount: _charCount,
              selectedMaterial: _selectedMaterial,
              selectedColor: _selectedColor,
              colorPreview: _colorPreview,
              onMaterialTap: _showMaterialPicker,
              onColorTap: _showColorPicker,
              length: widget.length,
              width: widget.width,
              shoulder: widget.shoulder,
              sleeve: widget.sleeve,
            ),
            const SizedBox(height: 30),

            // 💾 商品確定ボタン
            CustomButton(
              text: '商品確定',
              onPressed: () => saveProduct(context),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
