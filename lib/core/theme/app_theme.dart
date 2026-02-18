import 'package:flutter/material.dart';
import 'package:measure_master/constants.dart';

/// アプリ共通テーマ定義
/// 実際のテーマ適用は main.dart の MaterialApp.theme で行う
class AppTheme {
  // ⚡ GoogleFonts.interTextTheme() を削除
  //    AppConstants.notoSansJp（constants.dart）に統一することで
  //    フォントの二重ロードを解消
  static ThemeData get main => ThemeData(
    primaryColor: AppConstants.primaryCyan,
    scaffoldBackgroundColor: AppConstants.backgroundLight,
    colorScheme: ColorScheme.fromSwatch().copyWith(
      primary: AppConstants.primaryCyan,
      secondary: AppConstants.primaryCyan,
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
    ),
  );
}
