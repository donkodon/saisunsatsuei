import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/company_service.dart';
import '../constants.dart';
import '../widgets/custom_button.dart';
import 'dashboard_screen.dart';

/// Firebase 認証ログイン画面
/// 
/// サインイン・サインアップ機能を提供
/// サインアップ時に企業IDをFirestoreに保存
class FirebaseLoginScreen extends StatefulWidget {
  const FirebaseLoginScreen({super.key});

  @override
  State<FirebaseLoginScreen> createState() => _FirebaseLoginScreenState();
}

class _FirebaseLoginScreenState extends State<FirebaseLoginScreen> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _companyIdController = TextEditingController();
  
  bool _isSignUp = false;  // true: サインアップモード, false: サインインモード
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _companyIdController.dispose();
    super.dispose();
  }

  /// サインイン処理
  Future<void> _signIn() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showErrorSnackBar('メールアドレスとパスワードを入力してください');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Firebase Authentication でサインイン
      final credential = await _authService.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Firestore から企業IDを取得
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .get();

      if (!userDoc.exists) {
        throw Exception('ユーザーデータが見つかりません。管理者に連絡してください。');
      }

      final companyId = userDoc.data()?['companyId'] as String?;
      if (companyId == null || companyId.isEmpty) {
        throw Exception('企業IDが設定されていません。管理者に連絡してください。');
      }

      // CompanyService に企業IDを保存
      if (mounted) {
        final companyService = Provider.of<CompanyService>(context, listen: false);
        await companyService.saveCompanyId(companyId);
        
        // ダッシュボードへ遷移
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      _showErrorSnackBar(_authService.getErrorMessage(e.code));
    } catch (e) {
      _showErrorSnackBar('ログインエラー: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// サインアップ処理
  Future<void> _signUp() async {
    if (_emailController.text.isEmpty || 
        _passwordController.text.isEmpty || 
        _companyIdController.text.isEmpty) {
      _showErrorSnackBar('すべての項目を入力してください');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Firebase Authentication でサインアップ
      final credential = await _authService.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Firestore に企業IDを保存
      await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .set({
        'email': credential.user!.email,
        'companyId': _companyIdController.text.trim(),
        'displayName': credential.user!.email?.split('@').first,
        'role': 'user',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // CompanyService に企業IDを保存
      if (mounted) {
        final companyService = Provider.of<CompanyService>(context, listen: false);
        await companyService.saveCompanyId(_companyIdController.text.trim());
        
        _showSuccessSnackBar('アカウント作成成功！');
        
        // ダッシュボードへ遷移
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      _showErrorSnackBar(_authService.getErrorMessage(e.code));
    } catch (e) {
      _showErrorSnackBar('アカウント作成エラー: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppConstants.primaryCyan,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppConstants.primaryCyan.withValues(alpha: 0.1),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ロゴ・アイコン
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppConstants.primaryCyan,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppConstants.primaryCyan.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // タイトル
                  Text(
                    _isSignUp ? 'アカウント作成' : 'ログイン',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isSignUp ? '新しいアカウントを作成します' : '採寸撮影アプリへようこそ',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 48),

                  // メールアドレス入力
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'メールアドレス',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 16),

                  // パスワード入力
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'パスワード',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    obscureText: _obscurePassword,
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 16),

                  // 企業ID入力（サインアップ時のみ表示）
                  if (_isSignUp) ...[
                    TextField(
                      controller: _companyIdController,
                      decoration: InputDecoration(
                        labelText: '企業ID',
                        prefixIcon: const Icon(Icons.business),
                        hintText: '例: test_company',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 24),
                  ] else
                    const SizedBox(height: 24),

                  // ログイン/サインアップボタン
                  if (_isLoading)
                    const CircularProgressIndicator()
                  else
                    CustomButton(
                      text: _isSignUp ? 'アカウント作成' : 'ログイン',
                      icon: _isSignUp ? Icons.person_add : Icons.login,
                      onPressed: _isSignUp ? _signUp : _signIn,
                    ),
                  const SizedBox(height: 16),

                  // モード切替ボタン
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _isSignUp = !_isSignUp;
                              _companyIdController.clear();
                            });
                          },
                    child: Text(
                      _isSignUp
                          ? 'すでにアカウントをお持ちですか？ログイン'
                          : 'アカウントをお持ちでない方はこちら',
                      style: TextStyle(
                        color: AppConstants.primaryCyan,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
