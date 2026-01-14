import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:measure_master/constants.dart';
import 'package:measure_master/screens/landing_screen.dart';
import 'package:provider/provider.dart';
import 'package:measure_master/providers/inventory_provider.dart';
import 'package:measure_master/providers/api_product_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:measure_master/models/item.dart';
import 'package:measure_master/services/image_cache_service.dart';
import 'package:measure_master/utils/config_checker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🔧 Hive初期化
  await Hive.initFlutter();
  
  // 📦 TypeAdapterを登録
  Hive.registerAdapter(InventoryItemAdapter());
  
  // 📸 画像キャッシュサービスを初期化
  await ImageCacheService.initialize();
  
  // 🔍 設定状態をチェック（デバッグモードのみ）
  if (kDebugMode) {
    ConfigChecker.checkAllConfigs();
  }
  
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
        home: LandingScreen(),
      ),
    );
  }
}
