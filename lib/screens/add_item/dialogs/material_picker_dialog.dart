import 'package:flutter/material.dart';
import 'package:measure_master/constants.dart';

/// 素材選択ダイアログ
/// 
/// 使い方:
/// ```dart
/// final selectedMaterial = await showMaterialPickerDialog(
///   context: context,
///   currentValue: _selectedMaterial,
/// );
/// if (selectedMaterial != null) {
///   setState(() {
///     _selectedMaterial = selectedMaterial;
///   });
/// }
/// ```
Future<String?> showMaterialPickerDialog({
  required BuildContext context,
  String? currentValue,
}) {
  return showModalBottomSheet<String>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => MaterialPickerDialog(currentValue: currentValue),
  );
}

class MaterialPickerDialog extends StatelessWidget {
  final String? currentValue;

  const MaterialPickerDialog({
    super.key,
    this.currentValue,
  });

  // 素材リスト（定数化）
  static const List<String> _materials = [
    '選択してください',
    'コットン 100%',
    'ポリエステル 100%',
    'コットン 80% / ポリエステル 20%',
    'ウール 100%',
    'ナイロン 100%',
    'レザー',
    'デニム',
    'リネン 100%',
    'シルク 100%',
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
            "素材を選択",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // 素材リスト
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _materials.length,
              itemBuilder: (context, index) {
                final material = _materials[index];
                final isSelected = currentValue == material;

                return ListTile(
                  title: Text(material),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: AppConstants.primaryCyan)
                      : null,
                  onTap: () {
                    // 選択した素材を返す
                    Navigator.pop(context, material);
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
