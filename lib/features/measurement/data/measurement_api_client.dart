import 'dart:convert';
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

      final requestBody = {
        'image_url': imageUrl,
        'sku': sku,
        'company_id': companyId,
        'garment_class': garmentClass,
      };


      final response = await httpClient
          .post(
            Uri.parse('$d1ApiUrl/api/measure'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 10)); // Workers即レスポンス（prediction作成のみ）


      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;

        if (jsonData['success'] == true) {

          // 採寸結果を抽出（同期ポーリング方式の場合、結果が即座に返る）
          final measurementsData = jsonData['measurements'] as Map<String, dynamic>?;

          
          return MeasurementApiResponse(
            success: true,
            predictionId: jsonData['prediction_id'] as String? ?? '',
            status: jsonData['status'] as String? ?? 'processing',
            message: jsonData['message'] as String? ?? 'AI採寸リクエストを受け付けました',
            // 採寸結果フィールド
            measurements: measurementsData,
            measurementImageUrl: jsonData['measurement_image_url'] as String?,
            maskImageUrl: jsonData['mask_image_url'] as String?,
            aiLandmarks: jsonData['ai_landmarks'] is String
                ? jsonData['ai_landmarks'] as String
                : jsonData['ai_landmarks'] != null
                    ? json.encode(jsonData['ai_landmarks'])
                    : null,
            referenceObject: jsonData['reference_object'] is String
                ? jsonData['reference_object'] as String
                : jsonData['reference_object'] != null
                    ? json.encode(jsonData['reference_object'])
                    : null,
          );
        } else {
          throw MeasurementApiException(
            '採寸API失敗: ${jsonData['message'] ?? '不明なエラー'}',
            statusCode: response.statusCode,
          );
        }
      } else if (response.statusCode == 400) {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
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
      throw MeasurementApiException('ネットワークエラー: $e');
    } catch (e) {
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

  /// 採寸結果（shoulder_width, sleeve_length, body_length, body_width）
  final Map<String, dynamic>? measurements;

  /// 採寸結果の可視化画像URL
  final String? measurementImageUrl;

  /// マスク画像URL（セグメンテーション結果）
  final String? maskImageUrl;

  /// AIランドマーク座標（JSON文字列）
  final String? aiLandmarks;

  /// 基準物体情報（JSON文字列）
  final String? referenceObject;

  MeasurementApiResponse({
    required this.success,
    required this.predictionId,
    required this.status,
    required this.message,
    this.measurements,
    this.measurementImageUrl,
    this.maskImageUrl,
    this.aiLandmarks,
    this.referenceObject,
  });

  /// 採寸が完了しているか
  bool get isCompleted => status == 'completed' && measurements != null;
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
