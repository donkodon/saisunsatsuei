import 'dart:io';
import 'dart:convert';
import 'dart:typed_data'; // Uint8List用
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

/// 📦 Cloudflare R2 ストレージサービス
/// 無料で画像を保存・共有できる（10GB/月の無料枠）
class CloudflareStorageService {
  // 🔧 設定値（実際の値に置き換えてください）
  static const String accountId = 'YOUR_ACCOUNT_ID';
  static const String bucketName = 'product-images';
  static const String apiToken = 'YOUR_API_TOKEN';
  static const String publicDomain = 'pub-300562464768499b8fcaee903d0f9861.r2.dev'; // R2公開ドメイン
  
  /// 📸 画像をCloudflare R2にアップロード
  /// 
  /// [imageFile] - アップロードする画像ファイル
  /// [itemId] - 商品ID（一意な識別子）
  /// 
  /// Returns: 画像の公開URL
  static Future<String> uploadImage(File imageFile, String itemId) async {
    try {
      // ファイル名を生成
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${itemId}_$timestamp.jpg';
      
      // 画像データを読み込み
      final imageBytes = await imageFile.readAsBytes();
      
      // R2 API エンドポイント
      final url = Uri.parse(
        'https://api.cloudflare.com/client/v4/accounts/$accountId/r2/buckets/$bucketName/objects/$fileName'
      );
      
      // アップロード
      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $apiToken',
          'Content-Type': 'image/jpeg',
        },
        body: imageBytes,
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        // 成功: 公開URLを返す
        final imageUrl = 'https://$publicDomain/$fileName';
        debugPrint('✅ Cloudflare R2にアップロード成功: $imageUrl');
        return imageUrl;
      } else {
        debugPrint('❌ アップロード失敗: ${response.statusCode} ${response.body}');
        throw Exception('アップロードに失敗しました: ${response.statusCode}');
      }
      
    } catch (e) {
      debugPrint('❌ Cloudflare R2アップロードエラー: $e');
      rethrow;
    }
  }
  
  /// 🗑️ 画像を削除
  static Future<void> deleteImage(String fileName) async {
    try {
      final url = Uri.parse(
        'https://api.cloudflare.com/client/v4/accounts/$accountId/r2/buckets/$bucketName/objects/$fileName'
      );
      
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $apiToken',
        },
      );
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        debugPrint('✅ 画像を削除しました: $fileName');
      } else {
        debugPrint('❌ 削除失敗: ${response.statusCode}');
      }
      
    } catch (e) {
      debugPrint('❌ 画像削除エラー: $e');
    }
  }
  
  /// 🔍 設定が正しいか確認
  static bool isConfigured() {
    return accountId != 'YOUR_ACCOUNT_ID' &&
           apiToken != 'YOUR_API_TOKEN' &&
           publicDomain != 'YOUR_R2_PUBLIC_DOMAIN';
  }
}

/// 📦 簡易版: Cloudflare Workers経由でアップロード
/// Workers経由なら、APIトークンを公開せずに安全にアップロード可能
class CloudflareWorkersStorageService {
  // Workers APIエンドポイント（スクリーンショットの設定から）
  static const String workerBaseUrl = 'https://image-upload-api.jinkedon2.workers.dev';
  static const String uploadEndpoint = '$workerBaseUrl/upload';  // ✅ /upload パスを追加
  static const String checkEndpoint = '$workerBaseUrl/check';    // 🔍 ファイル存在チェック用
  
  /// 🔍 ファイルが既に存在するかチェック
  /// [fileName] - チェックするファイル名（例: "SKU_1.jpg"）
  /// Returns: true = 存在する, false = 存在しない
  static Future<bool> checkFileExists(String fileName) async {
    try {
      final checkUrl = Uri.parse('$checkEndpoint?filename=$fileName');
      
      final response = await http.get(checkUrl).timeout(
        Duration(seconds: 10),
        onTimeout: () => http.Response('timeout', 408),
      );
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return jsonResponse['exists'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('⚠️ ファイル存在チェックエラー: $e');
      return false;  // エラー時は存在しないと見なす
    }
  }
  
  /// 🔢 SKUに対して使用可能な次の連番を取得
  /// [sku] - SKUコード
  /// [startFrom] - 検索開始の連番（デフォルト: 1）
  /// Returns: 使用可能な連番
  static Future<int> getNextAvailableCounter(String sku, {int startFrom = 1}) async {
    int counter = startFrom;
    const maxAttempts = 100;  // 無限ループ防止
    
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final fileName = '${sku}_$counter.jpg';
      final exists = await checkFileExists(fileName);
      
      if (!exists) {
        debugPrint('✅ 使用可能な連番: $counter (ファイル名: $fileName)');
        return counter;
      }
      
      debugPrint('⚠️ 連番 $counter は既に使用中、次をチェック...');
      counter++;
    }
    
    // 最大試行回数を超えた場合はタイムスタンプベースに
    debugPrint('⚠️ 連番が見つからないため、タイムスタンプを使用');
    return DateTime.now().millisecondsSinceEpoch;
  }
  
