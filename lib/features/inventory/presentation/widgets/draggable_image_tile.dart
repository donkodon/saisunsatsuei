import 'package:flutter/material.dart';
import 'package:measure_master/constants.dart';
import 'package:measure_master/features/inventory/domain/image_item.dart';
import 'package:measure_master/core/utils/app_feedback.dart';

/// 🎨 ドラッグ可能な画像タイル
///
/// 責務:
/// - 画像のサムネイル表示
/// - ドラッグハンドル表示
/// - 順番バッジ表示
/// - 削除ボタン
class DraggableImageTile extends StatelessWidget {
  final ImageItem imageItem;
  final int index;
  final VoidCallback onDelete;
  final Widget Function(ImageItem) imageBuilder;

  const DraggableImageTile({
    super.key,
    required this.imageItem,
    required this.index,
    required this.onDelete,
    required this.imageBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final isMain = index == 0;

    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          // ── 画像本体 ──────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageBuilder(imageItem),
          ),

          // ── ドラッグハンドル（左下） ────────────────
          Positioned(
            bottom: 4,
            left: 4,
            child: _DragHandle(),
          ),

          // ── 順番バッジ（左上） ────────────────────
          Positioned(
            top: 4,
            left: 4,
            child: _SequenceBadge(
              sequence: index + 1,
              isMain: isMain,
            ),
          ),

          // ── 削除ボタン（右上） ────────────────────
          Positioned(
            top: 4,
            right: 4,
            child: _DeleteButton(
              onTap: () {
                onDelete();
                AppFeedback.showWarning(
                  context,
                  '画像を削除しました',
                  duration: const Duration(seconds: 2),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// ドラッグハンドル
class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(
        Icons.drag_indicator,
        color: Colors.white,
        size: 16,
      ),
    );
  }
}

/// 順番バッジ
class _SequenceBadge extends StatelessWidget {
  final int sequence;
  final bool isMain;

  const _SequenceBadge({
    required this.sequence,
    required this.isMain,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isMain
            ? AppConstants.primaryCyan
            : Colors.black.withValues(alpha: 0.6),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$sequence',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// 削除ボタン
class _DeleteButton extends StatelessWidget {
  final VoidCallback onTap;

  const _DeleteButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.close,
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }
}
