import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:measure_master/features/inventory/domain/api_product.dart';

class ApiService {
  /// ⚠️ TODO: 本番APIサーバーのURLに差し替えること
  /// 旧サンドボックスURL（開発環境専用・本番では使用不可）を削除済み
  /// 例: 'https://api.your-domain.com'
  static const String baseUrl = '';
  
  // 🔧 Cloudflare D1 API エンドポイント (本番環境)
  static const String d1ApiUrl = 'https://measure-master-api.jinkedon2.workers.dev';
  
  // ============================================
  // 🏢 共通ヘッダー生成（企業ID付き）
  // ============================================
  
  /// D1 API用の共通ヘッダーを生成
  /// company_id を X-Company-Id ヘッダーで送信
  /// 
  /// [forPost] POSTリクエストの場合はtrue（Content-Typeを含める）
  Map<String, String> _d1Headers({String? companyId, bool forPost = false}) {
    final headers = <String, String>{};
    
    // POSTリクエストの場合のみContent-Typeを追加
    if (forPost) {
      headers['Content-Type'] = 'application/json';
    }
    
    if (companyId != null && companyId.isNotEmpty) {
      headers['X-Company-Id'] = companyId;
    }
    return headers;
  }
  
  // ============================================
  // 📋 旧API（互換用）
  // ============================================
  
