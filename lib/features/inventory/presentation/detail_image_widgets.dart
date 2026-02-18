import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:measure_master/constants.dart';
import 'package:measure_master/features/inventory/domain/image_item.dart';
import 'package:measure_master/core/widgets/smart_image_viewer.dart';
import 'package:measure_master/features/camera/presentation/image_preview_screen.dart';

/// detail_screen から切り出した画像・採寸カード系ウィジェット
///
/// 含まれるもの:
/// - buildImageItemThumbnail (画像サムネイル + タップ→プレビュー)
/// - buildPlaceholder (プレースホルダー)
/// - buildMeasureCard (採寸カード)
mixin DetailImageWidgets<T extends StatefulWidget> on State<T> {

  // ────────────────────────────────────────────────────────
  // 画像サムネイル
  // ────────────────────────────────────────────────────────

  /// 画像サムネイルを返す。タップで ImagePreviewScreen に遷移。
  ///
  /// [imageItem]          : 表示する画像アイテム
  /// [allImages]          : 全画像リスト（プレビュー用）
  /// [showWhiteBackground]: 白抜き表示モード
  /// [isMain]             : メイン画像バッジ表示
  /// [index]              : タップ時の初期インデックス
  Widget buildImageItemThumbnail({
    required ImageItem imageItem,
    required List<ImageItem>? allImages,
    required bool showWhiteBackground,
    bool isMain = false,
    int? index,
  }) {
    return TappableSmartImageViewer(
      imageViewer: SmartImageViewer.fromImageItem(
        imageItem: imageItem,
        showWhiteBackground: showWhiteBackground,
        width: 100,
        height: 120,
        fit: BoxFit.cover,
        borderRadius: 12,
        isMain: isMain,
      ),
      onTap: () {
        if (kDebugMode) {
        }

        final imageUrls = <String>[];
        final whiteImageUrls = <String>[];

        if (allImages != null) {
          for (var img in allImages) {
            if (img.url != null) {
              imageUrls.add(img.url!);
              whiteImageUrls.add(img.whiteUrl ?? img.url!);
            }
          }
        }

        if (kDebugMode) {
        }

        if (imageUrls.isNotEmpty && index != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ImagePreviewScreen(
                imageUrls: imageUrls,
                whiteImageUrls:
                    whiteImageUrls.isNotEmpty ? whiteImageUrls : null,
                initialIndex: index,
                heroTag: 'detail_image_$index',
              ),
            ),
          );
        }
      },
    );
  }

  // ────────────────────────────────────────────────────────
  // プレースホルダー
  // ────────────────────────────────────────────────────────

  /// 画像がない場合のプレースホルダー
  Widget buildPlaceholder({bool isMain = false}) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 100,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border.all(
                color: Colors.grey[300]!,
                width: 2,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo, size: 32, color: Colors.grey[400]),
                const SizedBox(height: 4),
                Text(
                  '写真を追加',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ),
        if (isMain)
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'メイン',
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────
  // 採寸カード
  // ────────────────────────────────────────────────────────

  /// AI採寸結果を表示するカード
  Widget buildMeasureCard(String label, String value, bool isVerified) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isVerified ? AppConstants.primaryCyan : Colors.grey[300]!,
          width: isVerified ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isVerified
                  ? AppConstants.primaryCyan
                  : AppConstants.textDark,
            ),
          ),
          if (isVerified) ...[
            const SizedBox(height: 4),
            Icon(Icons.check_circle,
                size: 16, color: AppConstants.primaryCyan),
          ],
        ],
      ),
    );
  }
}
