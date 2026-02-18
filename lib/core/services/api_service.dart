import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:measure_master/features/inventory/domain/api_product.dart';

class ApiService {
  static const String baseUrl = 'https://3000-iuolnmmls4a53d2939w4c-3844e1b6.sandbox.novita.ai';
  
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
    final apiService = ApiService();
    final result = await apiService.searchByBarcodeOrSku(barcode, companyId: companyId);
    
    if (result != null && result['success'] == true && result['data'] != null) {
      final data = result['data'];
      return ApiProduct(
        id: 0,
        sku: data['sku'] ?? '',
        barcode: data['barcode'],
        name: data['name'] ?? '',
        brand: data['brand'],
        category: data['category'],
        size: data['size'],
        color: data['color'],
        priceSale: data['price'],
        createdAt: DateTime.now(),
        imageUrls: null,
      );
    }
    
    return null;
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
}
