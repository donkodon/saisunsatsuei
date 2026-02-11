# 🚀 Cloudflare D1 統合ガイド (2テーブル方式)

## 📊 システム構成

### データベース構造

```
┌─────────────────────────┐
│  product_master         │  ← WEBアプリが管理 (CSV import)
│  - sku (PK)            │
│  - name, brand, etc.   │
└─────────────────────────┘
         ↑ 参照
┌─────────────────────────┐
│  product_items          │  ← スマホアプリが管理 (撮影データ)
│  - id (PK)             │
│  - sku (FK)            │
│  - image_urls          │
│  - measurements        │
│  - condition           │
└─────────────────────────┘
```

### データフロー

```
① WEBアプリ: CSV更新
   ↓
   product_master のみ更新
   (product_items は保護!)
   
② スマホアプリ: SKU検索
   ↓
   product_master + product_items を JOIN
   ↓
   撮影済みか判定 → UI表示
   
③ スマホアプリ: 撮影・保存
   ↓
   product_items に追加
   (product_master は触らない!)
```

---

## 🔧 Phase 1: Cloudflare D1セットアップ

### 1-1. D1データベース作成

1. https://dash.cloudflare.com/ にログイン
2. 左サイドバー → **Workers & Pages** → **D1**
3. **Create database** をクリック
4. Database name: `measure-master-db`
5. **Create** をクリック

### 1-2. Database ID取得

作成後、Database詳細ページでDatabase IDをコピー:
```
例: a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

### 1-3. テーブル作成

D1コンソール (Console タブ) で以下のSQLを実行:

```sql
-- ① 商品マスタテーブル
CREATE TABLE IF NOT EXISTS product_master (
  sku TEXT PRIMARY KEY,
  barcode TEXT,
  name TEXT NOT NULL,
  brand TEXT,
  category TEXT,
  size TEXT,
  color TEXT,
  price INTEGER,
  description TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ② 商品実物データテーブル
CREATE TABLE IF NOT EXISTS product_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sku TEXT NOT NULL,
  item_code TEXT UNIQUE NOT NULL,
  image_urls TEXT,
  actual_measurements TEXT,
  condition TEXT,
  material TEXT,
  product_rank TEXT,
  inspection_notes TEXT,
  photographed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  photographed_by TEXT,
  status TEXT DEFAULT 'Ready',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (sku) REFERENCES product_master(sku)
);

-- インデックス
CREATE INDEX IF NOT EXISTS idx_master_barcode ON product_master(barcode);
CREATE INDEX IF NOT EXISTS idx_items_sku ON product_items(sku);
CREATE INDEX IF NOT EXISTS idx_items_code ON product_items(item_code);
```

✅ "Query executed successfully" と表示されればOK!

---

## 🔧 Phase 2: Cloudflare Workers API作成

### 2-1. Workers プロジェクト作成

ローカル環境で:

```bash
mkdir measure-master-api
cd measure-master-api
npm create cloudflare@latest
```

プロンプトに答える:
- Application name: `measure-master-api`
- Type: `"Hello World" Worker`
- Use TypeScript: `No`
- Use git: `Yes`
- Deploy: `No` (後でデプロイ)

### 2-2. wrangler.toml設定

`wrangler.toml` を編集:

```toml
name = "measure-master-api"
main = "src/index.js"
compatibility_date = "2024-01-01"

[[d1_databases]]
binding = "DB"
database_name = "measure-master-db"
database_id = "YOUR_DATABASE_ID_HERE"  # ← Phase 1-2でコピーしたIDを貼り付け
```

### 2-3. APIコード配置

`src/index.js` を削除して、`cloudflare_workers_api.js` の内容をコピー:

```bash
# Flutter プロジェクトから
cp /home/user/flutter_app/cloudflare_workers_api.js src/index.js
```

### 2-4. Workers デプロイ

```bash
wrangler deploy
```

成功すると、Workers URLが表示されます:
```
https://measure-master-api.YOUR_ACCOUNT.workers.dev
```

このURLをコピーしてください!

---

## 📱 Phase 3: Flutter アプリ統合

### 3-1. API URL設定

`lib/services/api_service.dart` の8行目を編集:

```dart
// 🔧 Cloudflare D1 API エンドポイント
static const String d1ApiUrl = 'https://measure-master-api.YOUR_ACCOUNT.workers.dev';
```

### 3-2. アプリ再ビルド

```bash
cd /home/user/flutter_app
flutter build web --release
```

### 3-3. サーバー再起動

```bash
lsof -ti:5060 | xargs -r kill -9
cd /home/user/flutter_app/build/web
python3 -m http.server 5060 --bind 0.0.0.0 &
```

---

## 🧪 テスト手順

### Test 1: 商品マスタ登録 (WEBアプリ側)

```bash
# curlでテスト
curl -X POST https://measure-master-api.YOUR_ACCOUNT.workers.dev/api/products/bulk-import \
  -H "Content-Type: application/json" \
  -d '{
    "products": [
      {
        "sku": "TEST001",
        "barcode": "4901234567890",
        "name": "テスト商品",
        "brand": "テストブランド",
        "category": "トップス",
        "price": 5000
      }
    ]
  }'
