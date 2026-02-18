import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:measure_master/constants.dart';
import 'package:measure_master/firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:measure_master/providers/inventory_provider.dart';
import 'package:measure_master/providers/api_product_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:measure_master/models/item.dart';
import 'package:measure_master/services/image_cache_service.dart';
import 'package:measure_master/auth/company_service.dart';
import 'package:measure_master/auth/auth_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (kDebugMode) {
    debugPrint('');
    debugPrint('=' * 60);
    debugPrint('🚀🚀🚀 Cargo Measure アプリ起動！ 🚀🚀🚀');
    debugPrint('=' * 60);
    debugPrint('⏰ 起動時刻: ${DateTime.now()}');
    debugPrint('🔍 このログが見えていれば、ログ出力は正常です');
    debugPrint('📱 これからログを監視してください');
    debugPrint('=' * 60);
    debugPrint('');
  }
  
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
      debugPrint('🔄 Step 1: Firebase初期化開始...');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('✅ Step 1: Firebase初期化成功');
      
      debugPrint('🔄 Step 2: Hive初期化開始...');
      await Hive.initFlutter();
      debugPrint('✅ Step 2: Hive初期化成功');
      
      debugPrint('🔄 Step 3: TypeAdapter登録開始...');
      Hive.registerAdapter(InventoryItemAdapter());
      debugPrint('✅ Step 3: TypeAdapter登録成功');
      
      debugPrint('🔄 Step 4: 画像キャッシュサービス初期化開始...');
      await ImageCacheService.initialize();
      debugPrint('✅ Step 4: 画像キャッシュサービス初期化成功');
      
      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }
      
      debugPrint('🎉 アプリ初期化完了！');
    } catch (e, stackTrace) {
      debugPrint('❌ アプリ初期化エラー: $e');
      debugPrint('📍 スタックトレース: $stackTrace');
      
      if (mounted) {
        setState(() {
          _error = true;
        });
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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final provider = InventoryProvider();
            CompanyService().getCompanyId().then((companyId) {
              provider.initialize(companyId: companyId);
            });
            return provider;
          },
        ),
        ChangeNotifierProvider(create: (_) => ApiProductProvider()),
        Provider<CompanyService>(create: (_) => CompanyService()),
      ],
      child: MaterialApp(
        title: 'Measure Master',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: AppConstants.primaryCyan,
          scaffoldBackgroundColor: AppConstants.backgroundLight,
          colorScheme: ColorScheme.fromSwatch().copyWith(
            primary: AppConstants.primaryCyan,
            secondary: AppConstants.primaryCyan,
          ),
        ),
        home: const AuthGate(),  // 🔒 認証は auth/ に完全委任
      ),
    );
  }
}
