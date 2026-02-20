/// 📅 日時ユーティリティ
/// 
/// 日本時間（JST）での日時処理を提供
class DateTimeUtils {
  /// 日本時間（JST）のDateTime文字列を取得
  /// 
  /// フォーマット: "YYYY-MM-DD HH:mm:ss" (24時間制)
  /// 
  /// 例: "2026-02-20 16:30:45"
  /// 
  /// D1データベースのDATETIME型カラムに直接保存可能
  static String getJstNow() {
    // UTC時間を取得して+9時間（JST）
    final jst = DateTime.now().toUtc().add(const Duration(hours: 9));
    
    // YYYY-MM-DD HH:mm:ss 形式に変換
    final year = jst.year.toString().padLeft(4, '0');
    final month = jst.month.toString().padLeft(2, '0');
    final day = jst.day.toString().padLeft(2, '0');
    final hour = jst.hour.toString().padLeft(2, '0');
    final minute = jst.minute.toString().padLeft(2, '0');
    final second = jst.second.toString().padLeft(2, '0');
    
    return '$year-$month-$day $hour:$minute:$second';
  }
  
  /// 日本時間（JST）のDateTime文字列を取得（ミリ秒付き）
  /// 
  /// フォーマット: "YYYY-MM-DD HH:mm:ss.SSS"
  /// 
  /// 例: "2026-02-20 16:30:45.123"
  static String getJstNowWithMillis() {
    final jst = DateTime.now().toUtc().add(const Duration(hours: 9));
    
    final year = jst.year.toString().padLeft(4, '0');
    final month = jst.month.toString().padLeft(2, '0');
    final day = jst.day.toString().padLeft(2, '0');
    final hour = jst.hour.toString().padLeft(2, '0');
    final minute = jst.minute.toString().padLeft(2, '0');
    final second = jst.second.toString().padLeft(2, '0');
    final millis = jst.millisecond.toString().padLeft(3, '0');
    
    return '$year-$month-$day $hour:$minute:$second.$millis';
  }
  
  /// DateTime文字列をJST形式に変換
  /// 
  /// [dateTime] - 変換元のDateTime
  /// 
  /// Returns: "YYYY-MM-DD HH:mm:ss" 形式の文字列
  static String toJstString(DateTime dateTime) {
    final jst = dateTime.toUtc().add(const Duration(hours: 9));
    
    final year = jst.year.toString().padLeft(4, '0');
    final month = jst.month.toString().padLeft(2, '0');
    final day = jst.day.toString().padLeft(2, '0');
    final hour = jst.hour.toString().padLeft(2, '0');
    final minute = jst.minute.toString().padLeft(2, '0');
    final second = jst.second.toString().padLeft(2, '0');
    
    return '$year-$month-$day $hour:$minute:$second';
  }
  
  /// JST文字列からDateTimeオブジェクトに変換
  /// 
  /// [jstString] - "YYYY-MM-DD HH:mm:ss" 形式の文字列
  /// 
  /// Returns: DateTime オブジェクト（JST）
  static DateTime? fromJstString(String jstString) {
    try {
      // "YYYY-MM-DD HH:mm:ss" をパース
      final parts = jstString.split(' ');
      if (parts.length != 2) return null;
      
      final dateParts = parts[0].split('-');
      final timeParts = parts[1].split(':');
      
      if (dateParts.length != 3 || timeParts.length != 3) return null;
      
      final year = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final day = int.parse(dateParts[2]);
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final second = int.parse(timeParts[2]);
      
      // JST として DateTime を作成
      return DateTime(year, month, day, hour, minute, second);
    } catch (e) {
      return null;
    }
  }
}