```

期待レスポンス:
```json
{
  "success": true,
  "message": "マスタデータを更新しました",
  "inserted": 1,
  "updated": 0,
  "total": 1
}
```

### Test 2: SKU検索 (スマホアプリ側)

Flutter アプリで:
1. ダッシュボード検索バーに `TEST001` を入力
2. **結果**: マスタ情報が表示される
3. **ステータス**: "未撮影" (hasCapturedData: false)

コンソールログ:
```
🔍 D1検索結果:
  sku: TEST001
  name: テスト商品
  hasCapturedData: false
  capturedItems: []
```

### Test 3: 商品撮影・保存

1. 商品情報入力画面で「写真を追加」
2. カメラで撮影 (3枚)
3. 商品情報を入力
4. **商品確定** ボタンをクリック

コンソールログ:
```
✅ D1に実物データ保存成功: TEST001
```

### Test 4: 再検索 (撮影済み確認)

1. ダッシュボードで再度 `TEST001` を検索
2. **結果**: "撮影済み" バッジ表示
3. **撮影画像**: サムネイル3枚表示

コンソールログ:
```
🔍 D1検索結果:
  sku: TEST001
  hasCapturedData: true ✅
  capturedItems: [
    {
      item_code: "TEST001_1735200000000",
      image_urls: ["https://...jpg", "https://...jpg"],
      condition: "目立った傷や汚れなし"
    }
  ]
```

### Test 5: CSV再更新 (データ保護確認)

```bash
# マスタ情報を更新
curl -X POST https://measure-master-api.YOUR_ACCOUNT.workers.dev/api/products/bulk-import \
  -H "Content-Type: application/json" \
  -d '{
    "products": [
      {
        "sku": "TEST001",
        "name": "テスト商品 (更新版)",
        "price": 6000
      }
    ]
  }'
```

Flutter アプリで再検索:
- **商品名**: "テスト商品 (更新版)" ✅ 更新された
- **価格**: 6000 ✅ 更新された
- **撮影画像**: そのまま残っている ✅ 保護された!

---

## 🎯 API エンドポイント一覧

| エンドポイント | メソッド | 用途 |
|-------------|---------|------|
| `/api/products` | GET | 商品一覧取得 (マスタ+実物) |
| `/api/products/search?sku=XXX` | GET | SKU検索 |
| `/api/products/search-barcode?barcode=XXX` | GET | バーコード検索 |
| `/api/products/bulk-import` | POST | CSV一括登録 |
| `/api/products/items` | POST | 実物データ保存 |

---

## 📊 データ構造

### product_master (WEBアプリ管理)

```json
{
  "sku": "1025L290001",
  "barcode": "4901234567890",
  "name": "商品名",
  "brand": "ブランド名",
  "category": "カテゴリ",
  "size": "M",
  "color": "ブルー",
  "price": 5000,
  "description": "商品説明",
  "created_at": "2025-12-31T00:00:00Z",
  "updated_at": "2025-12-31T12:00:00Z"
}
```

### product_items (スマホアプリ管理)

```json
{
  "id": 1,
  "sku": "1025L290001",
  "item_code": "1025L290001_1735200000000",
  "image_urls": "[\"https://...\", \"https://...\"]",
  "actual_measurements": "{\"length\":68,\"width\":52}",
  "condition": "目立った傷や汚れなし",
  "material": "コットン100%",
  "product_rank": "A",
  "inspection_notes": "検品OK",
  "photographed_at": "2025-12-31T10:00:00Z",
  "photographed_by": "mobile_app_user",
  "status": "Ready"
}
```

---

## 🔧 トラブルシューティング

### エラー: "商品マスタが見つかりません"

**原因**: product_master にマスタデータがない

**解決策**: 
1. WEBアプリでCSV登録
2. または curl で手動登録

### エラー: "CORS policy"

**原因**: Workers APIのCORS設定不足

**解決策**: `cloudflare_workers_api.js` のcorsHeadersを確認

### エラー: "D1 Database not found"

**原因**: wrangler.toml の database_id が間違っている

**解決策**: Cloudflare Dashboard でDatabase IDを再確認

---

## ✅ チェックリスト

Phase 1: D1セットアップ
- [ ] D1 Database作成
- [ ] Database ID取得
- [ ] テーブル作成 (SQL実行)
- [ ] テーブル確認 (Console で SELECT * FROM product_master)

Phase 2: Workers API
- [ ] ローカルプロジェクト作成
- [ ] wrangler.toml 設定
- [ ] APIコード配置
- [ ] Workers デプロイ
- [ ] Workers URL取得

Phase 3: Flutter統合
- [ ] api_service.dart にURL設定
- [ ] Flutter再ビルド
- [ ] サーバー再起動
- [ ] 動作確認

---

## 🎉 完成!

これで以下が実現します:
- ✅ WEBアプリでCSV一括更新 (マスタのみ)
- ✅ スマホアプリで撮影データ追加 (実物データのみ)
- ✅ データ競合なし!
- ✅ 複数ユーザー同時作業可能!
- ✅ 撮影データは永久保護!

質問があればお気軽にどうぞ!🚀
