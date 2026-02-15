// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'garment_measurement_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$GarmentMeasurementModelImpl _$$GarmentMeasurementModelImplFromJson(
        Map<String, dynamic> json) =>
    _$GarmentMeasurementModelImpl(
      id: json['id'] as String,
      sku: json['sku'] as String,
      companyId: json['companyId'] as String,
      measurements: GarmentMeasurements.fromJson(
          json['measurements'] as Map<String, dynamic>),
      measurementImageUrl: json['measurementImageUrl'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      status: $enumDecode(_$MeasurementStatusEnumMap, json['status']),
      errorMessage: json['errorMessage'] as String?,
    );

Map<String, dynamic> _$$GarmentMeasurementModelImplToJson(
        _$GarmentMeasurementModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sku': instance.sku,
      'companyId': instance.companyId,
      'measurements': instance.measurements,
      'measurementImageUrl': instance.measurementImageUrl,
      'timestamp': instance.timestamp.toIso8601String(),
      'status': _$MeasurementStatusEnumMap[instance.status]!,
      'errorMessage': instance.errorMessage,
    };

const _$MeasurementStatusEnumMap = {
  MeasurementStatus.processing: 'processing',
  MeasurementStatus.completed: 'completed',
  MeasurementStatus.failed: 'failed',
};

_$GarmentMeasurementsImpl _$$GarmentMeasurementsImplFromJson(
        Map<String, dynamic> json) =>
    _$GarmentMeasurementsImpl(
      shoulderWidth: (json['shoulderWidth'] as num).toDouble(),
      sleeveLength: (json['sleeveLength'] as num).toDouble(),
      bodyLength: (json['bodyLength'] as num).toDouble(),
      bodyWidth: (json['bodyWidth'] as num).toDouble(),
      unit: json['unit'] as String? ?? 'cm',
    );

Map<String, dynamic> _$$GarmentMeasurementsImplToJson(
        _$GarmentMeasurementsImpl instance) =>
    <String, dynamic>{
      'shoulderWidth': instance.shoulderWidth,
      'sleeveLength': instance.sleeveLength,
      'bodyLength': instance.bodyLength,
      'bodyWidth': instance.bodyWidth,
      'unit': instance.unit,
    };
