import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../domain/garment_measurement_model.dart';

/// 採寸データの永続化（Hive使用）
/// 
/// 採寸履歴の保存、採寸結果のキャッシュ、
/// オフライン時の採寸結果確認をサポートします。
class MeasurementRepository {
  /// Hiveボックス名
  static const String _boxName = 'measurements';

  /// 採寸リクエストを保存
  /// 
  /// Replicate APIに採寸リクエストを送信した直後に呼び出され、
  /// prediction_idと初期状態（processing）を保存します。
  /// 
  /// **パラメータ:**
  /// - `sku`: 商品SKU
  /// - `predictionId`: Replicate prediction ID
  /// - `companyId`: 企業ID
  /// - `status`: 初期状態（通常は processing）
  Future<void> saveMeasurement({
    required String sku,
    required String predictionId,
    required String companyId,
    required MeasurementStatus status,
  }) async {
    try {
      final box = await Hive.openBox<Map>(_boxName);

      final data = {
        'prediction_id': predictionId,
        'sku': sku,
        'company_id': companyId,
        'status': status.name,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await box.put(sku, data);

      if (kDebugMode) {
      }
    } catch (e) {
      if (kDebugMode) {
      }
      rethrow;
    }
  }

  /// 採寸結果を更新
  /// 
  /// Replicate APIから採寸結果を取得した後に呼び出され、
  /// 完全な採寸データを保存します。
  /// 
  /// **パラメータ:**
  /// - `measurement`: 採寸結果（GarmentMeasurementModel）
  Future<void> updateMeasurement(GarmentMeasurementModel measurement) async {
    try {
      final box = await Hive.openBox<Map>(_boxName);

      // GarmentMeasurementModelをJSON化して保存
      final data = measurement.toJson();

      await box.put(measurement.sku, data);

      if (kDebugMode) {
      }
    } catch (e) {
      if (kDebugMode) {
      }
      rethrow;
    }
  }

  /// SKUから採寸結果を取得
  /// 
  /// ローカルに保存された採寸結果を取得します。
  /// オフライン時でも過去の採寸結果を確認できます。
  /// 
  /// **パラメータ:**
  /// - `sku`: 商品SKU
  /// 
  /// **戻り値:**
  /// - 採寸結果が存在する場合: `GarmentMeasurementModel`
  /// - 存在しない場合: `null`
  Future<GarmentMeasurementModel?> getMeasurementBySku(String sku) async {
    try {
      final box = await Hive.openBox<Map>(_boxName);

      final data = box.get(sku);
      if (data == null) {
        if (kDebugMode) {
        }
        return null;
      }

      // Map<dynamic, dynamic> を Map<String, dynamic> に変換
      final jsonData = Map<String, dynamic>.from(data);

      // statusフィールドがあるかチェック（完全な採寸結果かどうか）
      if (jsonData.containsKey('measurements')) {
        // 完全な採寸結果
        final measurement = GarmentMeasurementModel.fromJson(jsonData);

        if (kDebugMode) {
        }

        return measurement;
      } else {
        // まだ採寸リクエストの初期状態のみ
        if (kDebugMode) {
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
      }
      return null;
    }
  }

  /// prediction_idから採寸結果を取得
  /// 
  /// **パラメータ:**
  /// - `predictionId`: Replicate prediction ID
  /// 
  /// **戻り値:**
  /// - 採寸結果が存在する場合: `GarmentMeasurementModel`
  /// - 存在しない場合: `null`
  Future<GarmentMeasurementModel?> getMeasurementByPredictionId(
    String predictionId,
  ) async {
    try {
      final box = await Hive.openBox<Map>(_boxName);

      // 全データを検索
      for (final key in box.keys) {
        final data = box.get(key);
        if (data != null) {
          final jsonData = Map<String, dynamic>.from(data);
          if (jsonData['prediction_id'] == predictionId ||
              jsonData['id'] == predictionId) {
            if (jsonData.containsKey('measurements')) {
              return GarmentMeasurementModel.fromJson(jsonData);
            }
          }
        }
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
      }
      return null;
    }
  }

  /// 採寸エラーを記録
  /// 
  /// Replicate APIでエラーが発生した場合、
  /// エラー情報を保存します。
  /// 
  /// **パラメータ:**
  /// - `sku`: 商品SKU
  /// - `predictionId`: Replicate prediction ID（ある場合）
  /// - `error`: エラーメッセージ
  Future<void> saveMeasurementError({
    required String sku,
    String? predictionId,
    required String error,
  }) async {
    try {
      final box = await Hive.openBox<Map>(_boxName);

      final data = {
        'sku': sku,
        if (predictionId != null) 'prediction_id': predictionId,
        'status': MeasurementStatus.failed.name,
        'error': error,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await box.put(sku, data);

      if (kDebugMode) {
      }
    } catch (e) {
      if (kDebugMode) {
      }
      rethrow;
    }
  }

  /// すべての採寸履歴を取得
  /// 
  /// ローカルに保存されているすべての採寸結果を取得します。
  /// 
  /// **戻り値:**
  /// - 採寸結果のリスト（新しい順）
  Future<List<GarmentMeasurementModel>> getAllMeasurements() async {
    try {
      final box = await Hive.openBox<Map>(_boxName);

      final measurements = <GarmentMeasurementModel>[];

      for (final key in box.keys) {
        final data = box.get(key);
        if (data != null) {
          try {
            final jsonData = Map<String, dynamic>.from(data);
            if (jsonData.containsKey('measurements')) {
              final measurement = GarmentMeasurementModel.fromJson(jsonData);
              measurements.add(measurement);
            }
          } catch (e) {
            if (kDebugMode) {
            }
          }
        }
      }

      // 日時でソート（新しい順）
      measurements.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (kDebugMode) {
      }

      return measurements;
    } catch (e) {
      if (kDebugMode) {
      }
      return [];
    }
  }

  /// 採寸結果を削除
  /// 
  /// **パラメータ:**
  /// - `sku`: 商品SKU
  Future<void> deleteMeasurement(String sku) async {
    try {
      final box = await Hive.openBox<Map>(_boxName);

      await box.delete(sku);

      if (kDebugMode) {
      }
    } catch (e) {
      if (kDebugMode) {
      }
      rethrow;
    }
  }

  /// すべての採寸データをクリア
  /// 
  /// デバッグ用。すべての採寸履歴を削除します。
  Future<void> clearAllMeasurements() async {
    try {
      final box = await Hive.openBox<Map>(_boxName);

      await box.clear();

      if (kDebugMode) {
      }
    } catch (e) {
      if (kDebugMode) {
      }
      rethrow;
    }
  }
}
