# 🔍 AI自動採寸デバッグガイド

## 📋 概要

このドキュメントでは、AI自動採寸機能のデバッグログを確認する方法を説明します。

## 🎯 AI自動採寸の動作フロー

```
[AddItemScreen]
    ↓ AI自動採寸トグルON
[DetailScreen]
    ↓ 商品確定ボタン
[MeasurementService]
    ↓ measureGarmentAsync()
[MeasurementApiClient]
    ↓ POST /api/measure
[Cloudflare Workers]
    ↓ Replicate API呼び出し
[Webhook]
    ↓ /api/webhook/replicate
[D1 Database]
    ↓ product_items テーブル更新
    - measurements (肩幅/袖丈/着丈/身幅)
    - ai_landmarks (ランドマーク座標)
    - reference_object (基準物体情報)
    - measurement_image_url (採寸画像URL)
    - mask_image_url (マスク画像URL)
```

## 🔍 デバッグログの確認方法

### 1. AddItemScreen でのトグル状態確認

**ログ出力場所**: `lib/screens/add_item_screen.dart`

```
🔍 ========== 商品詳細画面への遷移 ==========
📏 AI自動採寸トグル状態: ON/OFF
📸 画像数: X枚
📦 商品名: XXX
🏷️ SKU: XXX
==========================================
```

**確認ポイント**:
- `AI自動採寸トグル状態: ON` であることを確認
- 画像が1枚以上あることを確認

---

### 2. CameraScreenV2 での初期化確認

**ログ出力場所**: `lib/screens/camera_screen_v2.dart`

```
🔍 ========== CameraScreenV2 初期化 ==========
📏 AI自動採寸フラグ: ON/OFF
📸 既存画像数: X枚
📦 商品名: XXX
🏷️ SKU: XXX
==========================================
```

**確認ポイント**:
- `AI自動採寸フラグ: ON` が正しく渡されている

---

### 3. DetailScreen での採寸実行確認

**ログ出力場所**: `lib/screens/detail_screen.dart`

```
🔍 ========== AI自動採寸デバッグ情報 ==========
📏 AI自動採寸トグル: ON
📸 アップロード済み画像数: X枚
🎯 採寸対象画像（シーケンス1）: https://...
📦 SKU: XXX
🏢 企業ID取得中...
🏢 企業ID: XXX
📂 カテゴリ: XXX
🚀 Replicate API呼び出し開始...
✅ AI採寸リクエスト送信成功
⏳ Webhook経由でD1に結果が保存されます
   - measurements (肩幅/袖丈/着丈/身幅)
   - ai_landmarks (ランドマーク座標)
   - reference_object (基準物体情報)
   - measurement_image_url (採寸画像URL)
   - mask_image_url (マスク画像URL)
==========================================
```

**確認ポイント**:
- `AI自動採寸トグル: ON` であること
- 画像URLが正しく取得されていること
- SKUと企業IDが正しく設定されていること
- `✅ AI採寸リクエスト送信成功` が表示されること

---

### 4. MeasurementService でのリクエスト送信確認

**ログ出力場所**: `lib/features/measurement/logic/measurement_service.dart`

```
🔍 ========== MeasurementService デバッグ ==========
📥 受信パラメータ:
   imageUrl: https://...
   sku: XXX
   companyId: XXX
   category: XXX
🔄 カテゴリ変換結果:
   XXX → long sleeve top / jacket / pants
📏 AI採寸リクエスト送信開始...
📡 Workers レスポンス受信:
   success: true
   prediction_id: XXX
   status: processing
   message: AI採寸処理を開始しました...
✅ AI採寸リクエスト完了: prediction_id=XXX
💾 ローカルDBに記録完了
⏳ Webhook経由でD1に結果が保存されます:
   - product_items.measurements (肩幅/袖丈/着丈/身幅)
   - product_items.ai_landmarks (ランドマーク座標)
   - product_items.reference_object (基準物体情報)
   - product_items.measurement_image_url (採寸画像)
   - product_items.mask_image_url (マスク画像)
==========================================
```

**確認ポイント**:
- カテゴリ変換が正しく行われていること
- Workers APIから `success: true` が返ってくること
- `prediction_id` が取得できていること

---

### 5. MeasurementApiClient でのAPI呼び出し確認

**ログ出力場所**: `lib/features/measurement/data/measurement_api_client.dart`

