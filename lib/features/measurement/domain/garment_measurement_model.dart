import 'package:freezed_annotation/freezed_annotation.dart';

part 'garment_measurement_model.freezed.dart';
part 'garment_measurement_model.g.dart';

/// 衣類採寸結果のデータモデル
/// 
/// Replicate API経由で取得した採寸データを保持します。
/// Freezedで不変性を保証し、JSON変換をサポートします。
@freezed
class GarmentMeasurementModel with _$GarmentMeasurementModel {
  const factory GarmentMeasurementModel({
    /// 採寸ID（Replicate prediction_id）
    required String id,
    
    /// 商品SKU
    required String sku,
    
    /// 企業ID
    required String companyId,
    
    /// 採寸結果（肩幅、袖丈、着丈、身幅）
    required GarmentMeasurements measurements,
    
    /// Replicate出力画像URL（採寸線が描画された画像）
    String? measurementImageUrl,
    
    /// 採寸日時
    required DateTime timestamp,
    
    /// 採寸状態（processing/completed/failed）
    required MeasurementStatus status,
    
    /// エラーメッセージ（status=failedの場合）
    String? errorMessage,
  }) = _GarmentMeasurementModel;

  factory GarmentMeasurementModel.fromJson(Map<String, dynamic> json) =>
      _$GarmentMeasurementModelFromJson(json);
}

/// 衣類の採寸値
/// 
/// すべての値はcm単位で保持されます。
@freezed
class GarmentMeasurements with _$GarmentMeasurements {
  const factory GarmentMeasurements({
    /// 肩幅（cm）
    required double shoulderWidth,
    
    /// 袖丈（cm）
    required double sleeveLength,
    
    /// 着丈（cm）
    required double bodyLength,
    
    /// 身幅（cm）
    required double bodyWidth,
    
    /// 単位（デフォルト: cm）
    @Default('cm') String unit,
  }) = _GarmentMeasurements;

  factory GarmentMeasurements.fromJson(Map<String, dynamic> json) =>
      _$GarmentMeasurementsFromJson(json);
}

/// 採寸処理の状態
enum MeasurementStatus {
  /// 処理中（Replicate APIで処理中）
  processing,
  
  /// 完了（採寸結果が取得済み）
  completed,
  
  /// 失敗（エラーが発生）
  failed,
}

/// MeasurementStatus の拡張メソッド
extension MeasurementStatusExtension on MeasurementStatus {
  /// 状態を日本語で表示
  String get displayName {
    switch (this) {
      case MeasurementStatus.processing:
        return '処理中';
      case MeasurementStatus.completed:
        return '完了';
      case MeasurementStatus.failed:
        return '失敗';
    }
  }
  
  /// 状態がcompletedかどうか
  bool get isCompleted => this == MeasurementStatus.completed;
  
  /// 状態がprocessingかどうか
  bool get isProcessing => this == MeasurementStatus.processing;
  
  /// 状態がfailedかどうか
  bool get isFailed => this == MeasurementStatus.failed;
}
