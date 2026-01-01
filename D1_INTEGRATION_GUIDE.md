# 🚀 Cloudflare D1 統合ガイド

## 📋 概要

Measure Master アプリを Cloudflare D1 Database と統合し、複数ユーザーでのリアルタイム同期を実現します。

---

## 🏗️ アーキテクチャ

```
📱 Flutter App
    ↓
💾 Hive (ローカルキャッシュ)
    ↓
🌐 Cloudflare Workers API
    ↓
🗄️ Cloudflare D1 Database
```

**メリット:**
- ⚡ 高速レスポンス (50-150ms)
- 💰 低コスト (無料枠: 500万読み取り/日)
- 🔄 複数ユーザー同時作業
- 📦 全部Cloudflareエコシステム

---

## Phase 1: D1 データベースセットアップ

### 1-1. Cloudflare Dashboard でデータベース作成

1. https://dash.cloudflare.com/ にログイン
2. **Workers & Pages** → **D1** → **Create database**
3. Database name: `measure-master-db`
4. **Create** をクリック

### 1-2. テーブル作成

D1コンソールで以下のSQLを実行:

```sql
-- 📦 商品テーブル
CREATE TABLE products (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sku TEXT UNIQUE NOT NULL,
  barcode TEXT,
  name TEXT NOT NULL,
  brand TEXT,
  category TEXT,
  size TEXT,
  color TEXT,
  material TEXT,
  condition TEXT,
  product_rank TEXT,
  price TEXT,
  description TEXT,
  image_urls TEXT, -- JSON配列
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_by TEXT,
  status TEXT DEFAULT 'Ready'
);

-- 📊 インデックス作成
CREATE INDEX idx_sku ON products(sku);
CREATE INDEX idx_barcode ON products(barcode);
CREATE INDEX idx_updated_at ON products(updated_at DESC);
CREATE INDEX idx_status ON products(status);
```

### 1-3. Database ID を取得

```bash
# CLIで確認
wrangler d1 list

# または Dashboard で Database ID をコピー
```

---

## Phase 2: Cloudflare Workers API 作成

### 2-1. Workers プロジェクト作成

```bash
# ローカル環境で
mkdir measure-master-api
cd measure-master-api
npm create cloudflare@latest
```

### 2-2. wrangler.toml 設定

```toml
name = "measure-master-api"
main = "src/index.js"
compatibility_date = "2024-01-01"

[[d1_databases]]
binding = "DB"
database_name = "measure-master-db"
database_id = "あなたのDATABASE_IDをここに"
```

### 2-3. Workers API コード

`src/index.js` を作成:

