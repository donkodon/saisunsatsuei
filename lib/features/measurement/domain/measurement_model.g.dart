// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'measurement_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MeasurementModelImpl _$$MeasurementModelImplFromJson(
        Map<String, dynamic> json) =>
    _$MeasurementModelImpl(
      id: json['id'] as String,
      widthCm: (json['widthCm'] as num).toDouble(),
      heightCm: (json['heightCm'] as num).toDouble(),
      depthCm: (json['depthCm'] as num).toDouble(),
      volumeM3: (json['volumeM3'] as num).toDouble(),
      volumetricWeightKg: (json['volumetricWeightKg'] as num).toDouble(),
      shippingClass: json['shippingClass'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      imageUrl: json['imageUrl'] as String?,
      sku: json['sku'] as String?,
    );

Map<String, dynamic> _$$MeasurementModelImplToJson(
        _$MeasurementModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'widthCm': instance.widthCm,
      'heightCm': instance.heightCm,
      'depthCm': instance.depthCm,
      'volumeM3': instance.volumeM3,
      'volumetricWeightKg': instance.volumetricWeightKg,
      'shippingClass': instance.shippingClass,
      'timestamp': instance.timestamp.toIso8601String(),
      'imageUrl': instance.imageUrl,
      'sku': instance.sku,
    };
