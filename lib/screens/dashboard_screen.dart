import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:measure_master/constants.dart';
import 'package:measure_master/providers/inventory_provider.dart';
import 'package:measure_master/screens/add_item_screen.dart';
import 'package:measure_master/screens/api_products_screen.dart';
import 'package:measure_master/screens/barcode_scanner_screen.dart';
import 'package:measure_master/screens/login_screen.dart';
import 'package:measure_master/models/item.dart';
import 'package:measure_master/services/api_service.dart';
import 'package:measure_master/services/company_service.dart';
import 'package:measure_master/models/api_product.dart';
import 'package:measure_master/services/image_cache_service.dart';
import 'package:measure_master/screens/image_preview_screen.dart';
import 'package:measure_master/widgets/smart_image_viewer.dart';
import 'dart:io' show File, Platform;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ApiService _apiService = ApiService();
  final CompanyService _companyService = CompanyService();
  bool _isSearching = false;
  String _companyId = '';
  String _companyName = '';

  @override
  void initState() {
    super.initState();
    _loadCompanyInfo();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 企業情報を読み込み
  Future<void> _loadCompanyInfo() async {
    final companyId = await _companyService.getCompanyId();
    final companyName = await _companyService.getCompanyName();
    
    setState(() {
      _companyId = companyId;
      _companyName = companyName ?? '';
    });
  }

  /// ログアウト処理
  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ログアウト'),
        content: const Text('ログアウトしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _companyService.logout();
      
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
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
      // 🔍 ステップ1: ローカル保存データを検索
      final inventoryProvider = Provider.of<InventoryProvider>(context, listen: false);
      final savedItem = inventoryProvider.findBySku(query);
      
      if (savedItem != null) {
        // 💾 保存済み商品が見つかった
        setState(() {
          _isSearching = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存済み商品: ${savedItem.name}'),
            backgroundColor: Colors.green,
          ),
        );
        
        // 🔧 修正: 保存済み商品は existingItem として渡す
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => AddItemScreen(
              existingItem: savedItem,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 200),
          ),
        );
        
        _searchController.clear();
        return;
      }
      
      // 🌐 ステップ2: 統合検索API（product_items → product_master）
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
            transitionDuration: const Duration(milliseconds: 200),
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
            transitionDuration: const Duration(milliseconds: 200),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("出品ダッシュボード", style: AppConstants.subHeaderStyle),
                      if (_companyId.isNotEmpty)
                        Text(
                          _companyName.isNotEmpty ? _companyName : _companyId,
                          style: AppConstants.captionStyle.copyWith(
                            color: AppConstants.primaryCyan,
                          ),
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.notifications_outlined, color: AppConstants.textDark),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: _handleLogout,
                        child: CircleAvatar(
                          backgroundColor: AppConstants.primaryCyan,
                          radius: 18,
                          child: Icon(Icons.logout, color: Colors.white, size: 20),
                        ),
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
              // 🚀 Consumer で必要な部分だけ再描画
              Consumer<InventoryProvider>(
                builder: (context, inventory, _) => Row(
                  children: [
                    Expanded(child: _buildStatCard("Ready", inventory.readyCount.toString(), "出品待ちアイテム", AppConstants.successGreen, Icons.check_circle)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildStatCard("Draft", inventory.draftCount.toString(), "下書き保存中", AppConstants.warningOrange, Icons.edit_document)),
                  ],
                ),
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
                        transitionDuration: const Duration(milliseconds: 200),
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
              // 「最近のアイテム」セクションを削除しました
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
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: "バーコード"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "設定"),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
           // 🔍 バーコードスキャナーへ遷移
           Navigator.push(
              context, 
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const BarcodeScannerScreen(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
                transitionDuration: const Duration(milliseconds: 200),
              ),
            );
        },
        backgroundColor: Color(0xFF1A2A3A), // Dark color from screenshot
        child: Icon(Icons.qr_code_scanner, color: Colors.white),
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
            transitionDuration: const Duration(milliseconds: 200),
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
