import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:measure_master/constants.dart';
import 'package:measure_master/features/inventory/presentation/dashboard_screen.dart';
import 'package:measure_master/features/auth/presentation/login_screen.dart';
import 'package:measure_master/features/auth/logic/auth_service.dart';
import 'package:measure_master/features/auth/logic/company_service.dart';

/// 🔥 Firebase認証ゲート
/// Firebase Authentication + Firestore users の状態に応じて画面を切り替え
/// Auth済み → Firestore users/{uid} から companyId 取得 → DashboardScreen
///
/// 🔧 設計方針:
/// - StreamBuilder の再ビルドだけで画面遷移を管理する
/// - Navigator.pushReplacement は使わない（二重遷移の原因になる）
/// - このファイルが認証フローの唯一のゲートキーパー
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService _authService = AuthService();
  
  @override
  Widget build(BuildContext context) {
    // 🔄 StreamBuilderで認証状態を監視
    // ⚠️ 重要: この StreamBuilder が唯一の画面遷移制御ポイント
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        debugPrint('🔄 StreamBuilder状態: ${snapshot.connectionState}, hasData: ${snapshot.hasData}');
        
        // 認証状態を確認中
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
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
                  const SizedBox(height: 16),
                  Text(
                    '認証状態を確認中...',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }

        // 未ログイン → ログイン画面
        if (!snapshot.hasData || snapshot.data == null) {
          debugPrint('❌ 未ログイン状態 - ログイン画面表示');
          return const FirebaseLoginScreen();
        }

        // Auth済み → Firestore users/{uid} を確認してから DashboardScreen
        debugPrint('✅ ログイン済み状態 - プロフィール読み込み開始');
        final user = snapshot.data!;
        return _FirestoreProfileLoader(
          key: ValueKey(user.uid),  // 🔧 UID変更時にWidgetを再生成
          user: user,
          authService: _authService,
        );
      },
    );
  }
}

/// Firestore users/{uid} を読み込んで companyId を設定してから Dashboard へ
///
/// 設計: Navigator.pushReplacement を使わず、
/// setState で _profileState を切り替えるだけで画面遷移を実現
/// StreamBuilder の再ビルドと競合しない安全な設計
class _FirestoreProfileLoader extends StatefulWidget {
  final User user;
  final AuthService authService;

  const _FirestoreProfileLoader({
    super.key,
    required this.user,
    required this.authService,
  });

  @override
  State<_FirestoreProfileLoader> createState() => _FirestoreProfileLoaderState();
}

/// プロフィール読み込みの状態
enum _ProfileState {
  loading,   // 読み込み中
  success,   // 成功 → DashboardScreen表示
  error,     // エラー
}

class _FirestoreProfileLoaderState extends State<_FirestoreProfileLoader> {
  _ProfileState _profileState = _ProfileState.loading;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      debugPrint('🔍 Firestore ユーザープロフィール取得: ${widget.user.uid}');

      final profile = await widget.authService.getUserProfile(widget.user.uid);

      if (!mounted) return;

      if (profile == null) {
        setState(() {
          _profileState = _ProfileState.error;
          _errorMessage = 'アカウントが未設定です。\n管理者にお問い合わせください。';
        });
        return;
      }

      final companyId = profile['companyId'] as String?;
      if (companyId == null || companyId.isEmpty) {
        setState(() {
          _profileState = _ProfileState.error;
          _errorMessage = '企業IDが未設定です。\n管理者にお問い合わせください。';
        });
        return;
      }

      // companyId 取得成功 → CompanyService に保存
      final companyService = Provider.of<CompanyService>(context, listen: false);
      await companyService.saveCompanyId(
        companyId,
        companyName: profile['displayName'] as String?,
      );

      // lastLoginAt を更新（失敗しても画面遷移はする）
      widget.authService.updateLastLogin(widget.user.uid).catchError((e) {
        debugPrint('⚠️ lastLoginAt更新失敗（無視）: $e');
      });

      debugPrint('═══════════════════════════════════════');
      debugPrint('✅ ログイン成功 - 企業ID設定完了');
      debugPrint('   企業ID: "$companyId"');
      debugPrint('   Firebase UID: "${widget.user.uid}"');
      debugPrint('   Email: "${widget.user.email}"');
      debugPrint('   表示名: "${profile['displayName']}"');
      debugPrint('═══════════════════════════════════════');
      debugPrint('🚀 DashboardScreenを表示');

      if (mounted) {
        setState(() {
          _profileState = _ProfileState.success;
        });
      }
    } catch (e) {
      debugPrint('❌ プロフィール取得エラー: $e');
      if (mounted) {
        setState(() {
          _profileState = _ProfileState.error;
          _errorMessage = 'ユーザー情報の取得に失敗しました。\n再度ログインしてください。';
        });
      }
    }
  }

  /// ログアウト処理
  /// Firebase Auth signOut → authStateChanges が null を発火
  /// → StreamBuilder が自動的に FirebaseLoginScreen を表示
  Future<void> _forceSignOut() async {
    try {
      final companyService = Provider.of<CompanyService>(context, listen: false);
      await companyService.logout();
      debugPrint('✅ _forceSignOut: CompanyService クリア完了');

      await widget.authService.signOut();
      debugPrint('✅ _forceSignOut: Firebase サインアウト完了');

      // Web での authStateChanges 伝搬遅延に対応
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      debugPrint('❌ _forceSignOut エラー: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_profileState) {
      case _ProfileState.loading:
        return Scaffold(
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
                const SizedBox(height: 16),
                Text(
                  'ユーザー情報を読み込み中...',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ),
        );

      case _ProfileState.error:
        return Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_off_outlined,
                    size: 64,
                    color: Colors.orange[400],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'アカウント未設定',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage ?? '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.user.email ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.logout),
                      label: const Text('ログアウトして戻る'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red[400],
                        side: BorderSide(color: Colors.red[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _forceSignOut,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('再試行'),
                      onPressed: () {
                        setState(() {
                          _profileState = _ProfileState.loading;
                          _errorMessage = null;
                        });
                        _loadUserProfile();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

      case _ProfileState.success:
        // 🎯 Navigator不使用: StreamBuilder ツリー内で直接表示
        return const DashboardScreen();
    }
  }
}
