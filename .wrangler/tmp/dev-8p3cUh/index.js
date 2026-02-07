var __defProp = Object.defineProperty;
var __name = (target, value) => __defProp(target, "name", { value, configurable: true });

// src/index.js
async function initializeDatabase(env) {
  try {
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
    const migrationColumns = [
      { name: "measurements", type: "TEXT" },
      { name: "ai_landmarks", type: "TEXT" },
      { name: "reference_object", type: "TEXT" },
      { name: "measurement_image_url", type: "TEXT" }
    ];
    for (const col of migrationColumns) {
      try {
        await env.DB.prepare(
          `ALTER TABLE product_items ADD COLUMN ${col.name} ${col.type}`
        ).run();
        console.log(`\u2705 \u30AB\u30E9\u30E0\u8FFD\u52A0: ${col.name}`);
      } catch (e) {
        if (!e.message.includes("duplicate column")) {
          console.log(`\u2139\uFE0F \u30AB\u30E9\u30E0 ${col.name} \u306F\u65E2\u306B\u5B58\u5728\u3057\u307E\u3059`);
        }
      }
    }
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
    console.log("\u2705 Database initialized successfully");
  } catch (error) {
    console.error("\u274C Database initialization error:", error);
  }
}
__name(initializeDatabase, "initializeDatabase");
function parseReplicateOutput(output) {
  const result = {
    ai_landmarks: null,
    measurements: null,
    reference_object: null
  };
  try {
    if (Array.isArray(output)) {
      console.log("\u{1F4E6} output \u306F\u914D\u5217\u5F62\u5F0F (\u8981\u7D20\u6570:", output.length, ")");
      for (let i = 0; i < output.length; i++) {
        let parsed = output[i];
        if (typeof parsed === "string") {
          try {
            parsed = JSON.parse(parsed);
          } catch (e) {
            console.log(`\u26A0\uFE0F output[${i}] \u306EJSON\u30D1\u30FC\u30B9\u306B\u5931\u6557:`, e.message);
            continue;
          }
        }
        if (typeof parsed === "object" && parsed !== null) {
          if (parsed.body_length !== void 0 || parsed.shoulder_width !== void 0 || parsed.body_width !== void 0 || parsed.sleeve_length !== void 0) {
            result.measurements = parsed;
            console.log(`\u2705 output[${i}] \u2192 measurements:`, JSON.stringify(parsed));
          } else if (parsed["1"] !== void 0 || parsed["2"] !== void 0) {
            result.ai_landmarks = parsed;
            console.log(`\u2705 output[${i}] \u2192 ai_landmarks (${Object.keys(parsed).length} points)`);
            for (const key of Object.keys(parsed)) {
              const point = parsed[key];
              if (point && point.pixelPerCm !== void 0) {
                result.reference_object = {
                  type: "pixelPerCm",
                  pixelPerCm: point.pixelPerCm,
                  source_landmark: key
                };
                console.log(`\u2705 pixelPerCm \u62BD\u51FA (landmark ${key}):`, point.pixelPerCm);
                break;
              }
            }
          } else {
            console.log(`\u26A0\uFE0F output[${i}] \u306E\u5F62\u5F0F\u304C\u4E0D\u660E:`, JSON.stringify(parsed).substring(0, 200));
          }
        }
      }
    } else if (typeof output === "object" && output !== null) {
      console.log("\u{1F4E6} output \u306F\u30AA\u30D6\u30B8\u30A7\u30AF\u30C8\u5F62\u5F0F");
      result.measurements = output.measurements || null;
      result.ai_landmarks = output.ai_landmarks || output.ai_landmark || null;
      result.reference_object = output.reference_object || null;
    }
  } catch (e) {
    console.error("\u274C output \u30D1\u30FC\u30B9\u30A8\u30E9\u30FC:", e.message);
  }
  console.log("\u{1F4CA} \u30D1\u30FC\u30B9\u7D50\u679C\u30B5\u30DE\u30EA\u30FC:");
  console.log("   measurements:", result.measurements ? "\u2705" : "\u274C null");
  console.log("   ai_landmarks:", result.ai_landmarks ? "\u2705" : "\u274C null");
  console.log("   reference_object:", result.reference_object ? "\u2705" : "\u274C null");
  return result;
}
__name(parseReplicateOutput, "parseReplicateOutput");
function extractSkuAndCompany(webhookData, requestUrl) {
  let sku = "UNKNOWN";
  let companyId = "test_company";
  if (requestUrl) {
    try {
      const urlObj = new URL(requestUrl);
      const urlSku = urlObj.searchParams.get("sku");
      const urlCompanyId = urlObj.searchParams.get("company_id");
      if (urlSku) {
        sku = urlSku;
        console.log("\u2705 SKU \u3092\u30AF\u30A8\u30EA\u30D1\u30E9\u30E1\u30FC\u30BF\u304B\u3089\u53D6\u5F97:", sku);
      }
      if (urlCompanyId) {
        companyId = urlCompanyId;
        console.log("\u2705 company_id \u3092\u30AF\u30A8\u30EA\u30D1\u30E9\u30E1\u30FC\u30BF\u304B\u3089\u53D6\u5F97:", companyId);
      }
    } catch (e) {
      console.log("\u26A0\uFE0F URL\u30D1\u30FC\u30B9\u5931\u6557:", e.message);
    }
  }
  if (sku === "UNKNOWN") {
    const imageUrl = webhookData.input?.image || "";
    if (imageUrl.startsWith("http")) {
      const skuMatch = imageUrl.match(/\/([^\/]+)\/[^\/]+\.(jpg|jpeg|png)/i);
      if (skuMatch) {
        sku = skuMatch[1];
        console.log("\u2705 SKU \u3092URL\u30D1\u30BF\u30FC\u30F3\u304B\u3089\u53D6\u5F97:", sku);
      }
      if (imageUrl.includes("/test_company/")) {
        companyId = "test_company";
      } else {
        const companyMatch = imageUrl.match(/\.dev\/([^\/]+)\/[^\/]+\//);
        if (companyMatch) {
          companyId = companyMatch[1];
        }
      }
    }
  }
  console.log("\u{1F50D} SKU/Company\u6700\u7D42\u7D50\u679C:", { sku, companyId });
  return { sku, companyId };
}
__name(extractSkuAndCompany, "extractSkuAndCompany");
var src_default = {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;
    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type"
    };
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }
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
      if (path === "/api/products" && request.method === "GET") {
        const limit = parseInt(url.searchParams.get("limit") || "100");
        const offset = parseInt(url.searchParams.get("offset") || "0");
        const { results: masters } = await env.DB.prepare(`
          SELECT * FROM product_master 
          ORDER BY updated_at DESC 
          LIMIT ? OFFSET ?
        `).bind(limit, offset).all();
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
      if (path === "/api/products/search" && request.method === "GET") {
        const sku = url.searchParams.get("sku");
        if (!sku) {
          return Response.json({
            success: false,
            error: "SKU\u304C\u6307\u5B9A\u3055\u308C\u3066\u3044\u307E\u305B\u3093"
          }, { status: 400, headers: corsHeaders });
        }
        const master = await env.DB.prepare(
          "SELECT * FROM product_master WHERE sku = ?"
        ).bind(sku).first();
        if (!master) {
          return Response.json({
            success: false,
            error: "\u5546\u54C1\u30DE\u30B9\u30BF\u304C\u898B\u3064\u304B\u308A\u307E\u305B\u3093",
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
          message: `\u30DE\u30B9\u30BF\u30C7\u30FC\u30BF\u3092\u66F4\u65B0\u3057\u307E\u3057\u305F`,
          inserted: insertedCount,
          updated: updatedCount,
          total: products.length
        }, { headers: corsHeaders });
      }
      if (path === "/api/products/items" && request.method === "POST") {
        try {
          const data = await request.json();
          if (!data.sku) {
            return Response.json({
              success: false,
              error: "SKU\u304C\u5FC5\u9808\u3067\u3059"
            }, { status: 400, headers: corsHeaders });
          }
          console.log("\u{1F4E5} \u53D7\u4FE1\u30C7\u30FC\u30BF:", JSON.stringify(data));
          const existing = await env.DB.prepare(
            "SELECT id FROM product_items WHERE sku = ?"
          ).bind(data.sku).first();
          console.log("\u{1F50D} \u65E2\u5B58\u30C7\u30FC\u30BF:", existing ? "\u3042\u308A (ID: " + existing.id + ")" : "\u306A\u3057");
          if (data.upsert === true && existing) {
            console.log("\u267B\uFE0F UPDATE\u51E6\u7406\u5B9F\u884C");
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
            console.log("\u2705 UPDATE\u5B8C\u4E86:", updateResult);
            return Response.json({
              success: true,
              message: "\u5546\u54C1\u5B9F\u7269\u30C7\u30FC\u30BF\u3092\u66F4\u65B0\u3057\u307E\u3057\u305F",
              sku: data.sku,
              action: "updated"
            }, { headers: corsHeaders });
          } else {
            console.log("\u2795 INSERT\u51E6\u7406\u5B9F\u884C");
            const itemCode = data.item_code || data.itemCode || `${data.sku}_${Date.now()}`;
            console.log("\u{1F4CB} INSERT\u7528item_code:", itemCode);
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
              data.photographedAt || (/* @__PURE__ */ new Date()).toISOString(),
              data.photographedBy || data.photographed_by || "mobile_app_user",
              data.status || "Ready",
              data.company_id || "test_company"
            ).run();
            console.log("\u2705 INSERT\u5B8C\u4E86:", insertResult);
            return Response.json({
              success: true,
              message: "\u5546\u54C1\u5B9F\u7269\u30C7\u30FC\u30BF\u3092\u4FDD\u5B58\u3057\u307E\u3057\u305F",
              sku: data.sku,
              itemCode,
              action: "created"
            }, { headers: corsHeaders });
          }
        } catch (dbError) {
          console.error("\u274C Database Error:", dbError);
          console.error("Error message:", dbError.message);
          console.error("Error stack:", dbError.stack);
          return Response.json({
            success: false,
            error: `D1_ERROR: ${dbError.message}`,
            details: dbError.stack,
            endpoint: "POST /api/products/items"
          }, {
            status: 500,
            headers: corsHeaders
          });
        }
      }
      if (path.startsWith("/api/products/items/") && request.method === "PUT") {
        const sku = decodeURIComponent(path.replace("/api/products/items/", ""));
        const data = await request.json();
        const existing = await env.DB.prepare(
          "SELECT id FROM product_items WHERE sku = ?"
        ).bind(sku).first();
        if (!existing) {
          return Response.json({
            success: false,
            error: "\u5546\u54C1\u5B9F\u7269\u30C7\u30FC\u30BF\u304C\u898B\u3064\u304B\u308A\u307E\u305B\u3093",
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
          message: "\u5546\u54C1\u5B9F\u7269\u30C7\u30FC\u30BF\u3092\u66F4\u65B0\u3057\u307E\u3057\u305F",
          sku,
          action: "updated"
        }, { headers: corsHeaders });
      }
      if (path === "/api/products/items" && request.method === "GET") {
        const limit = parseInt(url.searchParams.get("limit") || "100");
        const offset = parseInt(url.searchParams.get("offset") || "0");
        const { results } = await env.DB.prepare(`
          SELECT * FROM product_items 
          ORDER BY updated_at DESC 
          LIMIT ? OFFSET ?
        `).bind(limit, offset).all();
        const items = results.map((item) => ({
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
      if (path.startsWith("/api/products/items/") && request.method === "GET") {
        const sku = decodeURIComponent(path.replace("/api/products/items/", ""));
        const item = await env.DB.prepare(
          "SELECT * FROM product_items WHERE sku = ? AND item_code NOT LIKE '%-%' ORDER BY id ASC LIMIT 1"
        ).bind(sku).first();
        if (!item) {
          return Response.json({
            success: false,
            error: "\u5546\u54C1\u5B9F\u7269\u30C7\u30FC\u30BF\u304C\u898B\u3064\u304B\u308A\u307E\u305B\u3093",
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
      if (path.startsWith("/api/products/items/") && request.method === "DELETE") {
        const sku = decodeURIComponent(path.replace("/api/products/items/", ""));
        await env.DB.prepare(
          "DELETE FROM product_items WHERE sku = ?"
        ).bind(sku).run();
        return Response.json({
          success: true,
          message: "\u5546\u54C1\u5B9F\u7269\u30C7\u30FC\u30BF\u3092\u524A\u9664\u3057\u307E\u3057\u305F",
          sku,
          action: "deleted"
        }, { headers: corsHeaders });
      }
      if (path === "/api/search" && request.method === "GET") {
        const query = url.searchParams.get("query");
        if (!query) {
          return Response.json({
            success: false,
            error: "\u691C\u7D22\u30AD\u30FC\u30EF\u30FC\u30C9\u304C\u6307\u5B9A\u3055\u308C\u3066\u3044\u307E\u305B\u3093"
          }, { status: 400, headers: corsHeaders });
        }
        console.log("\u{1F50D} \u7D71\u5408\u691C\u7D22\u958B\u59CB:", query);
        const item = await env.DB.prepare(`
          SELECT * FROM product_items 
          WHERE barcode = ? OR sku = ?
          ORDER BY photographed_at DESC
          LIMIT 1
        `).bind(query, query).first();
        if (item) {
          console.log("\u2705 product_items \u3067\u767A\u898B:", item.sku);
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
        console.log("\u26A0\uFE0F product_items \u306B\u898B\u3064\u304B\u3089\u305A\u3001product_master \u3092\u691C\u7D22");
        const master = await env.DB.prepare(
          "SELECT * FROM product_master WHERE barcode = ? OR sku = ?"
        ).bind(query, query).first();
        if (master) {
          console.log("\u2705 product_master \u3067\u767A\u898B:", master.sku);
          return Response.json({
            success: true,
            source: "product_master",
            data: master
          }, { headers: corsHeaders });
        }
        console.log("\u274C \u5546\u54C1\u304C\u898B\u3064\u304B\u308A\u307E\u305B\u3093:", query);
        return Response.json({
          success: false,
          error: "\u5546\u54C1\u304C\u898B\u3064\u304B\u308A\u307E\u305B\u3093",
          query
        }, { status: 404, headers: corsHeaders });
      }
      if (path === "/api/products/search-barcode" && request.method === "GET") {
        const barcode = url.searchParams.get("barcode");
        if (!barcode) {
          return Response.json({
            success: false,
            error: "\u30D0\u30FC\u30B3\u30FC\u30C9\u304C\u6307\u5B9A\u3055\u308C\u3066\u3044\u307E\u305B\u3093"
          }, { status: 400, headers: corsHeaders });
        }
        const master = await env.DB.prepare(
          "SELECT * FROM product_master WHERE barcode = ?"
        ).bind(barcode).first();
        if (!master) {
          return Response.json({
            success: false,
            error: "\u5546\u54C1\u304C\u898B\u3064\u304B\u308A\u307E\u305B\u3093"
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
      if (path === "/api/webhook/replicate" && request.method === "POST") {
        console.log("\u{1F514} Replicate Webhook \u53D7\u4FE1");
        try {
          const webhookData = await request.json();
          console.log("\u{1F4E6} Webhook \u30B9\u30C6\u30FC\u30BF\u30B9:", webhookData.status);
          console.log("\u{1F4E6} Webhook output type:", typeof webhookData.output, Array.isArray(webhookData.output) ? "(\u914D\u5217)" : "");
          if (webhookData.status === "succeeded" && webhookData.output) {
            console.log("\u2705 Replicate \u51E6\u7406\u6210\u529F");
            const parsed = parseReplicateOutput(webhookData.output);
            const { sku, companyId } = extractSkuAndCompany(webhookData, request.url);
            console.log("\u{1F4CF} \u30D1\u30FC\u30B9\u7D50\u679C:");
            console.log("   SKU:", sku);
            console.log("   Company ID:", companyId);
            console.log("   measurements:", parsed.measurements ? JSON.stringify(parsed.measurements) : "null");
            console.log("   ai_landmarks keys:", parsed.ai_landmarks ? Object.keys(parsed.ai_landmarks).length : 0);
            console.log("   reference_object:", parsed.reference_object ? JSON.stringify(parsed.reference_object) : "null");
            if (parsed.measurements || parsed.ai_landmarks) {
              try {
                console.log("\u{1F4BE} D1\u306B\u6E2C\u5B9A\u7D50\u679C\u3092\u4FDD\u5B58\u4E2D...");
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
                console.log("\u2705 D1\u66F4\u65B0\u7D50\u679C:", JSON.stringify(updateResult));
                if (updateResult.meta && updateResult.meta.changes === 0) {
                  console.log("\u26A0\uFE0F \u8B66\u544A: \u66F4\u65B0\u3055\u308C\u305F\u884C\u304C0\u4EF6");
                  console.log("   SKU:", sku, "/ Company:", companyId);
                  console.log("\u{1F504} \u30D5\u30A9\u30FC\u30EB\u30D0\u30C3\u30AF: company_id \u306A\u3057\u3067\u518D\u8A66\u884C...");
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
                  console.log("\u{1F504} \u30D5\u30A9\u30FC\u30EB\u30D0\u30C3\u30AF\u7D50\u679C:", JSON.stringify(fallbackResult));
                  if (fallbackResult.meta && fallbackResult.meta.changes > 0) {
                    console.log("\u2705 \u30D5\u30A9\u30FC\u30EB\u30D0\u30C3\u30AF\u3067\u66F4\u65B0\u6210\u529F");
                  } else {
                    console.log("\u274C \u30D5\u30A9\u30FC\u30EB\u30D0\u30C3\u30AF\u3082\u5931\u6557: SKU=" + sku + " \u306E\u30EC\u30B3\u30FC\u30C9\u304C\u5B58\u5728\u3057\u306A\u3044\u53EF\u80FD\u6027");
                  }
                } else {
                  console.log("\u2705 D1\u66F4\u65B0\u6210\u529F: " + (updateResult.meta?.changes || 0) + "\u884C\u66F4\u65B0");
                }
              } catch (dbError) {
                console.error("\u274C D1\u66F4\u65B0\u30A8\u30E9\u30FC:", dbError.message);
                console.error("   \u30B9\u30BF\u30C3\u30AF:", dbError.stack);
              }
            } else {
              console.log("\u26A0\uFE0F measurements \u3082 ai_landmarks \u3082\u53D6\u5F97\u3067\u304D\u307E\u305B\u3093\u3067\u3057\u305F");
              console.log("   output \u306E\u751F\u30C7\u30FC\u30BF:", JSON.stringify(webhookData.output).substring(0, 500));
            }
          } else if (webhookData.status === "failed") {
            console.log("\u274C Replicate \u51E6\u7406\u5931\u6557:", webhookData.error);
          } else {
            console.log("\u23F3 Replicate \u51E6\u7406\u4E2D:", webhookData.status);
          }
          return Response.json({ success: true }, { headers: corsHeaders });
        } catch (error) {
          console.error("\u274C Webhook \u51E6\u7406\u30A8\u30E9\u30FC:", error);
          return Response.json({
            success: false,
            error: error.message
          }, {
            status: 500,
            headers: corsHeaders
          });
        }
      }
      if (path === "/api/measure" && request.method === "POST") {
        console.log("\u{1F3AF} /api/measure \u30A8\u30F3\u30C9\u30DD\u30A4\u30F3\u30C8\u5230\u9054");
        try {
          const data = await request.json();
          console.log("\u{1F4CF} AI\u81EA\u52D5\u63A1\u5BF8\u30EA\u30AF\u30A8\u30B9\u30C8\u53D7\u4FE1:");
          console.log("   - image_url:", data.image_url);
          console.log("   - sku:", data.sku);
          console.log("   - garment_class:", data.garment_class);
          const replicateApiKey = env.REPLICATE_API_KEY;
          if (!replicateApiKey) {
            return Response.json({
              success: false,
              error: "Replicate API\u30AD\u30FC\u304C\u8A2D\u5B9A\u3055\u308C\u3066\u3044\u307E\u305B\u3093"
            }, { status: 500, headers: corsHeaders });
          }
          console.log("\u{1F511} API\u30AD\u30FC\u78BA\u8A8D: \u3042\u308A (\u9577\u3055:", replicateApiKey.length, ")");
          const imageInput = data.image_url;
          console.log("\u{1F680} Replicate API\u547C\u3073\u51FA\u3057\uFF08\u975E\u540C\u671F\u30E2\u30FC\u30C9\uFF09...");
          console.log("   \u753B\u50CF\u5F62\u5F0F: URL\u76F4\u63A5\u6E21\u3057");
          const replicateResponse = await fetch("https://api.replicate.com/v1/predictions", {
            method: "POST",
            headers: {
              "Authorization": `Bearer ${replicateApiKey}`,
              "Content-Type": "application/json"
            },
            body: JSON.stringify({
              version: "6f4a150f6355b07eff5151b7ef49f2bf0b297bd329ee5f17a46e283f0685f926",
              input: {
                image: imageInput,
                garment_class: data.garment_class || "long sleeve top"
              },
              webhook: `https://measure-master-api.jinkedon2.workers.dev/api/webhook/replicate?sku=${encodeURIComponent(data.sku || "")}&company_id=${encodeURIComponent(data.company_id || "test_company")}`,
              webhook_events_filter: ["completed"]
            })
          });
          console.log("\u{1F4E1} Replicate HTTP\u30B9\u30C6\u30FC\u30BF\u30B9:", replicateResponse.status);
          const replicateData = await replicateResponse.json();
          console.log("\u{1F4CF} prediction_id:", replicateData.id);
          console.log("\u{1F4CF} status:", replicateData.status);
          return Response.json({
            success: true,
            status: "processing",
            message: "AI\u63A1\u5BF8\u51E6\u7406\u3092\u958B\u59CB\u3057\u307E\u3057\u305F\u3002\u5B8C\u4E86\u307E\u306730\u79D2\u301C3\u5206\u304B\u304B\u308A\u307E\u3059\u3002",
            prediction_id: replicateData.id,
            sku: data.sku,
            company_id: data.company_id || "test_company"
          }, { headers: corsHeaders });
        } catch (measureError) {
          console.error("\u274C AI\u63A1\u5BF8\u30A8\u30E9\u30FC:", measureError.message);
          console.error("   \u30B9\u30BF\u30C3\u30AF:", measureError.stack);
          return Response.json({
            success: false,
            error: `AI\u63A1\u5BF8\u30A8\u30E9\u30FC: ${measureError.message}`,
            errorType: measureError.constructor.name
          }, { status: 500, headers: corsHeaders });
        }
      }
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

// ../../../usr/lib/node_modules/wrangler/templates/middleware/middleware-ensure-req-body-drained.ts
var drainBody = /* @__PURE__ */ __name(async (request, env, _ctx, middlewareCtx) => {
  try {
    return await middlewareCtx.next(request, env);
  } finally {
    try {
      if (request.body !== null && !request.bodyUsed) {
        const reader = request.body.getReader();
        while (!(await reader.read()).done) {
        }
      }
    } catch (e) {
      console.error("Failed to drain the unused request body.", e);
    }
  }
}, "drainBody");
var middleware_ensure_req_body_drained_default = drainBody;

// ../../../usr/lib/node_modules/wrangler/templates/middleware/middleware-miniflare3-json-error.ts
function reduceError(e) {
  return {
    name: e?.name,
    message: e?.message ?? String(e),
    stack: e?.stack,
    cause: e?.cause === void 0 ? void 0 : reduceError(e.cause)
  };
}
__name(reduceError, "reduceError");
var jsonError = /* @__PURE__ */ __name(async (request, env, _ctx, middlewareCtx) => {
  try {
    return await middlewareCtx.next(request, env);
  } catch (e) {
    const error = reduceError(e);
    return Response.json(error, {
      status: 500,
      headers: { "MF-Experimental-Error-Stack": "true" }
    });
  }
}, "jsonError");
var middleware_miniflare3_json_error_default = jsonError;

// .wrangler/tmp/bundle-77cQh0/middleware-insertion-facade.js
var __INTERNAL_WRANGLER_MIDDLEWARE__ = [
  middleware_ensure_req_body_drained_default,
  middleware_miniflare3_json_error_default
];
var middleware_insertion_facade_default = src_default;

// ../../../usr/lib/node_modules/wrangler/templates/middleware/common.ts
var __facade_middleware__ = [];
function __facade_register__(...args) {
  __facade_middleware__.push(...args.flat());
}
__name(__facade_register__, "__facade_register__");
function __facade_invokeChain__(request, env, ctx, dispatch, middlewareChain) {
  const [head, ...tail] = middlewareChain;
  const middlewareCtx = {
    dispatch,
    next(newRequest, newEnv) {
      return __facade_invokeChain__(newRequest, newEnv, ctx, dispatch, tail);
    }
  };
  return head(request, env, ctx, middlewareCtx);
}
__name(__facade_invokeChain__, "__facade_invokeChain__");
function __facade_invoke__(request, env, ctx, dispatch, finalMiddleware) {
  return __facade_invokeChain__(request, env, ctx, dispatch, [
    ...__facade_middleware__,
    finalMiddleware
  ]);
}
__name(__facade_invoke__, "__facade_invoke__");

// .wrangler/tmp/bundle-77cQh0/middleware-loader.entry.ts
var __Facade_ScheduledController__ = class ___Facade_ScheduledController__ {
  constructor(scheduledTime, cron, noRetry) {
    this.scheduledTime = scheduledTime;
    this.cron = cron;
    this.#noRetry = noRetry;
  }
  static {
    __name(this, "__Facade_ScheduledController__");
  }
  #noRetry;
  noRetry() {
    if (!(this instanceof ___Facade_ScheduledController__)) {
      throw new TypeError("Illegal invocation");
    }
    this.#noRetry();
  }
};
function wrapExportedHandler(worker) {
  if (__INTERNAL_WRANGLER_MIDDLEWARE__ === void 0 || __INTERNAL_WRANGLER_MIDDLEWARE__.length === 0) {
    return worker;
  }
  for (const middleware of __INTERNAL_WRANGLER_MIDDLEWARE__) {
    __facade_register__(middleware);
  }
  const fetchDispatcher = /* @__PURE__ */ __name(function(request, env, ctx) {
    if (worker.fetch === void 0) {
      throw new Error("Handler does not export a fetch() function.");
    }
    return worker.fetch(request, env, ctx);
  }, "fetchDispatcher");
  return {
    ...worker,
    fetch(request, env, ctx) {
      const dispatcher = /* @__PURE__ */ __name(function(type, init) {
        if (type === "scheduled" && worker.scheduled !== void 0) {
          const controller = new __Facade_ScheduledController__(
            Date.now(),
            init.cron ?? "",
            () => {
            }
          );
          return worker.scheduled(controller, env, ctx);
        }
      }, "dispatcher");
      return __facade_invoke__(request, env, ctx, dispatcher, fetchDispatcher);
    }
  };
}
__name(wrapExportedHandler, "wrapExportedHandler");
function wrapWorkerEntrypoint(klass) {
  if (__INTERNAL_WRANGLER_MIDDLEWARE__ === void 0 || __INTERNAL_WRANGLER_MIDDLEWARE__.length === 0) {
    return klass;
  }
  for (const middleware of __INTERNAL_WRANGLER_MIDDLEWARE__) {
    __facade_register__(middleware);
  }
  return class extends klass {
    #fetchDispatcher = /* @__PURE__ */ __name((request, env, ctx) => {
      this.env = env;
      this.ctx = ctx;
      if (super.fetch === void 0) {
        throw new Error("Entrypoint class does not define a fetch() function.");
      }
      return super.fetch(request);
    }, "#fetchDispatcher");
    #dispatcher = /* @__PURE__ */ __name((type, init) => {
      if (type === "scheduled" && super.scheduled !== void 0) {
        const controller = new __Facade_ScheduledController__(
          Date.now(),
          init.cron ?? "",
          () => {
          }
        );
        return super.scheduled(controller);
      }
    }, "#dispatcher");
    fetch(request) {
      return __facade_invoke__(
        request,
        this.env,
        this.ctx,
        this.#dispatcher,
        this.#fetchDispatcher
      );
    }
  };
}
__name(wrapWorkerEntrypoint, "wrapWorkerEntrypoint");
var WRAPPED_ENTRY;
if (typeof middleware_insertion_facade_default === "object") {
  WRAPPED_ENTRY = wrapExportedHandler(middleware_insertion_facade_default);
} else if (typeof middleware_insertion_facade_default === "function") {
  WRAPPED_ENTRY = wrapWorkerEntrypoint(middleware_insertion_facade_default);
}
var middleware_loader_entry_default = WRAPPED_ENTRY;
export {
  __INTERNAL_WRANGLER_MIDDLEWARE__,
  middleware_loader_entry_default as default
};
//# sourceMappingURL=index.js.map
