import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  /// `email` メールアドレス
  /// `password` パスワード（6文字以上推奨）
  /// 
  /// 成功時は `UserCredential` を返す
  /// 失敗時は `FirebaseAuthException` をスロー
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      
      return credential;
    } on FirebaseAuthException catch (_) {
      rethrow;
    }
  }

  /// メールアドレスとパスワードでサインイン
  /// 
  /// `email` メールアドレス
  /// `password` パスワード
  /// 
  /// 成功時は `UserCredential` を返す
  /// 失敗時は `FirebaseAuthException` をスロー
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      
      return credential;
    } on FirebaseAuthException catch (_) {
      rethrow;
    }
  }

  /// サインアウト
  Future<void> signOut() async {
    try {
      
      await _auth.signOut();
      
    } catch (_) {
      rethrow;
    }
  }

  /// パスワードリセットメールを送信
  /// 
  /// `email` パスワードをリセットしたいアカウントのメールアドレス
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      
      await _auth.sendPasswordResetEmail(email: email);
      
    } on FirebaseAuthException catch (_) {
      rethrow;
    }
  }

  /// Firestore users/`uid` からユーザープロフィールを取得
  /// 
  /// 返り値: `Map<String, dynamic>?` (null = ドキュメント未作成)
  /// 含まれるフィールド: email, companyId, displayName, role, createdAt
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      
      if (!doc.exists) {
        return null;
      }
      
      final data = doc.data();
      
      return data;
    } catch (_) {
      return null;
    }
  }

  /// Firestore users/`uid` の lastLoginAt を更新
  Future<void> updateLastLogin(String uid) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'lastLoginAt': FieldValue.serverTimestamp()});
    } catch (_) {
    }
  }

  /// Firebase Auth エラーコードを日本語メッセージに変換
  /// 
  /// `errorCode` Firebase Auth のエラーコード
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
