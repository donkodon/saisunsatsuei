import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:measure_master/constants.dart';
import 'package:measure_master/screens/camera_screen.dart';
import 'package:measure_master/widgets/custom_button.dart';

class AddItemScreen extends StatefulWidget {
  @override
  _AddItemScreenState createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  bool _aiMeasure = true;
  bool _aiBgRemove = true;
  
  // Form controllers
  final TextEditingController _nameController = TextEditingController(text: 'Vintage Denim Jacket');
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  
  String _selectedCategory = 'ジャケット/アウター';
  String _selectedCondition = '選択してください';
  
  // Category options
  final List<String> _categories = [
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
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photo Area
                  Stack(
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
                            Text("写真を変更", style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
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
                        _buildInputField("商品名", _nameController, "商品名を入力してください"),
                        Divider(),
                        _buildBrandField(),
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
                        _buildSwitchTile("AI自動採寸", "撮影時に自動でサイズを計測します", _aiMeasure, (v) => setState(() => _aiMeasure = v)),
                        Divider(),
                        _buildSwitchTile("AI自動白抜き", "撮影時に自動で背景を削除します", _aiBgRemove, (v) => setState(() => _aiBgRemove = v)),
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
              text: "次へ：撮影・採寸",
              icon: Icons.straighten,
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
                // 🚀 高速遷移
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => CameraScreen(
                      itemName: _nameController.text,
                      brand: _brandController.text,
                      category: _selectedCategory,
                      condition: _selectedCondition,
                      price: _priceController.text,
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
        return AlertDialog(
          title: Text("販売価格を入力"),
          content: TextField(
            controller: tempController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofocus: true,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("キャンセル"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  controller.text = tempController.text;
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryCyan,
              ),
              child: Text("確定", style: TextStyle(color: Colors.white)),
            ),
          ],
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
}
