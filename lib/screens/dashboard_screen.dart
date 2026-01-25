import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:measure_master/constants.dart';
import 'package:measure_master/screens/add_item_screen.dart';
import 'package:measure_master/screens/api_products_screen.dart';
// Web環境ではMLKitが使えないためバーコードスキャナーは無効
// import 'package:measure_master/screens/barcode_scanner_screen.dart';
import 'package:measure_master/models/item.dart';
import 'package:measure_master/services/api_service.dart';
import 'package:measure_master/models/api_product.dart';
import 'package:measure_master/services/image_cache_service.dart';
import 'package:measure_master/screens/image_preview_screen.dart';
import 'package:measure_master/widgets/smart_image_viewer.dart';
import 'package:measure_master/utils/cleanup_helper.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ✅ 定数化: ページ遷移のアニメーション時間
  static const Duration _pageTransitionDuration = Duration(milliseconds: 200);
  
  final TextEditingController _searchController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isSearching = false;
  
  // 🏢 ログイン中の企業ID
  String _loggedInCompanyId = 'test_company';
  
  // 📊 D1から取得した商品データ
  List<InventoryItem> _d1Items = [];
  bool _isLoadingD1 = true;

  @override
  void initState() {
    super.initState();
    _loadCompanyIdAndData();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  /// 🏢 ログイン中の企業IDを取得してD1からデータを読み込み
  Future<void> _loadCompanyIdAndData() async {
    try {
      String companyId = 'test_company';
      
      // Web版エラー対応: SharedPreferences取得を try-catch で囲む
      try {
        final prefs = await SharedPreferences.getInstance();
        companyId = prefs.getString('company_id') ?? 'test_company';
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ SharedPreferences取得エラー（Web版）: $e');
          debugPrint('🏢 デフォルト企業IDを使用: $companyId');
        }
      }
      
      if (kDebugMode) {
        debugPrint('🏢 ログイン中の企業ID: $companyId');
      }
      
      setState(() {
        _loggedInCompanyId = companyId;
      });
      
      // D1からデータを取得
      await _loadDataFromD1();
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 企業ID取得エラー: $e');
      }
      
      setState(() {
        _isLoadingD1 = false;
      });
    }
  }
  
  /// 📊 D1から商品データを取得
  Future<void> _loadDataFromD1() async {
    setState(() {
      _isLoadingD1 = true;
    });
    
    try {
      if (kDebugMode) {
        debugPrint('📊 D1からデータを取得開始 (company_id: $_loggedInCompanyId)');
      }
      
      final d1Products = await _apiService.fetchProductsFromD1(
        companyId: _loggedInCompanyId,
        limit: 100,
      );
      
      if (kDebugMode) {
        debugPrint('✅ D1からデータを取得完了: ${d1Products.length}件');
      }
      
      // D1データをInventoryItemに変換
      final items = d1Products.map((d1Data) => _convertD1ToInventoryItem(d1Data)).toList();
      
      // 日付順にソート（新しい順）
      items.sort((a, b) => b.date.compareTo(a.date));
      
      setState(() {
        _d1Items = items;
        _isLoadingD1 = false;
      });
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ D1データ取得エラー: $e');
      }
      
      setState(() {
        _d1Items = [];
        _isLoadingD1 = false;
      });
    }
  }
  
  /// 🔄 D1データをInventoryItemに変換
  InventoryItem _convertD1ToInventoryItem(Map<String, dynamic> d1Data) {
    final imageUrlsList = _parseImageUrls(d1Data['imageUrls']);
    
    return InventoryItem(
      id: d1Data['sku'] ?? 'NO_SKU',
      sku: d1Data['sku'] ?? '',
      name: d1Data['name'] ?? '',
      brand: d1Data['brand'] ?? '',
      imageUrl: imageUrlsList.isNotEmpty ? imageUrlsList.first : '',
      category: d1Data['category'] ?? '',
      condition: d1Data['condition'] ?? '',
      salePrice: d1Data['price'] != null ? int.tryParse(d1Data['price'].toString()) : null,
      date: _parseDate(d1Data['created_at']),
      status: 'Ready',
      barcode: d1Data['barcode'] ?? '',
      size: d1Data['size'] ?? '',
      color: d1Data['color'] ?? '',
      productRank: d1Data['product_rank'] ?? '',
      material: d1Data['material'] ?? '',
      description: d1Data['inspection_notes'] ?? '',
      imageUrls: imageUrlsList,
    );
  }
  
  /// 📅 日付パース
  DateTime _parseDate(dynamic dateStr) {
    if (dateStr == null) return DateTime.now();
    try {
      return DateTime.parse(dateStr.toString());
    } catch (_) {
      return DateTime.now();
    }
  }
  
  /// 🖼️ 画像URLリストパース
  List<String> _parseImageUrls(dynamic imageUrls) {
    if (imageUrls == null) return [];
    if (imageUrls is List) {
      return imageUrls.map((e) => e.toString()).toList();
    }
    if (imageUrls is String) {
      try {
        final decoded = json.decode(imageUrls);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  /// 🔍 商品を検索してAddItemScreenに遷移
  Future<void> _searchProduct(String query) async {
    if (query.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('商品IDまたはバーコードを入力してください')),
      );
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      // 🌐 D1統合検索API（product_items → product_master）
      // company_id でフィルタされた結果のみ取得
      final searchResult = await _apiService.searchByBarcodeOrSku(query);

      setState(() {
        _isSearching = false;
      });

      if (searchResult != null && searchResult['success'] == true) {
        final source = searchResult['source'];
        final data = searchResult['data'];
        
        if (kDebugMode) {
          debugPrint('✅ 検索成功: source=$source, data=$data');
        }
        
        // データソースに応じてメッセージを変更
        String message = '';
        if (source == 'product_items') {
          message = '実物データ: ${data['name'] ?? data['sku']}';
        } else if (source == 'product_master') {
          message = 'マスタ商品: ${data['name'] ?? data['sku']}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppConstants.successGreen,
          ),
        );

        // ApiProduct形式に変換してAddItemScreenへ遷移
        final product = ApiProduct(
          id: data['id'] ?? 0,
          sku: data['sku'] ?? query,
          name: data['name'] ?? '',
          brand: data['brand'],
          category: data['category'],
          size: data['size'],
          color: data['color'],
          priceSale: data['price'] ?? data['price_sale'],
          createdAt: DateTime.now(),
          imageUrls: data['imageUrls'],
          barcode: data['barcode'],
          // 🔧 product_items の情報を追加
          condition: data['condition'],
          material: data['material'],
          productRank: data['product_rank'],
          description: data['inspection_notes'],
        );

        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => AddItemScreen(
              prefillData: product,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: _pageTransitionDuration,
          ),
        );

        // 検索窓をクリア
        _searchController.clear();
      } else {
        // 商品が見つからない場合は、検索したバーコード/SKUを初期値として新規作成画面へ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('商品が見つかりませんでした。新規作成します。'),
            backgroundColor: AppConstants.warningOrange,
            duration: const Duration(seconds: 2),
          ),
        );

        // 仮のAPIプロダクトを作成して渡す（バーコード/SKUのみ入力済み）
        final dummyProduct = ApiProduct(
          id: 0,
          sku: query,
          name: '',
          createdAt: DateTime.now(),
          category: '',
          priceSale: 0,
          stockQuantity: 0,
          barcode: query, // バーコードとしてセット
        );

        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => AddItemScreen(
              prefillData: dummyProduct,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: _pageTransitionDuration,
          ),
        );
        _searchController.clear();
      }
    } catch (e) {
      setState(() {
        _isSearching = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('検索エラー: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 📸 バーコードスキャン実行
  Future<void> _scanBarcode() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Web版ではバーコードスキャンはサポートされていません')),
      );
      return;
    }

    // Web環境ではBarcodeScannerScreenは使用不可
    // try {
    //   final result = await Navigator.push(
    //     context,
    //     MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
    //   );

    //   if (result != null && result is String) {
    //     // スキャン結果を使って検索を実行
    //     _searchProduct(result);
    //   }
    // } catch (e) {
    //   if (kDebugMode) {
    //     debugPrint('⚠️ バーコードスキャンエラー: $e');
    //   }
    // }
  }
  
  /// 🗑️ Phase 1: クリーンアップダイアログを表示
  Future<void> _showCleanupDialog() async {
    // 現在のデータ件数を取得
    final dataCount = await CleanupHelper.getHiveDataCount();
    final itemCount = dataCount['inventory_box'] ?? 0;
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Phase 1: データ削除'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('既存のHiveデータを削除します。', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Text('削除されるデータ:'),
            Text('  • 商品データ: $itemCount件', style: TextStyle(color: Colors.red)),
            SizedBox(height: 12),
            Text('⚠️ この操作は取り消せません', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Phase 1完了後に商品を再登録してください。', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _executeCleanup();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('削除実行'),
          ),
        ],
      ),
    );
  }
  
  /// 🗑️ Phase 1: クリーンアップを実行
  Future<void> _executeCleanup() async {
    // ローディング表示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('データ削除中...'),
              ],
            ),
          ),
        ),
      ),
    );
    
    // クリーンアップ実行
    await CleanupHelper.showMigrationChecklist();
    final success = await CleanupHelper.clearAllHiveData();
    
    if (!mounted) return;
    Navigator.pop(context); // ローディングを閉じる
    
    // 結果表示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? '✅ データ削除完了！Phase 1の準備が整いました' : '❌ データ削除に失敗しました'),
        backgroundColor: success ? Colors.green : Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
    
    // 画面を更新
    if (success) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🚀 listen: false で不要な再描画を防止（パフォーマンス最適化）
    // InventoryProviderは Consumer内でのみ使用

    return Scaffold(
      backgroundColor: AppConstants.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("出品ダッシュボード", style: AppConstants.subHeaderStyle),
                  Row(
                    children: [
                      // 🗑️ Phase 1: デバッグモード専用クリーンアップボタン
                      if (kDebugMode)
                        IconButton(
                          icon: Icon(Icons.delete_sweep, color: Colors.red),
                          tooltip: 'Hiveデータ削除（Phase 1）',
                          onPressed: _showCleanupDialog,
                        ),
                      Icon(Icons.notifications_outlined, color: AppConstants.textDark),
                      const SizedBox(width: 16),
                      CircleAvatar(
                        backgroundColor: AppConstants.primaryCyan,
                        radius: 18,
                        child: Icon(Icons.person, color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              Text("こんにちは、山田さん", style: AppConstants.headerStyle),
              const SizedBox(height: 8),
              Text(
                "今日の出品準備状況を確認しましょう。",
                style: AppConstants.bodyStyle.copyWith(color: AppConstants.textGrey),
              ),
              const SizedBox(height: 24),

              // Stats Cards
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      "Ready",
                      _d1Items.where((i) => i.status == 'Ready').length.toString(),
                      "出品待ちアイテム",
                      AppConstants.successGreen,
                      Icons.check_circle,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      "Draft",
                      _d1Items.where((i) => i.status == 'Draft').length.toString(),
                      "下書き保存中",
                      AppConstants.warningOrange,
                      Icons.edit_document,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Big CTA
              Container(
                width: double.infinity,
                height: 80,
                child: ElevatedButton(
                  onPressed: () {
                    // 🚀 高速遷移
                    Navigator.push(
                      context, 
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) => AddItemScreen(),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          return FadeTransition(opacity: animation, child: child);
                        },
                        transitionDuration: _pageTransitionDuration,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryCyan,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                    shadowColor: AppConstants.primaryCyan.withValues(alpha: 0.4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo, size: 32, color: Colors.white),
                      const SizedBox(width: 16),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("新規アイテムを撮影", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                          Text("採寸・撮影を開始する", style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.9))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // API連携ボタン (バーコードスキャンに変更)
              Container(
                width: double.infinity,
                height: 60,
                child: OutlinedButton(
                  onPressed: _scanBarcode,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppConstants.primaryCyan, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_scanner, size: 28, color: AppConstants.primaryCyan),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "バーコードを読み取る",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppConstants.primaryCyan,
                            ),
                          ),
                          Text(
                            "商品情報を自動取得",
                            style: TextStyle(
                              fontSize: 11,
                              color: AppConstants.textGrey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 🔍 Search Bar (商品ID/バーコード検索)
              TextField(
                controller: _searchController,
                onSubmitted: _searchProduct,
                enabled: !_isSearching,
                decoration: InputDecoration(
                  hintText: "商品ID/バーコードで検索... (例: 1025L190003)",
                  prefixIcon: _isSearching
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppConstants.primaryCyan,
                            ),
                          ),
                        )
                      : Icon(Icons.search, color: AppConstants.textGrey),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: AppConstants.textGrey),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                ),
              ),
              const SizedBox(height: 16),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip("すべて", true),
                    _buildFilterChip("採寸済み", false),
                    _buildFilterChip("下書き", false),
                    _buildFilterChip("出品完了", false),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Recent Items
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("最近のアイテム", style: AppConstants.subHeaderStyle),
                  Text("すべて見る", style: TextStyle(color: AppConstants.primaryCyan, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),

              // 📊 D1から取得したデータを表示
              _isLoadingD1
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(AppConstants.primaryCyan),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'データを読み込み中...',
                            style: TextStyle(color: AppConstants.textGrey),
                          ),
                        ],
                      ),
                    ),
                  )
                : _d1Items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 64, color: AppConstants.textGrey),
                              SizedBox(height: 16),
                              Text(
                                'データがありません',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppConstants.textGrey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                '商品を撮影して登録しましょう',
                                style: TextStyle(color: AppConstants.textGrey),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: _d1Items.length,
                        itemBuilder: (context, index) {
                          return _buildItemCard(_d1Items[index]);
                        },
                      ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: AppConstants.primaryCyan,
        unselectedItemColor: AppConstants.textGrey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "ホーム"),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: "撮影"), // Middle big button simulation
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "設定"),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
           // 🚀 高速遷移
           final result = await Navigator.push(
              context, 
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => AddItemScreen(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
                transitionDuration: _pageTransitionDuration,
              ),
            );
            
            // 📊 商品保存後にD1データを再読み込み
            if (result == true) {
              await _loadDataFromD1();
            }
        },
        backgroundColor: Color(0xFF1A2A3A), // Dark color from screenshot
        child: Icon(Icons.camera_alt, color: Colors.white),
        elevation: 4,
      ),
    );
  }

  Widget _buildStatCard(String badge, String count, String label, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConstants.borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(badge, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(count, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppConstants.textDark)),
          Text(label, style: AppConstants.captionStyle),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return Container(
      margin: EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(label),
        backgroundColor: isSelected ? Color(0xFF1A2A3A) : Colors.white,
        labelStyle: TextStyle(color: isSelected ? Colors.white : AppConstants.textDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: isSelected ? BorderSide.none : BorderSide(color: AppConstants.borderGrey),
        ),
      ),
    );
  }

  Widget _buildItemCard(InventoryItem item) {
    return GestureDetector(
      onTap: () {
        // 📝 商品をタップしたら編集モードでAddItemScreenを開く
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => AddItemScreen(
              existingItem: item,  // 既存商品データを渡す
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: _pageTransitionDuration,
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppConstants.borderGrey),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image - タップで拡大表示
          GestureDetector(
            // イベント伝播を停止して親のGestureDetectorと競合しないようにする
            behavior: HitTestBehavior.opaque,
            onTap: () {
              // 画像URLリストを取得（メイン画像 + 追加画像）
              final imageUrls = <String>[];
              if (item.imageUrl.isNotEmpty) {
                imageUrls.add(item.imageUrl);
              }
              if (item.imageUrls != null && item.imageUrls!.isNotEmpty) {
                imageUrls.addAll(item.imageUrls!);
              }
              
              // 画像プレビュー画面を表示
              if (imageUrls.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ImagePreviewScreen(
                      imageUrls: imageUrls,
                      initialIndex: 0,
                      heroTag: 'item_image_${item.id}',
                    ),
                  ),
                );
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  _buildItemImage(item.imageUrl),  // 📸 ファイルパスとアセットパスの両方に対応
                  if (item.status == 'Ready')
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        color: Color(0xFF1A2A3A).withValues(alpha: 0.8),
                        child: Text("済", style: TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: item.status == 'Ready' 
                            ? AppConstants.successGreen.withValues(alpha: 0.1) 
                            : (item.status == 'Draft' ? AppConstants.warningOrange.withValues(alpha: 0.1) : Colors.grey[200]),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.status == 'Ready' ? '出品待ち' : (item.status == 'Draft' ? '下書き' : '出品完了'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: item.status == 'Ready' 
                              ? AppConstants.successGreen 
                              : (item.status == 'Draft' ? AppConstants.warningOrange : Colors.grey),
                        ),
                      ),
                    ),
                    Icon(Icons.more_vert, color: Colors.grey, size: 20),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  item.name,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.category,
                  style: AppConstants.captionStyle,
                ),
                // 🔍 商品の状態を表示
                if (item.condition != null && item.condition!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "状態: ${item.condition}",
                      style: TextStyle(fontSize: 11, color: AppConstants.textGrey),
                    ),
                  ),
                // 🔍 商品の説明を表示（最初の30文字）
                if (item.description != null && item.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      item.description!.length > 30 
                          ? "${item.description!.substring(0, 30)}..." 
                          : item.description!,
                      style: TextStyle(fontSize: 11, color: AppConstants.textGrey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: 8),
                if (item.hasAlert)
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppConstants.warningOrange, size: 14),
                      SizedBox(width: 4),
                      Text("写真が不足しています", style: TextStyle(color: AppConstants.warningOrange, fontSize: 12)),
                    ],
                  )
                else if (item.length != null)
                   Row(
                    children: [
                      _buildDimensionTag("W: ${item.width}cm"),
                      SizedBox(width: 8),
                      _buildDimensionTag("L: ${item.length}cm"),
                    ],
                   ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildDimensionTag(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: AppConstants.borderGrey),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, color: AppConstants.textGrey)),
    );
  }

  /// 📸 ファイルパスとアセットパスの両方に対応した画像表示
  /// 
  /// 🔧 v2.0 改善点:
  /// - キャッシュバスティングを適用して常に最新画像を表示
  /// - Image.networkにキャッシュ制御ヘッダーを追加
  /// 
  /// 🎨 Phase 5: SmartImageViewerに統一
  Widget _buildItemImage(String imageUrl) {
    return SmartImageViewer(
      imageUrl: imageUrl,
      width: 80,
      height: 80,
      fit: BoxFit.cover,
      borderRadius: 8,
    );
  }

  /// 📸 旧実装（Phase 5で置き換え済み）
  Widget _buildItemImage_Legacy(String imageUrl) {
    // 📸 まずローカルキャッシュをチェック（CORS回避）
    if (imageUrl.contains('.r2.dev') || imageUrl.contains('workers.dev')) {
      // 🔧 キャッシュバスティングパラメータを除去したURLでキャッシュを検索
      final cleanUrl = ImageCacheService.removeCacheBusting(imageUrl);
      final cachedBytes = ImageCacheService.getCachedImage(cleanUrl);
      if (cachedBytes != null) {
        if (kDebugMode) {
          debugPrint('✅ キャッシュから画像表示: $cleanUrl');
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            cachedBytes,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildPlaceholderImage(Icons.broken_image);
            },
          ),
        );
      }
      
      if (kDebugMode) {
        debugPrint('⚠️ キャッシュなし、ネットワーク画像を試行: $imageUrl');
      }
      
      // 🔧 キャッシュバスティングを適用してネットワークから取得
      final cacheBustedUrl = ImageCacheService.getCacheBustedUrl(cleanUrl);
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          cacheBustedUrl,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          // ✅ Phase 1のUUID形式でキャッシュ衝突は回避済み
          // ✅ ?t=timestamp パラメータでキャッシュバスティング実現
          // ❌ Cache-Controlヘッダーは削除（CORS問題回避）
          errorBuilder: (c, o, s) {
            if (kDebugMode) {
              debugPrint('❌ ネットワーク画像読み込みエラー: $imageUrl');
              debugPrint('   エラー詳細: $o');
            }
            
            // 🔧 404エラーの場合、古い画像URLの可能性があることを記録
            // （自動削除はせず、ログで警告のみ）
            if (o.toString().contains('404') || o.toString().contains('Not Found')) {
              if (kDebugMode) {
                debugPrint('⚠️ 404エラー: 古い画像URLの可能性があります: $imageUrl');
                debugPrint('   💡 ヒント: 商品を再編集して保存すると、無効な画像URLが削除されます');
              }
            }
            
            return _buildPlaceholderImage(Icons.cloud_off);
          },
        ),
      );
    }
    
    // ファイルパス（/data/user/0/...）の場合
    if (imageUrl.startsWith('/')) {
      // Web環境ではファイルシステムアクセスができないため、プレースホルダーを表示
      if (kIsWeb) {
        return _buildPlaceholderImage(Icons.image);
      }
      
      // モバイル環境ではファイル画像を表示
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(imageUrl),
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholderImage(Icons.image_not_supported);
          },
        ),
      );
    } else if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      // 🔧 その他のHTTP URLはキャッシュバスティングを適用してネットワーク画像として試行
      final cacheBustedUrl = ImageCacheService.getCacheBustedUrl(imageUrl);
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          cacheBustedUrl,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          // ✅ Phase 1のUUID形式でキャッシュ衝突は回避済み
          // ✅ ?t=timestamp パラメータでキャッシュバスティング実現
          errorBuilder: (c, o, s) => _buildPlaceholderImage(Icons.cloud_off),
        ),
      );
    } else {
      // その他の場合はプレースホルダー
      return _buildPlaceholderImage(Icons.image);
    }
  }
  
  // 🖼️ プレースホルダー画像を生成
  Widget _buildPlaceholderImage(IconData icon) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 32, color: Colors.grey[400]),
    );
  }
}
