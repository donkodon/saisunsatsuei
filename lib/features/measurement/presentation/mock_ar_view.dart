import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/measurement_model.dart';
import 'package:measure_master/core/utils/app_feedback.dart';

// State for the current measurement session
final measurementStateProvider = StateNotifierProvider<MeasurementNotifier, MeasurementModel>((ref) {
  return MeasurementNotifier();
});

class MeasurementNotifier extends StateNotifier<MeasurementModel> {
  MeasurementNotifier()
      : super(MeasurementModel(
          id: '',
          widthCm: 30.0,
          heightCm: 20.0,
          depthCm: 40.0,
          volumeM3: 0.024,
          volumetricWeightKg: 4.8,
          shippingClass: '100サイズ',
          timestamp: DateTime.now(),
        ));

  void updateDimensions(double w, double h, double d) {
    final vol = CargoLogic.calculateVolumeM3(w, h, d);
    final weight = CargoLogic.calculateVolumetricWeight(w, h, d);
    final sClass = CargoLogic.determineShippingClass(w, h, d);

    state = state.copyWith(
      widthCm: w,
      heightCm: h,
      depthCm: d,
      volumeM3: vol,
      volumetricWeightKg: weight,
      shippingClass: sClass,
      timestamp: DateTime.now(),
    );
  }
}

class MockARView extends ConsumerStatefulWidget {
  const MockARView({super.key});

  @override
  ConsumerState<MockARView> createState() => _MockARViewState();
}

class _MockARViewState extends ConsumerState<MockARView> {
  // Simulating AR Bounding Box with sliders/gestures
  double _width = 30.0;
  double _height = 20.0;
  double _depth = 40.0;
  bool _isReferenceMode = false; // Toggle for "Standard Mode" vs "Pro Mode"

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Camera Feed Simulation (Background)
        Positioned.fill(
          child: Container(
            color: Colors.black87,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const Icon(Icons.camera_alt, color: Colors.white24, size: 64),
                   const SizedBox(height: 16),
                   Text(
                     "AR Camera Simulation",
                     style: TextStyle(color: Colors.white54, fontSize: 16),
                   ),
                   if (_isReferenceMode)
                     Padding(
                       padding: const EdgeInsets.only(top: 20.0),
                       child: Container(
                         width: 200,
                         height: 120,
                         decoration: BoxDecoration(
                           border: Border.all(color: Colors.yellow, width: 2),
                           color: Colors.yellow.withValues(alpha: 0.1),
                         ),
                         child: Center(child: Text("Reference Object\n(A4 Paper / Card)", textAlign: TextAlign.center, style: TextStyle(color: Colors.yellow))),
                       ),
                     )
                ],
              ),
            ),
          ),
        ),

        // 2. AR Bounding Box Overlay (Interactive)
        Center(
          child: Container(
            width: _width * 5, // Simple visual scaling
            height: _height * 5,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blueAccent, width: 3),
              color: Colors.blueAccent.withValues(alpha: 0.1),
            ),
            child: Stack(
              children: [
                // Dimensions Labels
                Positioned(top: -25, left: 0, right: 0, child: Center(child: _DimensionChip(label: "W: ${_width.toStringAsFixed(1)} cm"))),
                Positioned(left: -60, top: 0, bottom: 0, child: Center(child: _DimensionChip(label: "H: ${_height.toStringAsFixed(1)} cm"))),
                Positioned(bottom: -25, right: 0, child: _DimensionChip(label: "D: ${_depth.toStringAsFixed(1)} cm")),
              ],
            ),
          ),
        ),

        // 3. Controls
        Positioned(
          bottom: 180,
          left: 20,
          right: 20,
          child: Column(
            children: [
              _ControlSlider(label: "幅 (Width)", value: _width, min: 5, max: 100, onChanged: (v) => setState(() { _width = v; _updateModel(); })),
              _ControlSlider(label: "高さ (Height)", value: _height, min: 5, max: 100, onChanged: (v) => setState(() { _height = v; _updateModel(); })),
              _ControlSlider(label: "奥行 (Depth)", value: _depth, min: 5, max: 100, onChanged: (v) => setState(() { _depth = v; _updateModel(); })),
            ],
          ),
        ),

        // 4. Mode Toggle (Top Right)
        Positioned(
          top: 50,
          right: 20,
          child: FloatingActionButton.small(
            backgroundColor: _isReferenceMode ? Colors.yellow : Colors.white,
            foregroundColor: Colors.black,
            child: const Icon(Icons.aspect_ratio),
            onPressed: () {
              setState(() {
                _isReferenceMode = !_isReferenceMode;
              });
              AppFeedback.showInfo(
                context,
                _isReferenceMode ? "基準物モード: ON (通常スマホ用)" : "LiDARモード: ON (Pro用)",
                duration: const Duration(seconds: 1),
              );
            },
          ),
        ),
      ],
    );
  }

  void _updateModel() {
    ref.read(measurementStateProvider.notifier).updateDimensions(_width, _height, _depth);
  }
}

class _DimensionChip extends StatelessWidget {
  final String label;
  const _DimensionChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }
}

class _ControlSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _ControlSlider({required this.label, required this.value, required this.min, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12))),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              activeColor: Colors.blueAccent,
              inactiveColor: Colors.white24,
              onChanged: onChanged,
            ),
          ),
          SizedBox(width: 40, child: Text("${value.toInt()}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}
