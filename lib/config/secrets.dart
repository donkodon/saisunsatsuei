/// 🔐 機密情報テンプレート
/// 
/// このファイルは実際の認証情報を含みません。
/// 使用方法:
/// 1. このファイルを secrets.dart にコピー
/// 2. 実際の認証情報を入力
/// 3. secrets.dart は .gitignore に含まれているため Git にコミットされません
/// 
/// 使用例:
/// ```bash
/// cp lib/config/secrets.dart.example lib/config/secrets.dart
/// # エディタで secrets.dart を開いて実際の値を入力
/// ```
class Secrets {
  /// Cloudflare アカウントID
  /// 取得方法: https://dash.cloudflare.com/ → Overview → Account ID
  /// 
  /// 📝 実際の値の例: 'a1b2c3d4e5f6g7h8i9j0'
  static const String cloudflareAccountId = 'YOUR_ACCOUNT_ID_HERE';  // ← ここを実際の値に変更
  
  /// Cloudflare API トークン
  /// 取得方法: https://dash.cloudflare.com/ → My Profile → API Tokens
  /// 権限: R2 Read & Write
  /// 
  /// 📝 実際の値の例: 'abcdefghijklmnopqrstuvwxyz1234567890'
  static const String cloudflareApiToken = 'YOUR_API_TOKEN_HERE';  // ← ここを実際の値に変更
  
  /// Cloudflare R2 公開ドメイン
  /// 取得方法: R2バケット設定 → Public Access → Custom Domain
  /// 
  /// 📝 実際の値の例: 'pub-1234567890abcdef.r2.dev'
  static const String cloudflarePublicDomain = 'your-bucket.r2.dev';  // ← ここを実際の値に変更
  
  /// その他のAPI Key（必要に応じて追加）
  // static const String otherApiKey = 'YOUR_API_KEY_HERE';
}
