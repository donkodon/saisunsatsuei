// Cloudflare Workers API for Measure Master
// D1 Database integration with 2-table architecture
// 🏢 マルチテナント対応: company_id が最優先キー

// ============================================
// 🔧 テーブル初期化 (マイグレーション対応)
// ============================================
async function initializeDatabase(env) {
  try {
    // 既存テーブルの存在チェック
    const tableCheck = await env.DB.prepare(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='product_master'"
    ).first();

    if (tableCheck) {
      // 既存テーブルにcompany_idカラムがあるか確認
      const colCheck = await env.DB.prepare(
        "PRAGMA table_info(product_master)"
      ).all();
      
      const hasCompanyId = colCheck.results.some(col => col.name === 'company_id');
      
      if (!hasCompanyId) {
        // 🔄 マイグレーション: 既存テーブルにcompany_idを追加
        console.log('🔄 マイグレーション開始: company_id カラム追加');
        
        // 1. 旧テーブルをリネーム
        await env.DB.prepare('ALTER TABLE product_master RENAME TO product_master_old').run();
        await env.DB.prepare('ALTER TABLE product_items RENAME TO product_items_old').run();
        
        // 2. 新テーブル作成
        await createTables(env);
        
        // 3. 旧データ移行（company_id = '' でデフォルト）
        await env.DB.prepare(`
          INSERT INTO product_master (company_id, sku, barcode, name, brand, category, size, color, price, description, created_at, updated_at)
          SELECT '', sku, barcode, name, brand, category, size, color, price, description, created_at, updated_at
          FROM product_master_old
        `).run();
        
        await env.DB.prepare(`
          INSERT INTO product_items (company_id, sku, item_code, image_urls, actual_measurements, condition, material, product_rank, inspection_notes, photographed_at, photographed_by, status, created_at, updated_at)
          SELECT '', sku, item_code, image_urls, actual_measurements, condition, material, product_rank, inspection_notes, photographed_at, photographed_by, status, created_at, updated_at
          FROM product_items_old
        `).run();
        
        // 4. 旧テーブル削除
        await env.DB.prepare('DROP TABLE IF EXISTS product_items_old').run();
        await env.DB.prepare('DROP TABLE IF EXISTS product_master_old').run();
        
        console.log('✅ マイグレーション完了');
      } else {
        console.log('✅ テーブルは最新状態です');
      }
    } else {
      // 新規作成
      await createTables(env);
      console.log('✅ Database initialized successfully');
    }
  } catch (error) {
    console.error('❌ Database initialization error:', error);
    throw error;
  }
}

async function createTables(env) {
  await env.DB.prepare(`
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
    )
  `).run();
  
  await env.DB.prepare(`
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
    )
  `).run();
  
  await env.DB.prepare('CREATE INDEX IF NOT EXISTS idx_master_company ON product_master(company_id)').run();
  await env.DB.prepare('CREATE INDEX IF NOT EXISTS idx_master_barcode ON product_master(company_id, barcode)').run();
  await env.DB.prepare('CREATE INDEX IF NOT EXISTS idx_items_company_sku ON product_items(company_id, sku)').run();
  await env.DB.prepare('CREATE INDEX IF NOT EXISTS idx_items_code ON product_items(item_code)').run();
}

