import 'package:flutter/material.dart';
import 'package:measure_master/constants.dart';
import 'package:measure_master/features/inventory/domain/image_item.dart';
import 'package:measure_master/features/inventory/presentation/detail_image_widgets.dart';

/// 🎨 詳細画面の画像セクション（カルーセル + 白抜き切替ボタン）
///
/// 責務:
/// - 複数画像のサムネイルカルーセル表示
/// - 白抜き画像の有無に応じた切替ボタン表示
/// - 白抜き表示状態の管理（StatefulWidget）
class DetailScreenImageSection extends StatefulWidget {
  final List<ImageItem>? images;

  const DetailScreenImageSection({
    super.key, 
    this.images,
  });

  @override
  State<DetailScreenImageSection> createState() =>
      _DetailScreenImageSectionState();
}

class _DetailScreenImageSectionState extends State<DetailScreenImageSection>
    with DetailImageWidgets<DetailScreenImageSection> {
  bool _showWhiteBackground = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── サムネイルカルーセル ──────────────────────────────
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              if (widget.images != null && widget.images!.isNotEmpty)
                ...widget.images!.asMap().entries.map((entry) {
                  return buildImageItemThumbnail(
                    imageItem: entry.value,
                    allImages: widget.images,
                    showWhiteBackground: _showWhiteBackground,
                    isMain: entry.key == 0,
                    index: entry.key,
                  );
                })
              else
                buildPlaceholder(isMain: true),
            ],
          ),
        ),

        // ── 白抜き切替ボタン（白抜き画像がある場合のみ） ────────
        if (widget.images != null &&
            widget.images!.any((img) => img.whiteUrl != null))
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Center(
              child: _WhiteToggleButton(
                isActive: _showWhiteBackground,
                onToggle: () {
                  setState(() {
                    _showWhiteBackground = !_showWhiteBackground;
                  });
                },
              ),
            ),
          ),
      ],
    );
  }
}

// ── 白抜き切替ボタン（内部 Widget） ─────────────────────────────
class _WhiteToggleButton extends StatelessWidget {
  final bool isActive;
  final VoidCallback onToggle;

  const _WhiteToggleButton({required this.isActive, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final activeColor = AppConstants.primaryCyan;
    final inactiveColor = Colors.grey[600]!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? activeColor.withValues(alpha: 0.1)
                : Colors.grey[200],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? activeColor : Colors.grey[400]!,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? Icons.check_circle : Icons.circle_outlined,
                size: 18,
                color: isActive ? activeColor : inactiveColor,
              ),
              const SizedBox(width: 6),
              Text(
                isActive ? '白抜き表示中' : '元画像表示中',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? activeColor : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
