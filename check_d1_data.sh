#!/bin/bash

echo "🔍 D1データベース確認"
echo "================================"

D1_API_URL="https://measure-master-api.jinkedon2.workers.dev"

echo "📊 テスト: product_items テーブルから最新データを取得"

# 最新の採寸データを取得
curl -X GET "${D1_API_URL}/api/products?limit=5" \
  -H "Content-Type: application/json" \
  -s | jq '.' 2>/dev/null || curl -X GET "${D1_API_URL}/api/products?limit=5" -s

echo ""
echo "================================"