```
🔍 ========== MeasurementApiClient デバッグ ==========
📏 AI自動採寸API呼び出し開始
🎯 リクエスト詳細:
   画像URL: https://...
   SKU: XXX
   企業ID: XXX
   衣類タイプ: long sleeve top
📤 Workers APIリクエスト送信:
   エンドポイント: https://measure-master-api.jinkedon2.workers.dev/api/measure
   メソッド: POST
   Body: {...}
   タイムアウト: 10秒
📡 Workers APIレスポンス受信:
   HTTPステータス: 200
   レスポンスBody: {...}
✅ 採寸リクエスト受付成功
📊 レスポンス詳細:
   status: processing
   prediction_id: XXX
   message: AI採寸処理を開始しました...
🔗 Webhook URL設定済み:
   /api/webhook/replicate?sku=XXX&company_id=XXX
📦 採寸結果データ確認:
   measurements: null（Webhook完了後に設定）
   measurement_image_url: null（Webhook完了後に設定）
   mask_image_url: null（Webhook完了後に設定）
   ai_landmarks: null（Webhook完了後に設定）
   reference_object: null（Webhook完了後に設定）
==========================================
```

**確認ポイント**:
- Workers APIエンドポイントが正しいこと
- HTTPステータスが200であること
- `success: true` と `prediction_id` が取得できていること
- Webhook URLが正しく設定されていること

---

## ❌ エラーケースの確認

### トグルOFFの場合

```
⚠️ AI自動採寸スキップ:
   理由: AI自動採寸トグルがOFF
```

### 画像が0枚の場合

```
⚠️ AI自動採寸スキップ:
   理由: アップロード済み画像が0枚
```

### API呼び出しエラーの場合

```
❌ AI採寸リクエスト送信エラー: XXX
==========================================
```

```
❌ AI採寸エラー発生: XXX
📍 エラー発生箇所: ...
==========================================
```

---

## 🔧 トラブルシューティング

### 問題1: AI採寸が実行されない

**確認項目**:
1. AddItemScreen でトグルがONになっているか
2. 画像が1枚以上アップロードされているか
3. SKUが設定されているか

**ログ確認**:
- `AI自動採寸トグル状態: ON` が表示されるか
- `📸 アップロード済み画像数: X枚` で1以上か

---

### 問題2: API呼び出しが失敗する

**確認項目**:
1. Workers APIエンドポイントが正しいか
2. ネットワーク接続が正常か
3. Replicate APIキーが設定されているか

**ログ確認**:
- `HTTPステータス: 200` が表示されるか
- `success: true` が返ってくるか

---

### 問題3: Webhookが動作しない

**確認項目**:
1. Webhook URLが正しく設定されているか
2. Replicate APIで処理が完了しているか
3. D1データベースが正常か

**ログ確認**:
- `🔗 Webhook URL設定済み` が表示されるか
- Cloudflare Workers のログを確認

---

## 📊 D1データベース確認方法

### Cloudflare Dashboard でD1を確認

1. Cloudflare Dashboard にログイン
2. Workers & Pages → D1 → `measure-master-db`
3. `product_items` テーブルを確認
4. SKUで検索して該当レコードを確認

### 確認すべきフィールド

```sql
SELECT 
    sku,
    measurements,
    ai_landmarks,
    reference_object,
    measurement_image_url,
    mask_image_url,
    updated_at
FROM product_items
WHERE sku = 'YOUR_SKU'
ORDER BY updated_at DESC
LIMIT 1;
```

**期待される結果**:
- `measurements`: JSON文字列（肩幅/袖丈/着丈/身幅）
- `ai_landmarks`: JSON文字列（ランドマーク座標）
- `reference_object`: JSON文字列（基準物体情報）
- `measurement_image_url`: 採寸画像のURL
- `mask_image_url`: マスク画像のURL

---

## 🎯 正常動作の判定基準

### ✅ 成功ケース

1. AddItemScreen: `AI自動採寸トグル状態: ON`
2. DetailScreen: `✅ AI採寸リクエスト送信成功`
3. MeasurementService: `✅ AI採寸リクエスト完了: prediction_id=XXX`
4. MeasurementApiClient: `HTTPステータス: 200` + `success: true`
5. Cloudflare Workers ログ: Webhook受信 + D1更新成功

### ❌ 失敗ケース

1. トグルOFF: `AI自動採寸スキップ`
2. 画像なし: `アップロード済み画像が0枚`
3. API エラー: `❌ AI採寸エラー発生`
4. Webhook エラー: Cloudflare Workers ログにエラー

---

## 📞 サポート

問題が解決しない場合は、以下の情報を含めて報告してください:

1. 完全なデバッグログ（上記の全セクション）
2. SKU
3. 企業ID
4. 画像URL
5. エラーメッセージ