```javascript
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;
    
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    };
    
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    try {
      // 📋 商品一覧
      if (path === '/api/products' && request.method === 'GET') {
        const limit = url.searchParams.get('limit') || 100;
        const offset = url.searchParams.get('offset') || 0;
        
        const { results } = await env.DB.prepare(
          'SELECT * FROM products ORDER BY updated_at DESC LIMIT ? OFFSET ?'
        ).bind(limit, offset).all();
        
        return Response.json({ 
          success: true, 
          products: results 
        }, { headers: corsHeaders });
      }
      
      // 🔍 SKU検索
      if (path === '/api/products/search' && request.method === 'GET') {
        const sku = url.searchParams.get('sku');
        
        const result = await env.DB.prepare(
          'SELECT * FROM products WHERE sku = ?'
        ).bind(sku).first();
        
        return Response.json({ 
          success: true, 
          product: result 
        }, { headers: corsHeaders });
      }
      
      // 💾 商品登録・更新
      if (path === '/api/products' && request.method === 'POST') {
        const data = await request.json();
        
        const result = await env.DB.prepare(`
          INSERT INTO products (
            sku, barcode, name, brand, category, size, color, 
            material, condition, product_rank, price, description, 
            image_urls, status, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
          ON CONFLICT(sku) DO UPDATE SET
            barcode = excluded.barcode,
            name = excluded.name,
            brand = excluded.brand,
            category = excluded.category,
            size = excluded.size,
            color = excluded.color,
            material = excluded.material,
            condition = excluded.condition,
            product_rank = excluded.product_rank,
            price = excluded.price,
            description = excluded.description,
            image_urls = excluded.image_urls,
            status = excluded.status,
            updated_at = CURRENT_TIMESTAMP
        `).bind(
          data.sku, data.barcode, data.name, data.brand, data.category,
          data.size, data.color, data.material, data.condition,
          data.productRank, data.price, data.description,
          JSON.stringify(data.imageUrls), data.status
        ).run();
        
        return Response.json({ 
          success: true, 
          message: '商品を保存しました',
          sku: data.sku
        }, { headers: corsHeaders });
      }
      
      return Response.json({ 
        success: false, 
        error: 'Not Found' 
      }, { 
        status: 404, 
        headers: corsHeaders 
      });
      
    } catch (error) {
      return Response.json({ 
        success: false, 
        error: error.message 
      }, { 
        status: 500, 
        headers: corsHeaders 
      });
    }
  }
};
```

### 2-4. Workers デプロイ

```bash
wrangler deploy
```

デプロイ後、Workers URL を取得:
```
https://measure-master-api.あなたのアカウント.workers.dev
```

---

## Phase 3: Flutter アプリ側の設定

### 3-1. API URL を更新

`lib/services/api_service.dart` の `d1ApiUrl` を更新:

```dart
static const String d1ApiUrl = 'https://measure-master-api.あなたのアカウント.workers.dev';
```

### 3-2. 動作確認

Flutter アプリを再ビルド:
```bash
cd /home/user/flutter_app
flutter build web --release
```

---

## 🧪 テスト手順

### 1. 商品登録テスト

1. Flutter アプリで商品を撮影
2. 商品情報を入力
3. 「商品確定」ボタンをクリック
4. コンソールログで確認:
   ```
   ✅ D1に保存成功: 1025L290003
   ```

### 2. 同期テスト

1. **ユーザーA**: 商品を登録
2. **ユーザーB**: アプリをリロード
3. **ユーザーB**: ダッシュボードで商品が表示されることを確認

### 3. API直接テスト

```bash
# 商品リスト取得
curl https://measure-master-api.xxx.workers.dev/api/products

# SKU検索
curl https://measure-master-api.xxx.workers.dev/api/products/search?sku=1025L290003
```

---

## 📊 パフォーマンス目標

| 操作 | 目標レスポンス |
|------|---------------|
| 商品リスト取得 | < 150ms |
| SKU検索 | < 100ms |
| 商品登録 | < 200ms |

---

## 🔧 トラブルシューティング

### エラー: "CORS policy"

**原因**: Workers API の CORS設定不足

**解決策**: `corsHeaders` が正しく設定されているか確認

### エラー: "D1 Database not found"

**原因**: wrangler.toml の database_id が間違っている

**解決策**: Dashboard で正しい Database ID を確認

### エラー: "Network request failed"

**原因**: Workers URL が間違っている

**解決策**: `api_service.dart` の `d1ApiUrl` を確認

---

## 📈 今後の拡張

- [ ] ユーザー認証 (Cloudflare Access)
- [ ] リアルタイム通知 (Durable Objects WebSocket)
- [ ] 画像最適化 (Cloudflare Images)
- [ ] 全文検索 (D1 FTS5)
- [ ] 分析ダッシュボード (Workers Analytics)

---

## 💰 コスト見積もり

**月間利用量 (10人チーム):**
- 読み取り: 30,000回/日 × 30日 = 900,000回
- 書き込み: 100回/日 × 30日 = 3,000回
- ストレージ: 1GB

**料金**: **無料** (Cloudflare D1 無料枠内)

---

## ✅ チェックリスト

Phase 1:
- [ ] D1 Database 作成
- [ ] テーブル作成
- [ ] インデックス作成

Phase 2:
- [ ] Workers プロジェクト作成
- [ ] wrangler.toml 設定
- [ ] API コード実装
- [ ] Workers デプロイ

Phase 3:
- [ ] Flutter アプリで API URL 設定
- [ ] アプリ再ビルド
- [ ] 動作確認

---

完成したら、複数ユーザーで同時に商品登録できるようになります!🎉
