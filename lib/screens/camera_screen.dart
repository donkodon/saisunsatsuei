import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:measure_master/constants.dart';
import 'package:measure_master/screens/detail_screen.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:measure_master/services/cloudflare_storage_service.dart';
import 'package:measure_master/services/image_cache_service.dart';

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
  List<String> _capturedImages = []; // 📸 複数の撮影画像を保存
  bool _isCapturing = false;
  int _selectedImageIndex = 0; // 選択中の画像インデックス

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

  // 📸 保存ボタン押下時：撮影画像を持って元の画面に戻る
  void _goToDetailScreen() {
    if (_capturedImages.isEmpty) return;
    
    // 📸 撮影した画像リストを持って元の画面（AddItemScreen）に戻る
    Navigator.pop(context, _capturedImages);
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
        // 撮影成功のフィードバック
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('撮影完了 - アップロード中...'),
              ],
            ),
            backgroundColor: AppConstants.successGreen,
            duration: Duration(seconds: 2),
          ),
        );

        // 📸 画像を即座にアップロード
        String? uploadedImageUrl;
        try {
          Uint8List imageBytes;
          
          if (kIsWeb) {
            // Web環境：blob: URLから画像データを取得
            if (kDebugMode) {
              debugPrint('🌐 Web環境：blob URLから画像を読み込み: ${image.path}');
            }
            
            final response = await http.get(Uri.parse(image.path));
            if (response.statusCode == 200) {
              imageBytes = response.bodyBytes;
              if (kDebugMode) {
                debugPrint('✅ blob画像読み込み成功: ${imageBytes.length} bytes');
              }
            } else {
              throw Exception('blob画像の読み込みに失敗しました');
            }
          } else {
            // モバイル環境：ファイルパスから画像を読み込み
            final imageFile = File(image.path);
            imageBytes = await imageFile.readAsBytes();
            if (kDebugMode) {
              debugPrint('📱 モバイル環境：ファイル読み込み成功: ${imageBytes.length} bytes');
            }
          }
          
          // ユニークなアイテムIDを生成
          final uniqueId = '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
          
          // Workers経由でアップロード
          uploadedImageUrl = await CloudflareWorkersStorageService.uploadImage(
            imageBytes,
            uniqueId,
          );
          
          // 📸 アップロード成功時に画像をローカルキャッシュに保存
          await ImageCacheService.cacheImage(uploadedImageUrl, imageBytes);
          
          if (kDebugMode) {
            debugPrint('✅ 画像アップロード完了: $uploadedImageUrl');
          }
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.cloud_done, color: Colors.white),
                    SizedBox(width: 8),
                    Text('アップロード完了!'),
                  ],
                ),
                backgroundColor: AppConstants.successGreen,
                duration: Duration(seconds: 1),
              ),
            );
          }
        } catch (uploadError) {
          if (kDebugMode) {
            debugPrint('❌ アップロードエラー: $uploadError');
          }
          // アップロード失敗時はローカルパスを使用
          uploadedImageUrl = image.path;
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.white),
                    SizedBox(width: 8),
                    Text('オフラインモード（ローカル保存）'),
                  ],
                ),
                backgroundColor: AppConstants.warningOrange,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }

        // 📸 撮影した画像をリストに追加（連続撮影対応）
        setState(() {
          _capturedImages.add(uploadedImageUrl!);
          _selectedImageIndex = _capturedImages.length - 1; // 最新の画像を選択
          _isCapturing = false;
        });
        
        // 📸 連続撮影のため、遷移はしない（完了ボタンで遷移）
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
                      onPressed: _capturedImages.isEmpty ? null : _goToDetailScreen,
                      child: Text(
                        "保存", 
                        style: TextStyle(
                          color: _capturedImages.isEmpty 
                            ? Colors.grey 
                            : AppConstants.primaryCyan, 
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
                  // 📸 撮影済み画像のサムネイルプレビュー（横スクロール）
                  if (_capturedImages.isNotEmpty)
                    Container(
                      height: 80,
                      margin: EdgeInsets.only(bottom: 16),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _capturedImages.length,
                        itemBuilder: (context, index) {
                          final isSelected = index == _selectedImageIndex;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedImageIndex = index;
                              });
                            },
                            child: Container(
                              width: 80,
                              height: 80,
                              margin: EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? AppConstants.primaryCyan : Colors.white54,
                                  width: isSelected ? 3 : 2,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: kIsWeb
                                      ? Image.network(
                                          _capturedImages[index],
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                        )
                                      : Image.file(
                                          File(_capturedImages[index]),
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                        ),
                                  ),
                                  if (isSelected)
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: Container(
                                        padding: EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: AppConstants.primaryCyan,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  // 🗑️ 削除ボタン
                                  Positioned(
                                    bottom: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _capturedImages.removeAt(index);
                                          // 削除後のインデックス調整
                                          if (_selectedImageIndex >= _capturedImages.length) {
                                            _selectedImageIndex = _capturedImages.length - 1;
                                          }
                                          if (_selectedImageIndex < 0) {
                                            _selectedImageIndex = 0;
                                          }
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('画像を削除しました'),
                                            duration: Duration(seconds: 1),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // ギャラリーボタン（撮影枚数を表示）
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white54),
                        ),
                        child: Stack(
                          children: [
                            Center(child: Icon(Icons.image, color: Colors.white)),
                            if (_capturedImages.isNotEmpty)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  padding: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppConstants.primaryCyan,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${_capturedImages.length}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
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
