// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'measurement_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

MeasurementModel _$MeasurementModelFromJson(Map<String, dynamic> json) {
  return _MeasurementModel.fromJson(json);
}

/// @nodoc
mixin _$MeasurementModel {
  String get id => throw _privateConstructorUsedError;
  double get widthCm => throw _privateConstructorUsedError;
  double get heightCm => throw _privateConstructorUsedError;
  double get depthCm => throw _privateConstructorUsedError;
  double get volumeM3 => throw _privateConstructorUsedError;
  double get volumetricWeightKg =>
      throw _privateConstructorUsedError; // e.g., (L*W*H)/5000
  String get shippingClass =>
      throw _privateConstructorUsedError; // e.g., "60 Size", "80 Size"
  DateTime get timestamp => throw _privateConstructorUsedError;
  String? get imageUrl => throw _privateConstructorUsedError;
  String? get sku => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $MeasurementModelCopyWith<MeasurementModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MeasurementModelCopyWith<$Res> {
  factory $MeasurementModelCopyWith(
          MeasurementModel value, $Res Function(MeasurementModel) then) =
      _$MeasurementModelCopyWithImpl<$Res, MeasurementModel>;
  @useResult
  $Res call(
      {String id,
      double widthCm,
      double heightCm,
      double depthCm,
      double volumeM3,
      double volumetricWeightKg,
      String shippingClass,
      DateTime timestamp,
      String? imageUrl,
      String? sku});
}

/// @nodoc
class _$MeasurementModelCopyWithImpl<$Res, $Val extends MeasurementModel>
    implements $MeasurementModelCopyWith<$Res> {
  _$MeasurementModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? widthCm = null,
    Object? heightCm = null,
    Object? depthCm = null,
    Object? volumeM3 = null,
    Object? volumetricWeightKg = null,
    Object? shippingClass = null,
    Object? timestamp = null,
    Object? imageUrl = freezed,
    Object? sku = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      widthCm: null == widthCm
          ? _value.widthCm
          : widthCm // ignore: cast_nullable_to_non_nullable
              as double,
      heightCm: null == heightCm
          ? _value.heightCm
          : heightCm // ignore: cast_nullable_to_non_nullable
              as double,
      depthCm: null == depthCm
          ? _value.depthCm
          : depthCm // ignore: cast_nullable_to_non_nullable
              as double,
      volumeM3: null == volumeM3
          ? _value.volumeM3
          : volumeM3 // ignore: cast_nullable_to_non_nullable
              as double,
      volumetricWeightKg: null == volumetricWeightKg
          ? _value.volumetricWeightKg
          : volumetricWeightKg // ignore: cast_nullable_to_non_nullable
              as double,
      shippingClass: null == shippingClass
          ? _value.shippingClass
          : shippingClass // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      imageUrl: freezed == imageUrl
          ? _value.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      sku: freezed == sku
          ? _value.sku
          : sku // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MeasurementModelImplCopyWith<$Res>
    implements $MeasurementModelCopyWith<$Res> {
  factory _$$MeasurementModelImplCopyWith(_$MeasurementModelImpl value,
          $Res Function(_$MeasurementModelImpl) then) =
      __$$MeasurementModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      double widthCm,
      double heightCm,
      double depthCm,
      double volumeM3,
      double volumetricWeightKg,
      String shippingClass,
      DateTime timestamp,
      String? imageUrl,
      String? sku});
}

