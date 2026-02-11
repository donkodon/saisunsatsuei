import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// 企業ID管理サービス
/// 
/// ログイン時の企業IDをSharedPreferencesに保存・取得する
class CompanyService {
  static const String _companyIdKey = 'company_id';
  static const String _companyNameKey = 'company_name';
  static const String _defaultCompanyId = 'test_company';
  
  // メモリ内フォールバック（Web版SharedPreferences失敗時用）
  static String? _memoryCompanyId;
  static String? _memoryCompanyName;
  
  /// 企業IDを保存
  Future<bool> saveCompanyId(String companyId, {String? companyName}) async {
    // まずメモリに保存（必ず成功）
    _memoryCompanyId = companyId;
    if (companyName != null && companyName.isNotEmpty) {
      _memoryCompanyName = companyName;
    }
    
    if (kDebugMode) {
      debugPrint('📝 メモリに保存: $companyId');
    }
    
    // SharedPreferencesへの保存を試みる（失敗してもOK）
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_companyIdKey, companyId);
      
      if (companyName != null && companyName.isNotEmpty) {
        await prefs.setString(_companyNameKey, companyName);
      }
      
      if (kDebugMode) {
        debugPrint('✅ SharedPreferencesに保存: $companyId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ SharedPreferences保存失敗（メモリのみ使用）: $e');
      }
    }
    
    // メモリ保存は必ず成功するので true を返す
    return true;
  }
  
  /// 企業IDを取得
  Future<String> getCompanyId() async {
    // まずメモリから取得を試みる
    if (_memoryCompanyId != null && _memoryCompanyId!.isNotEmpty) {
      if (kDebugMode) {
        debugPrint('🏢 企業ID取得（メモリ）: $_memoryCompanyId');
      }
      return _memoryCompanyId!;
    }
    
    // SharedPreferencesから取得を試みる
    try {
      final prefs = await SharedPreferences.getInstance();
      final companyId = prefs.getString(_companyIdKey);
      
      if (companyId != null && companyId.isNotEmpty) {
        _memoryCompanyId = companyId; // メモリにキャッシュ
        if (kDebugMode) {
          debugPrint('🏢 企業ID取得（SharedPreferences）: $companyId');
        }
        return companyId;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ SharedPreferences取得失敗（デフォルト使用）: $e');
      }
    }
    
    // どちらも失敗した場合はデフォルト値
    if (kDebugMode) {
      debugPrint('🏢 企業ID取得（デフォルト）: $_defaultCompanyId');
    }
    return _defaultCompanyId;
  }
  
  /// 企業名を取得
  Future<String?> getCompanyName() async {
    // まずメモリから取得
    if (_memoryCompanyName != null && _memoryCompanyName!.isNotEmpty) {
      return _memoryCompanyName;
    }
    
    // SharedPreferencesから取得
    try {
      final prefs = await SharedPreferences.getInstance();
      final companyName = prefs.getString(_companyNameKey);
      if (companyName != null) {
        _memoryCompanyName = companyName; // メモリにキャッシュ
      }
      return companyName;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ 企業名取得失敗: $e');
      }
      return null;
    }
  }
  
  /// ログイン状態を確認
  Future<bool> isLoggedIn() async {
    // まずメモリをチェック
    if (_memoryCompanyId != null && _memoryCompanyId!.isNotEmpty) {
      return true;
    }
    
    // SharedPreferencesをチェック
    try {
      final prefs = await SharedPreferences.getInstance();
      final companyId = prefs.getString(_companyIdKey);
      if (companyId != null && companyId.isNotEmpty) {
        _memoryCompanyId = companyId; // メモリにキャッシュ
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ ログイン状態確認失敗: $e');
      }
    }
    
    return false;
  }
  
  /// ログアウト（企業ID削除）
  Future<bool> logout() async {
    // メモリをクリア（必ず実行）
    _memoryCompanyId = null;
    _memoryCompanyName = null;
    
    if (kDebugMode) {
      debugPrint('📝 メモリクリア完了');
    }
    
    // SharedPreferencesもクリア（失敗してもOK）
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_companyIdKey);
      await prefs.remove(_companyNameKey);
      
      if (kDebugMode) {
        debugPrint('✅ SharedPreferencesクリア完了');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ SharedPreferencesクリア失敗（メモリはクリア済み）: $e');
      }
    }
    
    return true;
  }
}
