import 'package:flutter_test/flutter_test.dart';
import 'package:measure_master/core/utils/date_utils.dart';

void main() {
  group('DateTimeUtils', () {
    test('getJstNow returns correct format', () {
      final result = DateTimeUtils.getJstNow();
      
      // フォーマット検証: "YYYY-MM-DD HH:mm:ss"
      final regex = RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$');
      expect(regex.hasMatch(result), true);
      
      // 日付部分の検証
      final parts = result.split(' ');
      expect(parts.length, 2);
      
      final dateParts = parts[0].split('-');
      expect(dateParts.length, 3);
      expect(dateParts[0].length, 4); // YYYY
      expect(dateParts[1].length, 2); // MM
      expect(dateParts[2].length, 2); // DD
      
      // 時刻部分の検証
      final timeParts = parts[1].split(':');
      expect(timeParts.length, 3);
      expect(timeParts[0].length, 2); // HH
      expect(timeParts[1].length, 2); // mm
      expect(timeParts[2].length, 2); // ss
    });

    test('getJstNowWithMillis returns correct format with milliseconds', () {
      final result = DateTimeUtils.getJstNowWithMillis();
      
      // フォーマット検証: "YYYY-MM-DD HH:mm:ss.SSS"
      final regex = RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}$');
      expect(regex.hasMatch(result), true);
    });

    test('toJstString converts DateTime to JST string', () {
      final dateTime = DateTime(2026, 2, 20, 7, 30, 45); // UTC
      final result = DateTimeUtils.toJstString(dateTime);
      
      // UTC + 9時間 = JST
      expect(result, '2026-02-20 16:30:45');
    });

    test('fromJstString parses JST string correctly', () {
      const jstString = '2026-02-20 16:30:45';
      final result = DateTimeUtils.fromJstString(jstString);
      
      expect(result, isNotNull);
      expect(result!.year, 2026);
      expect(result.month, 2);
      expect(result.day, 20);
      expect(result.hour, 16);
      expect(result.minute, 30);
      expect(result.second, 45);
    });

    test('fromJstString returns null for invalid format', () {
      expect(DateTimeUtils.fromJstString('invalid'), null);
      expect(DateTimeUtils.fromJstString('2026-02-20'), null);
      expect(DateTimeUtils.fromJstString('16:30:45'), null);
    });

    test('JST conversion maintains 9 hours offset from UTC', () {
      // 現在時刻のUTC版を取得
      final nowUtc = DateTime.now().toUtc();
      
      // JST文字列を取得
      final jstString = DateTimeUtils.getJstNow();
      
      // JST文字列をパース
      final jstParsed = DateTimeUtils.fromJstString(jstString);
      
      expect(jstParsed, isNotNull);
      
      // JST = UTC + 9時間の検証（秒単位の誤差を許容）
      final utcPlus9 = nowUtc.add(const Duration(hours: 9));
      final difference = jstParsed!.difference(utcPlus9).inSeconds.abs();
      expect(difference, lessThan(2)); // 2秒以内の誤差を許容
    });

    test('JST time format uses 24-hour clock', () {
      // 深夜1時のテスト
      final midnight = DateTime(2026, 2, 20, 16, 0, 0); // UTC 16:00 = JST 01:00 (翌日)
      final result = DateTimeUtils.toJstString(midnight);
      
      // 時刻部分を抽出
      final timePart = result.split(' ')[1];
      final hour = int.parse(timePart.split(':')[0]);
      
      // 24時間制なので0-23の範囲
      expect(hour, greaterThanOrEqualTo(0));
      expect(hour, lessThan(24));
    });

    test('Leading zeros are preserved in date components', () {
      final result = DateTimeUtils.getJstNow();
      
      // 各コンポーネントが2桁（年は4桁）であることを確認
      final parts = result.split(' ');
      final dateParts = parts[0].split('-');
      final timeParts = parts[1].split(':');
      
      // 月・日・時・分・秒は必ず2桁
      expect(dateParts[1].length, 2); // 月
      expect(dateParts[2].length, 2); // 日
      expect(timeParts[0].length, 2); // 時
      expect(timeParts[1].length, 2); // 分
      expect(timeParts[2].length, 2); // 秒
    });
  });
}
