import 'package:flutter/material.dart';
import 'package:measure_master/constants.dart';

/// カテゴリ選択ダイアログ
/// 
/// 使い方:
/// ```dart
/// final selectedCategory = await showCategoryPickerDialog(
///   context: context,
///   currentValue: _selectedCategory,
/// );
/// if (selectedCategory != null) {
///   setState(() {
///     _selectedCategory = selectedCategory;
///   });
/// }
/// ```
Future<String?> showCategoryPickerDialog({
  required BuildContext context,
  String? currentValue,
}) {
  return showModalBottomSheet<String>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => CategoryPickerDialog(currentValue: currentValue),
  );
}

class CategoryPickerDialog extends StatelessWidget {
  final String? currentValue;

  const CategoryPickerDialog({
    super.key,
    this.currentValue,
  });

  // カテゴリリスト（定数化）
  static const List<String> _categories = [
    '選択してください',
    'トップス',
    'ジャケット/アウター',
    'パンツ',
    'スカート',
    'ワンピース',
    'シューズ',
    'バッグ',
    'アクセサリー',
    'その他',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
            "カテゴリを選択",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // カテゴリリスト
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = currentValue == category;

                return ListTile(
                  title: Text(category),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: AppConstants.primaryCyan)
                      : null,
                  onTap: () {
                    // 選択したカテゴリを返す
                    Navigator.pop(context, category);
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
