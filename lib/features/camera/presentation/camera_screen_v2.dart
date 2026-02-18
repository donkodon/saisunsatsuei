import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:measure_master/constants.dart';
import 'package:measure_master/features/inventory/domain/image_item.dart';
import 'package:measure_master/core/services/image_cache_service.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:measure_master/core/utils/app_feedback.dart';

/// 📸 撮影画面 v3（UUID管理）
/// 
/// 改善点：
/// - UUID方式による画像管理
/// - 削除・並び替えに完全対応
/// - ファイル名の衝突を防止
/// - 白抜き画像との整合性を保証
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
  final List<ImageItem>? existingImages;  // 📸 既存の画像アイテム（編集時）
  final bool aiMeasure;  // 📏 AI自動採寸フラグ

  const CameraScreenV2({
    super.key,
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
    this.existingImages,
    this.aiMeasure = false,  // 📏 デフォルトはfalse
  });

  @override
  @override
  State<CameraScreenV2> createState() => _CameraScreenV2State();
}

class _CameraScreenV2State extends State<CameraScreenV2> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  int _selectedMode = 0; // 0: Tops, 1: Pants, 2: Bags
  bool _isCameraInitialized = false;
  
  // 📸 画像アイテムのリスト（UUID管理）
  List<ImageItem> _images = [];
  
  bool _isCapturing = false;
  int _selectedImageIndex = 0;

  @override
  void initState() {
    super.initState();
    
    if (kDebugMode) {
    }
    
    _initializeCamera();
    _initializeExistingImages();
  }

  /// 📸 既存画像を初期化
  void _initializeExistingImages() {
    if (widget.existingImages != null && widget.existingImages!.isNotEmpty) {
      setState(() {
        _images = List.from(widget.existingImages!);
      });
      
      if (kDebugMode) {
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
    if (_images.isEmpty) return;
    
    // 🎯 順序を再計算してから返却
    final updatedImages = _updateSequences();
    
    if (kDebugMode) {
      for (var _ in updatedImages) {
      }
    }
    
    Navigator.pop(context, updatedImages);
  }
  
  /// 🎯 順序を再計算
  List<ImageItem> _updateSequences() {
    final List<ImageItem> updated = [];
    for (int i = 0; i < _images.length; i++) {
      updated.add(_images[i].copyWithSequence(i + 1, isMain: i == 0));
    }
    return updated;
  }
  
  /// 🗑️ 画像を削除（UUID方式）
  Future<void> _deleteImage(String id) async {
    final imageItem = _images.firstWhere((img) => img.id == id);
    
    final confirmed = await AppFeedback.showConfirm(
      context,
      title: '画像を削除',
      message: imageItem.isExisting
          ? 'この画像を削除しますか？\n（商品確定時にサーバーからも削除されます）'
          : 'この画像を削除しますか？',
      confirmLabel: '削除',
    );
    if (!confirmed) return;

    setState(() {
      _images.removeWhere((img) => img.id == id);
      if (_selectedImageIndex >= _images.length && _images.isNotEmpty) {
        _selectedImageIndex = _images.length - 1;
      }
    });
    if (mounted) {
      AppFeedback.showWarning(context, '画像を削除しました',
          duration: const Duration(seconds: 2));
    }
  }

  /// 📸 写真を撮影（UUID方式）
  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);

    try {
      final image = await _controller!.takePicture();
      
      if (kDebugMode) {
      }

      // 🔧 blob URL問題の回避: 即座にバイトデータに変換
      final imageBytes = await image.readAsBytes();
      if (kDebugMode) {
      }

      if (mounted) {
        // ✅ ImageItem として追加（bytesを保持）
        setState(() {
          final newItem = ImageItem.fromBytes(
            bytes: imageBytes,
            sequence: _images.length + 1,
            isMain: _images.isEmpty,
          );
          _images.add(newItem);
          _selectedImageIndex = _images.length - 1;
          
          if (kDebugMode) {
          }
        });
        
        setState(() {
          _selectedImageIndex = _images.length - 1;
          _isCapturing = false;
        });

        AppFeedback.showSuccess(context, '撮影完了 (${_images.length}枚)',
            duration: const Duration(seconds: 1));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCapturing = false);
        
        AppFeedback.showError(context, '撮影に失敗しました');
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
        return;
      }

      if (kDebugMode) {
      }

      if (mounted) {
        // ✅ ローカルファイルリストに追加
        setState(() {
          final newItem = ImageItem.fromFile(
            file: pickedFile,
            sequence: _images.length + 1,
            isMain: _images.isEmpty,
          );
          _images.add(newItem);
          _selectedImageIndex = _images.length - 1;
        });

        AppFeedback.showSuccess(context, '画像を選択しました (${_images.length}枚)',
            duration: const Duration(seconds: 1));
      }
    } catch (e) {
      
      if (mounted) {
        AppFeedback.showError(context, '画像の選択に失敗しました');
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
          if (_images.isNotEmpty)
            _buildImageThumbnails(),
          
          // 底部コントロール
          _buildBottomControls(),
        ],
      ),
    );
  }

  /// 画像ウィジェットを構築
  /// 
  /// 🔧 v2.0 改善点:
  /// - URLからの画像読み込み時にキャッシュバスティングを適用
  /// - キャッシュ制御ヘッダーを追加
  Widget _buildImageWidget(ImageItem imageItem) {
    if (imageItem.bytes != null) {
      // 🔧 バイトデータから表示（blob URL問題の回避）
      return Image.memory(
        imageItem.bytes!,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
      );
    } else if (imageItem.url != null) {
      // 🔧 既存画像（URLから表示）- キャッシュバスティングを適用
      final cacheBustedUrl = ImageCacheService.getCacheBustedUrl(imageItem.url!);
      return Image.network(
        cacheBustedUrl,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        // ✅ Phase 1のUUID形式でキャッシュ衝突は回避済み
        // ✅ ?t=timestamp パラメータでキャッシュバスティング実現
        // ❌ Cache-Controlヘッダーは削除（CORS問題回避）
        errorBuilder: (context, error, stackTrace) {
          if (kDebugMode) {
          }
          return Container(
            width: 80,
            height: 80,
            color: Colors.grey[300],
            child: const Icon(Icons.error, color: Colors.red),
          );
        },
      );
    } else if (imageItem.file != null) {
      // 新規画像（ローカルファイルから表示）
      return kIsWeb
          ? Image.network(
              imageItem.file!.path,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
            )
          : Image.file(
              File(imageItem.file!.path),
              width: 80,
              height: 80,
              fit: BoxFit.cover,
            );
    } else {
      // エラー状態
      return Container(
        width: 80,
        height: 80,
        color: Colors.grey[300],
        child: const Icon(Icons.image_not_supported, color: Colors.grey),
      );
    }
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
                onPressed: _images.isEmpty ? null : _saveAndReturn,
                child: Text(
                  "保存 (${_images.length})", 
                  style: TextStyle(
                    color: _images.isEmpty 
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
      child: SizedBox(
        height: 80,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _images.length,
          itemBuilder: (context, index) {
            final imageItem = _images[index];
            final isSelected = index == _selectedImageIndex;

            return GestureDetector(
              onTap: () => setState(() => _selectedImageIndex = index),
              child: Container(
                width: 80,
                margin: const EdgeInsets.only(right: 8),
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
                      child: _buildImageWidget(imageItem),
                    ),
                    
                    // 🎯 バッジ（既存画像）
                    if (imageItem.isExisting)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '保存済',
                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    
                    // 削除ボタン
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () => _deleteImage(imageItem.id),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                label: '${_images.length}',
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
    ..color = Colors.white.withValues(alpha: 0.3)
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
