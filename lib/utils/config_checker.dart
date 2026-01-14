import 'package:flutter/foundation.dart';
import 'package:measure_master/config/cloudflare_config.dart';
import 'package:measure_master/config/api_config.dart';

/// 🔍 設定確認ユーティリティ
/// 
/// アプリ起動時に設定状態をチェックして、適切なメッセージを表示
class ConfigChecker {
  /// 全設定をチェック
  static void checkAllConfigs() {
    if (kDebugMode) {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📋 設定状態チェック');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      _checkApiConfig();
      _checkCloudflareConfig();
      
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }
  }
  
  /// API設定をチェック
  static void _checkApiConfig() {
    debugPrint('\n🌐 API設定:');
    debugPrint('   Base URL: ${ApiConfig.baseUrl}');
    debugPrint('   D1 API URL: ${ApiConfig.d1ApiUrl}');
  }
  
  /// Cloudflare設定をチェック
  static void _checkCloudflareConfig() {
    debugPrint('\n☁️ Cloudflare R2 設定:');
    debugPrint('   Account ID: ${_maskSensitive(CloudflareConfig.accountId)}');
    debugPrint('   Bucket Name: ${CloudflareConfig.bucketName}');
    debugPrint('   API Token: ${_maskSensitive(CloudflareConfig.apiToken)}');
    debugPrint('   Public Domain: ${CloudflareConfig.publicDomain}');
    debugPrint('   設定完了: ${CloudflareConfig.isConfigured ? "✅ 完了" : "⚠️ 未設定"}');
    
    if (!CloudflareConfig.isConfigured) {
      debugPrint('\n⚠️ Cloudflareが未設定です。');
      debugPrint('   画像アップロード機能を使用するには設定が必要です。');
      debugPrint('\n   【設定方法】');
      debugPrint('   1. lib/config/secrets.dart.example をコピー');
      debugPrint('   2. secrets.dart に実際の認証情報を入力');
      debugPrint('   3. アプリを再起動');
    }
  }
  
  /// 機密情報をマスク表示
  static String _maskSensitive(String value) {
    if (value.isEmpty) return '(未設定)';
    if (value.startsWith('YOUR_')) return '(テンプレート値 - 要設定)';
    if (value.length <= 8) return '****';
    return '${value.substring(0, 4)}...${value.substring(value.length - 4)}';
  }
}
