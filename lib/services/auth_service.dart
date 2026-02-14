import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Firebase Authentication サービス
/// 
/// サインアップ、サインイン、サインアウトなどの認証機能を提供
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 現在ログイン中のユーザーを取得
  User? get currentUser => _auth.currentUser;

  /// 認証状態の変更を監視するStream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// メールアドレスとパスワードでサインアップ
  /// 
  /// [email] メールアドレス
  /// [password] パスワード（6文字以上推奨）
  /// 
  /// 成功時は [UserCredential] を返す
  /// 失敗時は [FirebaseAuthException] をスロー
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      if (kDebugMode) {
        print('🔐 AuthService: サインアップ開始 - $email');
      }
      
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (kDebugMode) {
        print('✅ AuthService: サインアップ成功 - UID: ${credential.user?.uid}');
      }
      
      return credential;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('❌ AuthService: サインアップエラー - ${e.code}: ${e.message}');
      }
      rethrow;
    }
  }

  /// メールアドレスとパスワードでサインイン
  /// 
  /// [email] メールアドレス
  /// [password] パスワード
  /// 
  /// 成功時は [UserCredential] を返す
  /// 失敗時は [FirebaseAuthException] をスロー
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      if (kDebugMode) {
        print('🔐 AuthService: サインイン開始 - $email');
      }
      
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (kDebugMode) {
        print('✅ AuthService: サインイン成功 - UID: ${credential.user?.uid}');
      }
      
      return credential;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('❌ AuthService: サインインエラー - ${e.code}: ${e.message}');
      }
      rethrow;
    }
  }

  /// サインアウト
  Future<void> signOut() async {
    try {
      if (kDebugMode) {
        print('🔐 AuthService: サインアウト開始');
      }
      
      await _auth.signOut();
      
      if (kDebugMode) {
        print('✅ AuthService: サインアウト成功');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ AuthService: サインアウトエラー - $e');
      }
      rethrow;
    }
  }

  /// パスワードリセットメールを送信
  /// 
  /// [email] パスワードをリセットしたいアカウントのメールアドレス
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      if (kDebugMode) {
        print('🔐 AuthService: パスワードリセットメール送信 - $email');
      }
      
      await _auth.sendPasswordResetEmail(email: email);
      
      if (kDebugMode) {
        print('✅ AuthService: パスワードリセットメール送信成功');
      }
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('❌ AuthService: パスワードリセットメール送信エラー - ${e.code}');
      }
      rethrow;
    }
  }

  /// Firebase Auth エラーコードを日本語メッセージに変換
  /// 
  /// [errorCode] Firebase Auth のエラーコード
  /// 
  /// 日本語のエラーメッセージを返す
  String getErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'email-already-in-use':
        return 'このメールアドレスは既に使用されています';
      case 'invalid-email':
        return 'メールアドレスの形式が正しくありません';
      case 'operation-not-allowed':
        return 'この操作は許可されていません';
      case 'weak-password':
        return 'パスワードが弱すぎます（6文字以上を推奨）';
      case 'user-disabled':
        return 'このアカウントは無効化されています';
      case 'user-not-found':
        return 'このメールアドレスのアカウントが見つかりません';
      case 'wrong-password':
        return 'パスワードが間違っています';
      case 'too-many-requests':
        return 'リクエストが多すぎます。しばらく待ってから再試行してください';
      case 'network-request-failed':
        return 'ネットワークエラーが発生しました。接続を確認してください';
      default:
        return '認証エラーが発生しました: $errorCode';
    }
  }
}
