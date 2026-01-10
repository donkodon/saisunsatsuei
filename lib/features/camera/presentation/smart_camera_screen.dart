import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../measurement/presentation/mock_ar_view.dart';

// State for Camera Mode
enum CameraMode { photo, measure }

final cameraModeProvider = StateProvider<CameraMode>((ref) => CameraMode.photo);

class SmartCameraScreen extends ConsumerWidget {
  const SmartCameraScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(cameraModeProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera Viewfinder (Common to both, but AR view adds overlays)
          // In a real app, this is CameraPreview(controller).
          // Here, we simulate the switching.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: mode == CameraMode.measure
                ? const MockARView(key: ValueKey('AR'))
                : const _StandardCameraView(key: ValueKey('Standard')),
          ),

          // 2. Camera Controls (Shutter, Mode Switcher)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(bottom: 30, top: 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mode Selector (iOS Style)
                  Container(
                    height: 40,
                    margin: const EdgeInsets.only(bottom: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ModeButton(
                          title: "標準撮影",
                          isSelected: mode == CameraMode.photo,
                          onTap: () => ref.read(cameraModeProvider.notifier).state = CameraMode.photo,
                        ),
                        const SizedBox(width: 24),
                        _ModeButton(
                          title: "自動採寸",
                          isSelected: mode == CameraMode.measure,
                          onTap: () => ref.read(cameraModeProvider.notifier).state = CameraMode.measure,
                        ),
                      ],
                    ),
                  ),

                  // Shutter Button Area
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Gallery Thumbnail (Mock)
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.photo_library, color: Colors.white, size: 20),
                      ),

                      // Shutter Button
                      GestureDetector(
                        onTap: () {
                          if (mode == CameraMode.photo) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("写真を撮影しました (エビデンス保存)")),
                            );
                          } else {
                             // In measure mode, shutter might "Capture & Measure" or "Save Measurement"
                             // For now, the MeasurementScreen has its own save button, but we can integrate here.
                             showModalBottomSheet(
                               context: context,
                               backgroundColor: Colors.transparent,
                               isScrollControlled: true,
                               builder: (context) => const _MeasurementResultSheet(),
                             );
                          }
                        },
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            color: mode == CameraMode.measure ? Colors.blueAccent.withValues(alpha: 0.8) : Colors.white,
                          ),
                          child: mode == CameraMode.measure
                              ? const Icon(Icons.check, color: Colors.white, size: 32)
                              : null,
                        ),
                      ),

                      // Settings/Flash (Mock)
                      const SizedBox(width: 48), 
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Top Bar (Flash, etc)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () {}),
              actions: [
                IconButton(onPressed: () {}, icon: const Icon(Icons.flash_off, color: Colors.white)),
                IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz, color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Standard Camera View (Simulation)
class _StandardCameraView extends ConsumerStatefulWidget {
  const _StandardCameraView({super.key});

  @override
  ConsumerState<_StandardCameraView> createState() => _StandardCameraViewState();
}

class _StandardCameraViewState extends ConsumerState<_StandardCameraView> {
  bool _showGrid = false;
  double _brightness = 0.0;
  bool _flashOn = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // カメラビューフィールド（シミュレーション）
        Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt_outlined, size: 80, color: Colors.white.withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                Text(
                  "標準カメラモード\n(エビデンス撮影)",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                ),
              ],
            ),
          ),
        ),
        
        // グリッド線表示（3x3グリッド）
        if (_showGrid)
          IgnorePointer(
            child: CustomPaint(
              painter: _GridPainter(),
              child: Container(),
            ),
          ),
        
        // カメラコントロール（トップ）
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // グリッド線トグル
                  IconButton(
                    icon: Icon(
                      _showGrid ? Icons.grid_on : Icons.grid_off,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () {
                      setState(() {
                        _showGrid = !_showGrid;
                      });
                    },
                  ),
                  
                  // フラッシュトグル
                  IconButton(
                    icon: Icon(
                      _flashOn ? Icons.flash_on : Icons.flash_off,
                      color: _flashOn ? Colors.yellow : Colors.white,
                      size: 28,
                    ),
                    onPressed: () {
                      setState(() {
                        _flashOn = !_flashOn;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // 明るさ調整スライダー
        Positioned(
          right: 16,
          top: 120,
          bottom: 120,
          child: Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 明るさアイコン（上）
                Icon(
                  Icons.brightness_high,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 20,
                ),
                const SizedBox(height: 8),
                
                // 明るさスライダー（縦）
                Expanded(
                  child: RotatedBox(
                    quarterTurns: -1,
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                      ),
                      child: Slider(
                        value: _brightness,
                        min: -1.0,
                        max: 1.0,
                        activeColor: Colors.white,
                        inactiveColor: Colors.white.withValues(alpha: 0.3),
                        onChanged: (value) {
                          setState(() {
                            _brightness = value;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 8),
                // 明るさアイコン（下）
                Icon(
                  Icons.brightness_low,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// グリッド線描画用のカスタムペインター
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1.0;
    
    // 縦線2本（3分割）
    final double verticalStep = size.width / 3;
    for (int i = 1; i < 3; i++) {
      final double x = verticalStep * i;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
    
    // 横線2本（3分割）
    final double horizontalStep = size.height / 3;
    for (int i = 1; i < 3; i++) {
      final double y = horizontalStep * i;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Mode Selector Button
class _ModeButton extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeButton({required this.title, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: isSelected
            ? BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16))
            : null,
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.yellowAccent : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
            shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ),
      ),
    );
  }
}

// Reusing the Result Sheet from MeasurementScreen logic, adapted for BottomSheet
class _MeasurementResultSheet extends ConsumerWidget {
  const _MeasurementResultSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Import the provider from measurement logic
    // We need to import 'package:measure_master/features/measurement/presentation/mock_ar_view.dart';
    // But since we are in the same file structure context, we rely on the import at top.
    final measurement = ref.watch(measurementStateProvider);

    return Container(
      height: 300,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(measurement.shippingClass, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.blue[800])),
              const Chip(label: Text("自動判定済", style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
            ],
          ),
          const Divider(),
          Row(
            children: [
              Expanded(child: _DetailItem(label: "幅 (W)", value: "${measurement.widthCm.toStringAsFixed(1)} cm")),
              Expanded(child: _DetailItem(label: "高 (H)", value: "${measurement.heightCm.toStringAsFixed(1)} cm")),
              Expanded(child: _DetailItem(label: "奥 (D)", value: "${measurement.depthCm.toStringAsFixed(1)} cm")),
            ],
          ),
          const SizedBox(height: 12),
          Text("容積重量: ${measurement.volumetricWeightKg.toStringAsFixed(2)} kg", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("エビデンス写真と共にデータを保存しました")));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[800],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text("保存して撮影に戻る"),
            ),
          )
        ],
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;
  const _DetailItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
