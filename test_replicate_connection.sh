#!/bin/bash

echo "🔍 Replicate API接続テスト"
echo "================================"

# D1 API URLを確認
D1_API_URL="https://measure-master-api.jinkedon2.workers.dev"

echo "📡 テスト1: /api/measure エンドポイントにリクエスト送信"
echo "URL: ${D1_API_URL}/api/measure"

# テスト用のリクエスト
curl -X POST "${D1_API_URL}/api/measure" \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "https://firebasestorage.googleapis.com/test.jpg",
    "sku": "TEST_CONNECTION_001",
    "company_id": "test_company",
    "garment_class": "long sleeve top"
  }' \
  -s -w "\n\nHTTPステータス: %{http_code}\n" \
  2>&1

echo ""
echo "================================"
echo "✅ テスト完了"
