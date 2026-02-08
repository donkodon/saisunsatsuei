#!/bin/bash
# 🚀 本番環境ビルド設定
# 
# 使用方法:
# 1. このファイルを編集して実際の認証情報を入力
# 2. 実行権限を付与: chmod +x build_config_production.sh
# 3. ビルド実行: ./build_config_production.sh

# ⚠️ セキュリティ注意: このファイルは .gitignore に追加済み
# 認証情報を含むため、絶対にGitにコミットしないでください

# Cloudflare R2 設定
export CLOUDFLARE_ACCOUNT_ID="YOUR_ACCOUNT_ID_HERE"
export CLOUDFLARE_BUCKET_NAME="product-images"
export CLOUDFLARE_API_TOKEN="YOUR_API_TOKEN_HERE"
export CLOUDFLARE_PUBLIC_DOMAIN="pub-300562464768499b8fcaee903d0f9861.r2.dev"

# API設定
export API_BASE_URL="https://your-production-api.com"
export D1_API_URL="https://measure-master-api.jinkedon2.workers.dev"

# ビルド実行
echo "🔨 本番環境APKをビルドしています..."
flutter build apk --release \
  --dart-define=CLOUDFLARE_ACCOUNT_ID=$CLOUDFLARE_ACCOUNT_ID \
  --dart-define=CLOUDFLARE_BUCKET_NAME=$CLOUDFLARE_BUCKET_NAME \
  --dart-define=CLOUDFLARE_API_TOKEN=$CLOUDFLARE_API_TOKEN \
  --dart-define=CLOUDFLARE_PUBLIC_DOMAIN=$CLOUDFLARE_PUBLIC_DOMAIN \
  --dart-define=API_BASE_URL=$API_BASE_URL \
  --dart-define=D1_API_URL=$D1_API_URL

echo "✅ ビルド完了！"
echo "📦 APKファイル: build/app/outputs/flutter-apk/app-release.apk"
