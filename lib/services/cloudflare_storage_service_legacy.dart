import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// ⚠️ 非推奨: Cloudflare R2 直接アクセスサービス
///
/// CORS問題があるため本番では使用不可。
/// 現行の実装は CloudflareWorkersStorageService (cloudflare_storage_service.dart) を使用すること。
///
/// このファイルはレガシーコードの保管場所として残しているが、
/// 新規コードからは参照しないこと。
@Deprecated('Use CloudflareWorkersStorageService instead for CORS compatibility')
class CloudflareStorageService {
  static const String accountId = 'YOUR_ACCOUNT_ID';
  static const String bucketName = 'product-images';
  static const String apiToken = 'YOUR_API_TOKEN';
  static const String publicDomain =
      'pub-300562464768499b8fcaee903d0f9861.r2.dev';

  /// 📸 画像をCloudflare R2に直接アップロード（CORS問題あり）
  @Deprecated('Use CloudflareWorkersStorageService.uploadImage() instead')
  static Future<String> uploadImage(File imageFile, String itemId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${itemId}_$timestamp.jpg';
      final imageBytes = await imageFile.readAsBytes();

      final url = Uri.parse(
        'https://api.cloudflare.com/client/v4/accounts/$accountId'
        '/r2/buckets/$bucketName/objects/$fileName',
      );

      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $apiToken',
          'Content-Type': 'image/jpeg',
        },
        body: imageBytes,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final imageUrl = 'https://$publicDomain/$fileName';
        debugPrint('✅ Cloudflare R2にアップロード成功: $imageUrl');
        return imageUrl;
      } else {
        throw Exception('アップロードに失敗しました: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Cloudflare R2アップロードエラー: $e');
      rethrow;
    }
  }

  /// 🗑️ 画像を削除（CORS問題あり）
  @Deprecated('Use CloudflareWorkersStorageService.deleteImage() instead')
  static Future<void> deleteImage(String fileName) async {
    try {
      final url = Uri.parse(
        'https://api.cloudflare.com/client/v4/accounts/$accountId'
        '/r2/buckets/$bucketName/objects/$fileName',
      );

      final response = await http.delete(
        url,
        headers: {'Authorization': 'Bearer $apiToken'},
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

  static bool isConfigured() {
    return accountId != 'YOUR_ACCOUNT_ID' &&
        apiToken != 'YOUR_API_TOKEN' &&
        publicDomain != 'YOUR_R2_PUBLIC_DOMAIN';
  }
}
