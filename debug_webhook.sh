#!/bin/bash

echo "🔍 Webhook動作テスト"
echo "================================"
echo ""

D1_API_URL="https://measure-master-api.jinkedon2.workers.dev"
TEST_SKU="WEBHOOK_TEST_$(date +%s)"

echo "📡 Step 1: AI採寸リクエスト送信"
echo "SKU: ${TEST_SKU}"
echo ""

RESPONSE=$(curl -X POST "${D1_API_URL}/api/measure" \
  -H "Content-Type: application/json" \
  -d "{
    \"image_url\": \"https://firebasestorage.googleapis.com/test_webhook.jpg\",
    \"sku\": \"${TEST_SKU}\",
    \"company_id\": \"test_company\",
    \"garment_class\": \"long sleeve top\"
  }" \
  -s)

echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"

PREDICTION_ID=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('prediction_id', 'なし'))" 2>/dev/null)

echo ""
echo "✅ prediction_id: ${PREDICTION_ID}"
echo ""
echo "⏳ Step 2: 60秒待機（Replicateの処理完了を待つ）..."
echo "   Webhook URLは: ${D1_API_URL}/api/webhook/replicate?sku=${TEST_SKU}&company_id=test_company"
echo ""

# 60秒待機
for i in {60..1}; do
  echo -ne "   残り ${i} 秒...\r"
  sleep 1
done

echo ""
echo ""
echo "📊 Step 3: D1から結果を確認"
echo "================================"

curl -X GET "${D1_API_URL}/api/products?sku=${TEST_SKU}" \
  -H "Content-Type: application/json" \
  -s | python3 -c "
import sys, json
data = json.load(sys.stdin)
products = data.get('products', [])
if not products:
    print('❌ データが見つかりませんでした！')
    print('   Webhookが動作していない可能性があります。')
else:
    print('✅ データが見つかりました！')
    for p in products:
        items = p.get('capturedItems', [])
        if items:
            item = items[0]
            print(f\"   - measurements: {item.get('measurements', 'なし')}\")
            print(f\"   - ai_landmarks: {'あり' if item.get('ai_landmarks') else 'なし'}\")
            print(f\"   - measurement_image_url: {item.get('measurement_image_url', 'なし')}\")
" 2>/dev/null

echo ""
echo "================================"
echo "✅ テスト完了"
echo ""
echo "💡 Cloudflare Workers のログも確認してください:"
echo "   https://dash.cloudflare.com/ → Workers & Pages → measure-master-api → Logs"
