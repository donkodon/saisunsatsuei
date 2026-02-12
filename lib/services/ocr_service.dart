import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// OCR文字認識サービス
/// 
/// Google Cloud Vision + Gemini 2.5 Flash による高精度OCR
class OcrService {
  // Cloudflare Workers API エンドポイント
  static const String _ocrApiUrl = 'https://measure-master-api.jinkedon2.workers.dev/api/ocr';
  
  /// タグ画像からテキスト情報を抽出
  /// 
  /// [imageBytes]: 撮影した画像のバイトデータ
  /// 
  /// 戻り値: OCR解析結果（ブランド、素材、原産国、サイズなど）
  Future<OcrResult> analyzeTag(Uint8List imageBytes) async {
    try {
      if (kDebugMode) {
        debugPrint('🔍 OCR解析開始: ${imageBytes.length} bytes');
      }
      
      // 画像をBase64エンコード
      final base64Image = base64Encode(imageBytes);
      
      // Cloudflare Workers に送信
      final response = await http.post(
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
        final data = jsonDecode(response.body);
        
        if (kDebugMode) {
          debugPrint('✅ OCR解析成功');
          debugPrint('   ブランド: ${data['brand']}');
          debugPrint('   素材: ${data['material']}');
          debugPrint('   原産国: ${data['country']}');
          debugPrint('   サイズ: ${data['size']}');
          debugPrint('   信頼度: ${data['confidence']}');
        }
        
        return OcrResult.fromJson(data);
      } else {
        throw Exception('OCR API エラー: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ OCR解析エラー: $e');
      }
      rethrow;
    }
  }
  
  /// OCR結果の品質チェック
  /// 
  /// 信頼度が低い場合は手動入力を促す
  bool shouldSuggestManualInput(OcrResult result) {
    return result.confidence < 0.5;
  }
}

/// OCR解析結果
class OcrResult {
  final String? brand;           // ブランド名
  final String? material;        // 素材（例: 綿100%）
  final String? country;         // 原産国
  final String? size;            // サイズ
  final double confidence;       // 信頼度 (0.0 - 1.0)
  final String? rawText;         // OCR生テキスト（デバッグ用）
  
  OcrResult({
    this.brand,
    this.material,
    this.country,
    this.size,
    required this.confidence,
    this.rawText,
  });
  
  factory OcrResult.fromJson(Map<String, dynamic> json) {
    return OcrResult(
      brand: json['brand'] as String?,
      material: json['material'] as String?,
      country: json['country'] as String?,
      size: json['size'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      rawText: json['raw_text'] as String?,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'brand': brand,
      'material': material,
      'country': country,
      'size': size,
      'confidence': confidence,
      'raw_text': rawText,
    };
  }
  
  /// 有効なデータが含まれているか
  bool get hasValidData {
    return brand != null || material != null || country != null || size != null;
  }
  
  /// デバッグ用の文字列表現
  @override
  String toString() {
    return 'OcrResult(brand: $brand, material: $material, country: $country, size: $size, confidence: $confidence)';
  }
}
