import 'package:flutter/material.dart';
import 'package:measure_master/features/auth/logic/auth_service.dart';
import 'package:measure_master/features/auth/presentation/login_bottom_sheet.dart';

/// Firebase 認証ログイン画面（管理者招待制 - ログインのみ）
/// 
/// トップページ（ランディングページ）として機能し、
/// ユーザーにアプリの価値を伝えた上でログインへ誘導する
/// ※ サインアップ機能なし（管理者がFirebase Consoleからアカウント作成）
class FirebaseLoginScreen extends StatefulWidget {
  const FirebaseLoginScreen({super.key});

  @override
  State<FirebaseLoginScreen> createState() => _FirebaseLoginScreenState();
}

class _FirebaseLoginScreenState extends State<FirebaseLoginScreen> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isBottomSheetOpen = false;  // ボトムシート重複表示防止フラグ

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // デザイン再現用カラー定義
    const bgGrey = Color(0xFFF7F8F9);
    const accentCyan = Color(0xFF00C4D6);
    const textDark = Color(0xFF1A1A1A);

    return Scaffold(
      backgroundColor: bgGrey,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    
                    // ヘッダータグ (AI MEASURE)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.straighten, size: 18, color: accentCyan),
                          const SizedBox(width: 8),
                          Text(
                            'AI MEASURE',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: textDark.withValues(alpha: 0.8),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                
                    const SizedBox(height: 24),
                
                    // ヒーロー画像 (スマホモックアップ)
                    SizedBox(
                      height: 400,
                      width: double.infinity,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // 背景のぼんやりした光
                          Container(
                            width: 320,
                            height: 320,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: accentCyan.withValues(alpha: 0.12),
                                  blurRadius: 80,
                                  spreadRadius: 30,
                                ),
                              ],
                            ),
                          ),
                          // スマホ画像
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Image.asset(
                              'assets/images/hero_mockup.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 300,
                                  width: 180,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.broken_image, color: Colors.grey, size: 48),
                                      const SizedBox(height: 8),
                                      Text(
                                        '画像読み込みエラー',
                                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                
                    const SizedBox(height: 16),
                
                    // メインコピー
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: const TextSpan(
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: textDark,
                            height: 1.3,
                            fontFamily: 'Noto Sans JP',
                          ),
                          children: [
                            TextSpan(text: 'AI自動採寸で、\n出品を'),
                            TextSpan(
                              text: '10倍',
                              style: TextStyle(
                                color: accentCyan,
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            TextSpan(text: '速く'),
                          ],
                        ),
                      ),
                    ),
                
                    const SizedBox(height: 16),
                
                    // サブコピー
                    Text(
                      '服を平置きして撮影するだけ。\nサイズ表を自動生成します。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[600],
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                
                    const SizedBox(height: 40),
                
                    // 3ステップカード
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCardStepItem(
                            icon: Icons.camera_alt_outlined,
                            step: 'STEP 1',
                            title: '撮影',
                            color: Colors.lightBlue[50]!,
                            iconColor: Colors.lightBlue,
                          ),
                          const SizedBox(width: 16),
                          _buildCardStepItem(
                            icon: Icons.auto_awesome,
                            step: 'STEP 2',
                            title: 'AI測定',
                            color: Colors.cyan[50]!,
                            iconColor: accentCyan,
                            isFeatured: true,
                          ),
                          const SizedBox(width: 16),
                          _buildCardStepItem(
                            icon: Icons.sell_outlined,
                            step: 'STEP 3',
                            title: '出品',
                            color: Colors.blue[50]!,
                            iconColor: Colors.blue,
                          ),
                        ],
                      ),
                    ),
                
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // フッター固定エリア - ログインボタンのみ
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              decoration: BoxDecoration(
                color: bgGrey,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.8),
                    blurRadius: 20,
                    offset: const Offset(0, -10),
                    spreadRadius: 10,
                  )
                ]
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ログインボタン
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => _showLoginDialog(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentCyan,
                        foregroundColor: Colors.white,
                        elevation: 8,
                        shadowColor: accentCyan.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'ログイン',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 22),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // 管理者招待制の説明
                  Text(
                    'アカウントは管理者から発行されます',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // カード形式のステップアイテム
  Widget _buildCardStepItem({
    required IconData icon,
    required String step,
    required String title,
    required Color color,
    required Color iconColor,
    bool isFeatured = false,
  }) {
    return Expanded(
      child: Container(
        height: 140,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            if (isFeatured)
              BoxShadow(
                color: iconColor.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 6),
                spreadRadius: 2,
              ),
          ],
          border: isFeatured 
              ? Border.all(color: iconColor.withValues(alpha: 0.5), width: 1.5)
              : Border.all(color: Colors.transparent),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isFeatured ? iconColor : color,
                shape: BoxShape.circle,
                gradient: isFeatured ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    iconColor.withValues(alpha: 0.8),
                    iconColor,
                  ],
                ) : null,
              ),
              child: Icon(
                icon,
                size: 26,
                color: isFeatured ? Colors.white : iconColor,
              ),
            ),
            const Spacer(),
            Text(
              step,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ログインダイアログ（ボトムシート）
  void _showLoginDialog(BuildContext parentContext) {
    // 🔒 重複表示を防止
    if (_isBottomSheetOpen) {
      return;
    }

    _isBottomSheetOpen = true;

    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => LoginBottomSheet(
        emailController: _emailController,
        passwordController: _passwordController,
        authService: _authService,
        parentContext: parentContext,
      ),
    ).whenComplete(() {
      // 🔓 ボトムシートが閉じたらフラグをリセット
      _isBottomSheetOpen = false;
    });
  }
}

