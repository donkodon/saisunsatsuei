import 'package:flutter/material.dart';

/// アプリ全体で使用するカラーオプション
/// 
/// 商品のカラー選択などで共通利用します。
class ColorConstants {
  /// カラー名と実際の色のマッピング
  static final Map<String, Color> colorOptions = {
    '選択してください': Colors.grey[400]!,
    'ホワイト': Colors.white,
    'ブラック': Colors.black,
    'グレー': Colors.grey,
    'ネイビー': const Color(0xFF001f3f),
    'ブルー': Colors.blue,
    'レッド': Colors.red,
    'ピンク': Colors.pink,
    'イエロー': Colors.yellow,
    'グリーン': Colors.green,
    'ブラウン': Colors.brown,
    'ベージュ': const Color(0xFFF5F5DC),
    'オレンジ': Colors.orange,
    'パープル': Colors.purple,
    'カーキ': const Color(0xFF7C7C54),
    'ボルドー': const Color(0xFF800020),
    'その他': Colors.grey[400]!,
  };

  /// カラー名からColor値を取得（存在しない場合はグレーを返す）
  static Color getColor(String colorName) {
    return colorOptions[colorName] ?? Colors.grey[400]!;
  }

  /// カラー名のリストを取得
  static List<String> get colorNames => colorOptions.keys.toList();
}
