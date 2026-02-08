// src/index.js
// v2: Webhook outputパース修正 + WHERE条件安定化 + アプリ側描画対応

/**
 * データベース初期化関数
 * product_master と product_items テーブルを作成
 */
async function initializeDatabase(env) {
  try {
    // 商品マスタテーブル作成
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

    // 商品実物データテーブル作成
    await env.DB.prepare(`
      CREATE TABLE IF NOT EXISTS product_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sku TEXT NOT NULL,
        item_code TEXT UNIQUE,
        name TEXT,
        barcode TEXT,
        brand TEXT,
        category TEXT,
        color TEXT,
        size TEXT,
        material TEXT,
        price INTEGER,
        condition TEXT,
        product_rank TEXT,
        image_urls TEXT,
        actual_measurements TEXT,
        measurements TEXT,
        measurement_image_url TEXT,
        ai_landmarks TEXT,
        reference_object TEXT,
        inspection_notes TEXT,
        photographed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        photographed_by TEXT,
        status TEXT DEFAULT 'Ready',
        company_id TEXT DEFAULT 'test_company',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `).run();

    // 既存テーブルにカラムが無い場合のマイグレーション（ALTER TABLE）
    const migrationColumns = [
      { name: 'measurements', type: 'TEXT' },
      { name: 'ai_landmarks', type: 'TEXT' },
      { name: 'reference_object', type: 'TEXT' },
      { name: 'measurement_image_url', type: 'TEXT' }
    ];
    
    for (const col of migrationColumns) {
      try {
        await env.DB.prepare(
          `ALTER TABLE product_items ADD COLUMN ${col.name} ${col.type}`
        ).run();
        console.log(`✅ カラム追加: ${col.name}`);
      } catch (e) {
        // カラムが既に存在する場合はエラーになるので無視
        if (!e.message.includes('duplicate column')) {
          console.log(`ℹ️ カラム ${col.name} は既に存在します`);
        }
      }
    }

    // インデックス作成
    await env.DB.prepare(
      "CREATE INDEX IF NOT EXISTS idx_master_barcode ON product_master(barcode)"
    ).run();
    
    await env.DB.prepare(
      "CREATE INDEX IF NOT EXISTS idx_items_sku ON product_items(sku)"
    ).run();
    
    await env.DB.prepare(
      "CREATE INDEX IF NOT EXISTS idx_items_code ON product_items(item_code)"
    ).run();

    await env.DB.prepare(
      "CREATE INDEX IF NOT EXISTS idx_items_company_id ON product_items(company_id)"
    ).run();

    await env.DB.prepare(
      "CREATE INDEX IF NOT EXISTS idx_items_company_sku ON product_items(company_id, sku)"
    ).run();

    console.log("✅ Database initialized successfully");
  } catch (error) {
    console.error("❌ Database initialization error:", error);
  }
}

/**
 * 🔍 Replicate output パーサー
 * 
 * Replicate モデルの output は配列で返る:
 *   output[0] = ai_landmarks JSON文字列 (ランドマーク1-8 + pixelPerCm)
 *   output[1] = measurements JSON文字列 (body_length, body_width, shoulder_width, sleeve_length)
 * 
 * またはオブジェクト形式で返る場合もある（モデルバージョンによる）
 */
