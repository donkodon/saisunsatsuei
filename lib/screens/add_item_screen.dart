import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:measure_master/constants.dart';
import 'package:measure_master/constants/color_constants.dart';
import 'package:measure_master/screens/camera_screen_v2.dart';
import 'package:measure_master/screens/detail_screen.dart';
import 'package:measure_master/widgets/custom_button.dart';
import 'package:measure_master/models/api_product.dart';
import 'package:measure_master/models/item.dart';
import 'package:measure_master/models/image_item.dart';
import 'package:measure_master/providers/inventory_provider.dart';
import 'package:measure_master/services/cloudflare_storage_service.dart';
import 'package:measure_master/services/image_cache_service.dart';
import 'package:measure_master/widgets/smart_image_viewer.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

// ダイアログファイルのインポート
import 'package:measure_master/screens/add_item/dialogs/brand_picker_dialog.dart';
import 'package:measure_master/screens/add_item/dialogs/category_picker_dialog.dart';
import 'package:measure_master/screens/add_item/dialogs/rank_picker_dialog.dart';
import 'package:measure_master/screens/add_item/dialogs/condition_picker_dialog.dart';
import 'package:measure_master/screens/add_item/dialogs/material_picker_dialog.dart';
import 'package:measure_master/screens/add_item/dialogs/color_picker_dialog.dart';
import 'package:measure_master/screens/add_item/dialogs/price_picker_dialog.dart';

class AddItemScreen extends StatefulWidget {
  final ApiProduct? prefillData; // 🔍 検索結果からの自動入力データ
  final InventoryItem? existingItem; // 📝 既存商品データ（編集用）
  
  const AddItemScreen({Key? key, this.prefillData, this.existingItem}) : super(key: key);
  
  @override
  _AddItemScreenState createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  bool _aiMeasure = true;
  bool _aiBgRemove = true;
  
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
  
  String _selectedCategory = '選択してください';
  String _selectedCondition = '選択してください';
  String _selectedRank = '選択してください'; // 🆕 商品ランク
  String _selectedMaterial = '選択してください'; // 🆕 素材
  String _selectedColor = '選択してください'; // 🆕 カラー
  Color _colorPreview = Colors.grey[400]!; // 🆕 カラープレビュー（デフォルト：選択前）
  
  // リスト定義はダイアログファイルに移動済み
  
  // 🚀 文字数カウンター用のValueNotifier(setState不要で効率的)
  final ValueNotifier<int> _charCount = ValueNotifier<int>(0);
  
  // 🔍 自動入力フラグ
  bool _isAutofilled = false;
  
  @override
  void initState() {
    super.initState();
    
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
        _selectedRank = product.productRank!.toUpperCase();
      }
      
      // 🆕 カテゴリを自動入力
      if (product.category != null && product.category!.isNotEmpty) {
        _selectedCategory = product.category!;
      }
      
      // 🆕 商品の状態を自動入力
      if (product.condition != null && product.condition!.isNotEmpty) {
        _selectedCondition = product.condition!;
      }
      
      // 🆕 素材を自動入力
      if (product.material != null && product.material!.isNotEmpty) {
        _selectedMaterial = product.material!;
      }
      
