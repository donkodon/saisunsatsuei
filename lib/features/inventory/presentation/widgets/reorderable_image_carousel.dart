import 'package:flutter/material.dart';
import 'package:measure_master/features/inventory/domain/image_item.dart';
import 'package:measure_master/features/inventory/presentation/widgets/draggable_image_tile.dart';
import 'package:measure_master/core/utils/image_reorder_helper.dart';

/// 🔄 並び替え可能な画像カルーセル
///
/// 責務:
/// - ReorderableListViewでドラッグ&ドロップ実装
/// - 画像の順番変更ロジック
/// - ドラッグ中のアニメーション
class ReorderableImageCarousel extends StatelessWidget {
  final List<ImageItem> images;
  final Function(List<ImageItem>) onReorder;
  final Function(int) onDelete;
  final Widget Function(ImageItem) imageBuilder;
  final double height;

  const ReorderableImageCarousel({
    super.key,
    required this.images,
    required this.onReorder,
    required this.onDelete,
    required this.imageBuilder,
    this.height = 120,
  });

  /// ドラッグ&ドロップで順番変更
  void _handleReorder(int oldIndex, int newIndex) {
    final reorderedImages = ImageReorderHelper.reorderImages(
      images,
      oldIndex,
      newIndex,
    );
    onReorder(reorderedImages);
  }

  /// ドラッグ中のアニメーション
  Widget _buildProxyDecorator(
    Widget child,
    int index,
    Animation<double> animation,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final double animValue = Curves.easeInOut.transform(animation.value);
        final double scale = 1.0 + (animValue * 0.1);
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: 0.8,
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: height,
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        onReorder: _handleReorder,
        proxyDecorator: _buildProxyDecorator,
        itemBuilder: (context, index) {
          final imageItem = images[index];
          
          return DraggableImageTile(
            key: ValueKey(imageItem.id),
            imageItem: imageItem,
            index: index,
            onDelete: () => onDelete(index),
            imageBuilder: imageBuilder,
          );
        },
      ),
    );
  }
}
