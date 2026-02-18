import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:measure_master/constants.dart';
import 'package:measure_master/features/inventory/domain/image_item.dart';

/// AddItemScreen で使われる純粋 UI ビルダーを mixin として切り出し。
///
/// - 状態の読み取りのみ行い、setState は呼ばない
/// - 呼び出し元（_AddItemScreenState）から必要な値をパラメータで受け取る
mixin AddItemFormFieldsMixin<T extends StatefulWidget> on State<T> {
  // ─────────────────────────────────────────────
  // テキスト入力フィールド
  // ─────────────────────────────────────────────

  Widget buildInputField(
    String label,
    TextEditingController controller,
    String hint,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: AppConstants.textGrey)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: TextFormField(
            controller: controller,
            style: TextStyle(fontSize: 16, color: AppConstants.textDark),
            enableInteractiveSelection: true,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: AppConstants.textGrey, fontSize: 16),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // ブランド入力フィールド（タップでピッカー）
  // ─────────────────────────────────────────────

  Widget buildBrandField({
    required TextEditingController brandController,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ブランド', style: TextStyle(fontSize: 12, color: AppConstants.textGrey)),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    brandController.text.isEmpty
                        ? 'ブランドを選択...'
                        : brandController.text,
                    style: TextStyle(
                      fontSize: 16,
                      color: brandController.text.isEmpty
                          ? AppConstants.textGrey
                          : AppConstants.textDark,
                    ),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: AppConstants.textGrey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // 選択タイル（カテゴリ・状態など）
  // ─────────────────────────────────────────────

  Widget buildSelectTile(
    String label,
    String value,
    VoidCallback onTap, {
    bool isPlaceholder = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            Row(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: isPlaceholder
                        ? AppConstants.textGrey
                        : AppConstants.primaryCyan,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: AppConstants.textGrey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // スイッチタイル（AI採寸など）
  // ─────────────────────────────────────────────

  Widget buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12, color: AppConstants.textGrey)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppConstants.primaryCyan.withValues(alpha: 0.5),
            activeThumbColor: AppConstants.primaryCyan,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // カラー選択タイル（プレビュー付き）
  // ─────────────────────────────────────────────

  Widget buildColorSelectTile({
    required String selectedColor,
    required Color colorPreview,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('カラー',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Row(
              children: [
                Text(
                  selectedColor,
                  style: TextStyle(
                      color: AppConstants.primaryCyan, fontSize: 16),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: colorPreview,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: AppConstants.textGrey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 画像サムネイルウィジェット
  // ─────────────────────────────────────────────

  /// ImageItem から表示用 Widget を生成する。
  Widget buildImageWidget(ImageItem imageItem) {
    // ⚡ RepaintBoundaryでドラッグ時の再描画を最適化
    return RepaintBoundary(
      child: _buildImageContent(imageItem),
    );
  }

  Widget _buildImageContent(ImageItem imageItem) {
    if (imageItem.bytes != null) {
      return Image.memory(
        imageItem.bytes!,
        width: 100,
        height: 120,
        fit: BoxFit.cover,
        gaplessPlayback: true, // ⚡ スムーズな画像切替
      );
    } else if (imageItem.file != null) {
      return kIsWeb
          ? CachedNetworkImage(
              imageUrl: imageItem.file!.path,
              width: 100,
              height: 120,
              fit: BoxFit.cover,
              memCacheWidth: 200,  // ⚡ メモリキャッシュ
              memCacheHeight: 240,
              placeholder: (context, url) => Container(
                width: 100, height: 120,
                color: Colors.grey[200],
              ),
              errorWidget: (context, url, error) => Container(
                width: 100, height: 120,
                color: Colors.grey[200],
                child: Icon(Icons.broken_image,
                    size: 40, color: Colors.grey[400]),
              ),
            )
          : Image.file(
              File(imageItem.file!.path),
              width: 100,
              height: 120,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            );
    } else if (imageItem.url != null) {
      // ⚡ CachedNetworkImageで確実にキャッシュ
      return CachedNetworkImage(
        imageUrl: imageItem.url!,
        width: 100,
        height: 120,
        fit: BoxFit.cover,
        memCacheWidth: 200,  // ⚡ メモリキャッシュ
        memCacheHeight: 240,
        placeholder: (context, url) => Container(
          width: 100, height: 120,
          color: Colors.grey[200],
        ),
        errorWidget: (context, url, error) {
          if (kDebugMode) debugPrint('❌ 画像読み込みエラー: $error');
          return Container(
            width: 100, height: 120,
            color: Colors.grey[200],
            child: Icon(Icons.broken_image,
                size: 40, color: Colors.grey[400]),
          );
        },
      );
    } else {
      return Container(
        width: 100,
        height: 120,
        color: Colors.grey[200],
        child: Icon(Icons.image, size: 40, color: Colors.grey[400]),
      );
    }
  }
}
