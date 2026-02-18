import 'package:flutter/foundation.dart' show debugPrint;
import 'package:hive_flutter/hive_flutter.dart';
import '../domain/garment_measurement_model.dart';

/// 採寸データの永続化（Hive使用）
///
/// ⚡ パフォーマンス改善: Hiveボックスをフィールドにキャッシュし、
/// メソッド呼び出しごとの openBox() を排除。
class MeasurementRepository {
  static const String _boxName = 'measurements';

  // ボックスをフィールドにキャッシュ（一度開いたら再利用）
  Box<Map>? _box;

  /// ボックスを取得（未オープンなら開く）
  Future<Box<Map>> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox<Map>(_boxName);
    return _box!;
  }

  /// 採寸リクエストを保存
  Future<void> saveMeasurement({
    required String sku,
    required String predictionId,
    required String companyId,
    required MeasurementStatus status,
  }) async {
    try {
      final box = await _getBox();
      await box.put(sku, {
        'prediction_id': predictionId,
        'sku': sku,
        'company_id': companyId,
        'status': status.name,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// 採寸結果を更新
  Future<void> updateMeasurement(GarmentMeasurementModel measurement) async {
    try {
      final box = await _getBox();
      await box.put(measurement.sku, measurement.toJson());
    } catch (e) {
      rethrow;
    }
  }

  /// SKUから採寸結果を取得
  Future<GarmentMeasurementModel?> getMeasurementBySku(String sku) async {
    try {
      final box = await _getBox();
      final data = box.get(sku);
      if (data == null) return null;

      final jsonData = Map<String, dynamic>.from(data);
      if (jsonData.containsKey('measurements')) {
        return GarmentMeasurementModel.fromJson(jsonData);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// prediction_idから採寸結果を取得
  Future<GarmentMeasurementModel?> getMeasurementByPredictionId(
    String predictionId,
  ) async {
    try {
      final box = await _getBox();
      for (final key in box.keys) {
        final data = box.get(key);
        if (data == null) continue;
        final jsonData = Map<String, dynamic>.from(data);
        if ((jsonData['prediction_id'] == predictionId ||
                jsonData['id'] == predictionId) &&
            jsonData.containsKey('measurements')) {
          return GarmentMeasurementModel.fromJson(jsonData);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 採寸エラーを記録
  Future<void> saveMeasurementError({
    required String sku,
    String? predictionId,
    required String error,
  }) async {
    try {
      final box = await _getBox();
      await box.put(sku, {
        'sku': sku,
        if (predictionId != null) 'prediction_id': predictionId,
        'status': MeasurementStatus.failed.name,
        'error': error,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// すべての採寸履歴を取得
  Future<List<GarmentMeasurementModel>> getAllMeasurements() async {
    try {
      final box = await _getBox();
      final measurements = <GarmentMeasurementModel>[];

      for (final key in box.keys) {
        final data = box.get(key);
        if (data == null) continue;
        try {
          final jsonData = Map<String, dynamic>.from(data);
          if (jsonData.containsKey('measurements')) {
            measurements.add(GarmentMeasurementModel.fromJson(jsonData));
          }
        } catch (e) {
          debugPrint('⚠️ 採寸データ変換失敗 (key: $key): $e');
        }
      }

      measurements.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return measurements;
    } catch (e) {
      return [];
    }
  }

  /// 採寸結果を削除
  Future<void> deleteMeasurement(String sku) async {
    try {
      final box = await _getBox();
      await box.delete(sku);
    } catch (e) {
      rethrow;
    }
  }

  /// すべての採寸データをクリア（デバッグ用）
  Future<void> clearAllMeasurements() async {
    try {
      final box = await _getBox();
      await box.clear();
    } catch (e) {
      rethrow;
    }
  }

  /// ボックスを明示的に閉じる（アプリ終了時など）
  Future<void> dispose() async {
    await _box?.close();
    _box = null;
  }
}
