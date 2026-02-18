import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:image_picker/image_picker.dart';
import 'package:measure_master/core/services/api_service.dart';
import 'package:measure_master/features/inventory/domain/api_product.dart';
import 'package:measure_master/features/inventory/presentation/add_item_screen.dart';

/// 静止画ベースのWeb版バーコードスキャナー（image_picker + Html5-QRCode）
class WebBarcodeScannerScreenV2 extends StatefulWidget {
  const WebBarcodeScannerScreenV2({super.key});

  @override
  State<WebBarcodeScannerScreenV2> createState() => _WebBarcodeScannerScreenV2State();
}

class _WebBarcodeScannerScreenV2State extends State<WebBarcodeScannerScreenV2> {
  final ImagePicker _picker = ImagePicker();
  bool _isAnalyzing = false;
  bool _isSearching = false;
  String _statusMessage = 'JANコード（バーコード）付きの写真を撮影してください';
  Uint8List? _imageBytes;
  String? _detectedBarcode;

  @override
  void initState() {
    super.initState();
    _ensureHtml5QrCodeLoaded();
  }

  /// ZXingライブラリが読み込まれているか確認
  void _ensureHtml5QrCodeLoaded() {
    final checkScript = html.ScriptElement()
      ..text = '''
        (function() {
          if (typeof ZXing === 'undefined') {
            console.error('❌ ZXingライブラリが見つかりません');
          } else {
            console.log('✅ ZXingライブラリ読み込み確認完了');
          }
        })();
      ''';
    html.document.head!.append(checkScript);
  }

