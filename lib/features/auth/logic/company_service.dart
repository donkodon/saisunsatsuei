import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

/// 企業ID管理サービス
/// 
/// ログイン時の企業IDをSharedPreferencesに保存・取得する
class CompanyService {
  static const String _companyIdKey = 'company_id';
  static const String _companyNameKey = 'company_name';
  // デフォルト値なし（管理者招待制：Firestoreに登録されたcompanyIdのみ使用）
  
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
    
    
    // SharedPreferencesへの保存を試みる（失敗してもOK）
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_companyIdKey, companyId);
      
      if (companyName != null && companyName.isNotEmpty) {
        await prefs.setString(_companyNameKey, companyName);
      }
      
    } catch (e) {
      // SharedPreferences への保存失敗は無視（メモリ保存済みのため継続可能）
      debugPrint('⚠️ CompanyService.saveCompanyId SharedPrefs失敗: $e');
    }
    
    // メモリ保存は必ず成功するので true を返す
    return true;
  }
  
  /// 企業IDを取得（未設定の場合はnullを返す）
  Future<String?> getCompanyId() async {
    // まずメモリから取得を試みる
    if (_memoryCompanyId != null && _memoryCompanyId!.isNotEmpty) {
      return _memoryCompanyId!;
    }
    
    // SharedPreferencesから取得を試みる
    try {
      final prefs = await SharedPreferences.getInstance();
      final companyId = prefs.getString(_companyIdKey);
      
      if (companyId != null && companyId.isNotEmpty) {
        _memoryCompanyId = companyId; // メモリにキャッシュ
        return companyId;
      }
    } catch (e) {
      debugPrint('⚠️ CompanyService.getCompanyId SharedPrefs失敗: $e');
    }
    
    // どちらも失敗した場合はnullを返す（デフォルト値なし）
    return null;
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
      debugPrint('⚠️ CompanyService.isLoggedIn SharedPrefs失敗: $e');
    }
    
    return false;
  }
  
  /// ログアウト（企業ID削除）
  Future<bool> logout() async {
    // メモリをクリア（必ず実行）
    _memoryCompanyId = null;
    _memoryCompanyName = null;
    
    
    // SharedPreferencesもクリア（失敗してもOK）
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_companyIdKey);
      await prefs.remove(_companyNameKey);
      
    } catch (e) {
      debugPrint('⚠️ CompanyService.logout SharedPrefs失敗: $e');
    }
    
    return true;
  }
}