/// @nodoc
class __$$MeasurementModelImplCopyWithImpl<$Res>
    extends _$MeasurementModelCopyWithImpl<$Res, _$MeasurementModelImpl>
    implements _$$MeasurementModelImplCopyWith<$Res> {
  __$$MeasurementModelImplCopyWithImpl(_$MeasurementModelImpl _value,
      $Res Function(_$MeasurementModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? widthCm = null,
    Object? heightCm = null,
    Object? depthCm = null,
    Object? volumeM3 = null,
    Object? volumetricWeightKg = null,
    Object? shippingClass = null,
    Object? timestamp = null,
    Object? imageUrl = freezed,
    Object? sku = freezed,
  }) {
    return _then(_$MeasurementModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      widthCm: null == widthCm
          ? _value.widthCm
          : widthCm // ignore: cast_nullable_to_non_nullable
              as double,
      heightCm: null == heightCm
          ? _value.heightCm
          : heightCm // ignore: cast_nullable_to_non_nullable
              as double,
      depthCm: null == depthCm
          ? _value.depthCm
          : depthCm // ignore: cast_nullable_to_non_nullable
              as double,
      volumeM3: null == volumeM3
          ? _value.volumeM3
          : volumeM3 // ignore: cast_nullable_to_non_nullable
              as double,
      volumetricWeightKg: null == volumetricWeightKg
          ? _value.volumetricWeightKg
          : volumetricWeightKg // ignore: cast_nullable_to_non_nullable
              as double,
      shippingClass: null == shippingClass
          ? _value.shippingClass
          : shippingClass // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      imageUrl: freezed == imageUrl
          ? _value.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      sku: freezed == sku
          ? _value.sku
          : sku // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MeasurementModelImpl implements _MeasurementModel {
  const _$MeasurementModelImpl(
      {required this.id,
      required this.widthCm,
      required this.heightCm,
      required this.depthCm,
      required this.volumeM3,
      required this.volumetricWeightKg,
      required this.shippingClass,
      required this.timestamp,
      this.imageUrl,
      this.sku});

  factory _$MeasurementModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$MeasurementModelImplFromJson(json);

  @override
  final String id;
  @override
  final double widthCm;
  @override
  final double heightCm;
  @override
  final double depthCm;
  @override
  final double volumeM3;
  @override
  final double volumetricWeightKg;
// e.g., (L*W*H)/5000
  @override
  final String shippingClass;
// e.g., "60 Size", "80 Size"
  @override
  final DateTime timestamp;
  @override
  final String? imageUrl;
  @override
  final String? sku;

  @override
  String toString() {
    return 'MeasurementModel(id: $id, widthCm: $widthCm, heightCm: $heightCm, depthCm: $depthCm, volumeM3: $volumeM3, volumetricWeightKg: $volumetricWeightKg, shippingClass: $shippingClass, timestamp: $timestamp, imageUrl: $imageUrl, sku: $sku)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MeasurementModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.widthCm, widthCm) || other.widthCm == widthCm) &&
            (identical(other.heightCm, heightCm) ||
                other.heightCm == heightCm) &&
            (identical(other.depthCm, depthCm) || other.depthCm == depthCm) &&
            (identical(other.volumeM3, volumeM3) ||
                other.volumeM3 == volumeM3) &&
            (identical(other.volumetricWeightKg, volumetricWeightKg) ||
                other.volumetricWeightKg == volumetricWeightKg) &&
            (identical(other.shippingClass, shippingClass) ||
                other.shippingClass == shippingClass) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.sku, sku) || other.sku == sku));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, widthCm, heightCm, depthCm,
      volumeM3, volumetricWeightKg, shippingClass, timestamp, imageUrl, sku);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$MeasurementModelImplCopyWith<_$MeasurementModelImpl> get copyWith =>
      __$$MeasurementModelImplCopyWithImpl<_$MeasurementModelImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MeasurementModelImplToJson(
      this,
    );
  }
}

abstract class _MeasurementModel implements MeasurementModel {
  const factory _MeasurementModel(
      {required final String id,
      required final double widthCm,
      required final double heightCm,
      required final double depthCm,
      required final double volumeM3,
      required final double volumetricWeightKg,
      required final String shippingClass,
      required final DateTime timestamp,
      final String? imageUrl,
      final String? sku}) = _$MeasurementModelImpl;

  factory _MeasurementModel.fromJson(Map<String, dynamic> json) =
      _$MeasurementModelImpl.fromJson;

  @override
  String get id;
  @override
  double get widthCm;
  @override
  double get heightCm;
  @override
  double get depthCm;
  @override
  double get volumeM3;
  @override
  double get volumetricWeightKg;
  @override // e.g., (L*W*H)/5000
  String get shippingClass;
  @override // e.g., "60 Size", "80 Size"
  DateTime get timestamp;
  @override
  String? get imageUrl;
  @override
  String? get sku;
  @override
  @JsonKey(ignore: true)
  _$$MeasurementModelImplCopyWith<_$MeasurementModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
