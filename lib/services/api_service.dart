import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:measure_master/models/api_product.dart';

class ApiService {
  static const String baseUrl = 'https://3000-iuolnmmls4a53d2939w4c-3844e1b6.sandbox.novita.ai';
  
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
}
