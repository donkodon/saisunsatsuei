import 'package:flutter/foundation.dart';
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
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      await Hive.initFlutter();
      
      Hive.registerAdapter(InventoryItemAdapter());
      
      await ImageCacheService.initialize();
      
      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ アプリ初期化エラー: $e');
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
    // 🔑 CompanyService を先に登録し、他のプロバイダーから参照できるようにする
    return MultiProvider(
      providers: [
        // ① CompanyService を先頭で登録（アプリ内で唯一のインスタンス）
        Provider<CompanyService>(create: (_) => CompanyService()),
        // ② InventoryProvider は CompanyService の同一インスタンスを使って初期化
        ChangeNotifierProxyProvider<CompanyService, InventoryProvider>(
          create: (_) => InventoryProvider(),
          update: (_, companyService, inventoryProvider) {
            // CompanyService が更新されるたびに企業IDを同期
            companyService.getCompanyId().then((companyId) {
              inventoryProvider?.initialize(companyId: companyId);
            });
            return inventoryProvider ?? InventoryProvider();
          },
        ),
        ChangeNotifierProvider<ApiProductProvider>(create: (_) => ApiProductProvider()),
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
