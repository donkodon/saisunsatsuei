import 'package:flutter/material.dart';
import 'package:measure_master/constants.dart';
import 'package:measure_master/screens/landing_screen.dart';
import 'package:provider/provider.dart';
import 'package:measure_master/providers/inventory_provider.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
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
