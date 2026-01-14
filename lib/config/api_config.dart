import 'package:flutter/foundation.dart';

/// 🌐 API設定クラス
/// 
/// 環境ごとに異なるAPIエンドポイントを管理します。
/// ビルド時に --dart-define で環境変数を指定できます。
/// 
/// 使用例:
/// ```bash
/// # 開発環境
/// flutter run
/// 
/// # 本番環境
/// flutter build apk --dart-define=API_BASE_URL=https://production-api.example.com
/// ```
class ApiConfig {
  /// メインAPIのベースURL
  /// 
  /// 環境変数 API_BASE_URL で上書き可能
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://3000-iuolnmmls4a53d2939w4c-3844e1b6.sandbox.novita.ai',
  );
  
  /// Cloudflare D1 API URL（本番環境）
  /// 
  /// 環境変数 D1_API_URL で上書き可能
  static const String d1ApiUrl = String.fromEnvironment(
    'D1_API_URL',
    defaultValue: 'https://measure-master-api.jinkedon2.workers.dev',
  );
  
  /// 🔧 現在の設定を表示（デバッグ用）
  static void printCurrentConfig() {
    if (kDebugMode) {
      debugPrint('📡 API Configuration:');
      debugPrint('   Base URL: $baseUrl');
      debugPrint('   D1 API URL: $d1ApiUrl');
    }
  }
}
