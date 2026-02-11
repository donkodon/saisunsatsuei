import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../services/image_cache_service.dart';
import '../models/image_item.dart';

/// 🎨 Phase 5: 統一された画像表示ウィジェット
/// 
/// 全画面で一貫した画像表示ロジックを提供:
/// - ローカルキャッシュチェック（CORS回避）
/// - キャッシュバスティング適用
/// - ネットワークから取得
/// - エラーハンドリング
/// - 白抜き画像対応
class SmartImageViewer extends StatelessWidget {
  /// 画像URL（元画像）
  final String? imageUrl;
  
  /// 白抜き画像URL（オプション）
  final String? whiteImageUrl;
  
  /// 白抜き画像を表示するか
  final bool showWhiteBackground;
  
  /// 画像バイトデータ（新規撮影の場合）
  final Uint8List? imageBytes;
  
  /// 幅
  final double width;
  
  /// 高さ
  final double height;
  
  /// フィット方法
  final BoxFit fit;
  
  /// 角丸半径
  final double borderRadius;
  
  /// プレースホルダーアイコン
  final IconData placeholderIcon;
  
  /// エラーアイコン
  final IconData errorIcon;
  
  /// 背景色
  final Color? backgroundColor;
  
  /// メイン画像フラグ表示
  final bool isMain;
  
  /// メイン画像ラベルテキスト
  final String mainLabel;
  
  const SmartImageViewer({
    super.key,
    this.imageUrl,
    this.whiteImageUrl,
    this.showWhiteBackground = false,
    this.imageBytes,
    this.width = 100,
    this.height = 120,
    this.fit = BoxFit.cover,
    this.borderRadius = 12,
    this.placeholderIcon = Icons.image,
    this.errorIcon = Icons.broken_image,
    this.backgroundColor,
    this.isMain = false,
    this.mainLabel = 'メイン',
  });
  
  /// ImageItemから生成するファクトリコンストラクタ
  factory SmartImageViewer.fromImageItem({
    required ImageItem imageItem,
    bool showWhiteBackground = false,
    double width = 100,
    double height = 120,
    BoxFit fit = BoxFit.cover,
    double borderRadius = 12,
    bool isMain = false,
    String mainLabel = 'メイン',
  }) {
    return SmartImageViewer(
      imageUrl: imageItem.url,
      whiteImageUrl: imageItem.whiteUrl,
      showWhiteBackground: showWhiteBackground,
      imageBytes: imageItem.bytes,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
      isMain: isMain,
      mainLabel: mainLabel,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    
    // 🎨 Phase 5: 表示するURLを決定（白抜き or 元画像）
    final displayUrl = showWhiteBackground && whiteImageUrl != null
        ? whiteImageUrl
        : imageUrl;
    
    // 🔧 優先順位: バイトデータ > URL
    if (imageBytes != null) {
      // バイトデータがある場合（最優先）
      imageWidget = _buildBytesImage();
    } else if (displayUrl != null && displayUrl.isNotEmpty) {
      // URLがある場合
      imageWidget = _buildNetworkImage(displayUrl);
    } else {
      // 何もない場合はプレースホルダー
      imageWidget = _buildPlaceholder();
    }
    
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: imageWidget,
        ),
        // メイン画像バッジ
        if (isMain)
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF00BCD4), // AppConstants.primaryCyan
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                mainLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
  
  /// バイトデータから画像を表示
  Widget _buildBytesImage() {
    return Image.memory(
      imageBytes!,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        if (kDebugMode) {
          debugPrint('❌ SmartImageViewer: バイト画像読み込みエラー: $error');
        }
        return _buildError();
      },
    );
  }
  
  /// ネットワークから画像を表示
  Widget _buildNetworkImage(String url) {
    // 🔧 キャッシュバスティング適用
    final cacheBustedUrl = ImageCacheService.getCacheBustedUrl(url);
    
    return Image.network(
      cacheBustedUrl,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return _buildLoading(loadingProgress);
      },
      errorBuilder: (context, error, stackTrace) {
        if (kDebugMode) {
          debugPrint('❌ SmartImageViewer: 画像読み込みエラー: $error');
          debugPrint('   URL: $url');
        }
        
        // 🎨 Phase 5: 白抜き画像のエラー時は元画像にフォールバック
        if (showWhiteBackground && imageUrl != null && url == whiteImageUrl) {
          if (kDebugMode) {
            debugPrint('⚠️ SmartImageViewer: 白抜き画像が存在しません。元画像を表示します。');
          }
          final fallbackUrl = ImageCacheService.getCacheBustedUrl(imageUrl!);
          return Image.network(
            fallbackUrl,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) => _buildError(),
          );
        }
        
        return _buildError();
      },
    );
  }
  
  /// プレースホルダー表示
  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: backgroundColor ?? Colors.grey[200],
      child: Icon(
        placeholderIcon,
        size: width / 2.5,
        color: Colors.grey[400],
      ),
    );
  }
  
  /// ローディング表示
  Widget _buildLoading(ImageChunkEvent loadingProgress) {
    final progress = loadingProgress.expectedTotalBytes != null
        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
        : null;
    
    return Container(
      width: width,
      height: height,
      color: backgroundColor ?? Colors.grey[100],
      child: Center(
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 2,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00BCD4)),
          ),
        ),
      ),
    );
  }
  
  /// エラー表示
  Widget _buildError() {
    return Container(
      width: width,
      height: height,
      color: backgroundColor ?? Colors.grey[200],
      child: Icon(
        errorIcon,
        size: width / 2.5,
        color: Colors.grey[400],
      ),
    );
  }
}

/// 🎨 Phase 5: SmartImageViewerの拡張版（タップ可能）
class TappableSmartImageViewer extends StatelessWidget {
  final SmartImageViewer imageViewer;
  final VoidCallback? onTap;
  
  const TappableSmartImageViewer({
    super.key,
    required this.imageViewer,
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    if (onTap == null) {
      return imageViewer;
    }
    
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: imageViewer,
    );
  }
}
