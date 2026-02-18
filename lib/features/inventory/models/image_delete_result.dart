/// 画像差分削除に関するデータクラス群
///
/// image_diff_manager.dart が使用する結果モデルをここに集約。
/// ロジック (ImageDiffManager) とデータ構造を分離して保守性を高める。
library;

// ============================================================
// 差分検出結果
// ============================================================

/// 白抜き・マスク・P画像・F画像の差分削除リスト
class WhiteMaskDiffResult {
  /// 削除すべき白抜き画像URLリスト
  final List<String> whiteUrlsToDelete;

  /// 削除すべきマスク画像URLリスト
  final List<String> maskUrlsToDelete;

  /// 削除すべきP画像（背景除去）URLリスト
  final List<String> pImageUrlsToDelete;

  /// 削除すべきF画像（最終保存）URLリスト
  final List<String> fImageUrlsToDelete;

  const WhiteMaskDiffResult({
    required this.whiteUrlsToDelete,
    required this.maskUrlsToDelete,
    this.pImageUrlsToDelete = const [],
    this.fImageUrlsToDelete = const [],
  });

  /// 削除対象が1件以上あるか
  bool get hasImagesToDelete =>
      whiteUrlsToDelete.isNotEmpty ||
      maskUrlsToDelete.isNotEmpty ||
      pImageUrlsToDelete.isNotEmpty ||
      fImageUrlsToDelete.isNotEmpty;
}

// ============================================================
// 削除実行結果
// ============================================================

/// 単一種別の削除結果（成功数・失敗数）
class ImageDeleteResult {
  /// 削除成功件数
  final int deletedCount;

  /// 削除失敗件数
  final int failedCount;

  const ImageDeleteResult({
    required this.deletedCount,
    required this.failedCount,
  });

  bool get hasFailures => failedCount > 0;
}

/// 全種別（通常・白抜き・マスク・P・F）の一括削除結果
class CombinedDeleteResult {
  final ImageDeleteResult normalResult;
  final ImageDeleteResult whiteResult;
  final ImageDeleteResult maskResult;
  final ImageDeleteResult pImageResult;
  final ImageDeleteResult fImageResult;

  /// 全種別の削除成功合計
  final int totalDeleted;

  /// 全種別の削除失敗合計
  final int totalFailed;

  const CombinedDeleteResult({
    required this.normalResult,
    required this.whiteResult,
    required this.maskResult,
    required this.pImageResult,
    required this.fImageResult,
    required this.totalDeleted,
    required this.totalFailed,
  });

  bool get hasFailures => totalFailed > 0;
}
