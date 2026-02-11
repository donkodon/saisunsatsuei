-- 商品マスタテーブル (WEBアプリ管理)
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

-- 商品実物データテーブル (スマホアプリ管理)
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
