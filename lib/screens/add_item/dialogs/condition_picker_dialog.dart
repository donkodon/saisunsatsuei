import 'package:flutter/material.dart';
import 'package:measure_master/constants.dart';

/// 商品の状態選択ダイアログ
/// 
/// 使い方:
/// ```dart
/// final selectedCondition = await showConditionPickerDialog(
///   context: context,
///   currentValue: _selectedCondition,
/// );
/// if (selectedCondition != null) {
///   setState(() {
///     _selectedCondition = selectedCondition;
///   });
/// }
/// ```
Future<String?> showConditionPickerDialog({
  required BuildContext context,
  String? currentValue,
}) {
  return showModalBottomSheet<String>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => ConditionPickerDialog(currentValue: currentValue),
  );
}

class ConditionPickerDialog extends StatelessWidget {
  final String? currentValue;

  const ConditionPickerDialog({
    super.key,
    this.currentValue,
  });

  // 商品の状態リスト（定数化）
  static const List<String> _conditions = [
    '選択してください',
    '新品・未使用',
    '未使用に近い',
    '目立った傷や汚れなし',
    'やや傷や汚れあり',
    '傷や汚れあり',
    '全体的に状態が悪い',
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
            "商品の状態を選択",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // 状態リスト
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _conditions.length,
              itemBuilder: (context, index) {
                final condition = _conditions[index];
                final isSelected = currentValue == condition;

                return ListTile(
                  title: Text(condition),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: AppConstants.primaryCyan)
                      : null,
                  onTap: () {
                    // 選択した状態を返す
                    Navigator.pop(context, condition);
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
