import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Replicate API との通信を担当するクライアント
/// 
/// Cloudflare Workers経由でReplicate APIを呼び出し、
/// 衣類の自動採寸を実行します。
class MeasurementApiClient {
  /// Cloudflare Workers APIのベースURL
  final String d1ApiUrl;
  
  /// HTTPクライアント（テスト時にモック可能）
  final http.Client httpClient;

  MeasurementApiClient({
    required this.d1ApiUrl,
    http.Client? httpClient,
  }) : httpClient = httpClient ?? http.Client();

  /// Replicate APIで採寸を実行（非同期・バックグラウンド）
  /// 
  /// Cloudflare Workers の `/api/measure` エンドポイントを呼び出し、
  /// Replicate API経由で衣類の採寸を開始します。
  /// 
  /// **パラメータ:**
  /// - `imageUrl`: 採寸対象の画像URL（Cloudflare R2）
  /// - `sku`: 商品SKU（必須）
  /// - `companyId`: 企業ID（必須）
  /// - `garmentClass`: 衣類タイプ（'long sleeve top', 'jacket', 'pants'など）
  /// 
  /// **戻り値:**
  /// ```dart
  /// MeasurementApiResponse(
  ///   success: true,
  ///   predictionId: 'abc123',
  ///   status: 'processing',
  ///   message: 'AI採寸リクエストを受け付けました'
  /// )
  /// ```
  /// 
  /// **エラー:**
  /// - `MeasurementApiException`: API呼び出しに失敗した場合
  Future<MeasurementApiResponse> measureGarment({
    required String imageUrl,
    required String sku,
    required String companyId,
    required String garmentClass,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('📏 AI自動採寸開始');
        debugPrint('   画像URL: $imageUrl');
        debugPrint('   SKU: $sku');
        debugPrint('   企業ID: $companyId');
        debugPrint('   衣類タイプ: $garmentClass');
      }

      final requestBody = {
        'image_url': imageUrl,
        'sku': sku,
        'company_id': companyId,
        'garment_class': garmentClass,
      };

      if (kDebugMode) {
        debugPrint('📤 採寸APIリクエスト送信');
        debugPrint('   URL: $d1ApiUrl/api/measure');
        debugPrint('   Body: ${json.encode(requestBody)}');
      }

      final response = await httpClient
          .post(
            Uri.parse('$d1ApiUrl/api/measure'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        debugPrint('📡 採寸APIレスポンス (${response.statusCode})');
        debugPrint('   Body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;

        if (jsonData['success'] == true) {
          if (kDebugMode) {
            debugPrint('✅ 採寸リクエスト受付成功');
            debugPrint('   status: ${jsonData['status']}');
            debugPrint('   prediction_id: ${jsonData['prediction_id']}');
          }

          return MeasurementApiResponse(
            success: true,
            predictionId: jsonData['prediction_id'] as String,
            status: jsonData['status'] as String? ?? 'processing',
            message: jsonData['message'] as String? ?? 'AI採寸リクエストを受け付けました',
          );
        } else {
          throw MeasurementApiException(
            '採寸API失敗: ${jsonData['message'] ?? '不明なエラー'}',
            statusCode: response.statusCode,
          );
        }
      } else if (response.statusCode == 400) {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        if (kDebugMode) {
          debugPrint('❌ 採寸リクエストエラー (400)');
          debugPrint('   エラー: ${errorData['message'] ?? '不明なエラー'}');
        }
        throw MeasurementApiException(
          '不正なリクエスト: ${errorData['message'] ?? '不明なエラー'}',
          statusCode: response.statusCode,
        );
      } else {
        throw MeasurementApiException(
          'HTTPエラー: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on http.ClientException catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ネットワークエラー: $e');
      }
      throw MeasurementApiException('ネットワークエラー: $e');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 採寸API呼び出しエラー: $e');
      }
      rethrow;
    }
  }



  /// リソースのクリーンアップ
  void dispose() {
    httpClient.close();
  }
}

/// 採寸API呼び出しのレスポンス
class MeasurementApiResponse {
  /// リクエスト成功フラグ
  final bool success;

  /// Replicate prediction ID
  final String predictionId;

  /// 採寸状態（'processing', 'completed', 'failed'）
  final String status;

  /// メッセージ
  final String message;

  MeasurementApiResponse({
    required this.success,
    required this.predictionId,
    required this.status,
    required this.message,
  });
}

/// 採寸API例外クラス
class MeasurementApiException implements Exception {
  /// エラーメッセージ
  final String message;

  /// HTTPステータスコード（ある場合）
  final int? statusCode;

  MeasurementApiException(this.message, {this.statusCode});

  @override
  String toString() {
    if (statusCode != null) {
      return 'MeasurementApiException($statusCode): $message';
    }
    return 'MeasurementApiException: $message';
  }
}
