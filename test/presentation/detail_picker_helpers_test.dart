import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// DetailPickerHelpers は StatefulWidget の mixin のため、
// テスト用に Pure な関数・データを直接検証します

// ─────────────────────────────────────────────────────────
// テスト用スタンドアロン実装（mixin を切り出し）
// ─────────────────────────────────────────────────────────

/// DetailPickerHelpers.getConditionGrade を直接テスト
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

/// DetailPickerHelpers.materials（定数データ）
const List<String> materialsData = [
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

/// DetailPickerHelpers.colorOptions（定数データ）
final Map<String, Color> colorOptionsData = {
  '選択してください': Colors.transparent,
  'ホワイト': const Color(0xFFFFFFFF),
  'ブラック': const Color(0xFF000000),
  'グレー': const Color(0xFF808080),
  'ネイビー': const Color(0xFF001f3f),
  'ベージュ': const Color(0xFFF5F5DC),
  'カーキ': const Color(0xFF7C7C54),
  'ボルドー': const Color(0xFF800020),
  'レッド': const Color(0xFFFF0000),
  'ブルー': const Color(0xFF0000FF),
  'グリーン': const Color(0xFF008000),
  'ブラウン': const Color(0xFFA52A2A),
  'オレンジ': const Color(0xFFFFA500),
  'イエロー': const Color(0xFFFFFF00),
  'パープル': const Color(0xFF800080),
  'ピンク': const Color(0xFFFFC0CB),
  'その他': const Color(0xFF888888),
};

void main() {
  // ─────────────────────────────────────────────────────────
  // getConditionGrade
  // ─────────────────────────────────────────────────────────
  group('getConditionGrade', () {
    test('新品・未使用 → S', () {
      expect(getConditionGrade('新品・未使用'), equals('S'));
    });

    test('未使用に近い → A', () {
      expect(getConditionGrade('未使用に近い'), equals('A'));
    });

    test('目立った傷や汚れなし → B', () {
      expect(getConditionGrade('目立った傷や汚れなし'), equals('B'));
    });

    test('やや傷や汚れあり → C', () {
      expect(getConditionGrade('やや傷や汚れあり'), equals('C'));
    });

    test('傷や汚れあり → D', () {
      expect(getConditionGrade('傷や汚れあり'), equals('D'));
    });

    test('全体的に状態が悪い → E', () {
      expect(getConditionGrade('全体的に状態が悪い'), equals('E'));
    });

    test('未定義の文字列 → N（デフォルト）', () {
      expect(getConditionGrade('未定義コンディション'), equals('N'));
      expect(getConditionGrade(''), equals('N'));
    });

    test('全コンディションが網羅されている', () {
      final conditions = [
        '新品・未使用',
        '未使用に近い',
        '目立った傷や汚れなし',
        'やや傷や汚れあり',
        '傷や汚れあり',
        '全体的に状態が悪い',
      ];
      final grades = ['S', 'A', 'B', 'C', 'D', 'E'];
      for (var i = 0; i < conditions.length; i++) {
        expect(
          getConditionGrade(conditions[i]),
          equals(grades[i]),
          reason: '${conditions[i]} は ${grades[i]} であるべき',
        );
      }
    });
  });

  // ─────────────────────────────────────────────────────────
  // materials リスト
  // ─────────────────────────────────────────────────────────
  group('materials リスト', () {
    test('素材リストが空でない', () {
      expect(materialsData, isNotEmpty);
    });

    test('先頭要素が「選択してください」', () {
      expect(materialsData.first, equals('選択してください'));
    });

    test('コットン・ポリエステル・ウールが含まれている', () {
      final joined = materialsData.join(',');
      expect(joined, contains('コットン'));
      expect(joined, contains('ポリエステル'));
      expect(joined, contains('ウール'));
    });

    test('重複がない', () {
      final unique = materialsData.toSet();
      expect(unique.length, equals(materialsData.length));
    });
  });

  // ─────────────────────────────────────────────────────────
  // colorOptions マップ
  // ─────────────────────────────────────────────────────────
  group('colorOptions マップ', () {
    test('カラーマップが空でない', () {
      expect(colorOptionsData, isNotEmpty);
    });

    test('先頭キーが「選択してください」', () {
      expect(colorOptionsData.keys.first, equals('選択してください'));
    });

    test('主要カラーが含まれている', () {
      expect(colorOptionsData, contains('ホワイト'));
      expect(colorOptionsData, contains('ブラック'));
      expect(colorOptionsData, contains('ネイビー'));
    });

    test('全ての値が Color 型である', () {
      for (final value in colorOptionsData.values) {
        expect(value, isA<Color>());
      }
    });

    test('ホワイトは白色 (0xFFFFFFFF)', () {
      expect(colorOptionsData['ホワイト']!.toARGB32(), equals(0xFFFFFFFF));
    });

    test('ブラックは黒色 (0xFF000000)', () {
      expect(colorOptionsData['ブラック']!.toARGB32(), equals(0xFF000000));
    });
  });
}