  /// 🗑️ Workers経由で画像を削除
  /// [imageUrl] - 削除する画像のURL
  /// Returns: true = 削除成功, false = 削除失敗
  static Future<bool> deleteImage(String imageUrl) async {
    try {
      // URLからファイル名を抽出
      final uri = Uri.tryParse(imageUrl);
      if (uri == null || uri.pathSegments.isEmpty) {
        debugPrint('⚠️ 無効なURL: $imageUrl');
        return false;
      }
      
      final fileName = uri.pathSegments.last;
      
      // Workers削除エンドポイント
      final deleteUrl = Uri.parse('$workerBaseUrl/delete?filename=$fileName');
      
      debugPrint('🗑️ Cloudflare削除リクエスト: $deleteUrl');
      debugPrint('📁 削除するファイル: $fileName');
      
      final response = await http.delete(deleteUrl).timeout(
        Duration(seconds: 15),
        onTimeout: () => http.Response('timeout', 408),
      );
      
      debugPrint('📨 削除レスポンス: ${response.statusCode}');
      debugPrint('📨 レスポンス内容: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        debugPrint('✅ 画像削除成功: $fileName');
        return true;
      } else {
        debugPrint('⚠️ 画像削除失敗: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Cloudflare画像削除エラー: $e');
      return false;
    }
  }

  /// 📸 Workers経由で画像をアップロード（SKUフォルダ対応）
  /// [imageBytes] - 画像のバイトデータ
  /// [itemId] - ファイル名（SKU_連番形式: 例 "1025L190003_1"）
  /// [sku] - SKUコード（フォルダ名として使用: 例 "1025L190003"）
  static Future<String> uploadImage(Uint8List imageBytes, String itemId, {String? sku}) async {
    try {
      // ファイル名形式: {SKU}_{連番}.jpg
      final fileName = '$itemId.jpg';
      
      // 🆕 SKU情報を取得（itemIdから抽出 or 引数から取得）
      String skuFolder = sku ?? itemId.split('_')[0];  // デフォルト: itemIdの最初の部分をSKUとして使用
      
      debugPrint('📤 Uploading to Cloudflare Workers: $uploadEndpoint');
      debugPrint('📁 SKU Folder: $skuFolder');
      debugPrint('📦 File name: $fileName');
      debugPrint('📊 File size: ${imageBytes.length} bytes');
      
      // Multipartリクエストを作成
      final request = http.MultipartRequest('POST', Uri.parse(uploadEndpoint));
      
      // 🆕 SKU情報をフォームデータに追加
      request.fields['sku'] = skuFolder;
      request.fields['fileName'] = fileName;
      
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: fileName,
        ),
      );
      
      // タイムアウトを設定（30秒）
      final streamedResponse = await request.send().timeout(
        Duration(seconds: 30),
        onTimeout: () {
          throw Exception('アップロードがタイムアウトしました（30秒）');
        },
      );
      
      final response = await http.Response.fromStream(streamedResponse);
      
      debugPrint('📨 Response status: ${response.statusCode}');
      debugPrint('📨 Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final imageUrl = jsonResponse['url'] as String;
        debugPrint('✅ Workers経由でアップロード成功（SKUフォルダ: $skuFolder）: $imageUrl');
        return imageUrl;
      } else {
        throw Exception('アップロードに失敗しました: ${response.statusCode} - ${response.body}');
      }
      
    } catch (e) {
      debugPrint('❌ Workersアップロードエラー: $e');
      rethrow;
    }
  }
}
