import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:measure_master/constants.dart';
import 'package:measure_master/features/inventory/domain/image_item.dart';
import 'package:measure_master/core/services/image_cache_service.dart';

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
    if (imageItem.bytes != null) {
      return Image.memory(
        imageItem.bytes!,
        width: 100,
        height: 120,
        fit: BoxFit.cover,
      );
    } else if (imageItem.file != null) {
      return kIsWeb
          ? Image.network(
              imageItem.file!.path,
              width: 100,
              height: 120,
              fit: BoxFit.cover,
              cacheWidth: 200,   // ⚡ Retina対応(2x)
              cacheHeight: 240,
            )
          : Image.file(
              File(imageItem.file!.path),
              width: 100,
              height: 120,
              fit: BoxFit.cover,
            );
    } else if (imageItem.url != null) {
      final cacheBustedUrl =
          ImageCacheService.getCacheBustedUrl(imageItem.url!);
      return Image.network(
        cacheBustedUrl,
        width: 100,
        height: 120,
        fit: BoxFit.cover,
        cacheWidth: 200,   // ⚡ Retina対応(2x)
        cacheHeight: 240,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: 100, height: 120,
            color: Colors.grey[200],
            child: const Center(child: SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          if (kDebugMode) debugPrint('❌ 画像読み込みエラー: $error');
          return Container(
            width: 100,
            height: 120,
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