  /// 商品リストを取得
  Future<ApiProductResponse> fetchProducts() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/products/list'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return ApiProductResponse.fromJson(jsonData);
      } else {
        throw Exception('商品データの取得に失敗しました (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('API通信エラー: $e');
    }
  }

  /// 単一商品を取得（将来の拡張用）
  Future<ApiProduct?> fetchProductBySku(String sku) async {
    try {
      final response = await fetchProducts();
      return response.products.firstWhere(
        (product) => product.sku == sku,
        orElse: () => throw Exception('商品が見つかりません'),
      );
    } catch (e) {
      return null;
    }
  }
  
  // ============================================
  // 🔍 統合検索
  // ============================================
  
  /// 🔍 バーコードまたはSKU(商品ID)で商品を検索
  /// 
  /// company_id が最優先: 同じSKUでも企業が違えば別商品
  Future<ApiProduct?> searchByIdOrBarcode(String query, {String? companyId}) async {
    if (query.trim().isEmpty) {
      return null;
    }
    
    try {
      // まずD1データベースから検索（企業ID必須）
      final d1Product = await searchProductInD1(query.trim(), companyId: companyId);
      
      if (d1Product != null) {
        return ApiProduct(
          id: 0,
          sku: d1Product['sku'] ?? '',
          name: d1Product['name'] ?? '',
          brand: d1Product['brand'],
          category: d1Product['category'],
          size: d1Product['size'],
          color: d1Product['color'],
          priceSale: d1Product['price'],
          createdAt: DateTime.now(),
          imageUrls: null,
        );
      }
      
      // D1で見つからない場合、旧APIから検索（フォールバック）
      final response = await fetchProducts();
      
      try {
        return response.products.firstWhere(
          (product) => product.sku.toLowerCase() == query.toLowerCase().trim(),
        );
      } catch (_) {
        return null;
      }
    } catch (e) {
      throw Exception('商品検索エラー: $e');
    }
  }
  
  // ============================================
  // 🔧 Cloudflare D1 Database API
  // 🏢 全APIに company_id を必須送信
  // ============================================
  
  /// 💾 D1に商品実物データを保存 (撮影データ)
  /// 
  /// company_id が最優先キー
  /// 同じSKUでも企業が違えば別レコードとして保存
  Future<bool> saveProductItemToD1(Map<String, dynamic> itemData) async {
    try {
      final companyId = itemData['company_id'] as String? ?? '';
      
      final dataWithUpsert = Map<String, dynamic>.from(itemData);
      dataWithUpsert['upsert'] = true;
      
      
      final response = await http.post(
        Uri.parse('$d1ApiUrl/api/products/items'),
        headers: _d1Headers(companyId: companyId, forPost: true),
        body: jsonEncode(dataWithUpsert),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return jsonData['success'] == true;
      } else if (response.statusCode == 409) {
        final sku = itemData['sku'];
        if (sku != null && sku.toString().isNotEmpty) {
          return await updateProductItemInD1(sku.toString(), itemData);
        }
        throw Exception('SKUが空のため更新できません');
      } else {
        String errorBody = '';
        try {
          errorBody = response.body;
        } catch (_) {}
        throw Exception('D1への保存に失敗しました (${response.statusCode})\n応答: $errorBody');
      }
    } catch (e) {
      throw Exception('D1 API通信エラー: $e');
    }
  }
  
  /// 💾 D1の商品実物データを更新（SKUで特定）
  Future<bool> updateProductItemInD1(String sku, Map<String, dynamic> itemData) async {
    try {
      final companyId = itemData['company_id'] as String? ?? '';
      
      final response = await http.put(
        Uri.parse('$d1ApiUrl/api/products/items/$sku'),
        headers: _d1Headers(companyId: companyId, forPost: true),
        body: jsonEncode(itemData),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return jsonData['success'] == true;
      } else {
        throw Exception('D1の更新に失敗しました (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('D1 API通信エラー: $e');
    }
  }
  
  /// 📦 D1に商品マスタを一括登録 (CSV import用)
  /// 
  /// company_id 付きで送信 → 同じSKUでも企業ごとに別レコード
  Future<Map<String, dynamic>> bulkImportToD1(
    List<Map<String, dynamic>> products, 
    {String? companyId}
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$d1ApiUrl/api/products/bulk-import'),
        headers: _d1Headers(companyId: companyId, forPost: true),
        body: jsonEncode({
          'products': products,
          'companyId': companyId ?? '',
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return jsonData;
      } else {
        throw Exception('一括登録に失敗しました (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('D1 API通信エラー: $e');
    }
  }
  
  /// 📋 D1から商品リストを取得
  /// 
  /// 企業IDでフィルタリング済みの結果のみ返す
  Future<List<Map<String, dynamic>>> fetchProductsFromD1({
    int limit = 100, 
    int offset = 0,
    String? companyId,
  }) async {
    try {
      String url = '$d1ApiUrl/api/products?limit=$limit&offset=$offset';
      if (companyId != null && companyId.isNotEmpty) {
        url += '&companyId=$companyId';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: _d1Headers(companyId: companyId),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['success'] == true) {
          return List<Map<String, dynamic>>.from(jsonData['products']);
        }
        throw Exception('D1データの取得に失敗しました');
      } else {
        throw Exception('D1商品リストの取得に失敗しました (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('D1 API通信エラー: $e');
    }
  }
  
  /// 🔍 D1からSKU検索
  /// 
  /// company_id が最優先: 自社のデータのみ返す
  Future<Map<String, dynamic>?> searchProductInD1(String sku, {String? companyId}) async {
    try {
      String url = '$d1ApiUrl/api/products/search?sku=$sku';
      if (companyId != null && companyId.isNotEmpty) {
        url += '&companyId=$companyId';
      }
      
      
      final response = await http.get(
        Uri.parse(url),
        headers: _d1Headers(companyId: companyId),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['success'] == true && jsonData['product'] != null) {
          return jsonData['product'];
        }
        return null;
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('D1商品検索に失敗しました (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('D1 API通信エラー: $e');
    }
  }
  
  /// 🔍 バーコードで商品検索（静的メソッド）
  static Future<ApiProduct?> searchByBarcode(String barcode, {String? companyId}) async {
    try {
      if (kDebugMode) {
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint('🔍 searchByBarcode START');
        debugPrint('   Query: $barcode');
        debugPrint('   CompanyId: $companyId');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }
      
      final apiService = ApiService();
      final result = await apiService.searchByBarcodeOrSku(barcode, companyId: companyId);
      
      if (kDebugMode) {
        debugPrint('📦 API Response received');
        debugPrint('   - Raw result: $result');
        debugPrint('   - result == null: ${result == null}');
        if (result != null) {
          debugPrint('   - success: ${result['success']}');
          debugPrint('   - data: ${result['data']}');
          debugPrint('   - error: ${result['error']}');
        }
      }
      
      if (result != null && result['success'] == true && result['data'] != null) {
        final data = result['data'];
        // 🔧 masterフィールドからマスタデータを取得（フォールバック用）
        final master = data['master'];
        
        if (kDebugMode) {
          debugPrint('✅ データ取得成功 - ApiProduct作成中');
          debugPrint('   - SKU: ${data['sku']}');
          debugPrint('   - Name: ${data['name']}');
          debugPrint('   - Barcode: ${data['barcode']}');
          debugPrint('   - Material (items): ${data['material']}');
          debugPrint('   - Material (master): ${master?['material']}');
          debugPrint('   - Condition: ${data['condition']}');
          debugPrint('   - ImageUrls: ${data['imageUrls']}');
          debugPrint('   - Source: ${result['source']}');
        }
        
        return ApiProduct(
          id: 0,
          sku: data['sku'] ?? '',
          // 📋 基本情報: product_items優先、なければmaster
          barcode: data['barcode'] ?? master?['barcode'],
          name: data['name'] ?? master?['name'] ?? '',
          brand: data['brand'] ?? master?['brand'],
          category: data['category'] ?? master?['category'],
          size: data['size'] ?? master?['size'],
          color: data['color'] ?? master?['color'],
          priceSale: data['price'] ?? data['price_sale'] ?? master?['price_sale'],
          createdAt: DateTime.now(),
          // 📸 画像: product_items優先（撮影済み実物画像）
          imageUrls: data['imageUrls'],
          // 🏷️ product_items固有の情報（実物データのみ）
          condition: data['condition'],
          productRank: data['product_rank'],
          description: data['inspection_notes'],
          // 📦 product_master由来の情報: product_items優先、なければmaster
          material: data['material'] ?? master?['material'],
          brandKana: data['brand_kana'] ?? master?['brand_kana'],
          categorySub: data['category_sub'] ?? master?['category_sub'],
          priceCost: data['price_cost'] ?? master?['price_cost'],
          season: data['season'] ?? master?['season'],
          releaseDate: data['release_date'] ?? master?['release_date'],
          buyer: data['buyer'] ?? master?['buyer'],
          storeName: data['store_name'] ?? master?['store_name'],
          priceRef: data['price_ref'] ?? master?['price_ref'],
          priceList: data['price_list'] ?? master?['price_list'],
          location: data['location'] ?? master?['location'],
        );
      }
      
      if (kDebugMode) {
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint('❌ searchByBarcode FAILED');
        debugPrint('   Reason: result is null or invalid');
        debugPrint('   - result: $result');
        if (result != null) {
          debugPrint('   - success: ${result['success']}');
          debugPrint('   - error: ${result['error']}');
        }
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }
      
      return null;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint('💥 searchByBarcode EXCEPTION');
        debugPrint('   Error: $e');
        debugPrint('   Stack trace:');
        debugPrint('$stackTrace');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }
      rethrow;
    }
  }
  
  /// 🔍 統合検索: バーコードまたはSKUで検索
  /// 
  /// company_id が最優先キー
  /// Workers API 側で企業IDフィルタリング済み
  Future<Map<String, dynamic>?> searchByBarcodeOrSku(String query, {String? companyId}) async {
    if (query.trim().isEmpty) {
      return null;
    }
    
    try {
      
      String url = '$d1ApiUrl/api/search?query=${Uri.encodeComponent(query.trim())}';
      if (companyId != null && companyId.isNotEmpty) {
        url += '&companyId=$companyId';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: _d1Headers(companyId: companyId),
      ).timeout(const Duration(seconds: 10));


      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['success'] == true) {
          return jsonData;
        }
      } else if (response.statusCode == 404) {
        return null;
      }
      
      throw Exception('統合検索に失敗しました (${response.statusCode})');
    } catch (e) {
      throw Exception('検索API通信エラー: $e');
    }
  }

  // ============================================
  // 📊 ダッシュボード統計API
  // ============================================

  /// 📊 ユーザーの当日登録商品統計を取得（カテゴリ別）
  /// 
  /// [companyId] 企業ID
  /// [photographedBy] ユーザー名（例：「スタッフ」）
  /// 
  /// Returns: {category: count} 形式のMap
  Future<Map<String, int>> getUserTodayStatsByCategory({
    required String companyId,
    required String photographedBy,
  }) async {
    try {
      // 今日の日付（JST）
      final now = DateTime.now();
      final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      
      final response = await http.get(
        Uri.parse('$d1ApiUrl/api/dashboard/user-stats?date=$today&photographed_by=$photographedBy'),
        headers: _d1Headers(companyId: companyId),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['categoryStats'] != null) {
          final Map<String, dynamic> categoryStats = data['categoryStats'];
          return categoryStats.map((key, value) => MapEntry(key, value as int));
        }
        return {};
      }
      
      return {};
    } catch (e) {
      // エラー時は空のMapを返す
      return {};
    }
  }

  /// 📊 チーム全体の当日登録商品統計を取得（カテゴリ別）
  /// 
  /// [companyId] 企業ID
  /// 
  /// Returns: {category: count} 形式のMap
  Future<Map<String, int>> getTeamTodayStatsByCategory({required String companyId}) async {
    try {
      // 今日の日付（JST）
      final now = DateTime.now();
      final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      
      final response = await http.get(
        Uri.parse('$d1ApiUrl/api/dashboard/team-stats?date=$today'),
        headers: _d1Headers(companyId: companyId),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['categoryStats'] != null) {
          final Map<String, dynamic> categoryStats = data['categoryStats'];
          return categoryStats.map((key, value) => MapEntry(key, value as int));
        }
        return {};
      }
      
      return {};
    } catch (e) {
      // エラー時は空のMapを返す
      return {};
    }
  }
}
