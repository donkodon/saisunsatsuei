-- Measure Master Database Schema
-- 商品管理データベース

-- 1️⃣ 商品マスタテーブル（SKU・型番管理）
CREATE TABLE IF NOT EXISTS product_master (
  sku TEXT PRIMARY KEY,
  barcode TEXT,
  name TEXT NOT NULL,
  brand TEXT,
  brand_kana TEXT,
  category TEXT,
  category_sub TEXT,
  size TEXT,
  color TEXT,
  price INTEGER,
  price_cost INTEGER,
  price_sale INTEGER,
  price_ref INTEGER,
  price_list INTEGER,
  season TEXT,
  rank TEXT,
  release_date TEXT,
  buyer TEXT,
  store_name TEXT,
  location TEXT,
  stock_quantity INTEGER,
  status TEXT,
  description TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 2️⃣ 商品実物テーブル（撮影データ管理）
CREATE TABLE IF NOT EXISTS product_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sku TEXT NOT NULL,
  item_code TEXT UNIQUE NOT NULL,
  -- 📦 基本情報
  name TEXT,
  brand TEXT,
  category TEXT,
  size TEXT,
  color TEXT,
  -- 💰 価格情報
  price INTEGER,
  price_sale INTEGER,
  -- 📝 商品詳細
  condition TEXT,
  material TEXT,
  product_rank TEXT,
  description TEXT,
  inspection_notes TEXT,
  -- 📸 撮影データ
  image_urls TEXT,
  actual_measurements TEXT,
  photographed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  photographed_by TEXT,
  status TEXT DEFAULT 'Ready',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (sku) REFERENCES product_master(sku)
);

-- インデックス作成
CREATE INDEX IF NOT EXISTS idx_master_barcode ON product_master(barcode);
CREATE INDEX IF NOT EXISTS idx_items_sku ON product_items(sku);
CREATE INDEX IF NOT EXISTS idx_items_code ON product_items(item_code);

-- サンプルデータ投入（テスト用）
INSERT OR IGNORE INTO product_master (sku, name, brand, category, size, color, price) VALUES 
('1025L190003', 'ベーシックコットンTシャツ', 'STAYGOLD', 'トップス', 'L', 'ホワイト', 2980),
('1025L190004', 'デニムジーンズ', 'STAYGOLD', 'ボトムス', 'M', 'インディゴ', 4980),
('1025L190005', 'ウールニット', 'STAYGOLD', 'トップス', 'XL', 'グレー', 3980);
