import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:measure_master/constants.dart';
import 'package:measure_master/screens/dashboard_screen.dart';
import 'package:measure_master/screens/firebase_login_screen.dart';
import 'package:measure_master/firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:measure_master/providers/inventory_provider.dart';
import 'package:measure_master/providers/api_product_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:measure_master/models/item.dart';
import 'package:measure_master/services/image_cache_service.dart';
import 'package:measure_master/services/company_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // 🔥 Firebase初期化（Web対応）
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase初期化成功');
  } catch (e) {
    debugPrint('❌ Firebase初期化エラー: $e');
    // Firebase初期化に失敗してもアプリは起動
  }
  
  // 🔧 Hive初期化
  await Hive.initFlutter();
  
  // 📦 TypeAdapterを登録
  Hive.registerAdapter(InventoryItemAdapter());
  
  // 📸 画像キャッシュサービスを初期化
  await ImageCacheService.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
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
        home: const FirebaseAuthCheckScreen(),
      ),
    );
  }
}

/// 🔥 Firebase認証チェック画面
/// Firebase Authentication の状態に応じて画面を切り替え
class FirebaseAuthCheckScreen extends StatelessWidget {
  const FirebaseAuthCheckScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 認証状態を確認中
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // ログイン済み
        if (snapshot.hasData && snapshot.data != null) {
          return const DashboardScreen();
        }

        // 未ログイン
        return const FirebaseLoginScreen();
      },
    );
  }
}

// 既存の AuthCheckScreen は削除（Firebase認証に置き換え）
