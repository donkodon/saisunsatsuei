import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:measure_master/constants.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// 📸 撮影画面 v2（ローカル保存のみ）
/// 
/// 改善点：
/// - 即時アップロードを削除 → ローカルファイルのみ管理
/// - 連番管理をシンプル化 → リストのインデックス = 連番
/// - 削除処理の簡素化 → ローカルリストから削除のみ
class CameraScreenV2 extends StatefulWidget {
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
  final List<XFile>? existingImageFiles;  // 📸 既存の画像ファイル（編集時）

  const CameraScreenV2({
    Key? key,
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
    this.existingImageFiles,
  }) : super(key: key);

  @override
  _CameraScreenV2State createState() => _CameraScreenV2State();
}

class _CameraScreenV2State extends State<CameraScreenV2> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  int _selectedMode = 0; // 0: Tops, 1: Pants, 2: Bags
  bool _isCameraInitialized = false;
  
  // 📸 ローカル画像ファイルのリスト（アップロード前）
  List<XFile> _capturedImageFiles = [];
  
  bool _isCapturing = false;
  int _selectedImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeExistingImages();
  }

  /// 📸 既存画像ファイルを初期化
  void _initializeExistingImages() {
    if (widget.existingImageFiles != null && widget.existingImageFiles!.isNotEmpty) {
      _capturedImageFiles = List.from(widget.existingImageFiles!);
      
      if (kDebugMode) {
        debugPrint('📸 既存画像を読み込み: ${_capturedImageFiles.length}枚');
      }
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() => _isCameraInitialized = false);
        }
        return;
      }

      // 背面カメラを優先選択
      CameraDescription selectedCamera;
      try {
        selectedCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
        );
      } catch (e) {
        selectedCamera = cameras.first;
      }

      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      _initializeControllerFuture = _controller!.initialize();
      await _initializeControllerFuture;

      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      debugPrint('❌ カメラ初期化エラー: $e');
      if (mounted) {
        setState(() => _isCameraInitialized = false);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// 📸 保存ボタン押下時：撮影画像を持って元の画面に戻る
  void _saveAndReturn() {
    if (_capturedImageFiles.isEmpty) return;
    
    if (kDebugMode) {
      debugPrint('📸 保存: ${_capturedImageFiles.length}枚の画像を返却');
    }
    
    Navigator.pop(context, _capturedImageFiles);
  }

  /// 📸 写真を撮影（ローカル保存のみ）
  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);

    try {
      final image = await _controller!.takePicture();
      
      if (kDebugMode) {
        debugPrint('✅ 撮影完了: ${image.path}');
      }

      if (mounted) {
        // ✅ ローカルファイルリストに追加（アップロードなし）
        setState(() {
          _capturedImageFiles.add(image);
          _selectedImageIndex = _capturedImageFiles.length - 1;
          _isCapturing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('撮影完了 (${_capturedImageFiles.length}枚)'),
              ],
            ),
            backgroundColor: AppConstants.successGreen,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ 撮影エラー: $e');
      if (mounted) {
        setState(() => _isCapturing = false);
        
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

  /// 📁 ギャラリーから画像を選択
  Future<void> _pickImageFromGallery() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 85,
      );
      
      if (pickedFile == null) {
        debugPrint('ℹ️ ギャラリー選択がキャンセルされました');
        return;
      }

      if (kDebugMode) {
        debugPrint('✅ ギャラリーから選択: ${pickedFile.name}');
      }

      if (mounted) {
        // ✅ ローカルファイルリストに追加
        setState(() {
          _capturedImageFiles.add(pickedFile);
          _selectedImageIndex = _capturedImageFiles.length - 1;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('画像を選択しました (${_capturedImageFiles.length}枚)'),
              ],
            ),
            backgroundColor: AppConstants.successGreen,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ ギャラリー選択エラー: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('画像の選択に失敗しました'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 🗑️ 画像を削除（ローカルリストから削除のみ）
  void _deleteImage(int index) {
    if (index < 0 || index >= _capturedImageFiles.length) return;

    final removedImage = _capturedImageFiles[index];
    
    if (kDebugMode) {
      debugPrint('🗑️ 画像を削除: ${removedImage.name} (index: $index)');
    }

    setState(() {
      _capturedImageFiles.removeAt(index);
      
      // 選択インデックスの調整
      if (_selectedImageIndex >= _capturedImageFiles.length) {
        _selectedImageIndex = _capturedImageFiles.length - 1;
      }
      if (_selectedImageIndex < 0) {
        _selectedImageIndex = 0;
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.delete, color: Colors.white),
              SizedBox(width: 8),
              Text('画像を削除しました'),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // カメラプレビュー
          _buildCameraPreview(),
          
          // グリッドオーバーレイ
          if (_isCameraInitialized)
            CustomPaint(
              painter: GridPainter(),
              child: Container(),
            ),
          
          // ヘッダー
          _buildHeader(),
          
          // カテゴリセレクター
          _buildCategorySelector(),
          
          // ヘルプテキスト
          _buildHelpText(),
          
          // 撮影画像サムネイル
          if (_capturedImageFiles.isNotEmpty)
            _buildImageThumbnails(),
          
          // 底部コントロール
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_isCameraInitialized || _controller == null) {
      return Center(
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
      );
    }

    return CameraPreview(_controller!);
  }

  Widget _buildHeader() {
    return Positioned(
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
                onPressed: _capturedImageFiles.isEmpty ? null : _saveAndReturn,
                child: Text(
                  "保存 (${_capturedImageFiles.length})", 
                  style: TextStyle(
                    color: _capturedImageFiles.isEmpty 
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
    );
  }

  Widget _buildCategorySelector() {
    return Positioned(
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
    );
  }

  Widget _buildCategoryChip(int mode, IconData icon, String label) {
    final isSelected = _selectedMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _selectedMode = mode),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.primaryCyan : Colors.black54,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.grey,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            SizedBox(width: 6),
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

  Widget _buildHelpText() {
    return Positioned(
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
    );
  }

  Widget _buildImageThumbnails() {
    return Positioned(
      bottom: 160,
      left: 0,
      right: 0,
      child: Container(
        height: 80,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 16),
          itemCount: _capturedImageFiles.length,
          itemBuilder: (context, index) {
            final imageFile = _capturedImageFiles[index];
            final isSelected = index == _selectedImageIndex;

            return GestureDetector(
              onTap: () => setState(() => _selectedImageIndex = index),
              child: Container(
                width: 80,
                margin: EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected ? AppConstants.primaryCyan : Colors.white,
                    width: isSelected ? 3 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  children: [
                    // 画像サムネイル
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: kIsWeb
                          ? Image.network(
                              imageFile.path,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            )
                          : Image.file(
                              File(imageFile.path),
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                    ),
                    // 削除ボタン
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () => _deleteImage(index),
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
                    // 連番表示
                    Positioned(
                      bottom: 2,
                      left: 2,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
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
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // ギャラリーボタン
              _buildControlButton(
                icon: Icons.photo_library,
                label: '${_capturedImageFiles.length}',
                onTap: _pickImageFromGallery,
              ),
              
              // 撮影ボタン
              GestureDetector(
                onTap: _isCapturing ? null : _takePicture,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: AppConstants.primaryCyan, width: 4),
                  ),
                  child: _isCapturing
                      ? Center(
                          child: CircularProgressIndicator(
                            color: AppConstants.primaryCyan,
                          ),
                        )
                      : null,
                ),
              ),
              
              // AR測定ボタン（将来用）
              _buildControlButton(
                icon: Icons.straighten,
                label: 'AR',
                onTap: () {
                  // AR測定機能（将来実装）
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              shadows: [Shadow(blurRadius: 4, color: Colors.black)],
            ),
          ),
        ],
      ),
    );
  }
}

/// グリッドペインター（撮影補助線）
class GridPainter extends CustomPainter {
  static final Paint _paint = Paint()
    ..color = Colors.white.withOpacity(0.3)
    ..strokeWidth = 1;

  @override
  void paint(Canvas canvas, Size size) {
    // 縦線
    canvas.drawLine(
      Offset(size.width / 3, 0),
      Offset(size.width / 3, size.height),
      _paint,
    );
    canvas.drawLine(
      Offset(size.width * 2 / 3, 0),
      Offset(size.width * 2 / 3, size.height),
      _paint,
    );
    
    // 横線
    canvas.drawLine(
      Offset(0, size.height / 3),
      Offset(size.width, size.height / 3),
      _paint,
    );
    canvas.drawLine(
      Offset(0, size.height * 2 / 3),
      Offset(size.width, size.height * 2 / 3),
      _paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
