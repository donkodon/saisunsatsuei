import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:image_picker/image_picker.dart';
import 'package:measure_master/constants.dart';
import 'package:measure_master/core/utils/app_feedback.dart';
import 'package:measure_master/features/ocr/logic/ocr_service.dart';
import 'package:measure_master/features/ocr/domain/ocr_result.dart';

/// AddItemScreen の OCR 機能（タグ読み取り）を mixin として切り出し。
///
/// 依存する State フィールド:
///   - `_brandController` (TextEditingController)
///   - `_selectedMaterial` (String)
///   - `_sizeController`  (TextEditingController)
///
/// これらのフィールドは実装クラスが提供する抽象ゲッターで参照する。
mixin AddItemOcrMixin<T extends StatefulWidget> on State<T> {
  // ── 実装クラスが提供するフィールドへの参照 ──────────────
  TextEditingController get ocrBrandController;
  TextEditingController get ocrSizeController;
  TextEditingController get ocrMaterialController; // 🆕 フリー入力対応
  // ────────────────────────────────────────────────────────

  // ─────────────────────────────────────────────
  // OCR プロセス開始
  // ─────────────────────────────────────────────

  /// カメラ起動 → OCR 解析 → 結果ダイアログ表示。
  Future<void> startOcrProcess() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (photo == null) {
      if (kDebugMode) debugPrint('❌ 撮影がキャンセルされました');
      return;
    }

    try {
      // ローディング SnackBar を直接表示（OCR 専用の長時間表示）
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 16),
              Text('🔍 タグを解析中...'),
            ],
          ),
          duration: Duration(hours: 1),
          backgroundColor: AppConstants.primaryCyan,
          behavior: SnackBarBehavior.floating,
        ),
      );

      final imageBytes = await photo.readAsBytes();
      final ocrResult = await OcrService().analyzeTag(imageBytes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      _showOcrResultDialog(ocrResult);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      AppFeedback.showError(context, '❌ OCR解析エラー: ${e.toString()}');
      if (kDebugMode) debugPrint('❌ OCR解析エラー: $e');
    }
  }

  // ─────────────────────────────────────────────
  // OCR 結果ダイアログ
  // ─────────────────────────────────────────────

  void _showOcrResultDialog(OcrResult ocrResult) {
    final brand = ocrResult.brand ?? '';
    final material = ocrResult.material ?? '';
    final country = ocrResult.country ?? '';
    final size = ocrResult.size ?? '';
    final confidence = ocrResult.confidence;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: AppConstants.successGreen),
            const SizedBox(width: 8),
            const Text('OCR解析結果'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (brand.isNotEmpty) _buildResultRow('ブランド', brand),
            if (material.isNotEmpty) _buildResultRow('素材', material),
            if (country.isNotEmpty) _buildResultRow('原産国', country),
            if (size.isNotEmpty) _buildResultRow('サイズ', size),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: confidence > 0.7
                    ? Colors.green[50]
                    : Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    confidence > 0.7
                        ? Icons.check_circle
                        : Icons.warning,
                    size: 16,
                    color: confidence > 0.7 ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '信頼度: ${(confidence * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: confidence > 0.7
                          ? Colors.green[700]
                          : Colors.orange[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('キャンセル',
                style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              // 結果をフォームに反映（setState は呼び出し元 State が行う）
              setState(() {
                if (brand.isNotEmpty) ocrBrandController.text = brand;
                if (material.isNotEmpty) ocrMaterialController.text = material; // 🆕 フリー入力対応
                if (size.isNotEmpty) ocrSizeController.text = size;
              });
              Navigator.pop(ctx);
              AppFeedback.showSuccess(context, '✅ タグ情報を登録しました');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryCyan,
            ),
            child: const Text('登録する',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // OCR 結果行ウィジェット（ダイアログ内）
  // ─────────────────────────────────────────────

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppConstants.textGrey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  fontSize: 14, color: AppConstants.textDark),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // OCR ボタン ウィジェット
  // ─────────────────────────────────────────────

  Widget buildOcrButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ElevatedButton.icon(
        onPressed: startOcrProcess,
        icon: const Icon(Icons.camera_alt, color: Colors.white),
        label: const Text(
          '📷 タグを撮影してOCR読み取り',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.primaryCyan,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }
}
