import 'package:flutter/material.dart';
import 'package:measure_master/constants.dart';
import 'package:measure_master/widgets/custom_button.dart';
import 'package:measure_master/screens/dashboard_screen.dart';
import 'package:provider/provider.dart';
import 'package:measure_master/providers/inventory_provider.dart';
import 'package:measure_master/models/item.dart';
import 'dart:io';

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
  final String? capturedImagePath;  // 📸 撮影した画像のパス（オプション）

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
    this.capturedImagePath,  // オプション
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
            // Image Carousel
            Container(
              height: 120,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // メイン画像（撮影画像 or デフォルト画像）
                  widget.capturedImagePath != null
                    ? _buildCapturedImageThumbnail(widget.capturedImagePath!, isMain: true)
                    : _buildImageThumbnail('assets/images/tshirt_hanger.jpg', isMain: true),
                  SizedBox(width: 12),
                  _buildImageThumbnail('assets/images/landing_hero.jpg'),
                  SizedBox(width: 12),
                  _buildImageThumbnail('assets/images/jeans_folded.jpg'),
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
              text: "出品プレビュー", 
              onPressed: () async {
                print('🔵 出品プレビューボタン押下');
                print('📝 商品の状態: ${widget.condition}');
                print('📝 商品の説明: ${_descriptionController.text}');
                
                // 🔑 ユニークなID生成: タイムスタンプ + マイクロ秒
                final uniqueId = '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
                
                // 📸 画像URL（撮影画像パスまたはデフォルト画像）
                final imageUrl = widget.capturedImagePath ?? "assets/images/tshirt_hanger.jpg";
                
                final newItem = InventoryItem(
                  id: uniqueId,
                  name: widget.itemName,
                  brand: widget.brand,
                  imageUrl: imageUrl,  // 撮影した画像パスを保存
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
                );
                
                print('📦 作成したInventoryItem:');
                print('   condition: ${newItem.condition}');
                print('   description: ${newItem.description}');
                 
                await Provider.of<InventoryProvider>(context, listen: false).addItem(newItem);
                 
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
          child: Image.file(
            File(imagePath), 
            width: 100, 
            height: 120, 
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // エラー時はデフォルト画像を表示
              return Image.asset(
                'assets/images/tshirt_hanger.jpg', 
                width: 100, 
                height: 120, 
                fit: BoxFit.cover,
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
