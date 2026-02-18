import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:measure_master/constants.dart';
import 'package:measure_master/features/camera/presentation/camera_screen_v2.dart';
import 'package:measure_master/features/inventory/presentation/detail_screen.dart';
import 'package:measure_master/core/widgets/custom_button.dart';
import 'package:measure_master/features/inventory/domain/api_product.dart';
import 'package:measure_master/features/inventory/domain/item.dart';
import 'package:measure_master/features/inventory/domain/image_item.dart';
// image_cache_service は add_item_form_fields.dart 内で使用

// 🆕 切り出したピッカー系 mixin と PricePickerDialog
import 'package:measure_master/features/inventory/presentation/add_item_pickers.dart';
// 🆕 フォームフィールド UI mixin
import 'package:measure_master/features/inventory/presentation/add_item_form_fields.dart';
// 🆕 OCR セクション mixin
import 'package:measure_master/features/inventory/presentation/add_item_ocr_section.dart';
import 'package:measure_master/core/utils/app_feedback.dart';

class AddItemScreen extends StatefulWidget {
  final ApiProduct? prefillData;    // 🔍 検索結果からの自動入力データ
  final InventoryItem? existingItem; // 📝 既存商品データ（編集用）

  const AddItemScreen({super.key, this.prefillData, this.existingItem});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen>
    with
        AddItemPickerMixin<AddItemScreen>,
        AddItemFormFieldsMixin<AddItemScreen>,
        AddItemOcrMixin<AddItemScreen> {

  // ─────────────────────────────────────────────
  // 状態変数
  // ─────────────────────────────────────────────
  bool _aiMeasure = true;
  List<ImageItem> _images = [];
  bool _isAutofilled = false;

  // Form controllers
  final TextEditingController _nameController       = TextEditingController();
  final TextEditingController _brandController      = TextEditingController();
  final TextEditingController _priceController      = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _barcodeController    = TextEditingController();
  final TextEditingController _skuController        = TextEditingController();
  final TextEditingController _sizeController       = TextEditingController();

  // 📏 実寸入力用コントローラー
  final TextEditingController _lengthController   = TextEditingController();
  final TextEditingController _widthController    = TextEditingController();
  final TextEditingController _shoulderController = TextEditingController();
  final TextEditingController _sleeveController   = TextEditingController();

  // 選択値
  String _selectedCategory  = '選択してください';
  String _selectedCondition = '選択してください';
  String _selectedRank      = '選択してください';
  String _selectedMaterial  = '選択してください';
  String _selectedColor     = '選択してください';
  Color  _colorPreview      = Colors.grey[400]!;

  // 🚀 文字数カウンター（setState 不要）
  final ValueNotifier<int> _charCount = ValueNotifier<int>(0);

  // ─────────────────────────────────────────────
  // オプションリスト
  // ─────────────────────────────────────────────

  final List<String> _ranks = ['選択してください', 'S', 'A', 'B', 'C', 'D', 'E', 'N'];

  final List<String> _materials = [
    '選択してください', 'コットン 100%', 'ポリエステル 100%',
    'コットン 80% / ポリエステル 20%', 'ウール 100%',
    'ナイロン 100%', 'レザー', 'デニム', 'リネン 100%', 'シルク 100%', 'その他',
  ];

  final Map<String, Color> _colorOptions = {
    '選択してください': Colors.grey[400]!,
    'ホワイト': Colors.white,
    'ブラック': Colors.black,
    'グレー': Colors.grey,
    'ネイビー': const Color(0xFF001f3f),
    'ブルー': Colors.blue,
    'レッド': Colors.red,
    'ピンク': Colors.pink,
    'イエロー': Colors.yellow,
    'グリーン': Colors.green,
    'ブラウン': Colors.brown,
    'ベージュ': const Color(0xFFF5F5DC),
    'オレンジ': Colors.orange,
    'パープル': Colors.purple,
    'カーキ': const Color(0xFF7C7C54),
    'ボルドー': const Color(0xFF800020),
    'その他': Colors.grey[400]!,
  };

  final List<String> _categories = [
    '選択してください', 'トップス', 'ジャケット/アウター',
    'パンツ', 'スカート', 'ワンピース',
    'シューズ', 'バッグ', 'アクセサリー', 'その他',
  ];

  final List<String> _conditions = [
    '選択してください', '新品・未使用', '未使用に近い',
    '目立った傷や汚れなし', 'やや傷や汚れあり', '傷や汚れあり', '全体的に状態が悪い',
  ];

  final List<String> _allBrands = [
    'Uniqlo', 'GU', 'ZARA', 'H&M', 'Nike', 'Adidas', 'Levi\'s', 'Gap',
    'Muji', 'Beams', 'United Arrows', 'Gucci', 'Louis Vuitton', 'Prada',
    'Chanel', 'Hermès', 'Burberry', 'Ralph Lauren', 'Tommy Hilfiger',
    'Calvin Klein', 'The North Face', 'Patagonia', 'Columbia', 'Champion',
    'New Balance', 'Converse', 'Vans', 'Supreme', 'Stussy', 'Carhartt',
  ];

  // ─────────────────────────────────────────────
  // AddItemOcrMixin への委譲（抽象ゲッター実装）
  // ─────────────────────────────────────────────
  @override
  TextEditingController get ocrBrandController => _brandController;
  @override
  TextEditingController get ocrSizeController  => _sizeController;
  @override
  String get ocrSelectedMaterial => _selectedMaterial;
  @override
  set ocrSelectedMaterial(String v) => _selectedMaterial = v;

  // ─────────────────────────────────────────────
  // ライフサイクル
  // ─────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      debugPrint('AddItemScreen 初期化 / AI採寸初期値: $_aiMeasure');
    }
    if (widget.existingItem != null) {
      _loadExistingItem(widget.existingItem!);
    } else if (widget.prefillData != null) {
      _autofillFromApiProduct(widget.prefillData!);
    }
    _descriptionController.addListener(() {
      _charCount.value = _descriptionController.text.length;
    });
  }

  @override
  void dispose() {
    for (final c in [
      _nameController, _brandController, _priceController,
      _descriptionController, _barcodeController, _skuController,
      _sizeController, _lengthController, _widthController,
      _shoulderController, _sleeveController,
    ]) {
      c.dispose();
    }
    _charCount.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // データ読み込み
  // ─────────────────────────────────────────────

  void _autofillFromApiProduct(ApiProduct product) {
    setState(() {
      _isAutofilled = true;
      _skuController.text  = product.sku;
      _nameController.text = product.name;
      if (product.brand?.isNotEmpty == true)    _brandController.text  = product.brand!;
      if (product.size?.isNotEmpty  == true)    _sizeController.text   = product.size!;
      if ((product.priceSale ?? 0) > 0)          _priceController.text  = product.priceSale.toString();
      if (product.barcode?.isNotEmpty == true)  _barcodeController.text = product.barcode!;
      if (product.productRank != null && _ranks.contains(product.productRank!.toUpperCase())) {
        _selectedRank = product.productRank!.toUpperCase();
      }
      if (product.category?.isNotEmpty == true && _categories.contains(product.category!)) {
        _selectedCategory = product.category!;
      }
      if (product.condition?.isNotEmpty == true && _conditions.contains(product.condition!)) {
        _selectedCondition = product.condition!;
      }
      if (product.material?.isNotEmpty == true && _materials.contains(product.material!)) {
        _selectedMaterial = product.material!;
      }
      if (product.color?.isNotEmpty == true) {
        _selectedColor = product.color!;
        if (_colorOptions.containsKey(product.color!)) {
          _colorPreview = _colorOptions[product.color!]!;
        }
      }
      if (product.description?.isNotEmpty == true) {
        _descriptionController.text = product.description!;
      }
      if (product.imageUrls?.isNotEmpty == true) {
        _images = product.imageUrls!.asMap().entries.map((e) => ImageItem.fromUrl(
          id: 'existing_${e.key}', url: e.value,
          sequence: e.key + 1, isMain: e.key == 0,
        )).toList();
      }
    });
  }

  void _loadExistingItem(InventoryItem item) {
    setState(() {
      _isAutofilled = true;
      _nameController.text  = item.name;
      _brandController.text = item.brand;
      _priceController.text = item.salePrice?.toString() ?? '';
      if (item.barcode != null) _barcodeController.text = item.barcode!;
      if (item.sku     != null) _skuController.text     = item.sku!;
      if (item.size    != null) _sizeController.text    = item.size!;
      if (item.category.isNotEmpty && _categories.contains(item.category)) {
        _selectedCategory = item.category;
      }
      if (item.condition?.isNotEmpty == true) _selectedCondition = item.condition!;
      if (item.productRank != null && _ranks.contains(item.productRank))     _selectedRank    = item.productRank!;
      if (item.material    != null && _materials.contains(item.material))    _selectedMaterial = item.material!;
      if (item.color != null) {
        _selectedColor = item.color!;
        if (_colorOptions.containsKey(item.color!)) _colorPreview = _colorOptions[item.color!]!;
      }
      if (item.description != null) _descriptionController.text = item.description!;
      if (item.imageUrls?.isNotEmpty == true) {
        _images = item.imageUrls!.asMap().entries.map((e) => ImageItem.fromUrl(
          id: 'existing_${e.key}', url: e.value,
          sequence: e.key + 1, isMain: e.key == 0,
        )).toList();
      }
    });
  }

  // ─────────────────────────────────────────────
  // カメラ遷移
  // ─────────────────────────────────────────────

  Future<void> _goToCameraScreen() async {
    if (_nameController.text.isEmpty) {
      AppFeedback.showInfo(context, '商品名を入力してください');
      return;
    }
    final result = await Navigator.push<List<ImageItem>>(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => CameraScreenV2(
          itemName:    _nameController.text,
          brand:       _brandController.text,
          category:    _selectedCategory,
          condition:   _selectedCondition,
          price:       _priceController.text,
          barcode:     _barcodeController.text,
          sku:         _skuController.text,
          size:        _sizeController.text,
          color:       _selectedColor,
          productRank: _selectedRank,
          material:    _selectedMaterial,
          description: _descriptionController.text,
          existingImages: _images.isNotEmpty ? _images : null,
          aiMeasure:   _aiMeasure,
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() => _images = result);
      if (!mounted) return;
      AppFeedback.showSuccess(context, '📸 ${result.length}枚の画像を管理中');
    }
  }

  // ─────────────────────────────────────────────
  // ピッカー呼び出し（AddItemPickerMixin へ委譲）
  // ─────────────────────────────────────────────

  void _showBrandPicker()     => showBrandPickerSheet(allBrands: _allBrands,      currentBrand: _brandController.text, onSelected: (v) => setState(() => _brandController.text = v));
  void _showCategoryPicker()  => showCategoryPickerSheet(categories: _categories,  currentCategory: _selectedCategory,  onSelected: (v) => setState(() => _selectedCategory = v));
  void _showRankPicker()      => showRankPickerSheet(ranks: _ranks,               currentRank: _selectedRank,          onSelected: (v) => setState(() => _selectedRank = v));
  void _showConditionPicker() => showConditionPickerSheet(conditions: _conditions, currentCondition: _selectedCondition, onSelected: (v) => setState(() => _selectedCondition = v));
  void _showMaterialPicker()  => showMaterialPickerSheet(materials: _materials,    currentMaterial: _selectedMaterial,   onSelected: (v) => setState(() => _selectedMaterial = v));
  void _showColorPicker()     => showColorPickerSheet(colorOptions: _colorOptions, currentColor: _selectedColor,         onSelected: (name, color) => setState(() { _selectedColor = name; _colorPreview = color; }));

  // ─────────────────────────────────────────────
  // build
  // ─────────────────────────────────────────────

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
        title: Text('新規商品追加', style: AppConstants.subHeaderStyle),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => AppFeedback.showInfo(context, '下書きを保存しました'),
            child: Text('保存',
                style: TextStyle(
                    color: AppConstants.primaryCyan,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          // 🔍 自動入力バッジ
          if (_isAutofilled)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppConstants.successGreen.withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(Icons.check_circle,
                      color: AppConstants.successGreen, size: 20),
                  const SizedBox(width: 8),
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 画像セクション ─────────────────────────
                  _buildImageSection(),
                  const SizedBox(height: 24),

                  // ── 基本情報 ───────────────────────────────
                  _buildSectionLabel('基本情報'),
                  _buildCard([
                    buildInputField('バーコード', _barcodeController, 'バーコードを入力してください'),
                    const Divider(),
                    buildInputField('SKU (商品管理ID)', _skuController, 'SKUを入力してください'),
                    const Divider(),
                    buildBrandField(brandController: _brandController, onTap: _showBrandPicker),
                    const Divider(),
                    buildInputField('商品名', _nameController, '商品名を入力してください'),
                    const Divider(),
                    buildSelectTile('商品ランク', _selectedRank, _showRankPicker,
                        isPlaceholder: _selectedRank == '選択してください'),
                  ]),
                  const SizedBox(height: 24),

                  // ── 商品の詳細 ─────────────────────────────
                  _buildSectionLabel('商品の詳細'),
                  _buildCard([
                    buildSelectTile('カテゴリ', _selectedCategory, _showCategoryPicker),
                    const Divider(),
                    buildSelectTile('商品の状態', _selectedCondition, _showConditionPicker,
                        isPlaceholder: _selectedCondition == '選択してください'),
                    const Divider(),
                    buildSelectTile('素材', _selectedMaterial, _showMaterialPicker),
                    const Divider(),
                    buildColorSelectTile(
                      selectedColor: _selectedColor,
                      colorPreview: _colorPreview,
                      onTap: _showColorPicker,
                    ),
                    const Divider(),
                    buildInputField('サイズ', _sizeController, 'サイズを入力してください (例: M, L, XL)'),
                    const Divider(),
                    buildSwitchTile('AI自動採寸', '撮影時に自動でサイズを計測します', _aiMeasure,
                        (v) => setState(() => _aiMeasure = v)),
                    const Divider(),
                    buildOcrButton(),   // ← AddItemOcrMixin 提供
                  ]),
                  const SizedBox(height: 24),

                  // ── 商品の説明 ─────────────────────────────
                  _buildSectionLabel('商品の説明'),
                  _buildDescriptionField(),
                  const SizedBox(height: 24),

                  // ── サイズ (cm) ────────────────────────────
                  _buildMeasurementSection(),
                  const SizedBox(height: 24),

                  // ── 価格と配送 ─────────────────────────────
                  _buildSectionLabel('価格と配送'),
                  _buildCard([
                    buildInputField('販売価格', _priceController, '¥ 販売価格を入力'),
                    const Divider(),
                    buildSelectTile('配送料の負担', '送料込み(出品者負担)', () {}),
                  ]),
                ],
              ),
            ),
          ),

          // ── 次へボタン ─────────────────────────────────────
          _buildBottomCta(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // build ヘルパー（画面固有の複合 Widget）
  // ─────────────────────────────────────────────

  Widget _buildSectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(label,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppConstants.textGrey)),
      );

  Widget _buildCard(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(children: children),
      );

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // サムネイル一覧
        if (_images.isNotEmpty) ...[
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length,
              itemBuilder: (ctx, index) {
                final imageItem = _images[index];
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: buildImageWidget(imageItem), // ← mixin 提供
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _images.removeAt(index));
                            AppFeedback.showWarning(context, '画像を削除しました',
                                duration: const Duration(seconds: 2));
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
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
              border: _images.isEmpty
                  ? null
                  : Border.all(color: AppConstants.primaryCyan, width: 2),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 4)
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_a_photo),
                            SizedBox(width: 8),
                            Text('写真を追加',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo,
                            color: AppConstants.primaryCyan, size: 20),
                        const SizedBox(width: 8),
                        Text('さらに写真を追加',
                            style: TextStyle(
                              color: AppConstants.primaryCyan,
                              fontWeight: FontWeight.bold,
                            )),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return Column(
      children: [
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
              hintText:
                  '傷や汚れ、特徴などを入力してください...\n\n例：\n・着用回数：3回程度\n・目立った傷や汚れなし\n・サイズ感：普通\n・素材感：柔らかめ',
              hintStyle:
                  TextStyle(color: AppConstants.textGrey, fontSize: 14),
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              counterText: '',
            ),
            style: TextStyle(
                fontSize: 14, color: AppConstants.textDark, height: 1.5),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: ValueListenableBuilder<int>(
            valueListenable: _charCount,
            builder: (_, count, __) => Text(
              '$count/1000',
              style: TextStyle(
                  fontSize: 12, color: AppConstants.textGrey),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMeasurementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('サイズ (cm)',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppConstants.textGrey)),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppConstants.primaryCyan.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome,
                      size: 12, color: AppConstants.primaryCyan),
                  const SizedBox(width: 4),
                  Text('AI自動採寸',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppConstants.primaryCyan,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildCard([
          buildInputField('着丈', _lengthController, 'cm'),
          const Divider(),
          buildInputField('身幅', _widthController, 'cm'),
          const Divider(),
          buildInputField('肩幅', _shoulderController, 'cm'),
          const Divider(),
          buildInputField('袖丈', _sleeveController, 'cm'),
        ]),
      ],
    );
  }

  Widget _buildBottomCta() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, -2))
        ],
      ),
      child: CustomButton(
        text: '次へ：商品詳細',
        icon: Icons.arrow_forward,
        onPressed: () {
          if (_nameController.text.isEmpty) {
            AppFeedback.showInfo(context, '商品名を入力してください');
            return;
          }
          if (_selectedCondition == '選択してください') {
            AppFeedback.showInfo(context, '商品の状態を選択してください');
            return;
          }
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => DetailScreen(
                itemName:    _nameController.text,
                brand:       _brandController.text.isEmpty ? '' : _brandController.text,
                category:    _selectedCategory,
                condition:   _selectedCondition,
                price:       _priceController.text,
                barcode:     _barcodeController.text,
                sku:         _skuController.text,
                size:        _sizeController.text,
                color:       _selectedColor,
                productRank: _selectedRank,
                material:    _selectedMaterial,
                description: _descriptionController.text,
                images:      _images.isEmpty ? null : _images,
                brandKana:   widget.prefillData?.brandKana,
                categorySub: widget.prefillData?.categorySub,
                priceCost:   widget.prefillData?.priceCost,
                season:      widget.prefillData?.season,
                releaseDate: widget.prefillData?.releaseDate,
                buyer:       widget.prefillData?.buyer,
                storeName:   widget.prefillData?.storeName,
                priceRef:    widget.prefillData?.priceRef,
                priceSale:   widget.prefillData?.priceSale,
                priceList:   widget.prefillData?.priceList,
                location:    widget.prefillData?.location,
                stockQuantity: widget.prefillData?.stockQuantity,
                length:      _lengthController.text,
                width:       _widthController.text,
                shoulder:    _shoulderController.text,
                sleeve:      _sleeveController.text,
                aiMeasureEnabled: _aiMeasure,
              ),
              transitionsBuilder: (_, animation, __, child) =>
                  FadeTransition(opacity: animation, child: child),
              transitionDuration: const Duration(milliseconds: 200),
            ),
          );
        },
      ),
    );
  }
}
