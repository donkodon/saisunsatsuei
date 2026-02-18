import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:measure_master/features/ocr/domain/ocr_result.dart';

/// OCR API クライアント
/// 
/// 責任:
/// - Cloudflare Workers OCR API との通信
/// - リクエスト/レスポンスの処理
/// - エラーハンドリング
class OcrApiClient {
  // Cloudflare Workers API エンドポイント
  static const String _ocrApiUrl = 'https://ocr-api.jinkedon2.workers.dev/api/ocr';
  
  final http.Client _httpClient;
  
  OcrApiClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();
  
  /// タグ画像からテキスト情報を抽出
  /// 
  /// [imageBytes]: 撮影した画像のバイトデータ
  /// 
  /// Returns: OCR解析結果（ブランド、素材、原産国、サイズなど）
  Future<OcrResult> analyzeImage(Uint8List imageBytes) async {
    try {
      
      // 画像をBase64エンコード
      final base64Image = base64Encode(imageBytes);
      
      // Cloudflare Workers に送信
      final response = await _httpClient.post(
        Uri.parse(_ocrApiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'image': base64Image,
          'options': {
            'extract_brand': true,
            'extract_material': true,
            'extract_country': true,
            'extract_size': true,
          }
        }),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        
        return OcrResult.fromJson(data);
      } else {
        throw OcrApiException(
          'OCR API エラー: ${response.statusCode}',
          statusCode: response.statusCode,
          responseBody: response.body,
        );
      }
    } on http.ClientException catch (e) {
      throw OcrApiException('ネットワークエラー: $e');
    } catch (e) {
      rethrow;
    }
  }
  
  /// リソースのクリーンアップ
  void dispose() {
    _httpClient.close();
  }
}

/// OCR API 例外
class OcrApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? responseBody;
  
  OcrApiException(
    this.message, {
    this.statusCode,
    this.responseBody,
  });
  
  @override
  String toString() {
    if (statusCode != null) {
      return 'OcrApiException: $message (HTTP $statusCode)';
    }
    return 'OcrApiException: $message';
  }
}
