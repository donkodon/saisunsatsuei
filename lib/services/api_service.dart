import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:measure_master/models/api_product.dart';
import 'package:measure_master/config/api_config.dart';

class ApiService {
  // ✅ API設定を外部ファイルから読み込み
  static String get baseUrl => ApiConfig.baseUrl;
  static String get d1ApiUrl => ApiConfig.d1ApiUrl;
  
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
      // まずD1データベースから検索
      final d1Product = await searchProductInD1(query.trim());
      
      if (d1Product != null) {
        // D1から商品マスタが見つかった場合、ApiProduct形式に変換
        return ApiProduct(
          id: 0, // D1にはIDがないため0を設定
          sku: d1Product['sku'] ?? '',
          name: d1Product['name'] ?? '',
          brand: d1Product['brand'],
          category: d1Product['category'],
          size: d1Product['size'],
          color: d1Product['color'],
          priceSale: d1Product['price'],
          createdAt: DateTime.now(), // 現在時刻を設定
          imageUrls: null, // D1マスタにはimageUrlsがない
        );
      }
      
      // D1で見つからない場合、旧APIから検索（フォールバック）
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
  /// ⚠️ SKUが重複している場合は既存データを上書き（UPSERT）
  Future<bool> saveProductItemToD1(Map<String, dynamic> itemData) async {
    try {
      // 🔧 upsert: true フラグを追加して上書きモードを有効化
      final dataWithUpsert = Map<String, dynamic>.from(itemData);
      dataWithUpsert['upsert'] = true;  // 重複時は上書き
      
      // 🔍 デバッグ: 送信データをログ出力
      if (kDebugMode) {
        debugPrint('🌐 D1 API送信データ: ${jsonEncode(dataWithUpsert)}');
        
        // 🔍 imageUrls の詳細ログ
        if (dataWithUpsert.containsKey('imageUrls') && dataWithUpsert['imageUrls'] is List) {
          final imageUrls = dataWithUpsert['imageUrls'] as List;
          debugPrint('🖼️ D1送信: imageUrls配列の詳細（${imageUrls.length}件）');
          for (int i = 0; i < imageUrls.length; i++) {
            final url = imageUrls[i].toString();
            // URLからUUID部分を抽出（末尾8文字）
            final uuidPart = url.contains('_') 
                ? url.split('_').last.substring(0, 8) 
                : 'unknown';
            debugPrint('   配列[$i] (Sequence ${i + 1}): UUID=$uuidPart');
            debugPrint('       Full URL: $url');
          }
        }
      }
      
      final response = await http.post(
        Uri.parse('$d1ApiUrl/api/products/items'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(dataWithUpsert),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (kDebugMode) {
          debugPrint('✅ D1 API成功: ${response.body}');
        }
        return jsonData['success'] == true;
      } else if (response.statusCode == 409) {
        // 🔧 409 Conflict = 重複エラー → PUTで更新を試行
        final sku = itemData['sku'];
        if (sku != null && sku.toString().isNotEmpty) {
          return await updateProductItemInD1(sku.toString(), itemData);
        }
        throw Exception('SKUが空のため更新できません');
      } else {
        // 🔧 詳細なエラーメッセージを表示
        String errorBody = '';
        try {
          errorBody = response.body;
          if (kDebugMode) {
            debugPrint('❌ D1 APIエラー (${response.statusCode}): $errorBody');
          }
        } catch (_) {}
        throw Exception('D1への保存に失敗しました (${response.statusCode})\n応答: $errorBody');
      }
    } catch (e) {
      throw Exception('D1 API通信エラー: $e');
    }
  }
  
  /// 💾 D1の商品実物データを更新（SKUで特定）
  /// 
  /// 既存データを上書きする専用メソッド
  Future<bool> updateProductItemInD1(String sku, Map<String, dynamic> itemData) async {
    try {
      final response = await http.put(
        Uri.parse('$d1ApiUrl/api/products/items/$sku'),
        headers: {
          'Content-Type': 'application/json',
        },
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
  
  /// 🔍 統合検索: バーコードまたはSKUで検索
  /// 
  /// 検索順序:
  /// 1. product_items（実物データ）で検索 → 最新1件のみ
  /// 2. product_master（商品マスタ）で検索
  /// 
  /// 戻り値:
  /// {
  ///   'success': true,
  ///   'source': 'product_items' or 'product_master',
  ///   'data': {...}
  /// }
  Future<Map<String, dynamic>?> searchByBarcodeOrSku(String query) async {
    if (query.trim().isEmpty) {
      return null;
    }
    
    try {
      if (kDebugMode) {
        debugPrint('🔍 統合検索開始: $query');
      }
      
      final response = await http.get(
        Uri.parse('$d1ApiUrl/api/search?query=${Uri.encodeComponent(query.trim())}'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        debugPrint('📡 検索レスポンス (${response.statusCode}): ${response.body}');
      }

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['success'] == true) {
          if (kDebugMode) {
            debugPrint('✅ 検索成功: source=${jsonData['source']}');
          }
          return jsonData;
        }
      } else if (response.statusCode == 404) {
        if (kDebugMode) {
          debugPrint('⚠️ 商品が見つかりません: $query');
        }
        return null;
      }
      
      throw Exception('統合検索に失敗しました (${response.statusCode})');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 統合検索エラー: $e');
      }
      throw Exception('検索API通信エラー: $e');
    }
  }
}
