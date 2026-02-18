import 'package:flutter/foundation.dart';
import 'package:measure_master/models/api_product.dart';
import 'package:measure_master/services/api_service.dart';

/// API商品データのキャッシュ管理とスマート更新を提供するProvider
class ApiProductProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  // キャッシュデータ
  List<ApiProduct> _products = [];
  DateTime? _lastFetchTime;
  bool _isLoading = false;
  String? _error;
  
  // 🔐 ログインベースキャッシュ: セッション中は無期限に有効
  // ログイン時のみAPIを呼び出し、セッション中はキャッシュを使用
  static const Duration _cacheValidDuration = Duration(days: 365); // 実質無期限
  
  // Getters
  List<ApiProduct> get products => _products;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasData => _products.isNotEmpty;
  DateTime? get lastFetchTime => _lastFetchTime;
  
  /// キャッシュが有効かどうかを判定
  bool get isCacheValid {
    if (_lastFetchTime == null) return false;
    final now = DateTime.now();
    final difference = now.difference(_lastFetchTime!);
    return difference < _cacheValidDuration;
  }
  
  /// キャッシュの残り有効時間を取得
  Duration? get cacheRemainingTime {
    if (_lastFetchTime == null) return null;
    final now = DateTime.now();
    final elapsed = now.difference(_lastFetchTime!);
    final remaining = _cacheValidDuration - elapsed;
    return remaining.isNegative ? null : remaining;
  }
  
  /// 🔐 ログインベース フェッチ: セッション中はキャッシュのみ使用
  /// 
  /// **ログイン戦略:**
  /// - ログイン時: 必ず最新データ取得 (forceRefresh: true)
  /// - セッション中: キャッシュのみ返却 (API呼び出しなし)
  /// - 手動更新: ユーザー操作時のみAPI呼び出し
  /// 
  /// **API呼び出し頻度:** 1回/日 (ログイン時のみ)
  Future<List<ApiProduct>> fetchProducts({bool forceRefresh = false}) async {
    // 🔐 強制更新 (ログイン時など)
    if (forceRefresh) {
      if (kDebugMode) {
        print('🔐 ログイン更新: API呼び出し');
      }
      return await _fetchFromApi();
    }
    
    // ✅ キャッシュがある場合は必ず返す (セッション中は無期限有効)
    if (_products.isNotEmpty) {
      if (kDebugMode) {
        final lastUpdate = _lastFetchTime != null 
          ? DateTime.now().difference(_lastFetchTime!).inMinutes
          : 0;
        print('✅ セッションキャッシュを使用 (最終更新: $lastUpdate分前)');
      }
      return _products;
    }
    
    // 🌐 初回アクセス (キャッシュなし) → API呼び出し
    if (kDebugMode) {
      print('🌐 初回API呼び出し');
    }
    return await _fetchFromApi();
  }
  
  /// 🔐 ログイン時に呼び出す: 必ず最新データを取得
  /// 
  /// 使用例:
  /// ```dart
  /// // ログイン成功後
  /// await Provider.of<ApiProductProvider>(context, listen: false).fetchOnLogin();
  /// ```
  Future<List<ApiProduct>> fetchOnLogin() async {
    if (kDebugMode) {
      print('🔐 ログイン時のデータ更新');
    }
    return await fetchProducts(forceRefresh: true);
  }
  
  /// APIから商品データを取得 (UIに反映)
  Future<List<ApiProduct>> _fetchFromApi() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _apiService.fetchProducts();
      _products = response.products;
      _lastFetchTime = DateTime.now();
      _error = null;
      
      if (kDebugMode) {
        print('✅ API取得成功: ${_products.length}件');
      }
      
      _isLoading = false;
      notifyListeners();
      return _products;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
  
  
  /// 手動リフレッシュ (ユーザー操作)
  Future<List<ApiProduct>> refresh() async {
    if (kDebugMode) {
      print('🔄 手動リフレッシュ');
    }
    return await _fetchFromApi();
  }
  
  /// キャッシュをクリア
  void clearCache() {
    _products = [];
    _lastFetchTime = null;
    _error = null;
    notifyListeners();
    
    if (kDebugMode) {
      print('🗑️ キャッシュクリア完了');
    }
  }
  
  /// SKUで商品を検索
  ApiProduct? findBySku(String sku) {
    try {
      return _products.firstWhere((product) => product.sku == sku);
    } catch (e) {
      return null;
    }
  }
  
  /// デバッグ情報を取得
  Map<String, dynamic> getDebugInfo() {
    return {
      'products_count': _products.length,
      'last_fetch_time': _lastFetchTime?.toIso8601String(),
      'cache_valid': isCacheValid,
      'cache_remaining_seconds': cacheRemainingTime?.inSeconds,
      'is_loading': _isLoading,
      'has_error': _error != null,
      'error': _error,
    };
  }
}
