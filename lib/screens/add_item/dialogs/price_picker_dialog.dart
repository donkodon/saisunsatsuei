import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, debugPrint;
import 'package:flutter/services.dart';
import 'package:measure_master/constants.dart';

/// 価格入力ダイアログ
/// 
/// 使い方:
/// ```dart
/// final newPrice = await showPricePickerDialog(
///   context: context,
///   currentValue: _priceController.text,
/// );
/// if (newPrice != null) {
///   setState(() {
///     _priceController.text = newPrice;
///   });
/// }
/// ```
Future<String?> showPricePickerDialog({
  required BuildContext context,
  String? currentValue,
}) {
  final tempController = TextEditingController(text: currentValue);

  return showDialog<String>(
    context: context,
    builder: (context) => PricePickerDialog(tempController: tempController),
  );
}

class PricePickerDialog extends StatefulWidget {
  final TextEditingController tempController;

  const PricePickerDialog({
    super.key,
    required this.tempController,
  });

  @override
  State<PricePickerDialog> createState() => _PricePickerDialogState();
}

class _PricePickerDialogState extends State<PricePickerDialog> {
  late FocusNode _focusNode;
  bool _hasFocused = false; // フォーカス済みフラグ

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();

    // フォーカスリスナーを追加（デバッグ用）
    _focusNode.addListener(() {
      if (kDebugMode) {
        debugPrint('🔍 Price TextField focus: ${_focusNode.hasFocus}');
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ビルド後にフォーカスを設定（1回だけ）
    if (!_hasFocused) {
      _hasFocused = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_focusNode.hasFocus) {
          _focusNode.requestFocus();
          // 少し遅延させてから全選択
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted && widget.tempController.text.isNotEmpty) {
              widget.tempController.selection = TextSelection(
                baseOffset: 0,
                extentOffset: widget.tempController.text.length,
              );
            }
          });
        }
      });
    }

    return AlertDialog(
      title: const Text("販売価格を入力"),
      content: SizedBox(
        width: 280, // 固定幅を設定
        child: TextField(
          controller: widget.tempController,
          focusNode: _focusNode,
          keyboardType: kIsWeb ? TextInputType.text : TextInputType.number, // Web環境ではtextに変更
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autofocus: false, // autofocusを無効化（手動でフォーカス管理）
          enableInteractiveSelection: true, // 選択を有効化
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          onChanged: (value) {
            // 入力変更をログ出力（デバッグ用）
            if (kDebugMode) {
              debugPrint('💰 Price input changed: $value');
            }
          },
          decoration: InputDecoration(
            prefixText: "¥ ",
            prefixStyle: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppConstants.textDark,
            ),
            hintText: "0",
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppConstants.primaryCyan, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppConstants.primaryCyan, width: 2),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("キャンセル"),
        ),
        ElevatedButton(
          onPressed: () {
            // 入力値を返す
            Navigator.pop(context, widget.tempController.text);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.primaryCyan,
          ),
          child: const Text("確定", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
