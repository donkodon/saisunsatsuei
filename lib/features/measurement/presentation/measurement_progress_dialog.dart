import 'package:flutter/material.dart';

/// 採寸中の進捗ダイアログ（オプション）
/// 
/// AI採寸がバックグラウンドで実行中であることをユーザーに通知します。
/// Fire & Forget方式のため、このダイアログは表示せずに
/// 保存完了後すぐに画面遷移することを推奨します。
class MeasurementProgressDialog extends StatelessWidget {
  const MeasurementProgressDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'AI採寸中...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'バックグラウンドで処理しています',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            '完了まで約1-2分かかります',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('閉じる'),
        ),
      ],
    );
  }

  /// ダイアログを表示
  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const MeasurementProgressDialog(),
    );
  }

  /// ダイアログを閉じる
  static void hide(BuildContext context) {
    Navigator.of(context).pop();
  }
}
