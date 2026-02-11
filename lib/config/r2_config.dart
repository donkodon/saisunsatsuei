class R2Config {
  // ⚠️ Cloudflare R2 Credentials
  // 以下の情報を入力してください
  static const String accountId = 'YOUR_ACCOUNT_ID';
  static const String accessKey = 'YOUR_ACCESS_KEY';
  static const String secretKey = 'YOUR_SECRET_KEY';
  static const String bucketName = 'YOUR_BUCKET_NAME';
  
  // Public URL Domain (Optional) - if you have a custom domain or public access enabled
  // Example: https://pub-xxxxxxxx.r2.dev
  // Leave empty if you want to use the default S3 style URL (might need signed URLs for private buckets)
  static const String publicDomain = '';
  
  // Endpoint URL construction
  static String get endpoint => 'https://$accountId.r2.cloudflarestorage.com';
}
