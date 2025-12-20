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
  
  // キャッシュ有効期間 (5分)
  static const Duration _cacheValidDuration = Duration(minutes: 5);
  
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
  
  /// スマートフェッチ: キャッシュの状態に応じて適切な処理を実行
  /// 
  /// - キャッシュなし → API呼び出し
  /// - キャッシュ有効 (5分以内) → キャッシュ返却 (API呼び出しなし)
  /// - キャッシュ期限切れ → バックグラウンド更新 + キャッシュ返却
  Future<List<ApiProduct>> fetchProducts({bool forceRefresh = false}) async {
    // 強制更新の場合
    if (forceRefresh) {
      return await _fetchFromApi();
    }
    
    // キャッシュが有効な場合はキャッシュを返す
    if (isCacheValid && _products.isNotEmpty) {
      if (kDebugMode) {
        print('✅ キャッシュを使用 (残り時間: ${cacheRemainingTime?.inSeconds}秒)');
      }
      return _products;
    }
    
    // キャッシュがあるが期限切れの場合 → バックグラウンド更新
    if (_products.isNotEmpty && !isCacheValid) {
      if (kDebugMode) {
        print('🔄 バックグラウンド更新を開始...');
      }
      // 古いキャッシュを即座に返しつつ、バックグラウンドで更新
      _fetchFromApiSilently();
      return _products;
    }
    
    // キャッシュなし → API呼び出し
    if (kDebugMode) {
      print('🌐 初回API呼び出し');
    }
    return await _fetchFromApi();
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
  
  /// バックグラウンドでAPIから商品データを取得 (サイレント更新)
  Future<void> _fetchFromApiSilently() async {
    try {
      final response = await _apiService.fetchProducts();
      _products = response.products;
      _lastFetchTime = DateTime.now();
      _error = null;
      
      if (kDebugMode) {
        print('🔄 バックグラウンド更新完了: ${_products.length}件');
      }
      
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ バックグラウンド更新失敗: $e');
      }
      // エラーは無視 (古いキャッシュを継続使用)
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
