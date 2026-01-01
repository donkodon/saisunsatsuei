import 'dart:io' show Platform;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Web環境ではMLKitは使用できない
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  CameraController? _controller;
  // Web環境ではMLKitを使用しないためnull許容型に
  dynamic _barcodeScanner = kIsWeb ? null : BarcodeScanner();
  bool _isBusy = false;
  String? _scanResult;
  List<CameraDescription> _cameras = [];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('カメラが見つかりません')),
          );
        }
        return;
      }

      // 背面カメラを選択
      final camera = _cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      _controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();
      
      if (!mounted) return;

      // 画像ストリームの開始
      await _controller!.startImageStream(_processCameraImage);
      
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('カメラの初期化エラー: $e')),
        );
      }
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isBusy || _controller == null) return;
    _isBusy = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        _isBusy = false;
        return;
      }

      final barcodes = await _barcodeScanner.processImage(inputImage);
      
      if (barcodes.isNotEmpty) {
        // 最初に見つかったバーコードを使用
        final barcode = barcodes.first;
        final String? rawValue = barcode.rawValue;

        if (rawValue != null && mounted) {
          // スキャン成功：カメラを停止して結果を返す
          await _controller!.stopImageStream();
          Navigator.of(context).pop(rawValue);
        }
      }
    } catch (e) {
      debugPrint('Error detecting barcode: $e');
    } finally {
      _isBusy = false;
    }
  }

  dynamic _inputImageFromCameraImage(CameraImage image) {
    // Web環境では使用しない
    if (kIsWeb) return null;
    if (_controller == null) return null;

    final camera = _controller!.description;
    final sensorOrientation = camera.sensorOrientation;
    
    // 現在のデバイスの向きを取得
    // 注: 簡易的な実装として縦向き固定で計算
    final rotations = InputImageRotationValue.fromRawValue(sensorOrientation);
    if (rotations == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    
    // Androidの場合はNV21が標準
    if (format == null || (Platform.isAndroid && format != InputImageFormat.nv21)) return null;

    if (image.planes.isEmpty) return null;
    
    // 平面データの結合 (NV21の場合)
    final plane = image.planes.first;
    
    return InputImage.fromBytes(
      bytes: Uint8List.fromList(
        image.planes.fold<List<int>>(
          <int>[],
          (previousValue, plane) => previousValue..addAll(plane.bytes),
        ),
      ),
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotations,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _barcodeScanner.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️ Web環境ではバーコードスキャン機能は使用できません
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('バーコードスキャン'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber_rounded, size: 64, color: Colors.orange),
              SizedBox(height: 16),
              Text(
                'Web環境ではバーコードスキャンは\n利用できません',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 8),
              Text(
                'SKUまたはバーコードを手動で入力してください',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('バーコードスキャン'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // カメラプレビュー
          CameraPreview(_controller!),
          
          // オーバーレイガイド
          Container(
            decoration: ShapeDecoration(
              shape: _ScannerOverlayShape(
                borderColor: Colors.red,
                borderRadius: 10,
                borderLength: 30,
                borderWidth: 10,
                cutOutSize: 300,
              ),
            ),
          ),
          
          // 説明テキスト
          const Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Text(
              'バーコードを枠内に合わせてください',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// スキャナー用のオーバーレイ描画クラス
class _ScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const _ScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderWidth = 10.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path getLeftTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.bottom - borderLength)
        ..lineTo(rect.left, rect.bottom - borderRadius)
        ..quadraticBezierTo(
            rect.left, rect.bottom, rect.left + borderRadius, rect.bottom)
        ..lineTo(rect.left + borderLength, rect.bottom)
        ..lineTo(rect.left + borderLength, rect.bottom - borderWidth)
        ..lineTo(rect.left + borderRadius, rect.bottom - borderWidth)
        ..quadraticBezierTo(rect.left + borderWidth, rect.bottom - borderWidth,
            rect.left + borderWidth, rect.bottom - borderRadius)
        ..lineTo(rect.left + borderWidth, rect.bottom - borderLength)
        ..close();
    }

    return Path()
      ..addRect(Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height))
      ..addRect(
        Rect.fromCenter(
          center: rect.center,
          width: cutOutSize,
          height: cutOutSize,
        ),
      );
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final height = rect.height;
    final borderOffset = borderWidth / 2;
    final _cutOutSize = cutOutSize;
    final _borderLength = borderLength;
    final _borderRadius = borderRadius;

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final boxPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill;

    final cutOutRect = Rect.fromCenter(
      center: rect.center,
      width: _cutOutSize,
      height: _cutOutSize,
    );

    canvas.saveLayer(rect, backgroundPaint);
    canvas.drawRect(rect, backgroundPaint);
    
    // 切り抜き部分をクリア（透明にする）
    canvas.drawRect(cutOutRect, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    // 四隅の枠線を描画
    final path = Path();
    
    // 左上
    path.moveTo(cutOutRect.left, cutOutRect.top + _borderLength);
    path.lineTo(cutOutRect.left, cutOutRect.top + _borderRadius);
    path.quadraticBezierTo(cutOutRect.left, cutOutRect.top, 
        cutOutRect.left + _borderRadius, cutOutRect.top);
    path.lineTo(cutOutRect.left + _borderLength, cutOutRect.top);

    // 右上
    path.moveTo(cutOutRect.right - _borderLength, cutOutRect.top);
    path.lineTo(cutOutRect.right - _borderRadius, cutOutRect.top);
    path.quadraticBezierTo(cutOutRect.right, cutOutRect.top, 
        cutOutRect.right, cutOutRect.top + _borderRadius);
    path.lineTo(cutOutRect.right, cutOutRect.top + _borderLength);

    // 右下
    path.moveTo(cutOutRect.right, cutOutRect.bottom - _borderLength);
    path.lineTo(cutOutRect.right, cutOutRect.bottom - _borderRadius);
    path.quadraticBezierTo(cutOutRect.right, cutOutRect.bottom, 
        cutOutRect.right - _borderRadius, cutOutRect.bottom);
    path.lineTo(cutOutRect.right - _borderLength, cutOutRect.bottom);

    // 左下
    path.moveTo(cutOutRect.left + _borderLength, cutOutRect.bottom);
    path.lineTo(cutOutRect.left + _borderRadius, cutOutRect.bottom);
    path.quadraticBezierTo(cutOutRect.left, cutOutRect.bottom, 
        cutOutRect.left, cutOutRect.bottom - _borderRadius);
    path.lineTo(cutOutRect.left, cutOutRect.bottom - _borderLength);

    canvas.drawPath(path, borderPaint);
  }

  @override
  ShapeBorder scale(double t) {
    return _ScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth * t,
      overlayColor: overlayColor,
      borderRadius: borderRadius * t,
      borderLength: borderLength * t,
      cutOutSize: cutOutSize * t,
    );
  }
}
