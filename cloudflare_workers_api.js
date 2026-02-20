// src/index.js
// v2: Webhook outputパース修正 + WHERE条件安定化 + アプリ側描画対応
// v3: JST タイムスタンプ対応（photographed_at, created_at, updated_at）

/**
 * データベース初期化関数
 * product_master と product_items テーブルを作成
 */
async function initializeDatabase(env) {
  try {
    // 🔍 既存テーブルの存在チェック
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
        console.log('🔄 マイグレーション開始: product_master に company_id カラム追加');
        
        // 1. 旧テーブルをリネーム
        await env.DB.prepare('ALTER TABLE product_master RENAME TO product_master_old').run();
        
        // 2. 新テーブル作成（company_id + sku 複合主キー）
        await env.DB.prepare(`
          CREATE TABLE product_master (
            company_id TEXT NOT NULL DEFAULT '',
            sku TEXT NOT NULL,
            barcode TEXT,
            name TEXT NOT NULL,
            brand TEXT,
            category TEXT,
            size TEXT,
            color TEXT,
            price_list INTEGER,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (company_id, sku)
          )
        `).run();
        
        // 3. 旧データ移行（company_id = '' でデフォルト）
        await env.DB.prepare(`
          INSERT INTO product_master (company_id, sku, barcode, name, brand, category, size, color, price_list, created_at, updated_at)
          SELECT '', sku, barcode, name, brand, category, size, color, price_list, created_at, updated_at
          FROM product_master_old
        `).run();
        
        // 4. 旧テーブル削除
        await env.DB.prepare('DROP TABLE IF EXISTS product_master_old').run();
        
        console.log('✅ マイグレーション完了: product_master');
      } else {
        console.log('✅ product_master は最新状態です');
      }
    } else {
      // 新規作成
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
          price_list INTEGER,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (company_id, sku)
        )
      `).run();
    }

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
      { name: 'measurement_image_url', type: 'TEXT' },
      { name: 'mask_image_url', type: 'TEXT' },
      { name: 'measurement_image_url_r2', type: 'TEXT' },  // 🆕 R2保存URL (アノテーション画像)
      { name: 'mask_image_url_r2', type: 'TEXT' }           // 🆕 R2保存URL (マスク画像)
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

    // インデックス作成（company_id対応）
    await env.DB.prepare(
      "CREATE INDEX IF NOT EXISTS idx_master_company ON product_master(company_id)"
    ).run();
    
    await env.DB.prepare(
      "CREATE INDEX IF NOT EXISTS idx_master_barcode ON product_master(company_id, barcode)"
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
 * 🏢 company_id 抽出ヘルパー関数
 * リクエストから企業IDを取得（優先順: ヘッダー → クエリパラメータ → ボディ）
 * @param {Request} request - HTTP リクエスト
 * @param {URL} url - パース済みURL
 * @returns {string|null} 企業ID または null
 */
function getCompanyId(request, url) {
  return request.headers.get('X-Company-Id') 
    || url.searchParams.get('companyId') 
    || null;
}

/**
 * 📤 Replicate画像をimage-upload-api経由でR2に保存
 * @param {string} replicateUrl - Replicate画像URL
 * @param {string} sku - 商品SKU
 * @param {string} companyId - 企業ID
 * @param {string} type - 画像タイプ ("measurement" または "mask")
 * @returns {Promise<string|null>} R2公開URL または null
 */
async function uploadImageToR2ViaWorker(replicateUrl, sku, companyId, type) {
  if (!replicateUrl) {
    console.log(`⚠️ ${type}画像URLがnull - R2アップロードスキップ`);
    return null;
  }

  try {
    console.log(`📤 R2アップロード開始 (${type}): ${replicateUrl.substring(0, 80)}...`);
    
    // Step 1: Replicateから画像をダウンロード（タイムアウト: 10秒）
    const downloadStartTime = Date.now();
    const imageResponse = await fetch(replicateUrl, {
      signal: AbortSignal.timeout(10000) // 10秒でタイムアウト
    });
    console.log(`⏱️ ダウンロード時間 (${type}): ${Date.now() - downloadStartTime}ms`);
    
    if (!imageResponse.ok) {
      console.error(`❌ 画像ダウンロード失敗 (${type}): ${imageResponse.status}`);
      return null;
    }
    
    const imageBlob = await imageResponse.blob();
    console.log(`✅ 画像ダウンロード完了 (${type}): ${imageBlob.size} bytes`);
    console.log(`🔍 Blob type: ${imageBlob.type}, size: ${imageBlob.size}`);
    
    // Step 2: FormDataを作成
    const ext = replicateUrl.includes('.png') ? 'png' : 'jpg';
    const fileName = `${sku}_${Date.now()}_${type}.${ext}`;
    
    // ✅ Cloudflare Workers 環境用の FormData 作成
    const formData = new FormData();
    
    // Blob を File オブジェクトに変換（Cloudflare Workers 互換）
    const file = new File([imageBlob], fileName, { 
      type: ext === 'png' ? 'image/png' : 'image/jpeg' 
    });
    
    formData.append('file', file);
    formData.append('fileName', fileName);
    formData.append('company_id', companyId);
    formData.append('sku', sku);
    
    console.log(`📤 FormData構築完了:`);
    console.log(`   - file: [File object] ${fileName}`);
    console.log(`   - file.type: ${file.type}`);
    console.log(`   - file.size: ${file.size} bytes`);
    console.log(`   - file.name: ${file.name}`);
    console.log(`   - fileName パラメータ: ${fileName}`);
    console.log(`   - company_id: ${companyId}`);
    console.log(`   - sku: ${sku}`);
    console.log(`📤 POST先: https://image-upload-api.jinkedon2.workers.dev/upload`);
    
    // FormData の全フィールドをダンプ
    console.log(`🔍 FormData 検証:`);
    for (const [key, value] of formData.entries()) {
      if (value instanceof File) {
        console.log(`   ${key}: [File] name="${value.name}", type="${value.type}", size=${value.size}`);
      } else {
        console.log(`   ${key}: ${value}`);
      }
    }
    
    // Step 3: image-upload-apiへPOST（タイムアウト: 15秒）
    console.log(`🚀 POST リクエスト送信開始...`);
    const uploadStartTime = Date.now();
    const uploadResponse = await fetch('https://image-upload-api.jinkedon2.workers.dev/upload', {
      method: 'POST',
      body: formData,
      signal: AbortSignal.timeout(15000) // 15秒でタイムアウト
      // Content-Typeは自動設定されるため明示的に指定しない
    });
    console.log(`⏱️ アップロード時間 (${type}): ${Date.now() - uploadStartTime}ms`);
    console.log(`✅ POST リクエスト送信完了`);
    
    console.log(`📡 image-upload-api レスポンス: ${uploadResponse.status} ${uploadResponse.statusText}`);
    console.log(`   Content-Type: ${uploadResponse.headers.get('content-type')}`);
    console.log(`   Response URL: ${uploadResponse.url}`);
    
    if (!uploadResponse.ok) {
      const errorText = await uploadResponse.text();
      console.error(`❌ R2アップロード失敗 (${type}): ${uploadResponse.status}`);
      console.error(`❌ エラー詳細: ${errorText}`);
      console.error(`❌ レスポンスURL: ${uploadResponse.url}`);
      
      // レスポンスボディをパース試行
      try {
        const errorJson = JSON.parse(errorText);
        console.error(`❌ エラーJSON:`, JSON.stringify(errorJson, null, 2));
      } catch (e) {
        console.error(`❌ エラーテキスト（生データ）: ${errorText}`);
      }
      
      return null;
    }
    
    const uploadResult = await uploadResponse.json();
    const r2Url = uploadResult.url;
    
    console.log(`✅ R2アップロード完了 (${type}): ${r2Url}`);
    
    return r2Url;
    
  } catch (error) {
    console.error(`❌ R2アップロードエラー (${type}):`, error.message);
    console.error(`❌ エラー名: ${error.name}`);
    console.error(`❌ エラースタック:`, error.stack);
    
    // タイムアウトエラーの場合
    if (error.message.includes('Network connection lost') || 
        error.message.includes('timeout') ||
        error.name === 'TimeoutError') {
      console.error(`⏰ タイムアウトエラー: Cloudflare Workers の実行時間制限に達した可能性があります`);
    }
    
    return null;
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
    reference_object: null,
    measurement_image_url: null,  // 🆕 アノテーション画像URL
    mask_image_url: null           // 🆕 マスク画像URL
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
      
      // 🆕 image → measurement_image_url (アノテーション画像)
      if (output.image) {
        result.measurement_image_url = output.image;
        console.log('✅ image → measurement_image_url 抽出完了:', output.image.substring(0, 80) + '...');
      }
      
      // 🆕 mask → mask_image_url (マスク画像)
      if (output.mask) {
        result.mask_image_url = output.mask;
        console.log('✅ mask → mask_image_url 抽出完了:', output.mask.substring(0, 80) + '...');
      }
      
      console.log('✅ measurements:', result.measurements ? 'あり' : 'null');
      console.log('✅ ai_landmarks:', result.ai_landmarks ? 'あり' : 'null');
      console.log('✅ reference_object:', result.reference_object ? 'あり' : 'null');
      console.log('✅ measurement_image_url:', result.measurement_image_url ? 'あり' : 'null');
      console.log('✅ mask_image_url:', result.mask_image_url ? 'あり' : 'null');
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
  console.log('   measurement_image_url:', result.measurement_image_url ? '✅' : '❌ null');
  console.log('   mask_image_url:', result.mask_image_url ? '✅' : '❌ null');
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
  
  // 方法0.5（新規追加）: measurement_image_url からSKUを抽出
  // ファイル名パターン: 1025L190001_1770561189941_measurement.png
  if (sku === 'UNKNOWN' || sku.length < 5) {
    // 🔧 修正: output がオブジェクト形式の場合に対応
    const measurementUrl = (typeof webhookData.output === 'object' && webhookData.output?.image) || '';
    
    if (measurementUrl) {
      // ファイル名からSKUを抽出（アンダースコアの前の部分）
      const fileNameMatch = measurementUrl.match(/\/([^/]+)_(\d+)_measurement\.(png|jpg)$/i);
      if (fileNameMatch && fileNameMatch[1]) {
        sku = fileNameMatch[1];
        console.log('✅ SKU を measurement_image_url から取得:', sku);
      }
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
    
    // CORS ヘッダー（X-Company-Idヘッダーを明示的に許可）
    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, X-Company-Id, x-company-id",
      "Access-Control-Max-Age": "86400"
    };

    // OPTIONS リクエスト（CORS プリフライト）
    if (request.method === "OPTIONS") {
      return new Response(null, { 
        status: 204,
        headers: corsHeaders 
      });
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

      // 🔧 POST /api/products/items - 新規作成 or UPSERT（企業ID考慮 + JST対応）
      if (path === "/api/products/items" && request.method === "POST") {
        try {
          const data = await request.json();
          const companyId = data.company_id || data.companyId || getCompanyId(request, url) || '';

          if (!data.sku) {
            return Response.json({
              success: false,
              error: "SKUが必須です"
            }, { status: 400, headers: corsHeaders });
          }

          console.log('📥 受信データ:', JSON.stringify(data));
          console.log('🏢 企業ID:', companyId);

          // 🏢 企業ID + SKU で既存データをチェック
          const existing = await env.DB.prepare(
            "SELECT id FROM product_items WHERE company_id = ? AND sku = ?"
          ).bind(companyId, data.sku).first();

          console.log('🔍 既存データ:', existing ? 'あり (ID: ' + existing.id + ')' : 'なし');

          if (data.upsert === true && existing) {
            console.log('♻️ UPDATE処理実行（company_id + sku）');
            
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
                updated_at = COALESCE(?, updated_at)
              WHERE company_id = ? AND sku = ?
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
              data.updated_at || null,
              companyId,
              data.sku
            ).run();

            console.log('✅ UPDATE完了:', updateResult);

            return Response.json({
              success: true,
              message: "商品実物データを更新しました",
              sku: data.sku,
              companyId: companyId,
              action: "updated"
            }, { headers: corsHeaders });
            
          } else {
            console.log('➕ INSERT処理実行（company_id付き + JST対応）');
            
            const itemCode = data.item_code || data.itemCode || `${data.sku}_${Date.now()}`;
            console.log('📋 INSERT用item_code:', itemCode);
            console.log('📅 photographedAt:', data.photographedAt);
            console.log('📅 created_at:', data.created_at);
            console.log('📅 updated_at:', data.updated_at);

            const insertResult = await env.DB.prepare(`
              INSERT INTO product_items (
                company_id, sku, item_code, name, barcode,
                brand, category, color, size, material, price,
                condition, product_rank,
                image_urls, actual_measurements, inspection_notes,
                photographed_at, photographed_by, status,
                created_at, updated_at
              ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            `).bind(
              companyId,
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
              data.photographedAt || null,
              data.photographedBy || data.photographed_by || 'mobile_app_user',
              data.status || "Ready",
              data.created_at || null,
              data.updated_at || null
            ).run();

            console.log('✅ INSERT完了:', insertResult);

            return Response.json({
              success: true,
              message: "商品実物データを保存しました",
              sku: data.sku,
              companyId: companyId,
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
        const companyId = getCompanyId(request, url) || '';
        const query = url.searchParams.get("query");
        
        if (!query) {
          return Response.json({
            success: false,
            error: "検索キーワードが指定されていません"
          }, { status: 400, headers: corsHeaders });
        }

        console.log('🔍 統合検索開始:', query, 'companyId:', companyId);

        // 1. product_items から検索（企業ID + SKU or item_code）
        const item = await env.DB.prepare(`
          SELECT * FROM product_items 
          WHERE company_id = ? AND (sku = ? OR item_code = ? OR barcode = ?)
          ORDER BY photographed_at DESC
          LIMIT 1
        `).bind(companyId, query, query, query).first();

        if (item) {
          console.log('✅ product_items で発見:', item.sku);
          
          // マスタ情報も取得
          const master = await env.DB.prepare(
            'SELECT * FROM product_master WHERE company_id = ? AND sku = ?'
          ).bind(companyId, item.sku).first();
          
          const parsedItem = {
            ...item,
            master: master,
            imageUrls: item.image_urls ? JSON.parse(item.image_urls) : null,
            actualMeasurements: item.actual_measurements ? JSON.parse(item.actual_measurements) : null
          };

          return Response.json({
            success: true,
            source: "product_items",
            data: parsedItem,
            companyId: companyId
          }, { headers: corsHeaders });
        }

        console.log('⚠️ product_items に見つからず、product_master を検索');

        // 2. product_master から検索（企業ID + SKU or バーコード）
        const master = await env.DB.prepare(
          "SELECT * FROM product_master WHERE company_id = ? AND (sku = ? OR barcode = ?)"
        ).bind(companyId, query, query).first();

        if (master) {
          console.log('✅ product_master で発見:', master.sku);
          
          return Response.json({
            success: true,
            source: "product_master",
            data: master,
            companyId: companyId
          }, { headers: corsHeaders });
        }

        console.log('❌ 商品が見つかりません:', query);

        return Response.json({
          success: false,
          error: "商品が見つかりません",
          query: query,
          companyId: companyId
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
        
        // 🔧 mask_image_url カラムが存在しない場合は自動追加
        try {
          await env.DB.prepare(
            `ALTER TABLE product_items ADD COLUMN mask_image_url TEXT`
          ).run();
          console.log('✅ mask_image_url カラムを追加しました');
        } catch (e) {
          if (e.message && e.message.includes('duplicate column')) {
            console.log('ℹ️ mask_image_url カラムは既に存在します');
          } else {
            console.log('⚠️ mask_image_url カラム追加スキップ:', e.message);
          }
        }
        
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
            console.log('   measurement_image_url:', parsed.measurement_image_url || 'null');
            console.log('   mask_image_url:', parsed.mask_image_url || 'null');
            
            // データが1つでもあればD1に保存
            if (parsed.measurements || parsed.ai_landmarks) {
              try {
                // ✅ Replicate一時URLをそのまま取得
                const measurementTempUrl = parsed.measurement_image_url || null;
                const maskTempUrl = parsed.mask_image_url || null;
                
                console.log('💾 D1に測定結果を保存中...');
                console.log('🔍 保存データの最終確認:');
                console.log('   measurements:', parsed.measurements ? 'JSON文字列 (長さ: ' + JSON.stringify(parsed.measurements).length + ')' : 'null');
                console.log('   ai_landmarks:', parsed.ai_landmarks ? 'JSON文字列 (長さ: ' + JSON.stringify(parsed.ai_landmarks).length + ')' : 'null');
                console.log('   reference_object:', parsed.reference_object ? 'JSON文字列 (長さ: ' + JSON.stringify(parsed.reference_object).length + ')' : 'null');
                console.log('   measurement_image_url (一時URL):', measurementTempUrl ? measurementTempUrl.substring(0, 60) + '...' : 'null');
                console.log('   mask_image_url (一時URL):', maskTempUrl ? maskTempUrl.substring(0, 60) + '...' : 'null');
                console.log('📱 Flutter側でR2永久保存を実施してください');
                
                // Step 1: 更新対象のレコードIDを取得
                console.log('🔍 更新対象レコードを検索中...');
                console.log('   SKU:', sku, '/ company_id:', companyId);
                const targetRecord = await env.DB.prepare(`
                  SELECT id FROM product_items 
                  WHERE sku = ? AND company_id = ?
                  ORDER BY id DESC
                  LIMIT 1
                `).bind(sku, companyId).first();
                
                if (!targetRecord) {
                  console.error('❌ 更新対象レコードが見つかりません');
                  console.error('   SKU:', sku, '/ company_id:', companyId);
                  // フォールバック: company_id なしで再検索
                  const fallbackRecord = await env.DB.prepare(`
                    SELECT id FROM product_items 
                    WHERE sku = ?
                    ORDER BY id DESC
                    LIMIT 1
                  `).bind(sku).first();
                  
                  if (!fallbackRecord) {
                    console.error('❌ フォールバックでも見つかりません');
                    return Response.json({
                      success: false,
                      error: 'レコードが見つかりません',
                      sku: sku,
                      companyId: companyId
                    }, { status: 404 });
                  }
                  
                  console.log('✅ フォールバックでレコード発見 ID:', fallbackRecord.id);
                  // Step 2: レコードを更新（IDで直接指定）
                  const updateResult = await env.DB.prepare(`
                    UPDATE product_items 
                    SET 
                      measurements = ?,
                      ai_landmarks = ?,
                      reference_object = ?,
                      measurement_image_url = ?,
                      mask_image_url = ?,
                      updated_at = CURRENT_TIMESTAMP
                    WHERE id = ?
                  `).bind(
                    parsed.measurements ? JSON.stringify(parsed.measurements) : null,
                    parsed.ai_landmarks ? JSON.stringify(parsed.ai_landmarks) : null,
                    parsed.reference_object ? JSON.stringify(parsed.reference_object) : null,
                    measurementTempUrl,
                    maskTempUrl,
                    fallbackRecord.id
                  ).run();
                  
                  console.log('✅ D1更新結果 (fallback):', JSON.stringify(updateResult));
                } else {
                  console.log('✅ 更新対象レコード発見 ID:', targetRecord.id);
                  
                  // Step 2: レコードを更新（IDで直接指定）
                  const updateResult = await env.DB.prepare(`
                    UPDATE product_items 
                    SET 
                      measurements = ?,
                      ai_landmarks = ?,
                      reference_object = ?,
                      measurement_image_url = ?,
                      mask_image_url = ?,
                      updated_at = CURRENT_TIMESTAMP
                    WHERE id = ?
                  `).bind(
                    parsed.measurements ? JSON.stringify(parsed.measurements) : null,
                    parsed.ai_landmarks ? JSON.stringify(parsed.ai_landmarks) : null,
                    parsed.reference_object ? JSON.stringify(parsed.reference_object) : null,
                    measurementTempUrl,
                    maskTempUrl,
                    targetRecord.id
                  ).run();
                  
                  console.log('✅ D1更新結果:', JSON.stringify(updateResult));
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
              version: 'cae92e11d94e550f65219633c0bfc0b10db1e290a417001a81ec6a3da66f3216',  // 🆕 mask対応の最新バージョン
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

      // ============================================
      // 📊 ダッシュボード統計API
      // ============================================

      // 📊 ユーザーの当日登録商品統計（カテゴリ別）
      if (path === '/api/dashboard/user-stats' && request.method === 'GET') {
        const companyId = getCompanyId(request, url) || '';
        const date = url.searchParams.get('date') || '';
        const photographedBy = url.searchParams.get('photographed_by') || '';

        if (!date || !photographedBy) {
          return Response.json({
            success: false,
            error: 'dateとphotographed_byパラメータが必要です'
          }, { status: 400, headers: corsHeaders });
        }

        console.log('📊 ユーザー統計取得:', { companyId, date, photographedBy });

        try {
          // created_atがdateで始まる（例: "2026-02-20"で始まる）レコードを取得
          const results = await env.DB.prepare(`
            SELECT category, COUNT(*) as count
            FROM product_items
            WHERE company_id = ? 
              AND photographed_by = ?
              AND created_at LIKE ?
            GROUP BY category
          `).bind(companyId, photographedBy, `${date}%`).all();

          const categoryStats = {};
          results.results.forEach(row => {
            const category = row.category || '未分類';
            categoryStats[category] = row.count;
          });

          return Response.json({
            success: true,
            date,
            photographedBy,
            categoryStats,
            companyId
          }, { headers: corsHeaders });

        } catch (error) {
          console.error('📊 ユーザー統計エラー:', error);
          return Response.json({
            success: false,
            error: error.message
          }, { status: 500, headers: corsHeaders });
        }
      }

      // 📊 チーム全体の当日登録商品総数
      if (path === '/api/dashboard/team-stats' && request.method === 'GET') {
        const companyId = getCompanyId(request, url) || '';
        const date = url.searchParams.get('date') || '';

        if (!date) {
          return Response.json({
            success: false,
            error: 'dateパラメータが必要です'
          }, { status: 400, headers: corsHeaders });
        }

        console.log('📊 チーム統計取得:', { companyId, date });

        try {
          // created_atがdateで始まるレコードをカテゴリ別に集計
          const results = await env.DB.prepare(`
            SELECT category, COUNT(*) as count
            FROM product_items
            WHERE company_id = ? 
              AND created_at LIKE ?
            GROUP BY category
          `).bind(companyId, `${date}%`).all();

          const categoryStats = {};
          results.results.forEach(row => {
            const category = row.category || '未分類';
            categoryStats[category] = row.count;
          });

          return Response.json({
            success: true,
            date,
            categoryStats,
            companyId
          }, { headers: corsHeaders });

        } catch (error) {
          console.error('📊 チーム統計エラー:', error);
          return Response.json({
            success: false,
            error: error.message
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
