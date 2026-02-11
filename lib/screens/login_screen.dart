import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:measure_master/constants.dart';
import 'package:measure_master/services/company_service.dart';
import 'package:measure_master/screens/dashboard_screen.dart';
import 'package:measure_master/widgets/custom_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _companyIdController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final CompanyService _companyService = CompanyService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _companyIdController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// ログイン処理
  Future<void> _handleLogin() async {
    final companyId = _companyIdController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // バリデーション
    if (companyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('企業IDを入力してください'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('メールアドレスを入力してください'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('パスワードを入力してください'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 🔐 将来の認証処理用（現在は入力があればログイン成功）
      // TODO: 実際の認証APIを呼び出す
      
      debugPrint('🔐 ログイン処理開始');
      debugPrint('   企業ID: $companyId');
      debugPrint('   メール: $email');
      
      // 企業IDを保存（メモリには必ず保存される）
      await _companyService.saveCompanyId(companyId);
      debugPrint('✅ 企業ID保存完了');

      // ログイン成功 → DashboardScreenへ遷移
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ ログイン成功'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );

        debugPrint('✅ ログイン成功 - DashboardScreenへ遷移');

        // 少し待ってから遷移
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const DashboardScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 200),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ エラー発生: $e');
      debugPrint('スタックトレース: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ロゴアイコン
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppConstants.primaryCyan.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.straighten,
                    size: 60,
                    color: AppConstants.primaryCyan,
                  ),
                ),
                const SizedBox(height: 32),

                // タイトル
                Text(
                  'AI自動採寸',
                  textAlign: TextAlign.center,
                  style: AppConstants.headerStyle.copyWith(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Measure Master',
                  textAlign: TextAlign.center,
                  style: AppConstants.bodyStyle.copyWith(
                    color: AppConstants.textGrey,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 48),

                // 企業ID入力フィールド
                TextField(
                  controller: _companyIdController,
                  decoration: InputDecoration(
                    labelText: '企業ID',
                    hintText: '例: staygold_inc',
                    prefixIcon: Icon(
                      Icons.business,
                      color: AppConstants.primaryCyan,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppConstants.primaryCyan,
                        width: 2,
                      ),
                    ),
                  ),
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 16),

                // メールアドレス入力フィールド
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'メールアドレス',
                    hintText: '例: kenji@staygold.co.jp',
                    prefixIcon: Icon(
                      Icons.email,
                      color: AppConstants.primaryCyan,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppConstants.primaryCyan,
                        width: 2,
                      ),
                    ),
                  ),
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 16),

                // パスワード入力フィールド
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'パスワード',
                    hintText: 'パスワードを入力',
                    prefixIcon: Icon(
                      Icons.lock,
                      color: AppConstants.primaryCyan,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: AppConstants.textGrey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppConstants.primaryCyan,
                        width: 2,
                      ),
                    ),
                  ),
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 32),

                // ログインボタン
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : CustomButton(
                        text: 'ログイン',
                        onPressed: _handleLogin,
                      ),
                const SizedBox(height: 16),

                // 説明テキスト
                Text(
                  '※ 企業ID、メールアドレス、パスワードは管理者から発行されます',
                  textAlign: TextAlign.center,
                  style: AppConstants.captionStyle.copyWith(
                    color: AppConstants.textGrey,
                  ),
                ),
                const SizedBox(height: 8),
                Column(
                  children: [
                    Text(
                      'テストアカウント:',
                      textAlign: TextAlign.center,
                      style: AppConstants.captionStyle.copyWith(
                        color: AppConstants.textGrey,
                      ),
                    ),
                    Text(
                      '企業ID: test_company',
                      textAlign: TextAlign.center,
                      style: AppConstants.captionStyle.copyWith(
                        color: AppConstants.primaryCyan,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'メール: test@example.com',
                      textAlign: TextAlign.center,
                      style: AppConstants.captionStyle.copyWith(
                        color: AppConstants.primaryCyan,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'パスワード: test1234',
                      textAlign: TextAlign.center,
                      style: AppConstants.captionStyle.copyWith(
                        color: AppConstants.primaryCyan,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
