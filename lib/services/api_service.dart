import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:measure_master/models/api_product.dart';

class ApiService {
  static const String baseUrl = 'https://3000-iuolnmmls4a53d2939w4c-3844e1b6.sandbox.novita.ai';
  
  // 🔧 Cloudflare D1 API エンドポイント
  static const String d1ApiUrl = 'https://measure-master-api.jinkedon2.workers.dev';
  
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
  
  /// 🔍 バーコードまたはSKU(商品ID)で商品を検索
  /// 
  /// 検索対象:
  /// - SKU (商品管理ID)
  /// - バーコード (将来対応)
  /// 
  /// 使用例:
  /// ```dart
  /// final product = await apiService.searchByIdOrBarcode('1025L190003');
  /// if (product != null) {
  ///   // 商品が見つかった
  /// }
  /// ```
  Future<ApiProduct?> searchByIdOrBarcode(String query) async {
    if (query.trim().isEmpty) {
      return null;
    }
    
    try {
      final response = await fetchProducts();
      
      // SKUで検索
      try {
        return response.products.firstWhere(
          (product) => product.sku.toLowerCase() == query.toLowerCase().trim(),
        );
      } catch (_) {
        // SKUで見つからない場合、将来的にバーコードで検索
        // 現在のAPIにはバーコードフィールドがないため、SKUのみ
        return null;
      }
    } catch (e) {
      throw Exception('商品検索エラー: $e');
    }
  }
  
  // ==========================================
  // 🔧 Cloudflare D1 Database API
  // ==========================================
  
  /// 💾 D1に商品実物データを保存 (撮影データ)
  /// 
  /// product_items テーブルに保存
  Future<bool> saveProductItemToD1(Map<String, dynamic> itemData) async {
    try {
      final response = await http.post(
        Uri.parse('$d1ApiUrl/api/products/items'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(itemData),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return jsonData['success'] == true;
      } else {
        throw Exception('D1への保存に失敗しました (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('D1 API通信エラー: $e');
    }
  }
  
  /// 📦 D1に商品マスタを一括登録 (CSV import用)
  Future<Map<String, dynamic>> bulkImportToD1(List<Map<String, dynamic>> products) async {
    try {
      final response = await http.post(
        Uri.parse('$d1ApiUrl/api/products/bulk-import'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'products': products}),
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
  Future<List<Map<String, dynamic>>> fetchProductsFromD1({int limit = 100, int offset = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$d1ApiUrl/api/products?limit=$limit&offset=$offset'),
        headers: {
          'Content-Type': 'application/json',
        },
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
  Future<Map<String, dynamic>?> searchProductInD1(String sku) async {
    try {
      final response = await http.get(
        Uri.parse('$d1ApiUrl/api/products/search?sku=$sku'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['success'] == true && jsonData['product'] != null) {
          return jsonData['product'];
        }
        return null;
      } else {
        throw Exception('D1商品検索に失敗しました (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('D1 API通信エラー: $e');
    }
  }
}
