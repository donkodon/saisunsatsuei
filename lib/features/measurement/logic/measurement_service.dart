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
      print('');
      print('🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥');
      print('🤖 MeasurementService 実行開始');
      print('🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥');
      print('📥 パラメータ:');
      print('   imageUrl: $imageUrl');
      print('   sku: $sku');
      print('   companyId: $companyId');
      print('   category: $category');
      print('🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥');
      print('');
      
      if (kDebugMode) {
        debugPrint('🔍 ========== MeasurementService デバッグ ==========');
        debugPrint('📥 受信パラメータ:');
        debugPrint('   imageUrl: $imageUrl');
        debugPrint('   sku: $sku');
        debugPrint('   companyId: $companyId');
        debugPrint('   category: $category');
      }
      
      // 1) カテゴリ→衣類タイプ変換
      final garmentClass = GarmentClassMapper.categoryToGarmentClass(category);

      if (kDebugMode) {
        debugPrint('🔄 カテゴリ変換結果:');
        debugPrint('   $category → $garmentClass');
        debugPrint('📏 AI採寸リクエスト送信開始...');
      }

      // 2) Workers に送信（即座に prediction_id が返る）
      final response = await _apiClient.measureGarment(
        imageUrl: imageUrl,
        sku: sku,
        companyId: companyId,
        garmentClass: garmentClass,
      );

      if (kDebugMode) {
        debugPrint('📡 Workers レスポンス受信:');
        debugPrint('   success: ${response.success}');
        debugPrint('   prediction_id: ${response.predictionId}');
        debugPrint('   status: ${response.status}');
        debugPrint('   message: ${response.message}');
      }

      // 3) prediction_id をローカルDBに記録（参照用）
      await _repository.saveMeasurement(
        sku: sku,
        predictionId: response.predictionId,
        companyId: companyId,
        status: MeasurementStatus.processing,
      );

      // 🔥 強制出力ログ（必ず表示される）
      print('');
      print('🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥');
      print('✅ AI採寸リクエスト送信成功！');
      print('🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥');
      print('📡 prediction_id: ${response.predictionId}');
      print('💾 ローカルDB記録完了');
      print('⏳ Webhook経由でD1に以下が保存されます:');
      print('   - measurements (肩幅/袖丈/着丈/身幅)');
      print('   - ai_landmarks (ランドマーク座標)');
      print('   - reference_object (基準物体情報)');
      print('   - measurement_image_url (採寸画像)');
      print('   - mask_image_url (マスク画像)');
      print('🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥');
      print('');
      
      if (kDebugMode) {
        debugPrint('✅ AI採寸リクエスト完了: prediction_id=${response.predictionId}');
        debugPrint('💾 ローカルDBに記録完了');
        debugPrint('⏳ Webhook経由でD1に結果が保存されます:');
        debugPrint('   - product_items.measurements (肩幅/袖丈/着丈/身幅)');
        debugPrint('   - product_items.ai_landmarks (ランドマーク座標)');
        debugPrint('   - product_items.reference_object (基準物体情報)');
        debugPrint('   - product_items.measurement_image_url (採寸画像)');
        debugPrint('   - product_items.mask_image_url (マスク画像)');
        debugPrint('==========================================');
      }
    } catch (e, stackTrace) {
      // 🔥 強制出力ログ（必ず表示される）
      print('');
      print('❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌');
      print('❌ AI採寸エラー発生！');
      print('❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌');
      print('エラー: $e');
      print('スタックトレース: ${stackTrace.toString().split('\n').take(3).join('\n')}');
      print('❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌');
      print('');
      
      if (kDebugMode) {
        debugPrint('❌ AI採寸エラー発生: $e');
        debugPrint('📍 エラー発生箇所: ${stackTrace.toString().split('\n').take(3).join('\n')}');
        debugPrint('==========================================');
      }

      // エラーをローカルDBに記録
      try {
        await _repository.saveMeasurementError(
          sku: sku,
          error: e.toString(),
        );
        if (kDebugMode) {
          debugPrint('💾 エラーをローカルDBに記録しました');
        }
      } catch (saveError) {
        if (kDebugMode) {
          debugPrint('❌ エラー記録失敗: $saveError');
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