  /// カメラで写真を撮影
  Future<void> _takePhoto() async {
    try {
      if (kDebugMode) {
        print('📷 カメラ撮影開始...');
      }

      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear, // 背面カメラ
        maxWidth: 1920, // 最大幅（高解像度）
        maxHeight: 1080,
        imageQuality: 90, // 高品質
      );

      if (photo == null) {
        if (kDebugMode) {
          print('⚠️ 撮影キャンセル');
        }
        return;
      }

      if (kDebugMode) {
        print('✅ 撮影完了: ${photo.name}');
      }

      // 画像を読み込んで解析
      final bytes = await photo.readAsBytes();
      _analyzeImage(bytes);
    } catch (e) {
      if (kDebugMode) {
        print('❌ 撮影エラー: $e');
      }
      _showError('カメラの起動に失敗しました: $e');
    }
  }

  /// ギャラリーから画像を選択
  Future<void> _pickFromGallery() async {
    try {
      if (kDebugMode) {
        print('🖼️ ギャラリー選択開始...');
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 90,
      );

      if (image == null) {
        if (kDebugMode) {
          print('⚠️ 選択キャンセル');
        }
        return;
      }

      if (kDebugMode) {
        print('✅ 画像選択完了: ${image.name}');
      }

      // 画像を読み込んで解析
      final bytes = await image.readAsBytes();
      _analyzeImage(bytes);
    } catch (e) {
      if (kDebugMode) {
        print('❌ ギャラリー選択エラー: $e');
      }
      _showError('画像の選択に失敗しました: $e');
    }
  }

  /// 画像を解析してバーコードを検出
  Future<void> _analyzeImage(Uint8List imageBytes) async {
    setState(() {
      _isAnalyzing = true;
      _imageBytes = imageBytes;
      _statusMessage = 'バーコードを解析中...';
      _detectedBarcode = null;
    });

    try {
      if (kDebugMode) {
        print('🔍 画像解析開始...');
      }

      // Base64エンコード
      final base64Image = base64Encode(imageBytes);
      final dataUrl = 'data:image/jpeg;base64,$base64Image';

      if (kDebugMode) {
        print('📊 Base64変換完了（サイズ: ${base64Image.length} bytes）');
      }

      // JavaScriptでZXing-jsを使って解析（JANコード専用最適化）
      final analysisScript = html.ScriptElement()
        ..text = '''
          (function() {
            console.log('🔬 ZXing-js解析開始（JANコード専用モード）...');
            
            // ZXingライブラリの確認
            if (typeof ZXing === 'undefined') {
              console.error('❌ ZXingライブラリが見つかりません');
              window.dispatchEvent(new CustomEvent('barcode-error', {
                detail: { message: 'ZXingライブラリが読み込まれていません' }
              }));
              return;
            }
            
            console.log('✅ ZXingライブラリ確認完了');
            
            try {
              // Image要素を作成
              const img = new Image();
              
              img.onload = function() {
                console.log('📷 画像読み込み完了 (' + img.width + 'x' + img.height + ')');
                
                // ZXing BrowserMultiFormatReader を作成（JANコード専用）
                const hints = new Map();
                const formats = [
                  ZXing.BarcodeFormat.EAN_13,  // JANコード（13桁）
                  ZXing.BarcodeFormat.EAN_8,   // 短縮JANコード（8桁）
                ];
                hints.set(ZXing.DecodeHintType.POSSIBLE_FORMATS, formats);
                hints.set(ZXing.DecodeHintType.TRY_HARDER, true);
                
                console.log('📋 ZXing JANコード専用設定完了');
                
                const codeReader = new ZXing.BrowserMultiFormatReader(hints);
                
                // 画像を解析
                codeReader.decodeFromImageElement(img)
                  .then(result => {
                    console.log('✅ JANコード検出成功:', result.text);
                    console.log('   形式:', result.format);
                    console.log('   桁数:', result.text.length);
                    
                    // バイブレーション
                    if (navigator.vibrate) {
                      navigator.vibrate(200);
                    }
                    
                    // Flutterにイベントを送信
                    window.dispatchEvent(new CustomEvent('barcode-detected', {
                      detail: { text: result.text }
                    }));
                  })
                  .catch(err => {
                    console.error('❌ JANコード検出失敗:', err);
                    console.error('   エラー詳細:', err.message || err);
                    window.dispatchEvent(new CustomEvent('barcode-error', {
                      detail: { message: 'JANコードが検出できませんでした。\\n・バーコード全体が映っていますか？\\n・ピントは合っていますか？\\n・明るい場所で撮影しましたか？' }
                    }));
                  });
              };
              
              img.onerror = function(err) {
                console.error('❌ 画像読み込みエラー:', err);
                window.dispatchEvent(new CustomEvent('barcode-error', {
                  detail: { message: '画像の読み込みに失敗しました' }
                }));
              };
              
              // Data URLを設定
              img.src = "$dataUrl";
              
            } catch (err) {
              console.error('❌ ZXing初期化エラー:', err);
              window.dispatchEvent(new CustomEvent('barcode-error', {
                detail: { message: 'バーコード解析の初期化に失敗しました' }
              }));
            }
          })();
        ''';

      html.document.head!.append(analysisScript);

      // イベントリスナーを設定（一時的）
      late html.EventListener successListener;
      late html.EventListener errorListener;

      successListener = (html.Event event) {
        final customEvent = event as html.CustomEvent;
        final barcode = customEvent.detail['text'] as String;

        if (kDebugMode) {
          print('📊 バーコード受信: $barcode');
        }

        // リスナーを削除
        html.window.removeEventListener('barcode-detected', successListener);
        html.window.removeEventListener('barcode-error', errorListener);

        setState(() {
          _isAnalyzing = false;
          _detectedBarcode = barcode;
          _statusMessage = 'バーコード検出: $barcode';
        });

        // 商品検索
        _onBarcodeDetected(barcode);
      };

      errorListener = (html.Event event) {
        final customEvent = event as html.CustomEvent;
        final message = customEvent.detail['message'] as String;

        if (kDebugMode) {
          print('❌ 解析エラー: $message');
        }

        // リスナーを削除
        html.window.removeEventListener('barcode-detected', successListener);
        html.window.removeEventListener('barcode-error', errorListener);

        if (mounted) {
          setState(() {
            _isAnalyzing = false;
            _statusMessage = message;
          });
          _showError(message);
        }
      };

      html.window.addEventListener('barcode-detected', successListener);
      html.window.addEventListener('barcode-error', errorListener);

      // タイムアウト処理（20秒に延長）
      Future.delayed(const Duration(seconds: 20), () {
        if (_isAnalyzing && mounted) {
          html.window.removeEventListener('barcode-detected', successListener);
          html.window.removeEventListener('barcode-error', errorListener);
          setState(() {
            _isAnalyzing = false;
            _statusMessage = '解析タイムアウト。以下を確認してください：\n・バーコード全体が映っている\n・ピントが合っている\n・明るい場所で撮影';
          });
          _showError('解析に時間がかかっています。\n・バーコード全体が映っていますか？\n・ピントは合っていますか？\n・明るい場所で撮影しましたか？');
        }
      });

    } catch (e) {
      if (kDebugMode) {
        print('❌ 解析エラー: $e');
      }
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _statusMessage = '解析エラー: $e';
        });
        _showError('画像の解析に失敗しました: $e');
      }
    }
  }

  /// バーコード検出時の処理
  Future<void> _onBarcodeDetected(String barcode) async {
    if (_isSearching) return;

    setState(() {
      _isSearching = true;
      _statusMessage = '商品を検索中...';
    });

    try {
      if (kDebugMode) {
        print('🔍 商品検索開始: $barcode');
      }

      // D1 API で商品検索
      final product = await ApiService.searchByBarcode(barcode);

      if (!mounted) return;

      // 商品が見つかった場合はデータを引っ張る、見つからない場合はブランクで遷移
      // DashboardScreenと同じ動作: AddItemScreenに遷移
      if (product != null) {
        if (kDebugMode) {
          print('✅ 商品発見: ${product.name} → AddItemScreenへ');
        }

        // ApiProduct形式に変換してAddItemScreenへ遷移
        final apiProduct = ApiProduct(
          id: 0,
          sku: product.sku,
          name: product.name,
          brand: product.brand,
          category: product.category,
          size: product.size,
          color: product.color,
          priceSale: product.priceSale,
          createdAt: DateTime.now(),
          barcode: product.barcode,
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AddItemScreen(
              prefillData: apiProduct,
            ),
          ),
        );
      } else {
        if (kDebugMode) {
          print('ℹ️ 商品未登録: $barcode → AddItemScreenへ（ブランク）');
        }
        
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
    } catch (e) {
      if (kDebugMode) {
        print('❌ 検索エラー: $e');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('エラーが発生しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isSearching = false;
        _statusMessage = '検索エラー。もう一度試してください。';
      });
    }
  }



  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: '閉じる',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('バーコードスキャン (Web版)'),
        backgroundColor: const Color(0xFF1A2A3A),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 画像プレビュー
              if (_imageBytes != null) ...[
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      _imageBytes!,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_detectedBarcode != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      border: Border.all(color: Colors.green, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '検出: $_detectedBarcode',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
              ] else ...[
                // アイコン表示
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_scanner,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'JANコード（バーコード）付きの写真を撮影',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ステータスメッセージ
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isAnalyzing || _isSearching
                      ? Colors.blue.shade50
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    if (_isAnalyzing || _isSearching) ...[
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        _statusMessage,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 写真撮影ボタン
              ElevatedButton.icon(
                onPressed: _isAnalyzing || _isSearching ? null : _takePhoto,
                icon: const Icon(Icons.camera_alt, size: 28),
                label: const Text(
                  '写真を撮影',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A2A3A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 12),

              // ギャラリー選択ボタン
              OutlinedButton.icon(
                onPressed: _isAnalyzing || _isSearching ? null : _pickFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('ギャラリーから選択'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),

              const SizedBox(height: 12),

              // 手動入力ボタン
              OutlinedButton.icon(
                onPressed: _isAnalyzing || _isSearching ? null : _showManualInputDialog,
                icon: const Icon(Icons.keyboard),
                label: const Text('手動入力'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),

              const SizedBox(height: 24),

              // ヒント（JANコード専用）
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          '撮影のコツ（JANコード専用）',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTip('• JANコード（13桁または8桁）を画面中央に'),
                    _buildTip('• バーコード全体が映るように撮影'),
                    _buildTip('• 明るい場所で撮影すると精度UP'),
                    _buildTip('• ピントが合っていることを確認'),
                    _buildTip('• バーコードが傾かないようにまっすぐ撮影'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
      ),
    );
  }
}
