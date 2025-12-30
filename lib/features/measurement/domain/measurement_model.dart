import 'package:freezed_annotation/freezed_annotation.dart';

part 'measurement_model.freezed.dart';
part 'measurement_model.g.dart';

@freezed
class MeasurementModel with _$MeasurementModel {
  const factory MeasurementModel({
    required String id,
    required double widthCm,
    required double heightCm,
    required double depthCm,
    required double volumeM3,
    required double volumetricWeightKg, // e.g., (L*W*H)/5000
    required String shippingClass, // e.g., "60 Size", "80 Size"
    required DateTime timestamp,
    String? imageUrl,
    String? sku,
  }) = _MeasurementModel;

  factory MeasurementModel.fromJson(Map<String, dynamic> json) =>
      _$MeasurementModelFromJson(json);
}

// Logic for Volumetric Weight and Class
class CargoLogic {
  static const double volumetricDivisor = 5000.0; // Standard Divisor

  static double calculateVolumeM3(double w, double h, double d) {
    return (w * h * d) / 1000000.0;
  }

  static double calculateVolumetricWeight(double w, double h, double d) {
    return (w * h * d) / volumetricDivisor;
  }

  static String determineShippingClass(double w, double h, double d) {
    double totalDim = w + h + d;
    if (totalDim <= 60) return "60サイズ";
    if (totalDim <= 80) return "80サイズ";
    if (totalDim <= 100) return "100サイズ";
    if (totalDim <= 120) return "120サイズ";
    if (totalDim <= 140) return "140サイズ";
    if (totalDim <= 160) return "160サイズ";
    return "170サイズ以上 (大型)";
  }
}
