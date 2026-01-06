/// 🎯 Result型（成功/失敗の明示的なハンドリング）
/// 
/// エラーハンドリングを明示的に行うための汎用Result型。
/// - Success: 成功時のデータを返す
/// - Failure: エラー情報を返す
sealed class Result<T> {
  const Result();
}

/// ✅ 成功
class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

/// ❌ 失敗
class Failure<T> extends Result<T> {
  final String message;
  final Exception? exception;
  final StackTrace? stackTrace;

  const Failure(
    this.message, {
    this.exception,
    this.stackTrace,
  });

  @override
  String toString() {
    return 'Failure(message: $message${exception != null ? ', exception: $exception' : ''})';
  }
}

/// Result型の拡張メソッド
extension ResultExtension<T> on Result<T> {
  /// 成功かどうか
  bool get isSuccess => this is Success<T>;
  
  /// 失敗かどうか
  bool get isFailure => this is Failure<T>;
  
  /// データを取得（成功の場合のみ）
  T? get dataOrNull => switch (this) {
    Success(data: final d) => d,
    Failure() => null,
  };
  
  /// エラーメッセージを取得（失敗の場合のみ）
  String? get errorOrNull => switch (this) {
    Success() => null,
    Failure(message: final msg) => msg,
  };
  
  /// マップ変換（成功時）
  Result<R> map<R>(R Function(T) transform) {
    return switch (this) {
      Success(data: final d) => Success(transform(d)),
      Failure(message: final msg, exception: final ex, stackTrace: final st) =>
        Failure(msg, exception: ex, stackTrace: st),
    };
  }
  
  /// flatMap変換（成功時に別のResult処理をチェーン）
  Result<R> flatMap<R>(Result<R> Function(T) transform) {
    return switch (this) {
      Success(data: final d) => transform(d),
      Failure(message: final msg, exception: final ex, stackTrace: final st) =>
        Failure(msg, exception: ex, stackTrace: st),
    };
  }
  
  /// fold（成功/失敗それぞれの処理を実行）
  R fold<R>({
    required R Function(T) onSuccess,
    required R Function(String) onFailure,
  }) {
    return switch (this) {
      Success(data: final d) => onSuccess(d),
      Failure(message: final msg) => onFailure(msg),
    };
  }
}
