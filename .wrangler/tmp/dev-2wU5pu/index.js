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
    await env.DB.prepare("CREATE INDEX IF NOT EXISTS idx_master_barcode ON product_master(barcode)").run();
    await env.DB.prepare("CREATE INDEX IF NOT EXISTS idx_items_sku ON product_items(sku)").run();
    await env.DB.prepare("CREATE INDEX IF NOT EXISTS idx_items_code ON product_items(item_code)").run();
    console.log("\u2705 Database initialized successfully");
  } catch (error) {
    console.error("\u274C Database initialization error:", error);
  }
}
__name(initializeDatabase, "initializeDatabase");
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
        const data = await request.json();
        const master = await env.DB.prepare(
          "SELECT sku FROM product_master WHERE sku = ?"
        ).bind(data.sku).first();
        if (!master) {
          return Response.json({
            success: false,
            error: "\u5546\u54C1\u30DE\u30B9\u30BF\u304C\u898B\u3064\u304B\u308A\u307E\u305B\u3093\u3002\u5148\u306B\u30DE\u30B9\u30BF\u3092\u767B\u9332\u3057\u3066\u304F\u3060\u3055\u3044\u3002",
            sku: data.sku
          }, { status: 404, headers: corsHeaders });
        }
        const itemCode = data.item_code || `${data.sku}_${Date.now()}`;
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
          data.rank || data.productRank || null,
          data.inspectionNotes || null,
          data.photographedBy || null,
          data.status || "Ready"
        ).run();
        if (data.name || data.category || data.brand || data.size || data.color || data.priceSale || data.brandKana || data.categorySub || data.priceCost || data.season || data.releaseDate || data.buyer || data.storeName || data.priceRef || data.priceList || data.location || data.stockQuantity) {
          await env.DB.prepare(`
            UPDATE product_master 
            SET 
              name = COALESCE(?, name),
              category = COALESCE(?, category),
              brand = COALESCE(?, brand),
              size = COALESCE(?, size),
              color = COALESCE(?, color),
              price = COALESCE(?, price),
              brand_kana = COALESCE(?, brand_kana),
              category_sub = COALESCE(?, category_sub),
              price_cost = COALESCE(?, price_cost),
              season = COALESCE(?, season),
              release_date = COALESCE(?, release_date),
              buyer = COALESCE(?, buyer),
              store_name = COALESCE(?, store_name),
              price_ref = COALESCE(?, price_ref),
              price_sale = COALESCE(?, price_sale),
              price_list = COALESCE(?, price_list),
              location = COALESCE(?, location),
              stock_quantity = COALESCE(?, stock_quantity),
              barcode = COALESCE(?, barcode),
              updated_at = CURRENT_TIMESTAMP
            WHERE sku = ?
          `).bind(
            data.name || null,
            data.category || null,
            data.brand || null,
            data.size || null,
            data.color || null,
            data.priceSale || null,
            data.brandKana || null,
            data.categorySub || null,
            data.priceCost || null,
            data.season || null,
            data.releaseDate || null,
            data.buyer || null,
            data.storeName || null,
            data.priceRef || null,
            data.priceSale || null,
            data.priceList || null,
            data.location || null,
            data.stockQuantity || null,
            data.barcode || null,
            data.sku
          ).run();
        }
        return Response.json({
          success: true,
          message: "\u5546\u54C1\u5B9F\u7269\u30C7\u30FC\u30BF\u3092\u4FDD\u5B58\u3057\u307E\u3057\u305F",
          sku: data.sku,
          itemCode
        }, { headers: corsHeaders });
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

// .wrangler/tmp/bundle-aRnACj/middleware-insertion-facade.js
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

// .wrangler/tmp/bundle-aRnACj/middleware-loader.entry.ts
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
