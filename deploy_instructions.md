# Cloudflare Workers デプロイ手順

## 前提条件
Cloudflare Workers AIを使用するには、Workers環境にデプロイする必要があります。

## デプロイ手順

### 1. Wranglerのインストール（もしまだの場合）
```bash
npm install -g wrangler
```

### 2. Cloudflareにログイン
```bash
wrangler login
```

### 3. D1 Databaseの設定
```bash
# D1データベースを作成
wrangler d1 create measure-master-db

# 出力されたdatabase_idをwrangler.tomlに設定
# 例: database_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

### 4. wrangler.tomlの編集
```toml
name = "smart-measure-api"
main = "cloudflare_workers_api.js"
compatibility_date = "2024-01-01"

[[d1_databases]]
binding = "DB"
database_name = "measure-master-db"
database_id = "YOUR_DATABASE_ID"  # ここを実際のIDに変更

[ai]
binding = "AI"
```

### 5. デプロイ
```bash
wrangler deploy
```

## デプロイ後のエンドポイント
```
https://smart-measure-api.YOUR_SUBDOMAIN.workers.dev/api/remove-bg
```

このエンドポイントをWEBサイトの`BACKGROUND_REMOVAL_API`に設定してください。
