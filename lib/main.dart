import 'package:flutter/material.dart';
import 'package:measure_master/constants.dart';
import 'package:measure_master/screens/landing_screen.dart';
import 'package:provider/provider.dart';
import 'package:measure_master/providers/inventory_provider.dart';
import 'package:measure_master/providers/api_product_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:measure_master/models/item.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🔧 Hive初期化
  await Hive.initFlutter();
  
  // 📦 TypeAdapterを登録
  Hive.registerAdapter(InventoryItemAdapter());
  
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
        home: LandingScreen(),
      ),
    );
  }
}
