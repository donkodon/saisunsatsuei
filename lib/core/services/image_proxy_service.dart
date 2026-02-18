import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// 📸 画像プロキシサービス
/// Cloudflare R2の画像をCORS対応で取得するためのプロキシ
class ImageProxyService {
  // Workers APIエンドポイント
  static const String workerBaseUrl = 'https://image-upload-api.jinkedon2.workers.dev';
  
  /// R2直URLをWorkers経由URLに変換
  /// 
  /// R2直URL: https://pub-xxx.r2.dev/filename.jpg
  /// Workers経由URL: https://image-upload-api.xxx.workers.dev/image/filename.jpg
  static String convertToProxyUrl(String imageUrl) {
    // 既にプロキシURLの場合はそのまま返す
    if (imageUrl.contains('workers.dev') && !imageUrl.contains('.r2.dev')) {
      return imageUrl;
    }
    
    // R2直URLの場合は変換
    if (imageUrl.contains('pub-300562464768499b8fcaee903d0f9861.r2.dev')) {
      final fileName = imageUrl.split('/').last;
      final proxyUrl = '$workerBaseUrl/image/$fileName';
      return proxyUrl;
    }
    
    // その他のURLはそのまま返す
    return imageUrl;
  }
  
  /// 画像URLがR2直URLかどうかをチェック
  static bool isR2DirectUrl(String url) {
    return url.contains('.r2.dev');
  }
  
  /// プロキシ経由で画像バイトデータを取得
  /// CORSエラーを回避するため、Workers経由で画像を取得
  static Future<Uint8List?> fetchImageBytes(String imageUrl) async {
    try {
      final proxyUrl = convertToProxyUrl(imageUrl);
      
      
      final response = await http.get(
        Uri.parse(proxyUrl),
        headers: {
          'Accept': 'image/*',
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('画像取得タイムアウト');
        },
      );
      
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}