// ============================================
// 🏢 company_id 抽出ヘルパー
// ============================================
function getCompanyId(request, url) {
  // 優先順: 1. ヘッダー → 2. クエリパラメータ → 3. ボディ
  return request.headers.get('X-Company-Id') 
    || url.searchParams.get('companyId') 
    || null;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;
    
    // CORS設定（X-Company-Idヘッダーを明示的に許可）
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, X-Company-Id, x-company-id',
      'Access-Control-Max-Age': '86400',
    };
    
    if (request.method === 'OPTIONS') {
      return new Response(null, { 
        status: 204,
        headers: corsHeaders 
      });
    }

    // 🔧 DB初期化/マイグレーション
    if (path === '/api/init' && request.method === 'GET') {
      await initializeDatabase(env);
      return Response.json({ 
        success: true, 
        message: 'Database initialized successfully' 
      }, { headers: corsHeaders });
    }

    try {
      // ================================================
      // 📋 商品一覧取得 (企業ID必須)
      // ================================================
      if (path === '/api/products' && request.method === 'GET') {
        const companyId = getCompanyId(request, url) || '';
        const limit = parseInt(url.searchParams.get('limit') || '100');
        const offset = parseInt(url.searchParams.get('offset') || '0');
        
        // 🏢 企業IDでフィルタリング
        const { results: masters } = await env.DB.prepare(`
          SELECT * FROM product_master 
          WHERE company_id = ?
          ORDER BY updated_at DESC 
          LIMIT ? OFFSET ?
        `).bind(companyId, limit, offset).all();
        
        const products = await Promise.all(
          masters.map(async (master) => {
            const { results: items } = await env.DB.prepare(
              'SELECT * FROM product_items WHERE company_id = ? AND sku = ? ORDER BY photographed_at DESC'
            ).bind(companyId, master.sku).all();
            
            return {
              ...master,
              hasCapturedData: items.length > 0,
              capturedItems: items,
              latestItem: items[0] || null,
              capturedCount: items.length,
            };
          })
        );
        
        return Response.json({ 
          success: true, 
          products: products,
          total: masters.length,
          companyId: companyId,
        }, { headers: corsHeaders });
      }
      
      // ================================================
      // 🔍 SKU検索 (企業ID優先)
      // ================================================
      if (path === '/api/products/search' && request.method === 'GET') {
        const companyId = getCompanyId(request, url) || '';
        const sku = url.searchParams.get('sku');
        
        if (!sku) {
          return Response.json({ 
            success: false, 
            error: 'SKUが指定されていません' 
          }, { status: 400, headers: corsHeaders });
        }
        
        // 🏢 企業ID + SKU で検索
        const master = await env.DB.prepare(
          'SELECT * FROM product_master WHERE company_id = ? AND sku = ?'
        ).bind(companyId, sku).first();
        
        if (!master) {
          return Response.json({ 
            success: false, 
            error: '商品マスタが見つかりません',
            sku: sku,
            companyId: companyId,
          }, { status: 404, headers: corsHeaders });
        }
        
        const { results: items } = await env.DB.prepare(
          'SELECT * FROM product_items WHERE company_id = ? AND sku = ? ORDER BY photographed_at DESC'
        ).bind(companyId, sku).all();
        
        return Response.json({ 
          success: true,
          product: {
            ...master,
            hasCapturedData: items.length > 0,
            capturedItems: items,
            latestItem: items[0] || null,
            capturedCount: items.length,
          }
        }, { headers: corsHeaders });
      }
      
      // ================================================
      // 💾 商品マスタ一括登録 (企業ID付き)
      // ================================================
      if (path === '/api/products/bulk-import' && request.method === 'POST') {
        const data = await request.json();
        const companyId = data.companyId || getCompanyId(request, url) || '';
        const products = data.products || [];
        
        let insertedCount = 0;
        let updatedCount = 0;
        
        for (const product of products) {
          const existing = await env.DB.prepare(
            'SELECT sku FROM product_master WHERE company_id = ? AND sku = ?'
          ).bind(companyId, product.sku).first();
          
          // 🏢 company_id + sku の複合キーで UPSERT
          await env.DB.prepare(`
            INSERT INTO product_master (
              company_id, sku, barcode, name, brand, category, size, color, 
              price, description, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(company_id, sku) DO UPDATE SET
              barcode = excluded.barcode,
              name = excluded.name,
              brand = excluded.brand,
              category = excluded.category,
              size = excluded.size,
              color = excluded.color,
              price = excluded.price,
              description = excluded.description,
              updated_at = CURRENT_TIMESTAMP
          `).bind(
            companyId,
            product.sku,
            product.barcode || null,
            product.name,
            product.brand || null,
            product.category || null,
            product.size || null,
            product.color || null,
            product.price || null,
            product.description || null
          ).run();
          
          if (existing) {
            updatedCount++;
          } else {
            insertedCount++;
          }
        }
        
        return Response.json({ 
          success: true, 
          message: `マスタデータを更新しました`,
          companyId: companyId,
          inserted: insertedCount,
          updated: updatedCount,
          total: products.length
        }, { headers: corsHeaders });
      }
      
      // ================================================
      // 📸 商品実物データ保存 (企業ID付き)
      // ================================================
      if (path === '/api/products/items' && request.method === 'POST') {
        const data = await request.json();
        const companyId = data.company_id || data.companyId || getCompanyId(request, url) || '';
        
        // 🏢 企業ID + SKU でマスタの存在確認
        let master = await env.DB.prepare(
          'SELECT sku FROM product_master WHERE company_id = ? AND sku = ?'
        ).bind(companyId, data.sku).first();
        
        if (!master) {
          // 🔧 マスタが未登録 → 自動作成（アプリからの保存を止めない）
          await env.DB.prepare(`
            INSERT INTO product_master (company_id, sku, barcode, name, brand, category, size, color, price, description, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
          `).bind(
            companyId,
            data.sku,
            data.barcode || null,
            data.name || data.sku,
            data.brand || null,
            data.category || null,
            data.size || null,
            data.color || null,
            data.price || null,
            data.inspectionNotes || null
          ).run();
          
          console.log(`✅ マスタ自動作成: company_id=${companyId}, sku=${data.sku}`);
        }
        
        const itemCode = data.item_code || data.itemCode || `${data.sku}_${Date.now()}`;
        
        await env.DB.prepare(`
          INSERT INTO product_items (
            company_id, sku, item_code, image_urls, actual_measurements, 
            condition, material, product_rank, inspection_notes,
            photographed_by, status, photographed_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
          ON CONFLICT(item_code) DO UPDATE SET
            image_urls = excluded.image_urls,
            actual_measurements = excluded.actual_measurements,
            condition = excluded.condition,
            material = excluded.material,
            product_rank = excluded.product_rank,
            inspection_notes = excluded.inspection_notes,
            status = excluded.status,
            updated_at = CURRENT_TIMESTAMP
        `).bind(
          companyId,
          data.sku,
          itemCode,
          JSON.stringify(data.imageUrls || []),
          JSON.stringify(data.actualMeasurements || {}),
          data.condition || null,
          data.material || null,
          data.productRank || null,
          data.inspectionNotes || null,
          data.photographedBy || null,
          data.status || 'Ready'
        ).run();
        
        return Response.json({ 
          success: true, 
          message: '商品実物データを保存しました',
          companyId: companyId,
          sku: data.sku,
          itemCode: itemCode
        }, { headers: corsHeaders });
      }
      
      // ================================================
      // 🔍 バーコード検索 (企業ID優先)
      // ================================================
      if (path === '/api/products/search-barcode' && request.method === 'GET') {
        const companyId = getCompanyId(request, url) || '';
        const barcode = url.searchParams.get('barcode');
        
        if (!barcode) {
          return Response.json({ 
            success: false, 
            error: 'バーコードが指定されていません' 
          }, { status: 400, headers: corsHeaders });
        }
        
        // 🏢 企業ID + バーコードで検索
        const master = await env.DB.prepare(
          'SELECT * FROM product_master WHERE company_id = ? AND barcode = ?'
        ).bind(companyId, barcode).first();
        
        if (!master) {
          return Response.json({ 
            success: false, 
            error: '商品が見つかりません',
            companyId: companyId,
          }, { status: 404, headers: corsHeaders });
        }
        
        const { results: items } = await env.DB.prepare(
          'SELECT * FROM product_items WHERE company_id = ? AND sku = ? ORDER BY photographed_at DESC'
        ).bind(companyId, master.sku).all();
        
        return Response.json({ 
          success: true,
          product: {
            ...master,
            hasCapturedData: items.length > 0,
            capturedItems: items,
            latestItem: items[0] || null,
          }
        }, { headers: corsHeaders });
      }
      
      // ================================================
      // 🔍 統合検索 (企業ID優先)
      // ================================================
      if (path === '/api/search' && request.method === 'GET') {
        const companyId = getCompanyId(request, url) || '';
        const query = url.searchParams.get('query');
        
        if (!query) {
          return Response.json({ 
            success: false, 
            error: '検索クエリが指定されていません' 
          }, { status: 400, headers: corsHeaders });
        }
        
        // 1. product_items から検索（企業ID + SKU or item_code）
        const item = await env.DB.prepare(`
          SELECT * FROM product_items 
          WHERE company_id = ? AND (sku = ? OR item_code = ?)
          ORDER BY photographed_at DESC LIMIT 1
        `).bind(companyId, query, query).first();
        
        if (item) {
          // マスタ情報も取得
          const master = await env.DB.prepare(
            'SELECT * FROM product_master WHERE company_id = ? AND sku = ?'
          ).bind(companyId, item.sku).first();
          
          return Response.json({ 
            success: true,
            source: 'product_items',
            data: { ...item, master: master },
            companyId: companyId,
          }, { headers: corsHeaders });
        }
        
        // 2. product_master から検索（企業ID + SKU or バーコード）
        const master = await env.DB.prepare(`
          SELECT * FROM product_master 
          WHERE company_id = ? AND (sku = ? OR barcode = ?)
        `).bind(companyId, query, query).first();
        
        if (master) {
          return Response.json({ 
            success: true,
            source: 'product_master',
            data: master,
            companyId: companyId,
          }, { headers: corsHeaders });
        }
        
        return Response.json({ 
          success: false, 
          error: '商品が見つかりません',
          query: query,
          companyId: companyId,
        }, { status: 404, headers: corsHeaders });
      }
      
      // ================================================
      // 🔄 商品実物データ更新 (PUT)
      // ================================================
      if (path.startsWith('/api/products/items/') && request.method === 'PUT') {
        const sku = path.replace('/api/products/items/', '');
        const data = await request.json();
        const companyId = data.company_id || data.companyId || getCompanyId(request, url) || '';
        
        // 🏢 企業ID + SKU で最新の item を更新
        const result = await env.DB.prepare(`
          UPDATE product_items SET
            image_urls = COALESCE(?, image_urls),
            actual_measurements = COALESCE(?, actual_measurements),
            condition = COALESCE(?, condition),
            material = COALESCE(?, material),
            product_rank = COALESCE(?, product_rank),
            inspection_notes = COALESCE(?, inspection_notes),
            status = COALESCE(?, status),
            updated_at = CURRENT_TIMESTAMP
          WHERE company_id = ? AND sku = ?
        `).bind(
          data.imageUrls ? JSON.stringify(data.imageUrls) : null,
          data.actualMeasurements ? JSON.stringify(data.actualMeasurements) : null,
          data.condition || null,
          data.material || null,
          data.productRank || null,
          data.inspectionNotes || null,
          data.status || null,
          companyId,
          sku
        ).run();
        
        return Response.json({ 
          success: true, 
          message: '商品実物データを更新しました',
          companyId: companyId,
          sku: sku,
          changes: result.meta.changes,
        }, { headers: corsHeaders });
      }
      
      // ================================================
      // ❌ 404 Not Found
      // ================================================
      return Response.json({ 
        success: false, 
        error: 'Not Found',
        path: path,
        method: request.method
      }, { 
        status: 404, 
        headers: corsHeaders 
      });
      
    } catch (error) {
      console.error('API Error:', error);
      return Response.json({ 
        success: false, 
        error: error.message,
        stack: error.stack
      }, { 
        status: 500, 
        headers: corsHeaders 
      });
    }
  }
};
