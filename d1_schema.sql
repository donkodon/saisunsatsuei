-- ============================================
-- 🏢 マルチテナント対応 D1 スキーマ
-- company_id が最優先キー
-- 同じSKUでも企業IDが違えば別レコード
-- ============================================

-- 商品マスタテーブル (WEBアプリ管理)
-- 主キー: company_id + sku の複合キー
CREATE TABLE IF NOT EXISTS product_master (
  company_id TEXT NOT NULL DEFAULT '',
  sku TEXT NOT NULL,
  barcode TEXT,
  name TEXT NOT NULL,
  brand TEXT,
  category TEXT,
  size TEXT,
  color TEXT,
  price INTEGER,
  description TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (company_id, sku)
);

-- 商品実物データテーブル (スマホアプリ管理)
CREATE TABLE IF NOT EXISTS product_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  company_id TEXT NOT NULL DEFAULT '',
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
  FOREIGN KEY (company_id, sku) REFERENCES product_master(company_id, sku)
);

-- インデックス
CREATE INDEX IF NOT EXISTS idx_master_company ON product_master(company_id);
CREATE INDEX IF NOT EXISTS idx_master_barcode ON product_master(company_id, barcode);
CREATE INDEX IF NOT EXISTS idx_items_company_sku ON product_items(company_id, sku);
CREATE INDEX IF NOT EXISTS idx_items_code ON product_items(item_code);
