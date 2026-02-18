import 'package:flutter/material.dart';
import 'package:measure_master/constants.dart';

/// detail_screen から切り出したピッカー・定数ヘルパー
///
/// 含まれるもの:
/// - 素材リスト (_materials)
/// - カラーマップ (_colorOptions)
/// - 素材選択ダイアログ (_showMaterialPicker)
/// - カラー選択ダイアログ (_showColorPicker)
/// - コンディショングレード変換 (_getConditionGrade)
mixin DetailPickerHelpers<T extends StatefulWidget> on State<T> {
  // ────────────────────────────────────────────────────────
  // 定数データ
  // ────────────────────────────────────────────────────────

  final List<String> materials = [
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

  final Map<String, Color> colorOptions = {
    '選択してください': Color(0xFFBDBDBD),
    'ホワイト': Colors.white,
    'ブラック': Colors.black,
    'グレー': Colors.grey,
    'ネイビー': Color(0xFF001f3f),
    'ブルー': Colors.blue,
    'レッド': Colors.red,
    'ピンク': Colors.pink,
    'イエロー': Colors.yellow,
    'グリーン': Colors.green,
    'ブラウン': Colors.brown,
    'ベージュ': Color(0xFFF5F5DC),
    'オレンジ': Colors.orange,
    'パープル': Colors.purple,
    'カーキ': Color(0xFF7C7C54),
    'ボルドー': Color(0xFF800020),
    'その他': Color(0xFFBDBDBD),
  };

  // ────────────────────────────────────────────────────────
  // ピッカー系メソッド（override して setState を使う側が実装）
  // ────────────────────────────────────────────────────────

  /// 素材選択ダイアログを表示する
  /// [currentMaterial]: 現在の選択値
  /// [onSelected]: 選択後のコールバック
  void showMaterialPickerDialog(
    BuildContext ctx,
    String currentMaterial,
    void Function(String) onSelected,
  ) {
    showDialog(
      context: ctx,
      builder: (context) => AlertDialog(
        title: const Text('素材を選択'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: materials.length,
            itemBuilder: (context, index) {
              final material = materials[index];
              return ListTile(
                title: Text(material),
                selected: material == currentMaterial,
                selectedColor: AppConstants.primaryCyan,
                onTap: () {
                  onSelected(material);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  /// カラー選択ダイアログを表示する
  /// [currentColor]: 現在の選択値
  /// [onSelected]: 選択後のコールバック (colorName, color)
  void showColorPickerDialog(
    BuildContext ctx,
    String currentColor,
    void Function(String colorName, Color color) onSelected,
  ) {
    showDialog(
      context: ctx,
      builder: (context) => AlertDialog(
        title: const Text('カラーを選択'),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: colorOptions.length,
            itemBuilder: (context, index) {
              final colorName = colorOptions.keys.elementAt(index);
              final color = colorOptions[colorName]!;
              final isSelected = currentColor == colorName;
              return GestureDetector(
                onTap: () {
                  onSelected(colorName, color);
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? AppConstants.primaryCyan
                          : Colors.grey[300]!,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      colorName,
                      style: TextStyle(
                        fontSize: 10,
                        color: color.computeLuminance() > 0.5
                            ? Colors.black
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────
  // ユーティリティ
  // ────────────────────────────────────────────────────────

  /// コンディション文字列をグレード記号に変換
  String getConditionGrade(String condition) {
    switch (condition) {
      case '新品・未使用':
        return 'S';
      case '未使用に近い':
        return 'A';
      case '目立った傷や汚れなし':
        return 'B';
      case 'やや傷や汚れあり':
        return 'C';
      case '傷や汚れあり':
        return 'D';
      case '全体的に状態が悪い':
        return 'E';
      default:
        return 'N';
    }
  }
}
