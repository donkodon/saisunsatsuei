import 'package:flutter/material.dart';
import 'package:measure_master/constants.dart';
import 'package:measure_master/screens/login_screen.dart';
import 'package:measure_master/widgets/custom_button.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Hero Image Area (simulated phone frame effect from screenshot)
            Expanded(
              flex: 5,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppConstants.backgroundLight,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(40),
                        bottomRight: Radius.circular(40),
                      ),
                    ),
                    child: ClipRRect(
                       borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(40),
                        bottomRight: Radius.circular(40),
                      ),
                      child: Image.asset(
                        'assets/images/phone_measure_tshirt.jpg',
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 20,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.straighten, color: AppConstants.primaryCyan, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "AI MEASURE",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: Color(0xFF2D3436),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Content Area
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        Text(
                          "AI自動採寸で、\n出品を10倍速く",
                          textAlign: TextAlign.center,
                          style: AppConstants.headerStyle.copyWith(height: 1.3),
                        ),
                        SizedBox(height: 16),
                        Text(
                          "服を平置きして撮影するだけ。\nサイズ表を自動生成します。",
                          textAlign: TextAlign.center,
                          style: AppConstants.bodyStyle.copyWith(color: AppConstants.textGrey),
                        ),
                      ],
                    ),
                    
                    // Steps Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStepItem(Icons.camera_alt, "STEP 1", "撮影"),
                        _buildStepItem(Icons.auto_awesome, "STEP 2", "AI測定", isActive: true),
                        _buildStepItem(Icons.sell, "STEP 3", "出品"),
                      ],
                    ),
                    
                    CustomButton(
                      text: "今すぐ始める",
                      onPressed: () {
                        // 🚀 ログイン画面へ遷移
                        Navigator.pushReplacement(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              return FadeTransition(opacity: animation, child: child);
                            },
                            transitionDuration: const Duration(milliseconds: 200),
                          ),
                        );
                      },
                    ),
                    
                    Text(
                      "すでにアカウントをお持ちの方",
                      style: AppConstants.captionStyle,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepItem(IconData icon, String step, String label, {bool isActive = false}) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: isActive ? AppConstants.primaryCyan : AppConstants.backgroundLight,
            shape: BoxShape.circle,
            boxShadow: isActive ? [
              BoxShadow(
                color: AppConstants.primaryCyan.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ] : [],
          ),
          child: Icon(
            icon,
            color: isActive ? Colors.white : AppConstants.primaryCyan,
            size: 30,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          step,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AppConstants.textGrey,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppConstants.textDark,
          ),
        ),
      ],
    );
  }
}
