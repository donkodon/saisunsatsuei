// Cloudflare Workers API for Measure Master
// D1 Database integration with 2-table architecture

// 🔧 テーブル初期化関数
async function initializeDatabase(env) {
  try {
    // product_master テーブルを作成
    await env.DB.prepare(`
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
      )
    `).run();
    
    // product_items テーブルを作成
    await env.DB.prepare(`
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
      )
    `).run();
    
    // インデックスを作成
    await env.DB.prepare('CREATE INDEX IF NOT EXISTS idx_master_barcode ON product_master(barcode)').run();
    await env.DB.prepare('CREATE INDEX IF NOT EXISTS idx_items_sku ON product_items(sku)').run();
    await env.DB.prepare('CREATE INDEX IF NOT EXISTS idx_items_code ON product_items(item_code)').run();
    
    console.log('✅ Database initialized successfully');
  } catch (error) {
    console.error('❌ Database initialization error:', error);
  }
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;
    
    // CORS設定
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    };
    
    // OPTIONSリクエスト
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    // 🔧 初回実行時にテーブルを自動作成
    if (path === '/api/init' && request.method === 'GET') {
      await initializeDatabase(env);
      return new Response(JSON.stringify({ 
        success: true, 
        message: 'Database initialized successfully' 
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    try {
      // ================================================
      // 📋 商品一覧取得 (マスタ + 実物データ結合)
      // ================================================
      if (path === '/api/products' && request.method === 'GET') {
        const limit = parseInt(url.searchParams.get('limit') || '100');
        const offset = parseInt(url.searchParams.get('offset') || '0');
        
        // マスタ情報を取得
        const { results: masters } = await env.DB.prepare(`
          SELECT * FROM product_master 
          ORDER BY updated_at DESC 
          LIMIT ? OFFSET ?
        `).bind(limit, offset).all();
        
        // 各マスタに対して実物データを取得
        const products = await Promise.all(
          masters.map(async (master) => {
            const { results: items } = await env.DB.prepare(
              'SELECT * FROM product_items WHERE sku = ? ORDER BY photographed_at DESC'
            ).bind(master.sku).all();
            
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
          total: masters.length
        }, { headers: corsHeaders });
      }
      
      // ================================================
      // 🔍 SKU検索 (マスタ + 実物データ結合)
      // ================================================
      if (path === '/api/products/search' && request.method === 'GET') {
        const sku = url.searchParams.get('sku');
        
        if (!sku) {
          return Response.json({ 
            success: false, 
            error: 'SKUが指定されていません' 
          }, { status: 400, headers: corsHeaders });
        }
        
        // 1️⃣ マスタ情報を取得
        const master = await env.DB.prepare(
          'SELECT * FROM product_master WHERE sku = ?'
        ).bind(sku).first();
        
        if (!master) {
          return Response.json({ 
            success: false, 
            error: '商品マスタが見つかりません',
            sku: sku
          }, { status: 404, headers: corsHeaders });
        }
        
        // 2️⃣ 実物データを取得
        const { results: items } = await env.DB.prepare(
          'SELECT * FROM product_items WHERE sku = ? ORDER BY photographed_at DESC'
        ).bind(sku).all();
        
        // 3️⃣ 結合して返す
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
      // 💾 商品マスタ一括登録 (CSV import用)
      // ================================================
      if (path === '/api/products/bulk-import' && request.method === 'POST') {
        const data = await request.json();
        const products = data.products || [];
        
        let insertedCount = 0;
        let updatedCount = 0;
        
        for (const product of products) {
          const existing = await env.DB.prepare(
            'SELECT sku FROM product_master WHERE sku = ?'
          ).bind(product.sku).first();
          
          await env.DB.prepare(`
            INSERT INTO product_master (
              sku, barcode, name, brand, category, size, color, 
              price, description, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(sku) DO UPDATE SET
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
          inserted: insertedCount,
          updated: updatedCount,
          total: products.length
        }, { headers: corsHeaders });
      }
      
      // ================================================
      // 📸 商品実物データ保存 (スマホアプリ用)
      // ================================================
      if (path === '/api/products/items' && request.method === 'POST') {
        const data = await request.json();
        
        // SKUの存在確認
        const master = await env.DB.prepare(
          'SELECT sku FROM product_master WHERE sku = ?'
        ).bind(data.sku).first();
        
        if (!master) {
          return Response.json({ 
            success: false, 
            error: '商品マスタが見つかりません。先にマスタを登録してください。',
            sku: data.sku
          }, { status: 404, headers: corsHeaders });
        }
        
        // item_code生成 (SKU_タイムスタンプ)
        const itemCode = data.item_code || `${data.sku}_${Date.now()}`;
        
        // 実物データ保存
        await env.DB.prepare(`
          INSERT INTO product_items (
            sku, item_code, image_urls, actual_measurements, 
            condition, material, product_rank, inspection_notes,
            photographed_by, status, photographed_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
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
          sku: data.sku,
          itemCode: itemCode
        }, { headers: corsHeaders });
      }
      
      // ================================================
      // 🔍 バーコード検索
      // ================================================
      if (path === '/api/products/search-barcode' && request.method === 'GET') {
        const barcode = url.searchParams.get('barcode');
        
        if (!barcode) {
          return Response.json({ 
            success: false, 
            error: 'バーコードが指定されていません' 
          }, { status: 400, headers: corsHeaders });
        }
        
        const master = await env.DB.prepare(
          'SELECT * FROM product_master WHERE barcode = ?'
        ).bind(barcode).first();
        
        if (!master) {
          return Response.json({ 
            success: false, 
            error: '商品が見つかりません' 
          }, { status: 404, headers: corsHeaders });
        }
        
        const { results: items } = await env.DB.prepare(
          'SELECT * FROM product_items WHERE sku = ? ORDER BY photographed_at DESC'
        ).bind(master.sku).all();
        
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
      // 🎨 背景削除API (Cloudflare AI)
      // ================================================
      if (path === '/api/remove-bg' && request.method === 'POST') {
        try {
          const formData = await request.formData();
          const imageUrl = formData.get('imageUrl');
          
          if (!imageUrl) {
            return Response.json({ 
              success: false, 
              error: 'imageUrl is required' 
            }, { status: 400, headers: corsHeaders });
          }
          
          // 画像をダウンロード
          const imageResponse = await fetch(imageUrl);
          if (!imageResponse.ok) {
            return Response.json({ 
              success: false, 
              error: 'Failed to fetch image from URL' 
            }, { status: 400, headers: corsHeaders });
          }
          
          const imageBlob = await imageResponse.blob();
          
          // Cloudflare AIで背景削除
          const aiResponse = await env.AI.run(
            '@cf/cloudflare/background-remover',  // 背景削除専用モデル
            {
              image: Array.from(new Uint8Array(await imageBlob.arrayBuffer()))
            }
          );
          
          // 処理済み画像を返す
          return new Response(aiResponse, {
            headers: {
              ...corsHeaders,
              'Content-Type': 'image/png'
            }
          });
          
        } catch (error) {
          console.error('Background removal error:', error);
          return Response.json({ 
            success: false, 
            error: 'Background removal failed',
            details: error.message
          }, { status: 500, headers: corsHeaders });
        }
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
