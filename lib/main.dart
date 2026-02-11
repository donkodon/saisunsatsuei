import 'package:flutter/material.dart';
import 'package:measure_master/constants.dart';
import 'package:measure_master/screens/landing_screen.dart';
import 'package:measure_master/screens/login_screen.dart';
import 'package:measure_master/screens/dashboard_screen.dart';
import 'package:provider/provider.dart';
import 'package:measure_master/providers/inventory_provider.dart';
import 'package:measure_master/providers/api_product_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:measure_master/models/item.dart';
import 'package:measure_master/services/image_cache_service.dart';
import 'package:measure_master/services/company_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🔧 Hive初期化
  await Hive.initFlutter();
  
  // 📦 TypeAdapterを登録
  Hive.registerAdapter(InventoryItemAdapter());
  
  // 📸 画像キャッシュサービスを初期化
  await ImageCacheService.initialize();
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final provider = InventoryProvider();
            provider.initialize(); // 🔄 Hiveからデータを読み込み
            return provider;
          },
        ),
        ChangeNotifierProvider(create: (_) => ApiProductProvider()),
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
        home: const AuthCheckScreen(),
      ),
    );
  }
}

/// 🔐 認証チェック画面
/// ログイン状態を確認して、適切な画面に遷移する
class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({Key? key}) : super(key: key);

  @override
  _AuthCheckScreenState createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  final CompanyService _companyService = CompanyService();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  /// ログイン状態をチェック
  Future<void> _checkLoginStatus() async {
    // 少し待機してスプラッシュ画面風にする
    await Future.delayed(const Duration(milliseconds: 500));

    final isLoggedIn = await _companyService.isLoggedIn();

    if (mounted) {
      if (isLoggedIn) {
        // ログイン済み → DashboardScreenへ
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      } else {
        // 未ログイン → LandingScreenへ
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LandingScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.straighten,
              size: 80,
              color: AppConstants.primaryCyan,
            ),
            const SizedBox(height: 24),
            Text(
              'Measure Master',
              style: AppConstants.headerStyle.copyWith(
                fontSize: 28,
                color: AppConstants.textDark,
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
