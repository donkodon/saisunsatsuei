import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:measure_master/constants.dart';
import 'package:measure_master/features/inventory/logic/inventory_provider.dart';
import 'package:measure_master/features/inventory/presentation/add_item_screen.dart';
import 'package:measure_master/features/ocr/presentation/barcode_scanner_screen.dart';
// firebase_login_screen は不要（ログアウトはStreamBuilderが自動処理）
import 'package:measure_master/core/services/api_service.dart';
import 'package:measure_master/features/auth/logic/company_service.dart';
import 'package:measure_master/features/auth/logic/auth_service.dart';
import 'package:measure_master/features/inventory/domain/api_product.dart';
import 'package:measure_master/core/utils/app_feedback.dart';
import 'package:measure_master/features/inventory/presentation/widgets/dashboard_pie_charts.dart';


class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  // ✅ CompanyService は Provider 経由で取得（直接 new しない）
  late final CompanyService _companyService;
  bool _isSearching = false;
  String _companyId = '';
  String _companyName = '';
  String _displayName = '';
  
  // 📊 ダッシュボード統計
  Map<String, int> _userCategoryData = {};
  int _userTotal = 0;
  Map<String, int> _teamCategoryData = {};
  int _teamTotal = 0;
  bool _statsLoading = true;

  @override
  void initState() {
    super.initState();
    // didChangeDependencies 内で Provider を取得するため、
    // initState では プレースホルダーだけ初期化
  }

  bool _dependenciesInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dependenciesInitialized) {
      _dependenciesInitialized = true;
      // Provider は context が有効になった後に取得する（初回のみ）
      _companyService = Provider.of<CompanyService>(context, listen: false);
      _loadCompanyInfo();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 企業情報を読み込み（メモリキャッシュ優先・非同期アクセスを最小化）
  Future<void> _loadCompanyInfo() async {
    // ⚡ まずメモリキャッシュから同期取得（SharedPreferences 待ち不要）
    String? companyId = _companyService.cachedCompanyId;
    String? companyName;

    // キャッシュにない場合のみ SharedPreferences へアクセス
    if (companyId == null || companyId.isEmpty) {
      companyId = await _companyService.getCompanyId();
    }

    // Firebase Auth の displayName はローカルキャッシュ（currentUser）から取得
    // Firestore へのネットワークアクセスを省略し起動を高速化
    final currentUser = _authService.currentUser;
    String? displayName = currentUser?.displayName;

    // displayName が空の場合のみ Firestore へフォールバック
    if ((displayName == null || displayName.isEmpty) && currentUser != null) {
      final profile = await _authService.getUserProfile(currentUser.uid);
      displayName = profile?['displayName'] as String?;
    }

    // companyName はキャッシュから取得
    companyName = await _companyService.getCompanyName();

    final firstName = (displayName != null && displayName.isNotEmpty)
        ? displayName.split(' ').first
        : null;

    // 👤 表示名の決定ロジック
    // 1. Firebase Auth の displayName から名前を取得
    // 2. なければ企業名を使用（ただし企業IDは除外）
    // 3. 最終的には「スタッフ」をデフォルトとして使用
    String finalDisplayName = 'スタッフ';  // デフォルト値
    
    if (firstName != null && firstName.isNotEmpty) {
      finalDisplayName = firstName;
    } else if (companyName != null && 
               companyName.isNotEmpty && 
               companyName != companyId) {  // 企業IDと同じ場合は使わない
      finalDisplayName = companyName;
    }

    if (!mounted) return;
    setState(() {
      _companyId = companyId ?? '';
      _companyName = companyName ?? '';
      _displayName = finalDisplayName;
    });

    // 🏢 InventoryProvider に企業IDを設定（変更があった場合のみ再読み込み）
    if (companyId != null && companyId.isNotEmpty) {
      final inventoryProvider =
          Provider.of<InventoryProvider>(context, listen: false);
      inventoryProvider.setCompanyIdIfChanged(companyId);
    }
    
    // 📊 ダッシュボード統計を読み込み
    if (companyId != null && companyId.isNotEmpty) {
      _loadDashboardStats();
    }
  }

  /// 📊 ダッシュボード統計を読み込む
  Future<void> _loadDashboardStats() async {
    if (_companyId.isEmpty || _displayName.isEmpty) return;
    
    setState(() {
      _statsLoading = true;
    });

    try {
      // 並列で2つのAPIを呼び出し
      final results = await Future.wait([
        _apiService.getUserTodayStatsByCategory(
          companyId: _companyId,
          photographedBy: _displayName,
        ),
        _apiService.getTeamTodayStatsByCategory(companyId: _companyId),
      ]);

      final userCategoryData = results[0];
      final teamCategoryData = results[1];
      
      // 総数を計算
      final userTotal = userCategoryData.values.fold<int>(0, (sum, count) => sum + count);
      final teamTotal = teamCategoryData.values.fold<int>(0, (sum, count) => sum + count);

      if (!mounted) return;
      setState(() {
        _userCategoryData = userCategoryData;
        _userTotal = userTotal;
        _teamCategoryData = teamCategoryData;
        _teamTotal = teamTotal;
        _statsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statsLoading = false;
      });
    }
  }

  /// ログアウト処理（Firebase対応）
  Future<void> _handleLogout() async {
    final confirmed = await AppFeedback.showConfirm(
      context,
      title: 'ログアウト',
      message: 'ログアウトしますか？',
      confirmLabel: 'ログアウト',
    );

    if (!confirmed) return;

    try {
      // ① CompanyService のメモリ・永続化キャッシュをクリア
      await _companyService.logout();

      // ② Firebase Auth からサインアウト
      // → authStateChanges が null を発火
      // → AuthGate の StreamBuilder が自動的に FirebaseLoginScreen を表示
      await _authService.signOut();

      // ③ Web では authStateChanges の伝搬に遅延が生じることがあるため
      //    少し待機してから状態を確認する
      await Future.delayed(const Duration(milliseconds: 500));

      // ④ まだこの画面が表示されていた場合は Navigator でルートまで戻る
      //    （StreamBuilder が正常に切り替わっていれば不要だが保険として入れる）
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) AppFeedback.showError(context, 'ログアウトに失敗しました。再度お試しください。');
    }
  }

  /// 🔍 商品を検索してAddItemScreenに遷移
  Future<void> _searchProduct(String query) async {
    if (query.trim().isEmpty) {
      AppFeedback.showInfo(context, '商品IDまたはバーコードを入力してください');
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
        
        AppFeedback.showSuccess(context, '保存済み商品: ${savedItem.name}');
        
        // 🔧 修正: 保存済み商品は existingItem として渡す
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => AddItemScreen(
              existingItem: savedItem,
              userDisplayName: _displayName,  // 👤 ユーザー名を渡す
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
      // 🏢 企業IDを取得して検索（企業別にデータを分離）
      final companyId = await _companyService.getCompanyId();
      if (!mounted) return;
      
      final searchResult = await _apiService.searchByBarcodeOrSku(query, companyId: companyId);
      if (!mounted) return;

      setState(() {
        _isSearching = false;
      });

      if (searchResult != null && searchResult['success'] == true) {
        final source = searchResult['source'];
        final data = searchResult['data'];
        
        // 🔒 最終防衛ライン: 企業IDの再検証
        final dataCompanyId = data['company_id'] ?? data['companyId'];
        if (companyId != null && dataCompanyId != null && dataCompanyId != companyId) {
          
          setState(() {
            _isSearching = false;
          });
          
          if (!mounted) return;
          AppFeedback.showError(context, 'この商品はあなたの企業のデータではありません');
          
          _searchController.clear();
          return;
        }
        
        
        // データソースに応じてメッセージを変更
        String message = '';
        if (source == 'product_items') {
          message = '実物データ: ${data['name'] ?? data['sku']}';
        } else if (source == 'product_master') {
          message = 'マスタ商品: ${data['name'] ?? data['sku']}';
        }
        
        if (!mounted) return;
        AppFeedback.showSuccess(context, message);

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
              userDisplayName: _displayName,  // 👤 ユーザー名を渡す
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
        if (!mounted) return;
        // 商品が見つからない場合は、検索したバーコード/SKUを初期値として新規作成画面へ
        AppFeedback.showWarning(context, '商品が見つかりませんでした。新規作成します。');

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
              userDisplayName: _displayName,  // 👤 ユーザー名を渡す
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
      if (!mounted) return;
      setState(() {
        _isSearching = false;
      });

      AppFeedback.showError(context, '検索エラー: $e');
    }
  }

  /// 📸 バーコードスキャン実行
  Future<void> _scanBarcode() async {
    if (kIsWeb) {
      AppFeedback.showInfo(context, 'Web版ではバーコードスキャンはサポートされていません');
      return;
    }

    try {
      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
      );

      if (!mounted) return;
      if (result != null && result.isNotEmpty) {
        // スキャン結果を使って検索を実行
        _searchController.text = result;
        _searchProduct(result);
      }
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(context, 'バーコードスキャンに失敗しました: $e');
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
              
              Text("こんにちは、$_displayNameさん", style: AppConstants.headerStyle),
              const SizedBox(height: 8),
              Text(
                "今日の出品準備状況を確認しましょう。",
                style: AppConstants.bodyStyle.copyWith(color: AppConstants.textGrey),
              ),
              const SizedBox(height: 24),

              // 📊 ダッシュボード円グラフ
              _statsLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : DashboardPieCharts(
                      userCategoryData: _userCategoryData,
                      userTotal: _userTotal,
                      teamCategoryData: _teamCategoryData,
                      teamTotal: _teamTotal,
                    ),
              const SizedBox(height: 24),

              // Big CTA
              SizedBox(
                width: double.infinity,
                height: 80,
                child: ElevatedButton(
                  onPressed: () {
                    // 🚀 高速遷移（ユーザー名を渡す）
                    Navigator.push(
                      context, 
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) => AddItemScreen(
                          userDisplayName: _displayName,  // 👤 ユーザー名を渡す
                        ),
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
              SizedBox(
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
        backgroundColor: Color(0xFF1A2A3A),
        elevation: 4, // Dark color from screenshot
        child: Icon(Icons.qr_code_scanner, color: Colors.white),
      ),
    );
  }
}
