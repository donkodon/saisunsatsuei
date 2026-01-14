import 'package:flutter/foundation.dart';

// 🔐 開発環境用: secrets.dart から認証情報を読み込む（オプション）
// secrets.dart が存在する場合のみインポート（存在しなくてもエラーにならない）
import 'secrets.dart' if (dart.library.io) 'secrets_stub.dart';

/// 🔐 Cloudflare R2 ストレージ設定クラス
/// 
/// 認証情報の優先順位:
/// 1. 環境変数（--dart-define）← 本番環境推奨
/// 2. secrets.dart ← 開発環境推奨
/// 3. デフォルト値（空文字）
/// 
/// 【開発環境】secrets.dart を使う方法:
/// ```bash
/// cp lib/config/secrets.dart.example lib/config/secrets.dart
/// # エディタで secrets.dart を開いて実際の認証情報を入力
/// flutter run  # そのまま実行するだけ
/// ```
/// 
/// 【本番環境】環境変数を使う方法:
/// ```bash
/// flutter build apk \
///   --dart-define=CLOUDFLARE_ACCOUNT_ID=your_account_id \
///   --dart-define=CLOUDFLARE_BUCKET_NAME=your_bucket_name \
///   --dart-define=CLOUDFLARE_API_TOKEN=your_api_token \
///   --dart-define=CLOUDFLARE_PUBLIC_DOMAIN=your_public_domain
/// ```
class CloudflareConfig {
  /// Cloudflare アカウントID
  static String get accountId {
    // 優先順位: 環境変数 → secrets.dart → デフォルト
    const envValue = String.fromEnvironment('CLOUDFLARE_ACCOUNT_ID', defaultValue: '');
    if (envValue.isNotEmpty) return envValue;
    
    try {
      return Secrets.cloudflareAccountId;
    } catch (e) {
      return '';  // secrets.dart が存在しない場合
    }
  }
  
  /// R2 バケット名
  static String get bucketName {
    const envValue = String.fromEnvironment('CLOUDFLARE_BUCKET_NAME', defaultValue: '');
    if (envValue.isNotEmpty) return envValue;
    return 'product-images';  // デフォルト
  }
  
  /// Cloudflare API トークン
  static String get apiToken {
    const envValue = String.fromEnvironment('CLOUDFLARE_API_TOKEN', defaultValue: '');
    if (envValue.isNotEmpty) return envValue;
    
    try {
      return Secrets.cloudflareApiToken;
    } catch (e) {
      return '';
    }
  }
  
  /// R2 公開ドメイン
  static String get publicDomain {
    const envValue = String.fromEnvironment('CLOUDFLARE_PUBLIC_DOMAIN', defaultValue: '');
    if (envValue.isNotEmpty) return envValue;
    
    try {
      return Secrets.cloudflarePublicDomain;
    } catch (e) {
      return 'pub-300562464768499b8fcaee903d0f9861.r2.dev';
    }
  }
  
  /// 🔍 設定が完全かチェック
  static bool get isConfigured {
    return accountId.isNotEmpty && 
           bucketName.isNotEmpty && 
           apiToken.isNotEmpty &&
           publicDomain.isNotEmpty;
  }
  
  /// ⚠️ 設定エラーメッセージ
  static String get configErrorMessage {
    if (isConfigured) return '';
    
    final missing = <String>[];
    if (accountId.isEmpty) missing.add('CLOUDFLARE_ACCOUNT_ID');
    if (bucketName.isEmpty) missing.add('CLOUDFLARE_BUCKET_NAME');
    if (apiToken.isEmpty) missing.add('CLOUDFLARE_API_TOKEN');
    if (publicDomain.isEmpty) missing.add('CLOUDFLARE_PUBLIC_DOMAIN');
    
    return '🔐 Cloudflare設定が不完全です。以下の環境変数を設定してください:\n  ${missing.join('\n  ')}';
  }
  
  /// 🔧 現在の設定を表示（デバッグ用 - トークンは隠す）
  static void printCurrentConfig() {
    if (kDebugMode) {
      debugPrint('☁️ Cloudflare R2 Configuration:');
      debugPrint('   Account ID: ${_maskSensitive(accountId)}');
      debugPrint('   Bucket Name: $bucketName');
      debugPrint('   API Token: ${_maskSensitive(apiToken)}');
      debugPrint('   Public Domain: $publicDomain');
      debugPrint('   Is Configured: $isConfigured');
    }
  }
  
  /// 機密情報をマスク表示
  static String _maskSensitive(String value) {
    if (value.isEmpty) return '(未設定)';
    if (value.length <= 8) return '****';
    return '${value.substring(0, 4)}...${value.substring(value.length - 4)}';
  }
}
