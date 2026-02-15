import 'package:flutter/foundation.dart';
import '../data/measurement_api_client.dart';
import '../data/measurement_repository.dart';
import '../domain/garment_measurement_model.dart';
import '../domain/garment_class_mapper.dart';

/// 採寸のビジネスロジックを管理
/// 
/// DetailScreenから呼び出され、Fire & Forget方式で
/// バックグラウンドで採寸を実行します。
class MeasurementService {
  final MeasurementApiClient _apiClient;
  final MeasurementRepository _repository;

  MeasurementService({
    required MeasurementApiClient apiClient,
    required MeasurementRepository repository,
  })  : _apiClient = apiClient,
        _repository = repository;

  /// AI自動採寸を実行（Fire & Forget方式）
  /// 
  /// DetailScreenの保存処理後にバックグラウンドで実行されます。
  /// 採寸完了を待たずに即座にreturnし、ユーザー体験を損ないません。
  /// 
  /// **処理フロー:**
  /// 1. カテゴリ → 衣類タイプ変換
  /// 2. Replicate API呼び出し（Cloudflare Workers経由）
  /// 3. prediction_idをローカルDBに保存
  /// 4. 完了
  /// 
  /// **採寸結果の取得:**
  /// - Replicate → Webhook → D1の`product_items`テーブルに自動保存
  /// - 商品詳細表示時に `GET /api/items?sku=` で測定結果を取得
  /// - `measurement_status`が`completed`なら測定値が利用可能
  /// 
  /// **パラメータ:**
  /// - `imageUrl`: 採寸対象の画像URL（Cloudflare R2）
  /// - `sku`: 商品SKU
  /// - `companyId`: 企業ID
  /// - `category`: 商品カテゴリ（日本語）
  /// 
  /// **エラーハンドリング:**
  /// - エラーが発生してもスローせず、ログに記録のみ
  /// - エラー情報はローカルDBに保存
  Future<void> measureGarmentAsync({
    required String imageUrl,
    required String sku,
    required String companyId,
    required String category,
  }) async {
    try {
      // 1) カテゴリ→衣類タイプ変換
      final garmentClass = GarmentClassMapper.categoryToGarmentClass(category);

      if (kDebugMode) {
        debugPrint('📏 AI採寸リクエスト送信（バックグラウンド）');
        debugPrint('   画像URL: $imageUrl');
        debugPrint('   SKU: $sku');
        debugPrint('   企業ID: $companyId');
        debugPrint('   カテゴリ: $category');
        debugPrint('   衣類タイプ: $garmentClass');
      }

      // 2) Replicate API呼び出し
      final response = await _apiClient.measureGarment(
        imageUrl: imageUrl,
        sku: sku,
        companyId: companyId,
        garmentClass: garmentClass,
      );

      if (kDebugMode) {
        debugPrint('📏 AI採寸レスポンス: prediction_id=${response.predictionId}');
      }

      // 3) prediction_idをローカルDBに保存
      await _repository.saveMeasurement(
        sku: sku,
        predictionId: response.predictionId,
        companyId: companyId,
        status: MeasurementStatus.processing,
      );

      if (kDebugMode) {
        debugPrint('✅ AI採寸リクエスト完了（Fire & Forget）');
        debugPrint('   結果はWebhook経由でD1に自動保存されます');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('⚠️ AI採寸エラー: $e');
        debugPrint('スタックトレース: $stackTrace');
      }

      // エラーをローカルDBに記録
      try {
        await _repository.saveMeasurementError(
          sku: sku,
          error: e.toString(),
        );
      } catch (saveError) {
        if (kDebugMode) {
          debugPrint('❌ エラー記録失敗: $saveError');
        }
      }
    }
  }



  /// SKUから採寸結果を取得
  /// 
  /// ローカルDBに保存された採寸結果を取得します。
  /// DetailScreenで過去の採寸結果を表示する際に使用します。
  /// 
  /// **パラメータ:**
  /// - `sku`: 商品SKU
  /// 
  /// **戻り値:**
  /// - 採寸結果が存在する場合: `GarmentMeasurementModel`
  /// - 存在しない場合: `null`
  Future<GarmentMeasurementModel?> getMeasurement(String sku) async {
    return await _repository.getMeasurementBySku(sku);
  }



  /// すべての採寸履歴を取得
  /// 
  /// 採寸履歴画面で使用します。
  /// 
  /// **戻り値:**
  /// - 採寸結果のリスト（新しい順）
  Future<List<GarmentMeasurementModel>> getAllMeasurements() async {
    return await _repository.getAllMeasurements();
  }

  /// 採寸結果を削除
  /// 
  /// **パラメータ:**
  /// - `sku`: 商品SKU
  Future<void> deleteMeasurement(String sku) async {
    return await _repository.deleteMeasurement(sku);
  }

  /// リソースのクリーンアップ
  void dispose() {
    _apiClient.dispose();
  }
}
