import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'dart:typed_data';
import '../services/image_cache_service.dart';

/// 📸 フルスクリーン画像プレビュー画面
/// 
/// 機能:
/// - 画像タップで拡大表示
/// - スワイプで画像切り替え
/// - ピンチズーム対応
/// - ダブルタップでズームイン/アウト
/// - 画像インジケーター表示
/// 
/// 🎨 Phase 5 追加機能:
/// - 白抜き画像の表示切替
class ImagePreviewScreen extends StatefulWidget {
  final List<String> imageUrls;
  final List<String>? whiteImageUrls; // 🎨 Phase 5: 白抜き画像URLリスト
  final int initialIndex;
  final String? heroTag;

  const ImagePreviewScreen({
    super.key,
    required this.imageUrls,
    this.whiteImageUrls, // 🎨 Phase 5: オプション
    this.initialIndex = 0,
    this.heroTag,
  });

  @override
  State<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<ImagePreviewScreen> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showUI = true;
  bool _showWhiteBackground = false; // 🎨 Phase 5: 白抜き表示切替状態

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleUI() {
    setState(() {
      _showUI = !_showUI;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 🎨 Phase 5: 表示するURLリストを決定（白抜き or 元画像）
    final displayUrls = _showWhiteBackground && widget.whiteImageUrls != null
        ? widget.whiteImageUrls!
        : widget.imageUrls;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 画像ギャラリー（スワイプ対応）
          GestureDetector(
            onTap: _toggleUI,
            child: PhotoViewGallery.builder(
              scrollPhysics: const BouncingScrollPhysics(),
              builder: (BuildContext context, int index) {
                return PhotoViewGalleryPageOptions.customChild(
                  child: _buildImage(displayUrls[index], isWhite: _showWhiteBackground),
                  initialScale: PhotoViewComputedScale.contained,
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 3,
                  heroAttributes: widget.heroTag != null && index == widget.initialIndex
                      ? PhotoViewHeroAttributes(tag: widget.heroTag!)
                      : null,
                );
              },
              itemCount: displayUrls.length,
              loadingBuilder: (context, event) => Center(
                child: CircularProgressIndicator(
                  value: event == null
                      ? 0
                      : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
                  color: Colors.white,
                ),
              ),
              backgroundDecoration: const BoxDecoration(
                color: Colors.black,
              ),
              pageController: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
            ),
          ),

          // トップバー（閉じるボタン）
          if (_showUI)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 28),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const Spacer(),
                        // 画像番号表示
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${_currentIndex + 1} / ${widget.imageUrls.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ボトムバー（画像インジケーター + 白抜き切替ボタン）
          if (_showUI)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 🎨 Phase 5: 白抜き切替ボタン（白抜き画像がある場合のみ）
                        if (widget.whiteImageUrls != null && widget.whiteImageUrls!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _showWhiteBackground = !_showWhiteBackground;
                                  });
                                  debugPrint('🎨 Phase 5 Preview: 白抜き表示切替 → ${_showWhiteBackground ? "白抜き" : "元画像"}');
                                },
                                borderRadius: BorderRadius.circular(24),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _showWhiteBackground 
                                        ? Colors.cyan.withOpacity(0.2)
                                        : Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: _showWhiteBackground 
                                          ? Colors.cyan 
                                          : Colors.white.withOpacity(0.5),
                                      width: 2,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _showWhiteBackground 
                                            ? Icons.check_circle 
                                            : Icons.circle_outlined,
                                        size: 20,
                                        color: _showWhiteBackground 
                                            ? Colors.cyan 
                                            : Colors.white,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _showWhiteBackground ? "白抜き表示中" : "元画像表示中",
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: _showWhiteBackground 
                                              ? Colors.cyan 
                                              : Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        
                        // 画像インジケーター（複数画像がある場合のみ）
                        if (widget.imageUrls.length > 1)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              widget.imageUrls.length,
                              (index) => AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: _currentIndex == index ? 24 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _currentIndex == index
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 画像を読み込んで表示
  /// 
  /// 🎨 Phase 5: 白抜き画像のエラーハンドリング対応
  Widget _buildImage(String imageUrl, {bool isWhite = false}) {
    // ネットワーク画像の場合はキャッシュから取得
    if (imageUrl.contains('http')) {
      return FutureBuilder<Uint8List?>(
        future: _loadImageFromCache(imageUrl),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return Image.memory(
              snapshot.data!,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // 🎨 Phase 5: 白抜き画像のエラー時は元画像にフォールバック
                if (isWhite && widget.imageUrls.isNotEmpty) {
                  final fallbackUrl = widget.imageUrls[_currentIndex];
                  debugPrint('⚠️ 白抜き画像が見つかりません。元画像を表示: $fallbackUrl');
                  return _buildImage(fallbackUrl, isWhite: false);
                }
                return _buildErrorWidget(isWhite: isWhite);
              },
            );
          } else if (snapshot.hasError) {
            // 🎨 Phase 5: エラー時のフォールバック
            if (isWhite && widget.imageUrls.isNotEmpty) {
              final fallbackUrl = widget.imageUrls[_currentIndex];
              debugPrint('⚠️ 白抜き画像の読み込みエラー。元画像を表示: $fallbackUrl');
              return _buildImage(fallbackUrl, isWhite: false);
            }
            return _buildErrorWidget(isWhite: isWhite);
          } else {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
        },
      );
    } else {
      // ローカル画像の場合
      return Image.network(
        imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // 🎨 Phase 5: エラー時のフォールバック
          if (isWhite && widget.imageUrls.isNotEmpty) {
            final fallbackUrl = widget.imageUrls[_currentIndex];
            debugPrint('⚠️ 白抜き画像が見つかりません。元画像を表示: $fallbackUrl');
            return _buildImage(fallbackUrl, isWhite: false);
          }
          return _buildErrorWidget(isWhite: isWhite);
        },
      );
    }
  }

  /// キャッシュから画像を読み込み
  Future<Uint8List?> _loadImageFromCache(String imageUrl) async {
    try {
      // cache-bustingパラメータを削除してクリーンなURLを取得
      final cleanUrl = imageUrl.split('?')[0];
      final cachedBytes = ImageCacheService.getCachedImage(cleanUrl);
      
      if (cachedBytes != null) {
        return cachedBytes;
      }
      
      // キャッシュになければネットワークから取得
      // TODO: ネットワーク取得の実装
      return null;
    } catch (e) {
      debugPrint('❌ キャッシュ画像読み込みエラー: $e');
      return null;
    }
  }

  /// エラー表示ウィジェット
  /// 
  /// 🎨 Phase 5: 白抜き画像エラーメッセージ対応
  Widget _buildErrorWidget({bool isWhite = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            size: 64,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            isWhite 
                ? '白抜き画像を読み込めませんでした\n元画像を表示してください'
                : '画像を読み込めませんでした',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
