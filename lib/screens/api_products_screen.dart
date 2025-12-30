import 'package:flutter/material.dart';
import 'package:measure_master/constants.dart';
import 'package:measure_master/models/api_product.dart';
import 'package:provider/provider.dart';
import 'package:measure_master/providers/inventory_provider.dart';
import 'package:measure_master/providers/api_product_provider.dart';
import 'package:measure_master/models/item.dart';

class ApiProductsScreen extends StatefulWidget {
  const ApiProductsScreen({Key? key}) : super(key: key);

  @override
  _ApiProductsScreenState createState() => _ApiProductsScreenState();
}

class _ApiProductsScreenState extends State<ApiProductsScreen> {
  Set<int> _selectedProductIds = {};

  @override
  void initState() {
    super.initState();
    // 🔐 ログインベース: キャッシュがあれば即座に表示、なければAPI呼び出し
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ApiProductProvider>(context, listen: false).fetchProducts();
    });
  }

  /// 最終更新時刻をユーザーフレンドリーにフォーマット
  String _formatLastUpdate(DateTime lastUpdate) {
    final now = DateTime.now();
    final difference = now.difference(lastUpdate);

    if (difference.inMinutes < 1) {
      return '最終更新: たった今';
    } else if (difference.inMinutes < 60) {
      return '最終更新: ${difference.inMinutes}分前';
    } else if (difference.inHours < 24) {
      return '最終更新: ${difference.inHours}時間前';
    } else {
      return '最終更新: ${difference.inDays}日前';
    }
  }

  Future<void> _refreshProducts() async {
    setState(() {
      _selectedProductIds.clear();
    });
    await Provider.of<ApiProductProvider>(context, listen: false).refresh();
  }

  void _importSelectedProducts(List<ApiProduct> allProducts) {
    final selectedProducts = allProducts
        .where((product) => _selectedProductIds.contains(product.id))
        .toList();

    if (selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('商品を選択してください')),
      );
      return;
    }

    final inventoryProvider = Provider.of<InventoryProvider>(context, listen: false);
    
    for (var product in selectedProducts) {
      // 🔑 ユニークなID生成
      final uniqueId = '${DateTime.now().millisecondsSinceEpoch}_${product.id}';
      
      final newItem = InventoryItem(
        id: uniqueId,
        name: product.name,
        brand: product.brand ?? '未設定',
        imageUrl: "assets/images/tshirt_hanger.jpg",
        category: product.category ?? 'その他',  // ✅ API商品のカテゴリを使用
        status: "Draft",
        date: DateTime.now(),
        length: 0,
        width: 0,
        size: product.size ?? '',
        barcode: product.barcode ?? '',          // ✅ バーコードを保存
        sku: product.sku,
        productRank: product.productRank ?? '',  // ✅ 商品ランクを保存
        color: product.color,                    // ✅ カラーを保存
        condition: product.condition,            // ✅ 商品の状態を保存
        description: product.description,        // ✅ 商品の説明を保存
        material: product.material,              // ✅ 素材を保存
      );
      
      inventoryProvider.addItem(newItem);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${selectedProducts.length}件の商品を取り込みました'),
        backgroundColor: AppConstants.successGreen,
      ),
    );

    Navigator.pop(context);
  }

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
        title: const Text(
          "API商品データ",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppConstants.primaryCyan),
            onPressed: _refreshProducts,
          ),
        ],
      ),
      body: Consumer<ApiProductProvider>(
        builder: (context, apiProvider, child) {
          // ローディング中
          if (apiProvider.isLoading && !apiProvider.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppConstants.primaryCyan),
                  const SizedBox(height: 16),
                  const Text('商品データを取得中...'),
                  if (apiProvider.lastFetchTime != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'キャッシュを更新しています...',
                      style: AppConstants.captionStyle,
                    ),
                  ],
                ],
              ),
            );
          }

          // エラー発生
          if (apiProvider.error != null && !apiProvider.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text('エラーが発生しました', style: AppConstants.subHeaderStyle),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      apiProvider.error!,
                      style: AppConstants.captionStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _refreshProducts,
                    icon: const Icon(Icons.refresh),
                    label: const Text('再試行'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryCyan,
                    ),
                  ),
                ],
              ),
            );
          }

          // データなし
          if (!apiProvider.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('商品データがありません'),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _refreshProducts,
                    icon: const Icon(Icons.refresh),
                    label: const Text('更新'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryCyan,
                    ),
                  ),
                ],
              ),
            );
          }

          final products = apiProvider.products;

          return Column(
            children: [
              // ヘッダー情報
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.data_usage, color: AppConstants.primaryCyan, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'SmartMeasure API',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppConstants.primaryCyan.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${products.length}件',
                            style: TextStyle(
                              color: AppConstants.primaryCyan,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // 最終更新時刻表示
                    if (apiProvider.lastFetchTime != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.update, size: 14, color: AppConstants.textGrey),
                          const SizedBox(width: 4),
                          Text(
                            _formatLastUpdate(apiProvider.lastFetchTime!),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppConstants.textGrey,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_selectedProductIds.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppConstants.successGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: AppConstants.successGreen, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '${_selectedProductIds.length}件選択中',
                              style: TextStyle(
                                color: AppConstants.successGreen,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // 商品リスト
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final isSelected = _selectedProductIds.contains(product.id);
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppConstants.primaryCyan : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: Checkbox(
                          value: isSelected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selectedProductIds.add(product.id);
                              } else {
                                _selectedProductIds.remove(product.id);
                              }
                            });
                          },
                          activeColor: AppConstants.primaryCyan,
                        ),
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppConstants.primaryCyan.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    product.sku,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppConstants.primaryCyan,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (product.brand != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    product.brand!,
                                    style: AppConstants.captionStyle,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              if (product.size != null) ...[
                                Icon(Icons.straighten, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(product.size!, style: AppConstants.captionStyle),
                                const SizedBox(width: 12),
                              ],
                              if (product.color != null) ...[
                                Icon(Icons.palette, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(product.color!, style: AppConstants.captionStyle),
                              ],
                            ],
                          ),
                        ),
                        trailing: product.status != null
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: product.status == '成約'
                                      ? AppConstants.successGreen.withValues(alpha: 0.1)
                                      : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  product.status!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: product.status == '成約'
                                        ? AppConstants.successGreen
                                        : Colors.grey[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: _selectedProductIds.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  final apiProvider = Provider.of<ApiProductProvider>(context, listen: false);
                  _importSelectedProducts(apiProvider.products);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryCyan,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.download, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      '選択した商品を取り込む (${_selectedProductIds.length}件)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
