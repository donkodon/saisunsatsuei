import 'package:flutter/material.dart';
import 'package:measure_master/constants.dart';
import 'package:measure_master/constants/color_constants.dart';

/// カラー選択の結果
class ColorPickerResult {
  final String colorName;
  final Color colorPreview;

  const ColorPickerResult({
    required this.colorName,
    required this.colorPreview,
  });
}

/// カラー選択ダイアログ
/// 
/// 使い方:
/// ```dart
/// final result = await showColorPickerDialog(
///   context: context,
///   currentValue: _selectedColor,
///   currentPreview: _colorPreview,
/// );
/// if (result != null) {
///   setState(() {
///     _selectedColor = result.colorName;
///     _colorPreview = result.colorPreview;
///   });
/// }
/// ```
Future<ColorPickerResult?> showColorPickerDialog({
  required BuildContext context,
  String? currentValue,
  Color? currentPreview,
}) {
  return showModalBottomSheet<ColorPickerResult>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => ColorPickerDialog(
      currentValue: currentValue,
      currentPreview: currentPreview,
    ),
  );
}

class ColorPickerDialog extends StatefulWidget {
  final String? currentValue;
  final Color? currentPreview;

  const ColorPickerDialog({
    super.key,
    this.currentValue,
    this.currentPreview,
  });

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    // 検索フィルタリング
    final filteredColors = _searchQuery.isEmpty
        ? ColorConstants.colorOptions.entries.toList()
        : ColorConstants.colorOptions.entries
            .where((entry) => entry.key.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ハンドルバー
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // タイトル
          const Text(
            "カラーを選択",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // 検索フィールド
          TextField(
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'カラー名で検索 or 自由入力...',
              prefixIcon: const Icon(Icons.search, color: AppConstants.primaryCyan),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppConstants.borderGrey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppConstants.primaryCyan, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            onSubmitted: (value) {
              // 自由入力 - カスタムカラー
              if (value.isNotEmpty && !ColorConstants.colorOptions.containsKey(value)) {
                Navigator.pop(
                  context,
                  ColorPickerResult(
                    colorName: value,
                    colorPreview: Colors.grey[400]!, // カスタム入力のデフォルト色
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 16),

          // 自由入力オプション表示
          if (_searchQuery.isNotEmpty && filteredColors.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppConstants.primaryCyan.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: () {
                  Navigator.pop(
                    context,
                    ColorPickerResult(
                      colorName: _searchQuery,
                      colorPreview: Colors.grey[400]!,
                    ),
                  );
                },
                child: Row(
                  children: [
                    const Icon(Icons.add_circle_outline, color: AppConstants.primaryCyan),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '"$_searchQuery" として追加',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppConstants.primaryCyan,
                            ),
                          ),
                          const Text(
                            'タップまたはEnterで確定',
                            style: TextStyle(fontSize: 12, color: AppConstants.textGrey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),

          // カラーリスト
          Expanded(
            child: ListView.builder(
              itemCount: filteredColors.length,
              itemBuilder: (context, index) {
                final entry = filteredColors[index];
                final isSelected = widget.currentValue == entry.key;

                return ListTile(
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: entry.value,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey[300]!, width: 2),
                    ),
                  ),
                  title: Text(entry.key),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: AppConstants.primaryCyan)
                      : null,
                  onTap: () {
                    // 選択したカラーを返す
                    Navigator.pop(
                      context,
                      ColorPickerResult(
                        colorName: entry.key,
                        colorPreview: entry.value,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
