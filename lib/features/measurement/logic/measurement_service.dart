import 'package:flutter/foundation.dart';
import '../data/measurement_api_client.dart';
import '../data/measurement_repository.dart';
import '../domain/garment_measurement_model.dart';
import '../domain/garment_class_mapper.dart';

/// 採寸のビジネスロジックを管理
/// 
/// DetailScreenから呼び出され、Fire & Forget方式で
/// バックグラウンドで採寸を実行します。
/// 結果はWorkers側でD1に直接保存されるため、
/// Flutter側での結果保存は行いません。
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
  /// Workers に POST /api/measure を送信するだけ。
  /// Workersが即座に prediction_id を返し、
  /// バックグラウンドで Replicate ポーリング → D1保存 を行う。
  /// Flutter側は結果を待たない。
  /// 
  /// **処理フロー:**
  /// 1. カテゴリ → 衣類タイプ変換
  /// 2. Workers に採寸リクエスト送信（即レスポンス）
  /// 3. prediction_id をローカルDBに記録（参照用）
  /// 4. Workers側で Replicate ポーリング → D1保存（バックグラウンド）
  Future<void> measureGarmentAsync({
    required String imageUrl,
    required String sku,
    required String companyId,
    required String category,
  }) async {
    try {
      // 🔥 強制出力ログ（必ず表示される）
      
      if (kDebugMode) {
      }
      
      // 1) カテゴリ→衣類タイプ変換
      final garmentClass = GarmentClassMapper.categoryToGarmentClass(category);

      if (kDebugMode) {
      }

      // 2) Workers に送信（即座に prediction_id が返る）
      final response = await _apiClient.measureGarment(
        imageUrl: imageUrl,
        sku: sku,
        companyId: companyId,
        garmentClass: garmentClass,
      );

      if (kDebugMode) {
      }

      // 3) prediction_id をローカルDBに記録（参照用）
      await _repository.saveMeasurement(
        sku: sku,
        predictionId: response.predictionId,
        companyId: companyId,
        status: MeasurementStatus.processing,
      );

      // 🔥 強制出力ログ（必ず表示される）
      
      if (kDebugMode) {
      }
    } catch (e) {
      // 🔥 強制出力ログ（必ず表示される）
      
      if (kDebugMode) {
      }

      // エラーをローカルDBに記録
      try {
        await _repository.saveMeasurementError(
          sku: sku,
          error: e.toString(),
        );
        if (kDebugMode) {
        }
      } catch (saveError) {
        if (kDebugMode) {
        }
      }
      
      rethrow;
    }
  }

  /// SKUから採寸結果を取得（ローカルDB）
  Future<GarmentMeasurementModel?> getMeasurement(String sku) async {
    return await _repository.getMeasurementBySku(sku);
  }

  /// すべての採寸履歴を取得
  Future<List<GarmentMeasurementModel>> getAllMeasurements() async {
    return await _repository.getAllMeasurements();
  }

  /// 採寸結果を削除
  Future<void> deleteMeasurement(String sku) async {
    return await _repository.deleteMeasurement(sku);
  }

  /// リソースのクリーンアップ
  void dispose() {
    _apiClient.dispose();
  }
}
