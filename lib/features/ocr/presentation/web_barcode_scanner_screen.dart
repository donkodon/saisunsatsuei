import 'dart:async';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:measure_master/core/services/api_service.dart';
import 'package:measure_master/features/inventory/presentation/detail_screen.dart';

class WebBarcodeScannerScreen extends StatefulWidget {
  const WebBarcodeScannerScreen({super.key});

  @override
  State<WebBarcodeScannerScreen> createState() => _WebBarcodeScannerScreenState();
}

class _WebBarcodeScannerScreenState extends State<WebBarcodeScannerScreen> {
  final String _videoId = 'barcode-video-${DateTime.now().millisecondsSinceEpoch}';
  bool _isScanning = false;
  bool _isSearching = false;
  String? _lastScannedCode;
  html.MediaStream? _mediaStream;
  html.VideoElement? _videoElement;
  Timer? _scanTimer;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeScanner();
  }

  Future<void> _initializeScanner() async {
    try {
      debugPrint('🎥 カメラ初期化開始...');
      
      // カメラストリームを取得
      final constraints = {
        'video': {
          'facingMode': 'environment', // 背面カメラを優先
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
        }
      };

      _mediaStream = await html.window.navigator.mediaDevices!.getUserMedia(constraints);
      debugPrint('✅ カメラストリーム取得成功');

      // Video要素を作成してDOMに追加
      _videoElement = html.VideoElement()
        ..id = _videoId
        ..autoplay = true
        ..muted = true
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..srcObject = _mediaStream;

      // View Factoryを登録
      // ignore: undefined_prefixed_name
      ui_web.platformViewRegistry.registerViewFactory(
        _videoId,
        (int viewId) => _videoElement!,
      );

      // Video要素が再生開始されるまで待機
      await _videoElement!.play();
      debugPrint('✅ Video要素再生開始');

      // 少し待ってからスキャン開始（Video要素が完全に準備されるまで）
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _isScanning = true;
        _isInitialized = true;
      });

      // バーコードスキャンを開始
      _startBarcodeDetection();
      
    } catch (e) {
      debugPrint('❌ カメラ初期化エラー: $e');
      if (mounted) {
        _showError('カメラの初期化に失敗しました: $e');
      }
    }
  }

  void _startBarcodeDetection() {
    debugPrint('🔍 バーコード検出開始...');
    
    // ZXingが読み込まれているか確認
    final checkZXing = '''
      if (typeof ZXing === 'undefined') {
        console.error('❌ ZXingライブラリが読み込まれていません');
        window.dispatchEvent(new CustomEvent('zxing-error', {
          detail: { message: 'ZXingライブラリが読み込まれていません' }
        }));
      } else {
        console.log('✅ ZXingライブラリ読み込み確認');
        window.dispatchEvent(new CustomEvent('zxing-ready'));
      }
    ''';
    
    // ScriptElementを作成してテキストを設定
    final scriptElement = html.ScriptElement()..text = checkZXing;
    html.document.head!.append(scriptElement);

    // ZXingエラーイベントをリッスン
    html.window.addEventListener('zxing-error', (event) {
      final customEvent = event as html.CustomEvent;
      debugPrint('❌ ZXingエラー: ${customEvent.detail['message']}');
      _showError('バーコードライブラリの初期化に失敗しました');
    });

    // ZXing準備完了後にスキャン開始
    html.window.addEventListener('zxing-ready', (event) {
      debugPrint('✅ ZXing準備完了、スキャン開始');
      _startContinuousScanning();
    });
    
    // 即座にZXingチェックを実行
    html.document.head!.append(html.ScriptElement()..text = checkZXing);
  }

  void _startContinuousScanning() {
    // 継続的なスキャンループを実装
    final scanScript = '''
      (function() {
        console.log('🔄 継続スキャンループ開始');
        
        if (typeof ZXing === 'undefined') {
          console.error('❌ ZXingが利用できません');
          return;
        }
        
        const codeReader = new ZXing.BrowserMultiFormatReader();
        const videoElement = document.getElementById('$_videoId');
        
        if (!videoElement) {
          console.error('❌ Video要素が見つかりません: $_videoId');
          window.dispatchEvent(new CustomEvent('barcode-error', {
            detail: { message: 'Video要素が見つかりません' }
          }));
          return;
        }
        
        console.log('✅ Video要素確認: $_videoId');
        console.log('   readyState:', videoElement.readyState);
        console.log('   videoWidth:', videoElement.videoWidth);
        console.log('   videoHeight:', videoElement.videoHeight);
        
        // 継続的にデコードを試行
        let isScanning = true;
        
        const scan = () => {
          if (!isScanning) return;
          
          codeReader.decodeFromVideoElement(videoElement, (result, err) => {
            if (result) {
              console.log('✅ バーコード検出成功:', result.text);
              console.log('   形式:', result.format);
              
              window.dispatchEvent(new CustomEvent('barcode-detected', {
                detail: { 
                  text: result.text,
                  format: result.format
                }
              }));
              
              // 検出後も継続スキャン（重複防止はFlutter側で処理）
            }
            
            if (err && err.name !== 'NotFoundException') {
              console.warn('⚠️ デコードエラー:', err.name, err.message);
            }
          });
        };
        
        // 1秒ごとにスキャン実行
        const scanInterval = setInterval(() => {
          if (isScanning) {
            scan();
          } else {
            clearInterval(scanInterval);
          }
        }, 1000);
        
        console.log('🔄 スキャンループ開始（1秒間隔）');
        
        // 停止イベント
        window.addEventListener('stop-scanning', () => {
          console.log('🛑 スキャン停止');
          isScanning = false;
          clearInterval(scanInterval);
          codeReader.reset();
        });
      })();
    ''';

    html.document.head!.append(html.ScriptElement()..text = scanScript);

    // Flutter側でバーコード検出イベントをリッスン
    html.window.addEventListener('barcode-detected', _handleBarcodeDetected);
    
    // エラーイベントをリッスン
    html.window.addEventListener('barcode-error', (event) {
      final customEvent = event as html.CustomEvent;
      debugPrint('❌ バーコードエラー: ${customEvent.detail['message']}');
    });
  }

  void _handleBarcodeDetected(html.Event event) {
    final customEvent = event as html.CustomEvent;
    final barcode = customEvent.detail['text'] as String;
    final format = customEvent.detail['format'] as String?;

    debugPrint('📊 Flutter側でバーコード受信: $barcode (形式: $format)');

    // 重複検出を防止
    if (barcode == _lastScannedCode || _isSearching) {
      debugPrint('⏭️ スキップ（重複またはスキャン中）');
      return;
    }

    _lastScannedCode = barcode;
    _onBarcodeDetected(barcode);
  }

  Future<void> _onBarcodeDetected(String barcode) async {
    if (_isSearching) return;

    debugPrint('🔍 商品検索開始: $barcode');

    setState(() {
      _isScanning = false;
      _isSearching = true;
    });

    try {
      final product = await ApiService.searchByBarcode(barcode);

      if (!mounted) return;

      if (product != null) {
        debugPrint('✅ 商品発見: ${product.name}');
        // 商品が見つかった
        _stopCamera();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DetailScreen(
              sku: product.sku,
              barcode: product.barcode ?? '',
              itemName: product.name,
              brand: product.brand ?? '',
              category: product.category ?? '',
              condition: '',
              price: product.priceSale?.toString() ?? '',
              size: product.size ?? '',
              color: product.color ?? '',
              productRank: '',
              material: '',
              description: '',
              priceSale: product.priceSale,
            ),
          ),
        );
      } else {
        debugPrint('⚠️ 商品未登録: $barcode');
        // 商品が見つからない
        _showProductNotFoundDialog(barcode);
      }
    } catch (e) {
      debugPrint('❌ 検索エラー: $e');
      if (!mounted) return;
      _showError('検索エラー: $e');
      setState(() {
        _isSearching = false;
        _isScanning = true;
        _lastScannedCode = null;
      });
    }
  }

  void _showProductNotFoundDialog(String barcode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('商品が見つかりません'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('バーコード: $barcode'),
            const SizedBox(height: 8),
            const Text('この商品は登録されていません。'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isSearching = false;
                _isScanning = true;
                _lastScannedCode = null;
              });
            },
            child: const Text('再スキャン'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _stopCamera();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => DetailScreen(
                    sku: '',
                    barcode: barcode,
                    itemName: '',
                    brand: '',
                    category: '',
                    condition: '',
                    price: '',
                    size: '',
                    color: '',
                    productRank: '',
                    material: '',
                    description: '',
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A2A3A),
              foregroundColor: Colors.white,
            ),
            child: const Text('新規登録'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showManualInputDialog() {
    final TextEditingController controller = TextEditingController();

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
              controller: controller,
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
              final barcode = controller.text.trim();
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

  void _stopCamera() {
    debugPrint('🛑 カメラ停止');
    
    // スキャン停止イベントを送信
    html.window.dispatchEvent(html.CustomEvent('stop-scanning'));
    
    if (_mediaStream != null) {
      _mediaStream!.getTracks().forEach((track) {
        track.stop();
      });
      _mediaStream = null;
    }
    
    _scanTimer?.cancel();
  }

  @override
  void dispose() {
    _stopCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('バーコードスキャン (Web版)'),
        backgroundColor: const Color(0xFF1A2A3A),
        foregroundColor: Colors.white,
      ),
      body: !_isInitialized
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('カメラを初期化中...'),
                ],
              ),
            )
          : Stack(
              children: [
                // カメラプレビュー
                HtmlElementView(viewType: _videoId),

                // スキャンエリア
                Center(
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
                  ),
                ),

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
}
