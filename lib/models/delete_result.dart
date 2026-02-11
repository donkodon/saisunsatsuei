/// 🗑️ 画像削除結果
class DeleteResult {
  final int total;          // 削除対象の総数
  final int successes;      // 成功数
  final int failures;       // 失敗数
  final List<String> successUrls;  // 成功したURL
  final List<DeleteFailure> failureDetails;  // 失敗詳細

  DeleteResult({
    required this.total,
    required this.successes,
    required this.failures,
    required this.successUrls,
    required this.failureDetails,
  });

  bool get isAllSuccess => failures == 0;
  bool get hasFailures => failures > 0;
}

/// 🗑️ 削除失敗の詳細
class DeleteFailure {
  final String url;
  final String reason;
  final int? statusCode;

  DeleteFailure({
    required this.url,
    required this.reason,
    this.statusCode,
  });
}
