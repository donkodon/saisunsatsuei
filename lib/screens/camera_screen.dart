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
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

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
  final List<String>? existingImages;  // 📸 既存の画像リスト（編集時）

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
    this.existingImages,  // オプション: 既存画像を渡す
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
  int _imageCounter = 1; // 🔢 画像の連番カウンター

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeExistingImages();  // 📸 既存画像と連番を初期化
  }

  /// 📸 既存画像と連番を初期化
  void _initializeExistingImages() {
    if (widget.existingImages != null && widget.existingImages!.isNotEmpty) {
      _capturedImages = List.from(widget.existingImages!);
      
      // 🔢 既存画像の連番を解析して、次の連番を決定
      _imageCounter = _calculateNextImageCounter();
      
      if (kDebugMode) {
        debugPrint('📸 既存画像を読み込み: ${_capturedImages.length}枚');
        debugPrint('📸 既存画像リスト:');
        for (int i = 0; i < _capturedImages.length; i++) {
          debugPrint('   [$i] ${_capturedImages[i]}');
        }
        debugPrint('🔢 次の連番: $_imageCounter');
      }
    } else {
      if (kDebugMode) {
        debugPrint('📸 既存画像なし、連番1から開始');
      }
    }
  }

  /// 🔢 既存画像から次の連番を計算
  int _calculateNextImageCounter() {
    if (_capturedImages.isEmpty) return 1;
    
    int maxCounter = 0;
    final skuTrimmed = widget.sku.trim();
    
    for (final imagePath in _capturedImages) {
      // URLからファイル名を抽出して連番を解析
      // 例: "https://.../{SKU}_3.jpg" → 3
      try {
        final uri = Uri.tryParse(imagePath);
        if (uri != null && uri.pathSegments.isNotEmpty) {
          final fileName = uri.pathSegments.last;
          if (kDebugMode) {
            debugPrint('🔍 解析中: $fileName');
          }
          
          // _{連番}.jpg 形式から連番を抽出（SKUの有無に関わらず）
          final match = RegExp(r'_(\d+)\.jpg').firstMatch(fileName);
          if (match != null) {
            final counter = int.tryParse(match.group(1) ?? '0') ?? 0;
            if (kDebugMode) {
              debugPrint('   → 連番: $counter');
            }
            if (counter > maxCounter) {
              maxCounter = counter;
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ URL解析エラー: $e');
        }
      }
    }
    
    // 既存の最大連番 + 1 を返す（最低でも既存画像数 + 1）
    final nextCounter = (maxCounter > 0) ? maxCounter + 1 : _capturedImages.length + 1;
    if (kDebugMode) {
      debugPrint('🔢 最大連番: $maxCounter → 次の連番: $nextCounter');
    }
    return nextCounter;
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
          
          // 🔑 SKUコードを使用してファイルIDを生成（ローカル連番を使用）
          if (kDebugMode) {
            debugPrint('🔍 widget.sku = "${widget.sku}" (isEmpty: ${widget.sku.isEmpty}, length: ${widget.sku.length})');
            debugPrint('🔢 現在の連番カウンター: $_imageCounter');
          }
          
          String fileId;
          final skuTrimmed = widget.sku.trim();
          if (skuTrimmed.isNotEmpty) {
            // SKUがある場合: ローカルカウンターを使用（既存画像から計算済み）
            final currentCounter = _imageCounter;
            fileId = '${skuTrimmed}_$currentCounter';
            _imageCounter++;  // 次回用に連番をインクリメント
            
            if (kDebugMode) {
              debugPrint('✅ SKUベースのファイル名: $fileId (SKU: $skuTrimmed, 連番: $currentCounter)');
              debugPrint('🔢 次回の連番: $_imageCounter');
            }
          } else {
            // SKUがない場合: タイムスタンプ
            fileId = '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
            if (kDebugMode) {
              debugPrint('⚠️ SKUが空のためタイムスタンプベース: $fileId');
            }
          }
          
          // Workers経由でアップロード
          uploadedImageUrl = await CloudflareWorkersStorageService.uploadImage(
            imageBytes,
            fileId,
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

  // 📁 ギャラリーから画像を選択（file_picker使用 - Web環境でより確実に動作）
  Future<void> _pickImageFromGallery() async {
    if (kDebugMode) {
      debugPrint('📁 ============================================');
      debugPrint('📁 ギャラリー選択を開始（file_picker）...');
      debugPrint('📁 kIsWeb: $kIsWeb');
      debugPrint('📁 ============================================');
    }
    
    // 🔔 ユーザーにフィードバック（ボタンが押されたことを確認）
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
              SizedBox(width: 12),
              Text('ファイル選択画面を開いています...'),
            ],
          ),
          backgroundColor: AppConstants.primaryCyan,
          duration: Duration(seconds: 3),
        ),
      );
    }
    
    try {
      if (kDebugMode) {
        debugPrint('📁 FilePicker.platform.pickFiles 呼び出し中...');
      }
      
      // file_picker を使用（Web環境でも確実に動作）
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,  // バイトデータを直接取得（Web環境で必要）
      );
      
      if (kDebugMode) {
        debugPrint('📁 FilePicker 完了: ${result != null ? "ファイル選択済み" : "キャンセル"}');
      }

      if (result == null || result.files.isEmpty) {
        // キャンセルされた場合
        if (kDebugMode) {
          debugPrint('ℹ️ ギャラリー選択がキャンセルされました');
        }
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
        }
        return;
      }
      
      final file = result.files.first;
      
      if (kDebugMode) {
        debugPrint('📁 選択されたファイル: ${file.name}');
        debugPrint('📁 ファイルサイズ: ${file.size} bytes');
        debugPrint('📁 バイトデータ: ${file.bytes != null ? "${file.bytes!.length} bytes" : "null"}');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('画像を選択しました: ${file.name}'),
              ],
            ),
            backgroundColor: AppConstants.successGreen,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // 📸 画像を即座にアップロード
      String? uploadedImageUrl;
      try {
        Uint8List? imageBytes;
        
        // file_picker の withData: true でバイトデータを取得
        if (file.bytes != null) {
          imageBytes = file.bytes!;
          if (kDebugMode) {
            debugPrint('✅ file_picker からバイトデータを取得: ${imageBytes.length} bytes');
          }
        } else if (file.path != null && !kIsWeb) {
          // モバイル環境でファイルパスがある場合
          final imageFile = File(file.path!);
          imageBytes = await imageFile.readAsBytes();
          if (kDebugMode) {
            debugPrint('✅ ファイルパスから読み込み: ${imageBytes.length} bytes');
          }
        }
        
        if (imageBytes == null || imageBytes.isEmpty) {
          throw Exception('画像データを取得できませんでした');
        }
        
        if (kDebugMode) {
          debugPrint('✅ 画像読み込み成功: ${imageBytes.length} bytes');
        }
        
        // 🔑 SKUコードを使用してファイルIDを生成（ローカル連番を使用）
        String fileId;
        final skuTrimmed = widget.sku.trim();
        if (skuTrimmed.isNotEmpty) {
          // SKUがある場合: ローカルカウンターを使用（既存画像から計算済み）
          final currentCounter = _imageCounter;
          fileId = '${skuTrimmed}_$currentCounter';
          _imageCounter++;  // 次回用に連番をインクリメント
          
          if (kDebugMode) {
            debugPrint('✅ SKUベースのファイル名: $fileId (SKU: $skuTrimmed, 連番: $currentCounter)');
            debugPrint('🔢 次回の連番: $_imageCounter');
          }
        } else {
          // SKUがない場合: タイムスタンプ
          fileId = '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
          if (kDebugMode) {
            debugPrint('⚠️ SKUが空のためタイムスタンプベース: $fileId');
          }
        }
        
        // Workers経由でアップロード
        uploadedImageUrl = await CloudflareWorkersStorageService.uploadImage(
          imageBytes,
          fileId,
        );
        
        // 📸 アップロード成功時に画像をローカルキャッシュに保存
        await ImageCacheService.cacheImage(uploadedImageUrl, imageBytes);
        
        if (kDebugMode) {
          debugPrint('✅ ギャラリー画像アップロード完了: $uploadedImageUrl');
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
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ アップロード失敗: $e');
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.warning, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(child: Text('アップロードに失敗しました: $e')),
                ],
              ),
              backgroundColor: AppConstants.warningOrange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;  // アップロード失敗時は追加しない
      }

      // 📸 選択した画像をリストに追加
      if (uploadedImageUrl != null) {
        setState(() {
          _capturedImages.add(uploadedImageUrl!);
          _selectedImageIndex = _capturedImages.length - 1; // 最新の画像を選択
        });
      }
      
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ ギャラリー選択エラー: $e');
        debugPrint('スタックトレース: $stackTrace');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('画像の選択に失敗しました: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
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
                                      onTap: () async {
                                        final deletedImageUrl = _capturedImages[index];
                                        
                                        // 🗑️ Cloudflareからも画像を削除
                                        if (deletedImageUrl.startsWith('http')) {
                                          if (kDebugMode) {
                                            debugPrint('🗑️ Cloudflareから画像を削除中: $deletedImageUrl');
                                          }
                                          
                                          // バックグラウンドで削除実行
                                          CloudflareWorkersStorageService.deleteImage(deletedImageUrl).then((success) {
                                            if (kDebugMode) {
                                              debugPrint(success 
                                                ? '✅ Cloudflare削除成功: $deletedImageUrl' 
                                                : '⚠️ Cloudflare削除失敗: $deletedImageUrl');
                                            }
                                          });
                                        }
                                        
                                        setState(() {
                                          _capturedImages.removeAt(index);
                                          // 削除後のインデックス調整
                                          if (_selectedImageIndex >= _capturedImages.length) {
                                            _selectedImageIndex = _capturedImages.length - 1;
                                          }
                                          if (_selectedImageIndex < 0) {
                                            _selectedImageIndex = 0;
                                          }
                                          
                                          // 🔢 連番を再計算: 既存画像の最大連番+1から開始
                                          _imageCounter = _calculateNextImageCounter();
                                          
                                          if (kDebugMode) {
                                            debugPrint('🗑️ 画像削除後、次の連番を $_imageCounter にリセット');
                                          }
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Row(
                                              children: [
                                                Icon(Icons.delete, color: Colors.white, size: 18),
                                                SizedBox(width: 8),
                                                Text('画像を削除しました（サーバーからも削除中...）'),
                                              ],
                                            ),
                                            duration: Duration(seconds: 2),
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
                      // 📁 ギャラリーボタン（GestureDetectorで確実にタップ検出）
                      GestureDetector(
                        onTap: () async {
                          if (kDebugMode) {
                            debugPrint('🖱️ ============================================');
                            debugPrint('🖱️ ギャラリーボタンがタップされました');
                            debugPrint('🖱️ ============================================');
                          }
                          try {
                            await _pickImageFromGallery();
                          } catch (e, stackTrace) {
                            if (kDebugMode) {
                              debugPrint('❌ ギャラリー選択でエラー: $e');
                              debugPrint('❌ スタックトレース: $stackTrace');
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('ギャラリーを開けませんでした: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        behavior: HitTestBehavior.opaque,  // 透明部分もタップ検出
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white54),
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Icon(
                                  Icons.photo_library,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
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
