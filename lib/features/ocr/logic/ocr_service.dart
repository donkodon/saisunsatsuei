import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:measure_master/features/ocr/domain/ocr_result.dart';
import 'package:measure_master/features/ocr/data/ocr_api_client.dart';

/// OCR文字認識サービス
/// 
/// 責任:
/// - タグ画像のOCR処理フロー制御
/// - OCR結果の品質チェック
/// - ビジネスロジックの実装
/// 
/// Google Cloud Vision + Gemini 2.5 Flash による高精度OCR
class OcrService {
  final OcrApiClient _apiClient;
  
  OcrService({OcrApiClient? apiClient})
      : _apiClient = apiClient ?? OcrApiClient();
  
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
      
      // API Client を使用してOCR実行
      final result = await _apiClient.analyzeImage(imageBytes);
      
      if (kDebugMode) {
        debugPrint('✅ OCR解析完了');
        debugPrint('   ブランド: ${result.brand}');
        debugPrint('   素材: ${result.material}');
        debugPrint('   原産国: ${result.country}');
        debugPrint('   サイズ: ${result.size}');
        debugPrint('   信頼度: ${result.confidence}');
      }
      
      return result;
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
