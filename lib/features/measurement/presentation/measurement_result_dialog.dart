import 'package:flutter/material.dart';
import '../domain/garment_measurement_model.dart';

/// 採寸結果表示ダイアログ
/// 
/// AI採寸が完了した後、結果を表示するダイアログです。
/// ユーザーは結果を確認し、商品詳細画面に反映できます。
class MeasurementResultDialog extends StatelessWidget {
  final GarmentMeasurementModel measurement;

  const MeasurementResultDialog({
    super.key,
    required this.measurement,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.straighten, color: Colors.blue),
          const SizedBox(width: 8),
          const Text('📏 AI採寸結果'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // SKU表示
            Text(
              'SKU: ${measurement.sku}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),

            // 採寸日時
            Text(
              '採寸日時: ${_formatDateTime(measurement.timestamp)}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),

            // 採寸結果
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildMeasurementItem('肩幅', measurement.measurements.shoulderWidth),
                  const Divider(height: 16),
                  _buildMeasurementItem('袖丈', measurement.measurements.sleeveLength),
                  const Divider(height: 16),
                  _buildMeasurementItem('着丈', measurement.measurements.bodyLength),
                  const Divider(height: 16),
                  _buildMeasurementItem('身幅', measurement.measurements.bodyWidth),
                ],
              ),
            ),

            // 採寸画像（ある場合）
            if (measurement.measurementImageUrl != null) ...[
              const SizedBox(height: 16),
              const Text(
                '採寸画像:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  measurement.measurementImageUrl!,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Text('画像の読み込みに失敗しました'),
                      ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 16),

            // 注意事項
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.amber.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI採寸は参考値です。正確な寸法は実測をおすすめします。',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('閉じる'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context, measurement),
          icon: const Icon(Icons.check),
          label: const Text('反映する'),
        ),
      ],
    );
  }

  /// 採寸項目を表示
  Widget _buildMeasurementItem(String label, double value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          '${value.toStringAsFixed(1)} cm',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }

  /// 日時をフォーマット
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// ダイアログを表示
  /// 
  /// **戻り値:**
  /// - ユーザーが「反映する」を選択: `GarmentMeasurementModel`
  /// - ユーザーが「閉じる」を選択: `null`
  static Future<GarmentMeasurementModel?> show(
    BuildContext context,
    GarmentMeasurementModel measurement,
  ) async {
    return await showDialog<GarmentMeasurementModel>(
      context: context,
      builder: (context) => MeasurementResultDialog(measurement: measurement),
    );
  }
}
