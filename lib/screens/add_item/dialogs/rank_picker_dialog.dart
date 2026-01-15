import 'package:flutter/material.dart';
import 'package:measure_master/constants.dart';

/// 商品ランク選択ダイアログ
/// 
/// 使い方:
/// ```dart
/// final selectedRank = await showRankPickerDialog(
///   context: context,
///   currentValue: _selectedRank,
/// );
/// if (selectedRank != null) {
///   setState(() {
///     _selectedRank = selectedRank;
///   });
/// }
/// ```
Future<String?> showRankPickerDialog({
  required BuildContext context,
  String? currentValue,
}) {
  return showModalBottomSheet<String>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => RankPickerDialog(currentValue: currentValue),
  );
}

class RankPickerDialog extends StatelessWidget {
  final String? currentValue;

  const RankPickerDialog({
    super.key,
    this.currentValue,
  });

  // 商品ランクリスト（定数化）
  static const List<String> _ranks = [
    '選択してください',
    'S',
    'A',
    'B',
    'C',
    'D',
    'E',
    'N',
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
            "商品ランクを選択",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // 説明テキスト
          const Text(
            "L列のデータに対応",
            style: TextStyle(fontSize: 12, color: AppConstants.textGrey),
          ),
          const SizedBox(height: 16),

          // ランクリスト
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _ranks.length,
              itemBuilder: (context, index) {
                final rank = _ranks[index];
                final isSelected = currentValue == rank;

                return ListTile(
                  title: Text(rank),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: AppConstants.primaryCyan)
                      : null,
                  onTap: () {
                    // 選択したランクを返す
                    Navigator.pop(context, rank);
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
