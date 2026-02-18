import 'package:flutter/material.dart';
import 'package:measure_master/constants.dart';

/// アプリ全体で統一された SnackBar / Dialog ユーティリティ。
///
/// 使い方:
///   AppFeedback.showSuccess(context, 'メッセージ');
///   AppFeedback.showError(context, 'エラー内容');
///   AppFeedback.showWarning(context, '警告メッセージ');
///   AppFeedback.showInfo(context, 'お知らせ');
///   final ok = await AppFeedback.showConfirm(context, title: '確認', message: '〜しますか？');
///   await AppFeedback.showAlert(context, title: 'タイトル', message: '内容');
abstract class AppFeedback {
  // ──────────────────────────────────────────────
  // SnackBar 系
  // ──────────────────────────────────────────────

  /// ✅ 成功（緑）
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _show(
      context,
      message: message,
      backgroundColor: AppConstants.successGreen,
      icon: Icons.check_circle,
      duration: duration,
    );
  }

  /// ❌ エラー（赤）
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(
      context,
      message: message,
      backgroundColor: Colors.red,
      icon: Icons.error,
      duration: duration,
    );
  }

  /// ⚠️ 警告（オレンジ）
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 5),
  }) {
    _show(
      context,
      message: message,
      backgroundColor: Colors.orange,
      icon: Icons.warning_amber_rounded,
      duration: duration,
    );
  }

  /// ℹ️ 情報（デフォルト色）
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 現在の SnackBar を非表示にして新しい SnackBar を表示
  static void replaceWith(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    _show(
      context,
      message: message,
      backgroundColor: backgroundColor,
      duration: duration,
    );
  }

  // ──────────────────────────────────────────────
  // Dialog 系
  // ──────────────────────────────────────────────

  /// 確認ダイアログ（キャンセル / OK）
  /// 戻り値: OK → true、キャンセル → false
  static Future<bool> showConfirm(
    BuildContext context, {
    required String title,
    required String message,
    String cancelLabel = 'キャンセル',
    String confirmLabel = 'OK',
    Color confirmColor = Colors.red,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: confirmColor),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// 情報ダイアログ（OK のみ）
  static Future<void> showAlert(
    BuildContext context, {
    required String title,
    required String message,
    String okLabel = 'OK',
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(okLabel),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // 内部ヘルパー
  // ──────────────────────────────────────────────

  static void _show(
    BuildContext context, {
    required String message,
    Color? backgroundColor,
    IconData? icon,
    Duration duration = const Duration(seconds: 2),
  }) {
    final content = icon != null
        ? Row(
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          )
        : Text(message) as Widget;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: content,
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
