import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:measure_master/constants.dart';
import 'package:measure_master/screens/detail_screen.dart';
import 'dart:io';

class CameraScreen extends StatefulWidget {
  final String itemName;
  final String brand;
  final String category;
  final String condition;
  final String price;
  final String barcode;
  final String sku;
  final String size;
  final String color;
  final String productRank;
  final String material;
  final String description;

  CameraScreen({
    required this.itemName,
    required this.brand,
    required this.category,
    required this.condition,
    required this.price,
    required this.barcode,
    required this.sku,
    required this.size,
    required this.color,
    required this.productRank,
    required this.material,
    required this.description,
  });

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  int _selectedMode = 0; // 0: Tops, 1: Pants, 2: Bags
  bool _isCameraInitialized = false;
  String? _capturedImagePath;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      // カメラデバイスのリストを取得
      final cameras = await availableCameras();
      
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _isCameraInitialized = false;
          });
        }
        return;
      }

      // 最初のカメラ（通常は背面カメラ）を選択
      final firstCamera = cameras.first;

      // カメラコントローラーを初期化
      _controller = CameraController(
        firstCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      _initializeControllerFuture = _controller!.initialize();
      
      await _initializeControllerFuture;

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      print('❌ カメラ初期化エラー: $e');
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) {
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      // 写真を撮影
      final image = await _controller!.takePicture();
      
      if (mounted) {
        setState(() {
          _capturedImagePath = image.path;
          _isCapturing = false;
        });

        // 撮影成功のフィードバック
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('撮影完了'),
              ],
            ),
            backgroundColor: AppConstants.successGreen,
            duration: Duration(seconds: 1),
          ),
        );

        // 1秒待ってから詳細画面へ遷移
        await Future.delayed(Duration(seconds: 1));

        // 詳細画面へ遷移（撮影した画像パスを渡す）
        if (mounted) {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => DetailScreen(
                itemName: widget.itemName,
                brand: widget.brand,
                category: widget.category,
                condition: widget.condition,
                price: widget.price,
                barcode: widget.barcode,
                sku: widget.sku,
                size: widget.size,
                color: widget.color,
                productRank: widget.productRank,
                material: widget.material,
                description: widget.description,
                capturedImagePath: _capturedImagePath,  // 📸 撮影した画像パスを渡す
              ),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 200),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ 撮影エラー: $e');
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Text('撮影に失敗しました'),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // カメラプレビューまたはプレースホルダー
          _buildCameraPreview(),
          
          // オーバーレイグリッド
          if (_isCameraInitialized)
            CustomPaint(
              painter: GridPainter(),
              child: Container(),
            ),
          
          // ヘッダー
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      "採寸・撮影", 
                      style: TextStyle(
                        color: Colors.white, 
                        fontSize: 18, 
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: Text(
                        "保存", 
                        style: TextStyle(
                          color: AppConstants.primaryCyan, 
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // カテゴリセレクター
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCategoryChip(0, Icons.checkroom, "トップス"),
                SizedBox(width: 12),
                _buildCategoryChip(1, Icons.shopping_bag, "パンツ"),
                SizedBox(width: 12),
                _buildCategoryChip(2, Icons.shopping_bag_outlined, "バッグ"),
              ],
            ),
          ),

          // ヘルプテキスト
          Positioned(
            bottom: 250,
            left: 0,
            right: 0,
            child: Text(
              _isCameraInitialized 
                ? "商品を枠に合わせて撮影してください"
                : "カメラを初期化中...",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // 下部コントロール
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black.withValues(alpha: 0.7),
              padding: EdgeInsets.only(bottom: 30, top: 20, left: 20, right: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // ギャラリーボタン
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white54),
                        ),
                        child: Icon(Icons.image, color: Colors.white),
                      ),
                      
                      // シャッターボタン
                      GestureDetector(
                        onTap: _isCameraInitialized && !_isCapturing ? _takePicture : null,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _isCameraInitialized ? Colors.white : Colors.grey, 
                              width: 4,
                            ),
                          ),
                          child: Container(
                            margin: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: _isCapturing 
                                ? Colors.grey 
                                : (_isCameraInitialized ? AppConstants.primaryCyan : Colors.grey[700]),
                              shape: BoxShape.circle,
                            ),
                            child: _isCapturing
                              ? Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : null,
                          ),
                        ),
                      ),
                      
                      // グリッド切り替えボタン
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.grid_on, color: Colors.white),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  // 寸法入力プレビュー
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "寸法入力", 
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                fontSize: 16,
                              ),
                            ),
                            Row(
                              children: [
                                Icon(
                                  Icons.center_focus_weak, 
                                  color: AppConstants.primaryCyan, 
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  "AR計測", 
                                  style: TextStyle(
                                    color: AppConstants.primaryCyan, 
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildDimInput("着丈 (Length)", "0")),
                            SizedBox(width: 16),
                            Expanded(child: _buildDimInput("身幅 (Width)", "0")),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_isCameraInitialized) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppConstants.primaryCyan),
              SizedBox(height: 16),
              Text(
                'カメラを初期化中...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    if (_controller == null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt, color: Colors.white54, size: 64),
              SizedBox(height: 16),
              Text(
                'カメラが利用できません',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    return FutureBuilder<void>(
      future: _initializeControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return CameraPreview(_controller!);
        } else {
          return Container(
            color: Colors.black,
            child: Center(
              child: CircularProgressIndicator(color: AppConstants.primaryCyan),
            ),
          );
        }
      },
    );
  }

  Widget _buildCategoryChip(int index, IconData icon, String label) {
    bool isSelected = _selectedMode == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedMode = index),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.primaryCyan : Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(
              label, 
              style: TextStyle(
                color: Colors.white, 
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDimInput(String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppConstants.backgroundLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label, 
                style: TextStyle(
                  fontSize: 10, 
                  color: AppConstants.textGrey,
                ),
              ),
              Text(
                value, 
                style: TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Text("cm", style: TextStyle(color: AppConstants.textGrey)),
        ],
      ),
    );
  }
}

