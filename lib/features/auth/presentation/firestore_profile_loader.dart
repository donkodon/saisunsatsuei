import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:measure_master/features/inventory/presentation/dashboard_screen.dart';
import 'package:measure_master/features/auth/logic/auth_service.dart';
import 'package:measure_master/features/auth/logic/company_service.dart';

/// Firestore users/{uid} を読み込んで companyId を設定してから Dashboard へ遷移
///
/// 設計: Navigator.pushReplacement を使わず setState で _profileState を
/// 切り替えるだけで画面遷移を実現。StreamBuilder の再ビルドと競合しない。
class FirestoreProfileLoader extends StatefulWidget {
  final User user;
  final AuthService authService;

  const FirestoreProfileLoader({
    super.key,
    required this.user,
    required this.authService,
  });

  @override
  State<FirestoreProfileLoader> createState() =>
      _FirestoreProfileLoaderState();
}

/// プロフィール読み込みの状態
enum _ProfileState { loading, success, error }

class _FirestoreProfileLoaderState extends State<FirestoreProfileLoader> {
  _ProfileState _profileState = _ProfileState.loading;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile =
          await widget.authService.getUserProfile(widget.user.uid);

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
      final companyService =
          Provider.of<CompanyService>(context, listen: false);
      await companyService.saveCompanyId(
        companyId,
        companyName: profile['displayName'] as String?,
      );

      // lastLoginAt を更新（失敗しても画面遷移はする）
      widget.authService.updateLastLogin(widget.user.uid).catchError((_) {});

      if (mounted) {
        setState(() => _profileState = _ProfileState.success);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _profileState = _ProfileState.error;
          _errorMessage = 'ユーザー情報の取得に失敗しました。\n再度ログインしてください。';
        });
      }
    }
  }

  Future<void> _forceSignOut() async {
    try {
      final companyService =
          Provider.of<CompanyService>(context, listen: false);
      await companyService.logout();
      await widget.authService.signOut();
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    switch (_profileState) {
      case _ProfileState.loading:
        return _buildLoading();
      case _ProfileState.error:
        return _buildError();
      case _ProfileState.success:
        return const DashboardScreen();
    }
  }

  Widget _buildLoading() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C4D6)),
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
  }

  Widget _buildError() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off_outlined,
                  size: 64, color: Colors.orange[400]),
              const SizedBox(height: 24),
              const Text(
                'アカウント未設定',
                style:
                    TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[600],
                    height: 1.5),
              ),
              const SizedBox(height: 8),
              Text(
                widget.user.email ?? '',
                style: TextStyle(fontSize: 13, color: Colors.grey[400]),
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
                        borderRadius: BorderRadius.circular(12)),
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
  }
}
