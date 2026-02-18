import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:measure_master/constants.dart';
import 'package:measure_master/firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:measure_master/features/inventory/logic/inventory_provider.dart';
import 'package:measure_master/features/inventory/logic/api_product_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:measure_master/features/inventory/domain/item.dart';
import 'package:measure_master/core/services/image_cache_service.dart';
import 'package:measure_master/features/auth/logic/company_service.dart';
import 'package:measure_master/features/auth/presentation/auth_gate.dart';
import 'package:measure_master/core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _initialized = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // ⚡ Firebase と Hive を並列初期化（互いに依存しないため同時実行可能）
      await Future.wait([
        Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
        Hive.initFlutter(),
      ]);

      // Hive アダプター登録（initFlutter 完了後に実行）
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(InventoryItemAdapter());
      }

      // ImageCacheService は Hive 完了後に開始（Hive ボックスを開くため）
      await ImageCacheService.initialize();

      if (mounted) {
        setState(() => _initialized = true);
      }
    } catch (e, stack) {
      debugPrint('❌ アプリ初期化エラー: $e');
      FlutterError.reportError(FlutterErrorDetails(
        exception: e,
        stack: stack,
        library: 'main',
        context: ErrorDescription('アプリ起動時の初期化処理'),
      ));
      if (mounted) {
        setState(() => _error = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 初期化中の表示
    if (!_initialized && !_error) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppConstants.primaryCyan,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'アプリを初期化中...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 初期化エラーの表示
    if (_error) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 24),
                const Text(
                  '初期化エラー',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'アプリの初期化に失敗しました\nページを再読み込みしてください',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryCyan,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      _initialized = false;
                      _error = false;
                    });
                    _initializeApp();
                  },
                  child: const Text('再試行'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 初期化完了後 → AuthGate に全てを委任
    // 🔑 CompanyService を先に登録し、他のプロバイダーから参照できるようにする
    return MultiProvider(
      providers: [
        // ① CompanyService を先頭で登録（アプリ内で唯一のインスタンス）
        Provider<CompanyService>(create: (_) => CompanyService()),
        // ② InventoryProvider は create 時に一度だけ初期化
        //    update では setCompanyId のみ呼び出し（initialize() の再実行を防止）
        ChangeNotifierProxyProvider<CompanyService, InventoryProvider>(
          create: (_) {
            final provider = InventoryProvider();
            // 初回のみ Hive ボックスを開く（create は一度だけ呼ばれる）
            provider.initialize();
            return provider;
          },
          update: (_, companyService, inventoryProvider) {
            final provider = inventoryProvider ?? InventoryProvider();
            // メモリキャッシュから同期的に取得（await 不要）
            final cachedId = companyService.cachedCompanyId;
            if (cachedId != null && cachedId.isNotEmpty) {
              // 既に同じIDなら setCompanyId はスキップ（内部で比較）
              provider.setCompanyIdIfChanged(cachedId);
            }
            return provider;
          },
        ),
        ChangeNotifierProvider<ApiProductProvider>(create: (_) => ApiProductProvider()),
      ],
      child: MaterialApp(
        title: 'Measure Master',
        debugShowCheckedModeBanner: false,
        // ⚡ AppTheme.main に統一（Google Fonts の二重ロードを解消済み）
        theme: AppTheme.main,
        home: const AuthGate(),  // 🔒 認証は auth/ に完全委任
      ),
    );
  }
}