// 🚀 最適化されたGridPainter（Paintオブジェクトをキャッシュ）
class GridPainter extends CustomPainter {
  // Paintオブジェクトを事前に作成してキャッシュ
  static final Paint _cachedPaint = Paint()
    ..color = AppConstants.primaryCyan.withValues(alpha: 0.5)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..strokeCap = StrokeCap.round;

  static const double _dashWidth = 5.0;
  static const double _dashSpace = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw Dashed Box
    final rect = Rect.fromLTWH(20, 100, size.width - 40, size.height - 350);
    _drawDashedRect(canvas, rect);

    // Draw Crosshair
    final centerX = size.width / 2;
    final centerY = rect.top + (rect.height / 2);
    
    // Vertical line
    _drawDashedLine(canvas, Offset(centerX, rect.top), Offset(centerX, rect.bottom));
    // Horizontal line
    _drawDashedLine(canvas, Offset(rect.left, centerY), Offset(rect.right, centerY));
  }
  
  void _drawDashedRect(Canvas canvas, Rect rect) {
    _drawDashedLine(canvas, rect.topLeft, rect.topRight);
    _drawDashedLine(canvas, rect.topRight, rect.bottomRight);
    _drawDashedLine(canvas, rect.bottomRight, rect.bottomLeft);
    _drawDashedLine(canvas, rect.bottomLeft, rect.topLeft);
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end) {
    final distance = (end - start).distance;
    if (distance == 0) return;
    
    final direction = (end - start) / distance;
    var currentDistance = 0.0;
    
    while (currentDistance < distance) {
      final endDistance = (currentDistance + _dashWidth).clamp(0.0, distance);
      canvas.drawLine(
        start + direction * currentDistance,
        start + direction * endDistance,
        _cachedPaint,
      );
      currentDistance += _dashWidth + _dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
