// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'garment_measurement_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

GarmentMeasurementModel _$GarmentMeasurementModelFromJson(
    Map<String, dynamic> json) {
  return _GarmentMeasurementModel.fromJson(json);
}

/// @nodoc
mixin _$GarmentMeasurementModel {
  /// 採寸ID（Replicate prediction_id）
  String get id => throw _privateConstructorUsedError;

  /// 商品SKU
  String get sku => throw _privateConstructorUsedError;

  /// 企業ID
  String get companyId => throw _privateConstructorUsedError;

  /// 採寸結果（肩幅、袖丈、着丈、身幅）
  GarmentMeasurements get measurements => throw _privateConstructorUsedError;

  /// Replicate出力画像URL（採寸線が描画された画像）
  String? get measurementImageUrl => throw _privateConstructorUsedError;

  /// 採寸日時
  DateTime get timestamp => throw _privateConstructorUsedError;

  /// 採寸状態（processing/completed/failed）
  MeasurementStatus get status => throw _privateConstructorUsedError;

  /// エラーメッセージ（status=failedの場合）
  String? get errorMessage => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $GarmentMeasurementModelCopyWith<GarmentMeasurementModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GarmentMeasurementModelCopyWith<$Res> {
  factory $GarmentMeasurementModelCopyWith(GarmentMeasurementModel value,
          $Res Function(GarmentMeasurementModel) then) =
      _$GarmentMeasurementModelCopyWithImpl<$Res, GarmentMeasurementModel>;
  @useResult
  $Res call(
      {String id,
      String sku,
      String companyId,
      GarmentMeasurements measurements,
      String? measurementImageUrl,
      DateTime timestamp,
      MeasurementStatus status,
      String? errorMessage});

  $GarmentMeasurementsCopyWith<$Res> get measurements;
}

/// @nodoc
class _$GarmentMeasurementModelCopyWithImpl<$Res,
        $Val extends GarmentMeasurementModel>
    implements $GarmentMeasurementModelCopyWith<$Res> {
  _$GarmentMeasurementModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? sku = null,
    Object? companyId = null,
    Object? measurements = null,
    Object? measurementImageUrl = freezed,
    Object? timestamp = null,
    Object? status = null,
    Object? errorMessage = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      sku: null == sku
          ? _value.sku
          : sku // ignore: cast_nullable_to_non_nullable
              as String,
      companyId: null == companyId
          ? _value.companyId
          : companyId // ignore: cast_nullable_to_non_nullable
              as String,
      measurements: null == measurements
          ? _value.measurements
          : measurements // ignore: cast_nullable_to_non_nullable
              as GarmentMeasurements,
      measurementImageUrl: freezed == measurementImageUrl
          ? _value.measurementImageUrl
          : measurementImageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as MeasurementStatus,
      errorMessage: freezed == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $GarmentMeasurementsCopyWith<$Res> get measurements {
    return $GarmentMeasurementsCopyWith<$Res>(_value.measurements, (value) {
      return _then(_value.copyWith(measurements: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$GarmentMeasurementModelImplCopyWith<$Res>
    implements $GarmentMeasurementModelCopyWith<$Res> {
  factory _$$GarmentMeasurementModelImplCopyWith(
          _$GarmentMeasurementModelImpl value,
          $Res Function(_$GarmentMeasurementModelImpl) then) =
      __$$GarmentMeasurementModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String sku,
      String companyId,
      GarmentMeasurements measurements,
      String? measurementImageUrl,
      DateTime timestamp,
      MeasurementStatus status,
      String? errorMessage});

  @override
  $GarmentMeasurementsCopyWith<$Res> get measurements;
}

/// @nodoc
class __$$GarmentMeasurementModelImplCopyWithImpl<$Res>
    extends _$GarmentMeasurementModelCopyWithImpl<$Res,
        _$GarmentMeasurementModelImpl>
    implements _$$GarmentMeasurementModelImplCopyWith<$Res> {
  __$$GarmentMeasurementModelImplCopyWithImpl(
      _$GarmentMeasurementModelImpl _value,
      $Res Function(_$GarmentMeasurementModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? sku = null,
    Object? companyId = null,
    Object? measurements = null,
    Object? measurementImageUrl = freezed,
    Object? timestamp = null,
    Object? status = null,
    Object? errorMessage = freezed,
  }) {
    return _then(_$GarmentMeasurementModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      sku: null == sku
          ? _value.sku
          : sku // ignore: cast_nullable_to_non_nullable
              as String,
      companyId: null == companyId
          ? _value.companyId
          : companyId // ignore: cast_nullable_to_non_nullable
              as String,
      measurements: null == measurements
          ? _value.measurements
          : measurements // ignore: cast_nullable_to_non_nullable
              as GarmentMeasurements,
      measurementImageUrl: freezed == measurementImageUrl
          ? _value.measurementImageUrl
          : measurementImageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as MeasurementStatus,
      errorMessage: freezed == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$GarmentMeasurementModelImpl implements _GarmentMeasurementModel {
  const _$GarmentMeasurementModelImpl(
      {required this.id,
      required this.sku,
      required this.companyId,
      required this.measurements,
      this.measurementImageUrl,
      required this.timestamp,
      required this.status,
      this.errorMessage});

  factory _$GarmentMeasurementModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$GarmentMeasurementModelImplFromJson(json);

  /// 採寸ID（Replicate prediction_id）
  @override
  final String id;

  /// 商品SKU
  @override
  final String sku;

  /// 企業ID
  @override
  final String companyId;

  /// 採寸結果（肩幅、袖丈、着丈、身幅）
  @override
  final GarmentMeasurements measurements;

  /// Replicate出力画像URL（採寸線が描画された画像）
  @override
  final String? measurementImageUrl;

  /// 採寸日時
  @override
  final DateTime timestamp;

  /// 採寸状態（processing/completed/failed）
  @override
  final MeasurementStatus status;

  /// エラーメッセージ（status=failedの場合）
  @override
  final String? errorMessage;

  @override
  String toString() {
    return 'GarmentMeasurementModel(id: $id, sku: $sku, companyId: $companyId, measurements: $measurements, measurementImageUrl: $measurementImageUrl, timestamp: $timestamp, status: $status, errorMessage: $errorMessage)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GarmentMeasurementModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.sku, sku) || other.sku == sku) &&
            (identical(other.companyId, companyId) ||
                other.companyId == companyId) &&
            (identical(other.measurements, measurements) ||
                other.measurements == measurements) &&
            (identical(other.measurementImageUrl, measurementImageUrl) ||
                other.measurementImageUrl == measurementImageUrl) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, sku, companyId, measurements,
      measurementImageUrl, timestamp, status, errorMessage);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$GarmentMeasurementModelImplCopyWith<_$GarmentMeasurementModelImpl>
      get copyWith => __$$GarmentMeasurementModelImplCopyWithImpl<
          _$GarmentMeasurementModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$GarmentMeasurementModelImplToJson(
      this,
    );
  }
}

abstract class _GarmentMeasurementModel implements GarmentMeasurementModel {
  const factory _GarmentMeasurementModel(
      {required final String id,
      required final String sku,
      required final String companyId,
      required final GarmentMeasurements measurements,
      final String? measurementImageUrl,
      required final DateTime timestamp,
      required final MeasurementStatus status,
      final String? errorMessage}) = _$GarmentMeasurementModelImpl;

  factory _GarmentMeasurementModel.fromJson(Map<String, dynamic> json) =
      _$GarmentMeasurementModelImpl.fromJson;

  @override

  /// 採寸ID（Replicate prediction_id）
  String get id;
  @override

  /// 商品SKU
  String get sku;
  @override

  /// 企業ID
  String get companyId;
  @override

  /// 採寸結果（肩幅、袖丈、着丈、身幅）
  GarmentMeasurements get measurements;
  @override

  /// Replicate出力画像URL（採寸線が描画された画像）
  String? get measurementImageUrl;
  @override

  /// 採寸日時
  DateTime get timestamp;
  @override

  /// 採寸状態（processing/completed/failed）
  MeasurementStatus get status;
  @override

  /// エラーメッセージ（status=failedの場合）
  String? get errorMessage;
  @override
  @JsonKey(ignore: true)
  _$$GarmentMeasurementModelImplCopyWith<_$GarmentMeasurementModelImpl>
      get copyWith => throw _privateConstructorUsedError;
}

GarmentMeasurements _$GarmentMeasurementsFromJson(Map<String, dynamic> json) {
  return _GarmentMeasurements.fromJson(json);
}

/// @nodoc
mixin _$GarmentMeasurements {
  /// 肩幅（cm）
  double get shoulderWidth => throw _privateConstructorUsedError;

  /// 袖丈（cm）
  double get sleeveLength => throw _privateConstructorUsedError;

  /// 着丈（cm）
  double get bodyLength => throw _privateConstructorUsedError;

  /// 身幅（cm）
  double get bodyWidth => throw _privateConstructorUsedError;

  /// 単位（デフォルト: cm）
  String get unit => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $GarmentMeasurementsCopyWith<GarmentMeasurements> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GarmentMeasurementsCopyWith<$Res> {
  factory $GarmentMeasurementsCopyWith(
          GarmentMeasurements value, $Res Function(GarmentMeasurements) then) =
      _$GarmentMeasurementsCopyWithImpl<$Res, GarmentMeasurements>;
  @useResult
  $Res call(
      {double shoulderWidth,
      double sleeveLength,
      double bodyLength,
      double bodyWidth,
      String unit});
}

/// @nodoc
class _$GarmentMeasurementsCopyWithImpl<$Res, $Val extends GarmentMeasurements>
    implements $GarmentMeasurementsCopyWith<$Res> {
  _$GarmentMeasurementsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? shoulderWidth = null,
    Object? sleeveLength = null,
    Object? bodyLength = null,
    Object? bodyWidth = null,
    Object? unit = null,
  }) {
    return _then(_value.copyWith(
      shoulderWidth: null == shoulderWidth
          ? _value.shoulderWidth
          : shoulderWidth // ignore: cast_nullable_to_non_nullable
              as double,
      sleeveLength: null == sleeveLength
          ? _value.sleeveLength
          : sleeveLength // ignore: cast_nullable_to_non_nullable
              as double,
      bodyLength: null == bodyLength
          ? _value.bodyLength
          : bodyLength // ignore: cast_nullable_to_non_nullable
              as double,
      bodyWidth: null == bodyWidth
          ? _value.bodyWidth
          : bodyWidth // ignore: cast_nullable_to_non_nullable
              as double,
      unit: null == unit
          ? _value.unit
          : unit // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$GarmentMeasurementsImplCopyWith<$Res>
    implements $GarmentMeasurementsCopyWith<$Res> {
  factory _$$GarmentMeasurementsImplCopyWith(_$GarmentMeasurementsImpl value,
          $Res Function(_$GarmentMeasurementsImpl) then) =
      __$$GarmentMeasurementsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {double shoulderWidth,
      double sleeveLength,
      double bodyLength,
      double bodyWidth,
      String unit});
}

/// @nodoc
class __$$GarmentMeasurementsImplCopyWithImpl<$Res>
    extends _$GarmentMeasurementsCopyWithImpl<$Res, _$GarmentMeasurementsImpl>
    implements _$$GarmentMeasurementsImplCopyWith<$Res> {
  __$$GarmentMeasurementsImplCopyWithImpl(_$GarmentMeasurementsImpl _value,
      $Res Function(_$GarmentMeasurementsImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? shoulderWidth = null,
    Object? sleeveLength = null,
    Object? bodyLength = null,
    Object? bodyWidth = null,
    Object? unit = null,
  }) {
    return _then(_$GarmentMeasurementsImpl(
      shoulderWidth: null == shoulderWidth
          ? _value.shoulderWidth
          : shoulderWidth // ignore: cast_nullable_to_non_nullable
              as double,
      sleeveLength: null == sleeveLength
          ? _value.sleeveLength
          : sleeveLength // ignore: cast_nullable_to_non_nullable
              as double,
      bodyLength: null == bodyLength
          ? _value.bodyLength
          : bodyLength // ignore: cast_nullable_to_non_nullable
              as double,
      bodyWidth: null == bodyWidth
          ? _value.bodyWidth
          : bodyWidth // ignore: cast_nullable_to_non_nullable
              as double,
      unit: null == unit
          ? _value.unit
          : unit // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$GarmentMeasurementsImpl implements _GarmentMeasurements {
  const _$GarmentMeasurementsImpl(
      {required this.shoulderWidth,
      required this.sleeveLength,
      required this.bodyLength,
      required this.bodyWidth,
      this.unit = 'cm'});

  factory _$GarmentMeasurementsImpl.fromJson(Map<String, dynamic> json) =>
      _$$GarmentMeasurementsImplFromJson(json);

  /// 肩幅（cm）
  @override
  final double shoulderWidth;

  /// 袖丈（cm）
  @override
  final double sleeveLength;

  /// 着丈（cm）
  @override
  final double bodyLength;

  /// 身幅（cm）
  @override
  final double bodyWidth;

  /// 単位（デフォルト: cm）
  @override
  @JsonKey()
  final String unit;

  @override
  String toString() {
    return 'GarmentMeasurements(shoulderWidth: $shoulderWidth, sleeveLength: $sleeveLength, bodyLength: $bodyLength, bodyWidth: $bodyWidth, unit: $unit)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GarmentMeasurementsImpl &&
            (identical(other.shoulderWidth, shoulderWidth) ||
                other.shoulderWidth == shoulderWidth) &&
            (identical(other.sleeveLength, sleeveLength) ||
                other.sleeveLength == sleeveLength) &&
            (identical(other.bodyLength, bodyLength) ||
                other.bodyLength == bodyLength) &&
            (identical(other.bodyWidth, bodyWidth) ||
                other.bodyWidth == bodyWidth) &&
            (identical(other.unit, unit) || other.unit == unit));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType, shoulderWidth, sleeveLength, bodyLength, bodyWidth, unit);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$GarmentMeasurementsImplCopyWith<_$GarmentMeasurementsImpl> get copyWith =>
      __$$GarmentMeasurementsImplCopyWithImpl<_$GarmentMeasurementsImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$GarmentMeasurementsImplToJson(
      this,
    );
  }
}

abstract class _GarmentMeasurements implements GarmentMeasurements {
  const factory _GarmentMeasurements(
      {required final double shoulderWidth,
      required final double sleeveLength,
      required final double bodyLength,
      required final double bodyWidth,
      final String unit}) = _$GarmentMeasurementsImpl;

  factory _GarmentMeasurements.fromJson(Map<String, dynamic> json) =
      _$GarmentMeasurementsImpl.fromJson;

  @override

  /// 肩幅（cm）
  double get shoulderWidth;
  @override

  /// 袖丈（cm）
  double get sleeveLength;
  @override

  /// 着丈（cm）
  double get bodyLength;
  @override

  /// 身幅（cm）
  double get bodyWidth;
  @override

  /// 単位（デフォルト: cm）
  String get unit;
  @override
  @JsonKey(ignore: true)
  _$$GarmentMeasurementsImplCopyWith<_$GarmentMeasurementsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
