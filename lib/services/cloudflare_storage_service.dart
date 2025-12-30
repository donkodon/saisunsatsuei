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
  
  /// 📸 Workers経由で画像をアップロード
  /// [imageBytes] - 画像のバイトデータ
  /// [itemId] - 商品ID
  static Future<String> uploadImage(Uint8List imageBytes, String itemId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${itemId}_$timestamp.jpg';
      
      debugPrint('📤 Uploading to Cloudflare Workers: $uploadEndpoint');
      debugPrint('📦 File name: $fileName');
      debugPrint('📊 File size: ${imageBytes.length} bytes');
      
      // Multipartリクエストを作成
      final request = http.MultipartRequest('POST', Uri.parse(uploadEndpoint));
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
        debugPrint('✅ Workers経由でアップロード成功: $imageUrl');
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
