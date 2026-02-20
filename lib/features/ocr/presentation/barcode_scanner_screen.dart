import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:measure_master/core/services/api_service.dart';
import 'package:measure_master/features/auth/logic/company_service.dart';
import 'package:measure_master/features/inventory/domain/api_product.dart';
import 'package:measure_master/features/inventory/presentation/add_item_screen.dart';
import 'package:measure_master/features/ocr/presentation/web_barcode_scanner_screen_v2.dart';
import 'package:measure_master/core/utils/app_feedback.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  late MobileScannerController controller;
  bool _isScanning = true;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _initializeController();
    }
  }

  void _initializeController() {
    controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Web プラットフォームでは Html5-QRCode を使用
    if (kIsWeb) {
      return const WebBarcodeScannerScreenV2();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(kIsWeb ? 'バーコードスキャン (Web版)' : 'バーコードスキャン'),
        backgroundColor: const Color(0xFF1A2A3A),
        foregroundColor: Colors.white,
        actions: [
          if (!kIsWeb)
            IconButton(
              icon: const Icon(Icons.flip_camera_ios),
              onPressed: () => controller.switchCamera(),
              tooltip: 'カメラ切り替え',
            ),
        ],
      ),
      body: Stack(
        children: [
          // カメラプレビュー
          MobileScanner(
            controller: controller,
            errorBuilder: (context, error, child) {
              return _buildErrorView(error);
            },
            onDetect: (capture) {
              if (!_isScanning || _isSearching) return;

              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
                  setState(() => _isScanning = false);
                  _onBarcodeDetected(barcode.rawValue!);
                  break;
                }
              }
            },
          ),

          // スキャンエリア表示
          _buildScanArea(),

          // 検索中インジケーター
          if (_isSearching)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      '商品を検索中...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

          // 説明テキスト
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black54,
              child: const Text(
                'バーコードを緑の枠内に合わせてください',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // 手動入力ボタン
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                onPressed: _showManualInputDialog,
                icon: const Icon(Icons.keyboard),
                label: const Text('手動入力'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1A2A3A),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// スキャンエリアの表示
  Widget _buildScanArea() {
    return Center(
      child: Container(
        width: 300,
        height: 200,
        decoration: BoxDecoration(
          border: Border.all(
            color: _isScanning ? Colors.green : Colors.grey,
            width: 3,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: CustomPaint(
          painter: ScannerOverlayPainter(),
        ),
      ),
    );
  }

  /// エラー表示
  Widget _buildErrorView(MobileScannerException error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'カメラアクセスエラー',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error.errorDetails?.message ?? 'カメラにアクセスできません',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showManualInputDialog,
              icon: const Icon(Icons.keyboard),
              label: const Text('手動入力で続ける'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A2A3A),
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('戻る'),
            ),
          ],
        ),
      ),
    );
  }

  /// バーコード検出時の処理
  Future<void> _onBarcodeDetected(String barcode) async {
    setState(() => _isSearching = true);

    try {
      // 🏢 企業IDを取得
      // ✅ Provider の同一インスタンスを取得
      final companyService = Provider.of<CompanyService>(context, listen: false);
      final companyId = await companyService.getCompanyId();
      
      // D1 API で商品検索（企業IDを渡す）
      if (kDebugMode) {
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('🔍 BarcodeScannerScreen._onBarcodeDetected');
        print('   - Barcode: $barcode');
        print('   - CompanyId: $companyId');
        print('   - CompanyId is null: ${companyId == null}');
        print('   - CompanyId is empty: ${companyId?.isEmpty ?? true}');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }
      
      final product = await ApiService.searchByBarcode(barcode, companyId: companyId);

      if (kDebugMode) {
        print('🔍 BarcodeScannerScreen: searchByBarcode returned');
        print('   - Product: ${product != null ? product.sku : 'null'}');
      }

      if (!mounted) return;

      // 商品が見つかった場合はデータを引っ張る、見つからない場合はブランクで遷移
      // DashboardScreenと同じ動作: AddItemScreenに遷移
      if (product != null) {
        // ✅ ApiService.searchByBarcodeが既に完全なApiProductを返すので、そのまま使用
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AddItemScreen(
              prefillData: product,  // 🔧 直接使用（重複ラッピング削除）
            ),
          ),
        );
      } else {
        // 商品が見つからない場合 → ブランクのAddItemScreenへ（バーコードのみ入力済み）
        final dummyProduct = ApiProduct(
          id: 0,
          sku: barcode,
          name: '',
          createdAt: DateTime.now(),
          category: '',
          priceSale: 0,
          stockQuantity: 0,
          barcode: barcode,
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AddItemScreen(
              prefillData: dummyProduct,
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      if (!mounted) return;
      if (kDebugMode) {
        print('💥 BarcodeScannerScreen Error: $e');
        print('Stack trace: $stackTrace');
      }
      AppFeedback.showError(context, 'エラーが発生しました: $e');
      setState(() {
        _isSearching = false;
        _isScanning = true;
      });
    }
  }



  /// 手動入力ダイアログ
  void _showManualInputDialog() {
    final TextEditingController barcodeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('バーコード・SKU検索'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'バーコード番号またはSKUを入力してください',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: barcodeController,
              decoration: const InputDecoration(
                labelText: 'バーコード/SKU',
                hintText: '例: 4901234567890 または 1025L190001',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              keyboardType: TextInputType.text,
              autofocus: true,
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  Navigator.pop(context);
                  _onBarcodeDetected(value.trim());
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final barcode = barcodeController.text.trim();
              if (barcode.isNotEmpty) {
                Navigator.pop(context);
                _onBarcodeDetected(barcode);
              }
            },
            icon: const Icon(Icons.search),
            label: const Text('検索'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A2A3A),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      controller.dispose();
    }
    super.dispose();
  }
}

/// スキャンエリアの角を描画するカスタムペインター
class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    const cornerLength = 30.0;

    // 左上
    canvas.drawLine(const Offset(0, 0), const Offset(cornerLength, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, cornerLength), paint);

    // 右上
    canvas.drawLine(Offset(size.width - cornerLength, 0), Offset(size.width, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, cornerLength), paint);

    // 左下
    canvas.drawLine(Offset(0, size.height - cornerLength), Offset(0, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(cornerLength, size.height), paint);

    // 右下
    canvas.drawLine(Offset(size.width - cornerLength, size.height), Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height - cornerLength), Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
