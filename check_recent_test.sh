#!/bin/bash

echo "🔍 1025L280002 の採寸データ確認"
echo "================================"

D1_API_URL="https://measure-master-api.jinkedon2.workers.dev"

echo "📊 SKU: 1025L280002 のデータを取得..."

curl -X GET "${D1_API_URL}/api/products?sku=1025L280002" \
  -H "Content-Type: application/json" \
  -s | python3 -m json.tool 2>/dev/null || curl -X GET "${D1_API_URL}/api/products?sku=1025L280002" -s

echo ""
echo "================================"

# 最新のテストデータも確認
echo ""
echo "🔍 TEST_CONNECTION_001 のデータ確認"
echo "================================"

curl -X GET "${D1_API_URL}/api/products?sku=TEST_CONNECTION_001" \
  -H "Content-Type: application/json" \
  -s | python3 -m json.tool 2>/dev/null || curl -X GET "${D1_API_URL}/api/products?sku=TEST_CONNECTION_001" -s

echo ""
echo "================================"