function parseReplicateOutput(output) {
  const result = {
    ai_landmarks: null,
    measurements: null,
    reference_object: null
  };

  // 🆕 デバッグ強化: 生データの完全ダンプ
  console.log('🔍 ============ REPLICATE OUTPUT DEBUG ============');
  console.log('🔍 [RAW] output 型:', typeof output);
  console.log('🔍 [RAW] Array.isArray:', Array.isArray(output));
  console.log('🔍 [RAW] output 完全ダンプ:');
  try {
    console.log(JSON.stringify(output, null, 2));
  } catch (e) {
    console.log('⚠️ JSON.stringify失敗 - output:', output);
  }
  console.log('🔍 ===============================================');

  try {
    if (Array.isArray(output)) {
      // 🆕 配列形式: output = [ai_landmarks_json, measurements_json]
      console.log('📦 output は配列形式 (要素数:', output.length, ')');
      
      for (let i = 0; i < output.length; i++) {
        let parsed = output[i];
        
        console.log(`🔍 output[${i}] 型:`, typeof parsed);
        console.log(`🔍 output[${i}] 内容 (最初の500文字):`, JSON.stringify(parsed).substring(0, 500));
        
        // 文字列ならパース
        if (typeof parsed === 'string') {
          try {
            parsed = JSON.parse(parsed);
            console.log(`✅ output[${i}] をJSONパース成功`);
          } catch (e) {
            console.log(`⚠️ output[${i}] のJSONパースに失敗:`, e.message);
            continue;
          }
        }
        
        if (typeof parsed === 'object' && parsed !== null) {
          const keys = Object.keys(parsed);
          console.log(`🔍 output[${i}] のキー:`, keys.slice(0, 10).join(', '));
          
          // measurements を判定: body_length or shoulder_width があれば measurements
          if (parsed.body_length !== undefined || parsed.shoulder_width !== undefined || 
              parsed.body_width !== undefined || parsed.sleeve_length !== undefined) {
            result.measurements = parsed;
            console.log(`✅ output[${i}] → measurements:`, JSON.stringify(parsed));
          }
          // ai_landmarks を判定: 数字キー "1", "2" ... があれば landmarks
          else if (parsed["1"] !== undefined || parsed["2"] !== undefined) {
            result.ai_landmarks = parsed;
            console.log(`✅ output[${i}] → ai_landmarks (${Object.keys(parsed).length} points)`);
            
            // pixelPerCm を reference_object として抽出
            // ランドマーク9番に {"pixelPerCm": 15.18} が入っている
            for (const key of Object.keys(parsed)) {
              const point = parsed[key];
              if (point && typeof point === 'object' && point.pixelPerCm !== undefined) {
                result.reference_object = {
                  type: "pixelPerCm",
                  pixelPerCm: point.pixelPerCm,
                  source_landmark: key
                };
                console.log(`✅ pixelPerCm 抽出 (landmark ${key}):`, point.pixelPerCm);
                break;
              }
            }
            
            // 🆕 pixelPerCm がトップレベルにある場合も対応
            if (!result.reference_object && parsed.pixelPerCm !== undefined) {
              result.reference_object = {
                type: "pixelPerCm",
                pixelPerCm: parsed.pixelPerCm,
                source_landmark: "top_level"
              };
              console.log(`✅ pixelPerCm をトップレベルから抽出:`, parsed.pixelPerCm);
            }
          }
          // 🆕 直接 ai_landmarks や measurements キーがある場合
          else if (parsed.ai_landmarks || parsed.ai_landmark || parsed.measurements) {
            console.log(`🔍 output[${i}] にai_landmarks/measurementsキーあり`);
            if (parsed.ai_landmarks || parsed.ai_landmark) {
              result.ai_landmarks = parsed.ai_landmarks || parsed.ai_landmark;
              console.log(`✅ ai_landmarks 抽出成功`);
            }
            if (parsed.measurements) {
              result.measurements = parsed.measurements;
              console.log(`✅ measurements 抽出成功`);
            }
            if (parsed.reference_object) {
              result.reference_object = parsed.reference_object;
              console.log(`✅ reference_object 抽出成功`);
            }
          }
          else {
            console.log(`⚠️ output[${i}] の形式が不明 - キー:`, keys.slice(0, 5));
            console.log(`⚠️ 内容サンプル:`, JSON.stringify(parsed).substring(0, 200));
          }
        }
      }
    } else if (typeof output === 'object' && output !== null) {
      // オブジェクト形式（旧バージョン互換）
      console.log('📦 output はオブジェクト形式');
      const keys = Object.keys(output);
      console.log('🔍 オブジェクトのキー:', keys.join(', '));
      
      // Standard keys
      result.measurements = output.measurements || null;
      result.ai_landmarks = output.ai_landmarks || output.ai_landmark || null;
      result.reference_object = output.reference_object || null;
      
      // 🆕 Replicate GarmentIQ 専用のキー名に対応
      // landmarks → ai_landmarks
      if (!result.ai_landmarks && output.landmarks) {
        result.ai_landmarks = output.landmarks;
        console.log('✅ landmarks → ai_landmarks 変換完了');
      }
      
      // pixel_per_cm → reference_object
      if (!result.reference_object && output.pixel_per_cm !== undefined) {
        result.reference_object = {
          type: "pixelPerCm",
          pixelPerCm: output.pixel_per_cm,
          source_landmark: "replicate_direct"
        };
        console.log('✅ pixel_per_cm → reference_object 変換完了:', output.pixel_per_cm);
      }
      
      console.log('✅ measurements:', result.measurements ? 'あり' : 'null');
      console.log('✅ ai_landmarks:', result.ai_landmarks ? 'あり' : 'null');
      console.log('✅ reference_object:', result.reference_object ? 'あり' : 'null');
    } else {
      console.log('⚠️ output が配列でもオブジェクトでもない:', typeof output);
    }
  } catch (e) {
    console.error('❌ output パースエラー:', e.message);
    console.error('❌ スタック:', e.stack);
  }

  console.log('📊 ========== パース結果サマリー ==========');
  console.log('   measurements:', result.measurements ? '✅' : '❌ null');
  console.log('   ai_landmarks:', result.ai_landmarks ? '✅' : '❌ null');
  console.log('   reference_object:', result.reference_object ? '✅' : '❌ null');
  console.log('==========================================');

  return result;
}