      // 🆕 カラーを自動入力（colorControllerではなく_selectedColorを使用）
      if (product.color != null && product.color!.isNotEmpty) {
        _selectedColor = product.color!;
        // カラーオプションに存在する場合はプレビューも設定
        if (ColorConstants.colorOptions.containsKey(product.color!)) {
          _colorPreview = ColorConstants.colorOptions[product.color!]!;
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
      if (item.category.isNotEmpty) {
        _selectedCategory = item.category;
      }
      
      // 選択項目
      if (item.condition != null && item.condition!.isNotEmpty) {
        _selectedCondition = item.condition!;
      }
      if (item.productRank != null) {
        _selectedRank = item.productRank!;
      }
      if (item.material != null) {
        _selectedMaterial = item.material!;
      }
      if (item.color != null) {
        _selectedColor = item.color!;
        if (ColorConstants.colorOptions.containsKey(item.color!)) {
          _colorPreview = ColorConstants.colorOptions[item.color!]!;
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
            debugPrint('✅ キャッシュから取得 (${i + 1}/${urls.length}): ${cachedFile.path}');
          }
          continue;
        }
        
        // 🎯 ステップ2: URLから画像をダウンロード
        if (kDebugMode) {
          debugPrint('⬇️ ダウンロード中 (${i + 1}/${urls.length}): $url');
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
            debugPrint('✅ 既存画像変換成功 (${i + 1}/${urls.length}): $fileName');
          }
        } else {
          if (kDebugMode) {
            debugPrint('❌ 画像ダウンロード失敗 (${i + 1}/${urls.length}): $url - Status ${response.statusCode}');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ 既存画像変換エラー (${i + 1}/${urls.length}): $e');
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
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
    
    // ✨ カメラ画面から戻ってきた時の処理（ImageItemリスト）
    if (result != null && result.isNotEmpty) {
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
  
  // リスト定義はダイアログファイルに移動済み

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
                        _buildInputField("サイズ", _sizeController, "サイズを入力してください (例: M, L, XL)"),
                        Divider(),
                        _buildSelectTile(
                          "商品ランク",
                          _selectedRank,
                          () async {
                            final selected = await showRankPickerDialog(
                              context: context,
                              currentValue: _selectedRank,
                            );
                            if (selected != null) {
                              setState(() {
                                _selectedRank = selected;
                              });
                            }
                          },
                          isPlaceholder: _selectedRank == '選択してください',
                        ),
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
                        _buildSelectTile(
                          "カテゴリ",
                          _selectedCategory,
                          () async {
                            final selected = await showCategoryPickerDialog(
                              context: context,
                              currentValue: _selectedCategory,
                            );
                            if (selected != null) {
                              setState(() {
                                _selectedCategory = selected;
                              });
                            }
                          },
                        ),
                        Divider(),
                        _buildSelectTile(
                          "商品の状態",
                          _selectedCondition,
                          () async {
                            final selected = await showConditionPickerDialog(
                              context: context,
                              currentValue: _selectedCondition,
                            );
                            if (selected != null) {
                              setState(() {
                                _selectedCondition = selected;
                              });
                            }
                          },
                          isPlaceholder: _selectedCondition == '選択してください',
                        ),
                        Divider(),
                        _buildSelectTile(
                          "素材",
                          _selectedMaterial,
                          () async {
                            final selected = await showMaterialPickerDialog(
                              context: context,
                              currentValue: _selectedMaterial,
                            );
                            if (selected != null) {
                              setState(() {
                                _selectedMaterial = selected;
                              });
                            }
                          },
                        ),
                        Divider(),
                        _buildColorSelectTile(),
                        Divider(),
                        _buildSwitchTile("AI自動採寸", "撮影時に自動でサイズを計測します", _aiMeasure, (v) => setState(() => _aiMeasure = v)),
                        Divider(),
                        _buildSwitchTile("AI自動白抜き", "撮影時に自動で背景を削除します", _aiBgRemove, (v) => setState(() => _aiBgRemove = v)),
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
                      aiMeasureEnabled: _aiMeasure,  // 📏 AI自動採寸フラグを渡す
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
          onTap: () async {
            final selectedBrand = await showBrandPickerDialog(
              context: context,
              currentValue: _brandController.text,
            );
            if (selectedBrand != null) {
              setState(() {
                _brandController.text = selectedBrand;
              });
            }
          },
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
      onTap: () async {
        final newPrice = await showPricePickerDialog(
          context: context,
          currentValue: controller.text,
        );
        if (newPrice != null) {
          setState(() {
            controller.text = newPrice;
          });
        }
      },
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

  // _showPricePicker は price_picker_dialog.dart に移動

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

  // 🆕 カラー選択タイル（カラープレビュー付き）
  Widget _buildColorSelectTile() {
    return InkWell(
      onTap: () async {
        final result = await showColorPickerDialog(
          context: context,
          currentValue: _selectedColor,
          currentPreview: _colorPreview,
        );
        if (result != null) {
          setState(() {
            _selectedColor = result.colorName;
            _colorPreview = result.colorPreview;
          });
        }
      },
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
  

  // _showColorPicker は color_picker_dialog.dart に移動

}