/**
 * 🔍 Webhook input から SKU と company_id を抽出
 * 
 * input.image が base64 の場合は URL からSKUを取れないので
 * webhook の他のフィールドからも探す
 */
function extractSkuAndCompany(webhookData, requestUrl) {
  let sku = 'UNKNOWN';
  let companyId = 'test_company';
  
  // 方法0（最優先）: webhook URLのクエリパラメータから取得
  // /api/measure が webhook URL に ?sku=XXX&company_id=YYY を付与している
  if (requestUrl) {
    try {
      const urlObj = new URL(requestUrl);
      const urlSku = urlObj.searchParams.get('sku');
      const urlCompanyId = urlObj.searchParams.get('company_id');
      if (urlSku) {
        sku = urlSku;
        console.log('✅ SKU をクエリパラメータから取得:', sku);
      }
      if (urlCompanyId) {
        companyId = urlCompanyId;
        console.log('✅ company_id をクエリパラメータから取得:', companyId);
      }
    } catch (e) {
      console.log('⚠️ URLパース失敗:', e.message);
    }
  }
  
  // 方法1: クエリパラメータで取れなかった場合、input.image のURLパターンから抽出
  if (sku === 'UNKNOWN') {
    const imageUrl = webhookData.input?.image || '';
    if (imageUrl.startsWith('http')) {
      const skuMatch = imageUrl.match(/\/([^\/]+)\/[^\/]+\.(jpg|jpeg|png)/i);
      if (skuMatch) {
        sku = skuMatch[1];
        console.log('✅ SKU をURLパターンから取得:', sku);
      }
      if (imageUrl.includes('/test_company/')) {
        companyId = 'test_company';
      } else {
        const companyMatch = imageUrl.match(/\.dev\/([^\/]+)\/[^\/]+\//);
        if (companyMatch) {
          companyId = companyMatch[1];
        }
      }
    }
  }
  
  console.log('🔍 SKU/Company最終結果:', { sku, companyId });
  
  return { sku, companyId };
}

/**
 * メインハンドラー
 */
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;
    
    // CORS ヘッダー
    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type"
    };

    // OPTIONS リクエスト（CORS プリフライト）
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }

    // データベース初期化エンドポイント
    if (path === "/api/init" && request.method === "GET") {
      await initializeDatabase(env);
      return new Response(JSON.stringify({
        success: true,
        message: "Database initialized successfully"
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

    try {
      // ==========================================
      // 商品マスタ (product_master) エンドポイント
      // ==========================================

      // GET /api/products - 商品マスタ一覧取得
      if (path === "/api/products" && request.method === "GET") {
        const limit = parseInt(url.searchParams.get("limit") || "100");
        const offset = parseInt(url.searchParams.get("offset") || "0");
        
        const { results: masters } = await env.DB.prepare(`
          SELECT * FROM product_master 
          ORDER BY updated_at DESC 
          LIMIT ? OFFSET ?
        `).bind(limit, offset).all();

        // 各マスタに関連する実物データを追加
        const products = await Promise.all(
          masters.map(async (master) => {
            const { results: items } = await env.DB.prepare(
              "SELECT * FROM product_items WHERE sku = ? ORDER BY photographed_at DESC"
            ).bind(master.sku).all();
            
            return {
              ...master,
              hasCapturedData: items.length > 0,
              capturedItems: items,
              latestItem: items[0] || null,
              capturedCount: items.length
            };
          })
        );

        return Response.json({
          success: true,
          products,
          total: masters.length
        }, { headers: corsHeaders });
      }

      // GET /api/products/search - SKU検索
      if (path === "/api/products/search" && request.method === "GET") {
        const sku = url.searchParams.get("sku");
        
        if (!sku) {
          return Response.json({
            success: false,
            error: "SKUが指定されていません"
          }, { status: 400, headers: corsHeaders });
        }

        const master = await env.DB.prepare(
          "SELECT * FROM product_master WHERE sku = ?"
        ).bind(sku).first();

        if (!master) {
          return Response.json({
            success: false,
            error: "商品マスタが見つかりません",
            sku
          }, { status: 404, headers: corsHeaders });
        }

        const { results: items } = await env.DB.prepare(
          "SELECT * FROM product_items WHERE sku = ? ORDER BY photographed_at DESC"
        ).bind(sku).all();

        return Response.json({
          success: true,
          product: {
            ...master,
            hasCapturedData: items.length > 0,
            capturedItems: items,
            latestItem: items[0] || null,
            capturedCount: items.length
          }
        }, { headers: corsHeaders });
      }

      // POST /api/products/bulk-import - 一括インポート
      if (path === "/api/products/bulk-import" && request.method === "POST") {
        const data = await request.json();
        const products = data.products || [];
        let insertedCount = 0;
        let updatedCount = 0;

        for (const product of products) {
          const existing = await env.DB.prepare(
            "SELECT sku FROM product_master WHERE sku = ?"
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

      // ==========================================
      // 商品実物データ (product_items) エンドポイント
      // ==========================================

      // 🔧 POST /api/products/items - 新規作成 or UPSERT
      if (path === "/api/products/items" && request.method === "POST") {
        try {
          const data = await request.json();

          if (!data.sku) {
            return Response.json({
              success: false,
              error: "SKUが必須です"
            }, { status: 400, headers: corsHeaders });
          }

          console.log('📥 受信データ:', JSON.stringify(data));

          const existing = await env.DB.prepare(
            "SELECT id FROM product_items WHERE sku = ?"
          ).bind(data.sku).first();

          console.log('🔍 既存データ:', existing ? 'あり (ID: ' + existing.id + ')' : 'なし');

          if (data.upsert === true && existing) {
            console.log('♻️ UPDATE処理実行');
            
            const updateResult = await env.DB.prepare(`
              UPDATE product_items SET
                name = COALESCE(?, name),
                barcode = COALESCE(?, barcode),
                brand = COALESCE(?, brand),
                category = COALESCE(?, category),
                color = COALESCE(?, color),
                size = COALESCE(?, size),
                material = COALESCE(?, material),
                price = COALESCE(?, price),
                condition = COALESCE(?, condition),
                product_rank = COALESCE(?, product_rank),
                image_urls = COALESCE(?, image_urls),
                actual_measurements = COALESCE(?, actual_measurements),
                inspection_notes = COALESCE(?, inspection_notes),
                photographed_at = COALESCE(?, photographed_at),
                photographed_by = COALESCE(?, photographed_by),
                status = COALESCE(?, status),
                company_id = COALESCE(?, company_id),
                updated_at = CURRENT_TIMESTAMP
              WHERE sku = ?
            `).bind(
              data.name || null,
              data.barcode || null,
              data.brand || null,
              data.category || null,
              data.color || null,
              data.size || null,
              data.material || null,
              data.price || null,
              data.condition || null,
              data.productRank || data.product_rank || null,
              data.imageUrls ? JSON.stringify(data.imageUrls) : null,
              data.actualMeasurements ? JSON.stringify(data.actualMeasurements) : null,
              data.inspectionNotes || data.inspection_notes || null,
              data.photographedAt || null,
              data.photographedBy || data.photographed_by || null,
              data.status || null,
              data.company_id || null,
              data.sku
            ).run();

            console.log('✅ UPDATE完了:', updateResult);

            return Response.json({
              success: true,
              message: "商品実物データを更新しました",
              sku: data.sku,
              action: "updated"
            }, { headers: corsHeaders });
            
          } else {
            console.log('➕ INSERT処理実行');
            
            const itemCode = data.item_code || data.itemCode || `${data.sku}_${Date.now()}`;
            console.log('📋 INSERT用item_code:', itemCode);

            const insertResult = await env.DB.prepare(`
              INSERT INTO product_items (
                sku, item_code, name, barcode,
                brand, category, color, size, material, price,
                condition, product_rank,
                image_urls, actual_measurements, inspection_notes,
                photographed_at, photographed_by, status,
                company_id,
                created_at, updated_at
              ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            `).bind(
              data.sku,
              itemCode,
              data.name || null,
              data.barcode || null,
              data.brand || null,
              data.category || null,
              data.color || null,
              data.size || null,
              data.material || null,
              data.price || null,
              data.condition || null,
              data.productRank || data.product_rank || null,
              data.imageUrls ? JSON.stringify(data.imageUrls) : null,
              data.actualMeasurements ? JSON.stringify(data.actualMeasurements) : null,
              data.inspectionNotes || data.inspection_notes || null,
              data.photographedAt || new Date().toISOString(),
              data.photographedBy || data.photographed_by || 'mobile_app_user',
              data.status || "Ready",
              data.company_id || 'test_company'
            ).run();

            console.log('✅ INSERT完了:', insertResult);

            return Response.json({
              success: true,
              message: "商品実物データを保存しました",
              sku: data.sku,
              itemCode,
              action: "created"
            }, { headers: corsHeaders });
          }

        } catch (dbError) {
          console.error('❌ Database Error:', dbError);
          console.error('Error message:', dbError.message);
          console.error('Error stack:', dbError.stack);
          
          return Response.json({
            success: false,
            error: `D1_ERROR: ${dbError.message}`,
            details: dbError.stack,
            endpoint: 'POST /api/products/items'
          }, { 
            status: 500, 
            headers: corsHeaders 
          });
        }
      }

      // PUT /api/products/items/:sku - SKU指定で更新
      if (path.startsWith("/api/products/items/") && request.method === "PUT") {
        const sku = decodeURIComponent(path.replace("/api/products/items/", ""));
        const data = await request.json();

        const existing = await env.DB.prepare(
          "SELECT id FROM product_items WHERE sku = ?"
        ).bind(sku).first();

        if (!existing) {
          return Response.json({
            success: false,
            error: "商品実物データが見つかりません",
            sku
          }, { status: 404, headers: corsHeaders });
        }

        await env.DB.prepare(`
          UPDATE product_items SET
            item_code = COALESCE(?, item_code),
            name = COALESCE(?, name),
            barcode = COALESCE(?, barcode),
            brand = COALESCE(?, brand),
            category = COALESCE(?, category),
            color = COALESCE(?, color),
            size = COALESCE(?, size),
            material = COALESCE(?, material),
            price = COALESCE(?, price),
            condition = COALESCE(?, condition),
            product_rank = COALESCE(?, product_rank),
            image_urls = COALESCE(?, image_urls),
            actual_measurements = COALESCE(?, actual_measurements),
            inspection_notes = COALESCE(?, inspection_notes),
            photographed_by = COALESCE(?, photographed_by),
            status = COALESCE(?, status),
            company_id = COALESCE(?, company_id),
            updated_at = CURRENT_TIMESTAMP
          WHERE sku = ?
        `).bind(
          data.item_code || data.itemCode || null,
          data.name || null,
          data.barcode || null,
          data.brand || null,
          data.category || null,
          data.color || null,
          data.size || null,
          data.material || null,
          data.price || null,
          data.condition || null,
          data.productRank || data.product_rank || data.rank || null,
          data.imageUrls ? JSON.stringify(data.imageUrls) : null,
          data.actualMeasurements ? JSON.stringify(data.actualMeasurements) : null,
          data.inspectionNotes || data.inspection_notes || null,
          data.photographedBy || data.photographed_by || null,
          data.status || null,
          data.company_id || null,
          sku
        ).run();

        return Response.json({
          success: true,
          message: "商品実物データを更新しました",
          sku,
          action: "updated"
        }, { headers: corsHeaders });
      }

      // GET /api/products/items - 商品実物データ一覧
      if (path === "/api/products/items" && request.method === "GET") {
        const limit = parseInt(url.searchParams.get("limit") || "100");
        const offset = parseInt(url.searchParams.get("offset") || "0");

        const { results } = await env.DB.prepare(`
          SELECT * FROM product_items 
          ORDER BY updated_at DESC 
          LIMIT ? OFFSET ?
        `).bind(limit, offset).all();

        const items = results.map(item => ({
          ...item,
          imageUrls: item.image_urls ? JSON.parse(item.image_urls) : null,
          actualMeasurements: item.actual_measurements ? JSON.parse(item.actual_measurements) : null
        }));

        return Response.json({
          success: true,
          items,
          count: items.length
        }, { headers: corsHeaders });
      }

      // GET /api/products/items/:sku - SKU指定で商品実物データ取得
      if (path.startsWith("/api/products/items/") && request.method === "GET") {
        const sku = decodeURIComponent(path.replace("/api/products/items/", ""));

        const item = await env.DB.prepare(
          "SELECT * FROM product_items WHERE sku = ? AND item_code NOT LIKE '%-%' ORDER BY id ASC LIMIT 1"
        ).bind(sku).first();

        if (!item) {
          return Response.json({
            success: false,
            error: "商品実物データが見つかりません",
            sku
          }, { status: 404, headers: corsHeaders });
        }

        return Response.json({
          success: true,
          item: {
            ...item,
            imageUrls: item.image_urls ? JSON.parse(item.image_urls) : null,
            actualMeasurements: item.actual_measurements ? JSON.parse(item.actual_measurements) : null
          }
        }, { headers: corsHeaders });
      }

      // DELETE /api/products/items/:sku - SKU指定で削除
      if (path.startsWith("/api/products/items/") && request.method === "DELETE") {
        const sku = decodeURIComponent(path.replace("/api/products/items/", ""));

        await env.DB.prepare(
          "DELETE FROM product_items WHERE sku = ?"
        ).bind(sku).run();

        return Response.json({
          success: true,
          message: "商品実物データを削除しました",
          sku,
          action: "deleted"
        }, { headers: corsHeaders });
      }

      // ==========================================
      // 統合検索（バーコード/SKU）
      // ==========================================

      if (path === "/api/search" && request.method === "GET") {
        const query = url.searchParams.get("query");
        
        if (!query) {
          return Response.json({
            success: false,
            error: "検索キーワードが指定されていません"
          }, { status: 400, headers: corsHeaders });
        }

        console.log('🔍 統合検索開始:', query);

        const item = await env.DB.prepare(`
          SELECT * FROM product_items 
          WHERE barcode = ? OR sku = ?
          ORDER BY photographed_at DESC
          LIMIT 1
        `).bind(query, query).first();

        if (item) {
          console.log('✅ product_items で発見:', item.sku);
          
          const parsedItem = {
            ...item,
            imageUrls: item.image_urls ? JSON.parse(item.image_urls) : null,
            actualMeasurements: item.actual_measurements ? JSON.parse(item.actual_measurements) : null
          };

          return Response.json({
            success: true,
            source: "product_items",
            data: parsedItem
          }, { headers: corsHeaders });
        }

        console.log('⚠️ product_items に見つからず、product_master を検索');

        const master = await env.DB.prepare(
          "SELECT * FROM product_master WHERE barcode = ? OR sku = ?"
        ).bind(query, query).first();

        if (master) {
          console.log('✅ product_master で発見:', master.sku);
          
          return Response.json({
            success: true,
            source: "product_master",
            data: master
          }, { headers: corsHeaders });
        }

        console.log('❌ 商品が見つかりません:', query);

        return Response.json({
          success: false,
          error: "商品が見つかりません",
          query
        }, { status: 404, headers: corsHeaders });
      }

      // バーコード検索（後方互換）
      if (path === "/api/products/search-barcode" && request.method === "GET") {
        const barcode = url.searchParams.get("barcode");
        
        if (!barcode) {
          return Response.json({
            success: false,
            error: "バーコードが指定されていません"
          }, { status: 400, headers: corsHeaders });
        }

        const master = await env.DB.prepare(
          "SELECT * FROM product_master WHERE barcode = ?"
        ).bind(barcode).first();

        if (!master) {
          return Response.json({
            success: false,
            error: "商品が見つかりません"
          }, { status: 404, headers: corsHeaders });
        }

        const { results: items } = await env.DB.prepare(
          "SELECT * FROM product_items WHERE sku = ? ORDER BY photographed_at DESC"
        ).bind(master.sku).all();

        return Response.json({
          success: true,
          product: {
            ...master,
            hasCapturedData: items.length > 0,
            capturedItems: items,
            latestItem: items[0] || null
          }
        }, { headers: corsHeaders });
      }

      // ==========================================
      // 🔔 Replicate Webhook エンドポイント（v2: 配列output対応）
      // ==========================================

      if (path === "/api/webhook/replicate" && request.method === "POST") {
        console.log('🔔 ========== Replicate Webhook 受信 ==========');
        console.log('🔔 受信時刻:', new Date().toISOString());
        
        try {
          const webhookData = await request.json();
          
          // 🆕 Webhook全体のダンプ（デバッグ用）
          console.log('📦 Webhook データ全体:');
          console.log(JSON.stringify(webhookData, null, 2));
          console.log('==========================================');
          
          console.log('📦 Webhook ステータス:', webhookData.status);
          console.log('📦 Webhook output 型:', typeof webhookData.output);
          console.log('📦 Webhook output 配列判定:', Array.isArray(webhookData.output));
          
          if (webhookData.status === 'succeeded' && webhookData.output) {
            console.log('✅ Replicate 処理成功');
            
            // 🆕 v2: 配列形式の output を正しくパース
            const parsed = parseReplicateOutput(webhookData.output);
            
            // SKU と company_id を抽出（リクエストURLのクエリパラメータ優先）
            const { sku, companyId } = extractSkuAndCompany(webhookData, request.url);
            
            console.log('📏 パース結果:');
            console.log('   SKU:', sku);
            console.log('   Company ID:', companyId);
            console.log('   measurements:', parsed.measurements ? JSON.stringify(parsed.measurements) : 'null');
            console.log('   ai_landmarks keys:', parsed.ai_landmarks ? Object.keys(parsed.ai_landmarks).length : 0);
            console.log('   reference_object:', parsed.reference_object ? JSON.stringify(parsed.reference_object) : 'null');
            
            // データが1つでもあればD1に保存
            if (parsed.measurements || parsed.ai_landmarks) {
              try {
                console.log('💾 D1に測定結果を保存中...');
                
                // 🆕 v2: WHERE条件を安定化（SKU + company_id + 最新レコード）
                // json_extract による不安定なマッチングを廃止
                const updateResult = await env.DB.prepare(`
                  UPDATE product_items 
                  SET 
                    measurements = ?,
                    ai_landmarks = ?,
                    reference_object = ?,
                    updated_at = CURRENT_TIMESTAMP
                  WHERE id = (
                    SELECT id FROM product_items 
                    WHERE sku = ? AND company_id = ?
                    ORDER BY id DESC
                    LIMIT 1
                  )
                `).bind(
                  parsed.measurements ? JSON.stringify(parsed.measurements) : null,
                  parsed.ai_landmarks ? JSON.stringify(parsed.ai_landmarks) : null,
                  parsed.reference_object ? JSON.stringify(parsed.reference_object) : null,
                  sku,
                  companyId
                ).run();
                
                console.log('✅ D1更新結果:', JSON.stringify(updateResult));
                
                if (updateResult.meta && updateResult.meta.changes === 0) {
                  console.log('⚠️ 警告: 更新された行が0件');
                  console.log('   SKU:', sku, '/ Company:', companyId);
                  
                  // フォールバック: company_id なしで再試行
                  console.log('🔄 フォールバック: company_id なしで再試行...');
                  const fallbackResult = await env.DB.prepare(`
                    UPDATE product_items 
                    SET 
                      measurements = ?,
                      ai_landmarks = ?,
                      reference_object = ?,
                      updated_at = CURRENT_TIMESTAMP
                    WHERE id = (
                      SELECT id FROM product_items 
                      WHERE sku = ?
                      ORDER BY id DESC
                      LIMIT 1
                    )
                  `).bind(
                    parsed.measurements ? JSON.stringify(parsed.measurements) : null,
                    parsed.ai_landmarks ? JSON.stringify(parsed.ai_landmarks) : null,
                    parsed.reference_object ? JSON.stringify(parsed.reference_object) : null,
                    sku
                  ).run();
                  
                  console.log('🔄 フォールバック結果:', JSON.stringify(fallbackResult));
                  
                  if (fallbackResult.meta && fallbackResult.meta.changes > 0) {
                    console.log('✅ フォールバックで更新成功');
                  } else {
                    console.log('❌ フォールバックも失敗: SKU=' + sku + ' のレコードが存在しない可能性');
                  }
                } else {
                  console.log('✅ D1更新成功: ' + (updateResult.meta?.changes || 0) + '行更新');
                }
                
              } catch (dbError) {
                console.error('❌ D1更新エラー:', dbError.message);
                console.error('   スタック:', dbError.stack);
              }
            } else {
              console.log('⚠️ measurements も ai_landmarks も取得できませんでした');
              console.log('   output の生データ:', JSON.stringify(webhookData.output).substring(0, 500));
            }
            
          } else if (webhookData.status === 'failed') {
            console.log('❌ Replicate 処理失敗:', webhookData.error);
          } else {
            console.log('⏳ Replicate 処理中:', webhookData.status);
          }
          
          return Response.json({ success: true }, { headers: corsHeaders });
          
        } catch (error) {
          console.error('❌ Webhook 処理エラー:', error);
          return Response.json({ 
            success: false, 
            error: error.message 
          }, { 
            status: 500, 
            headers: corsHeaders 
          });
        }
      }

      // ==========================================
      // 📏 AI自動採寸エンドポイント（v2: SKUをinputに含める）
      // ==========================================

      if (path === "/api/measure" && request.method === "POST") {
        console.log('🎯 /api/measure エンドポイント到達');
        
        try {
          const data = await request.json();
          
          console.log('📏 AI自動採寸リクエスト受信:');
          console.log('   - image_url:', data.image_url);
          console.log('   - sku:', data.sku);
          console.log('   - garment_class:', data.garment_class);

          const replicateApiKey = env.REPLICATE_API_KEY;
          
          if (!replicateApiKey) {
            return Response.json({
              success: false,
              error: "Replicate APIキーが設定されていません"
            }, { status: 500, headers: corsHeaders });
          }

          console.log('🔑 APIキー確認: あり (長さ:', replicateApiKey.length, ')');

          // 🚀 v2.1: base64変換スキップ + Prefer:wait削除
          // Replicateに画像URLを直接渡す（Replicate側がダウンロード）
          // base64変換もPrefer:waitも不要（webhookで結果を受け取る）
          const imageInput = data.image_url;

          console.log('🚀 Replicate API呼び出し（非同期モード）...');
          console.log('   画像形式: URL直接渡し');
          
          const replicateResponse = await fetch('https://api.replicate.com/v1/predictions', {
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${replicateApiKey}`,
              'Content-Type': 'application/json'
            },
            body: JSON.stringify({
              version: '6f4a150f6355b07eff5151b7ef49f2bf0b297bd329ee5f17a46e283f0685f926',
              input: {
                image: imageInput,
                garment_class: data.garment_class || 'long sleeve top'
              },
              webhook: `https://measure-master-api.jinkedon2.workers.dev/api/webhook/replicate?sku=${encodeURIComponent(data.sku || '')}&company_id=${encodeURIComponent(data.company_id || 'test_company')}`,
              webhook_events_filter: ['completed']
            })
          });

          console.log('📡 Replicate HTTPステータス:', replicateResponse.status);
          const replicateData = await replicateResponse.json();
          console.log('📏 prediction_id:', replicateData.id);
          console.log('📏 status:', replicateData.status);

          // Flutter にすぐにレスポンスを返す
          return Response.json({
            success: true,
            status: 'processing',
            message: 'AI採寸処理を開始しました。完了まで30秒〜3分かかります。',
            prediction_id: replicateData.id,
            sku: data.sku,
            company_id: data.company_id || 'test_company'
          }, { headers: corsHeaders });

        } catch (measureError) {
          console.error('❌ AI採寸エラー:', measureError.message);
          console.error('   スタック:', measureError.stack);
          
          return Response.json({
            success: false,
            error: `AI採寸エラー: ${measureError.message}`,
            errorType: measureError.constructor.name
          }, { status: 500, headers: corsHeaders });
        }
      }

      // 404 Not Found
      return Response.json({
        success: false,
        error: "Not Found",
        path,
        method: request.method
      }, {
        status: 404,
        headers: corsHeaders
      });

    } catch (error) {
      console.error("API Error:", error);
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
