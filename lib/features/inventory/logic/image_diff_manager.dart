import 'package:flutter/foundation.dart';
import 'package:measure_master/services/cloudflare_storage_service.dart';

/// 🗑️ 画像差分削除管理クラス
/// 
/// 責任:
/// - 古い画像と新しい画像を比較
/// - 削除対象の画像URLを特定
/// - R2から画像を削除
/// - 白抜き画像・マスク画像も自動削除
class ImageDiffManager {
  final CloudflareStorageService _storageService;

  ImageDiffManager({
    CloudflareStorageService? storageService,
  }) : _storageService = storageService ?? CloudflareStorageService();

  /// 🔍 差分削除対象を特定
  /// 
  /// [oldUrls] - 古い画像URLリスト（DB保存済み）
  /// [newUrls] - 新しい画像URLリスト（今回保存する）
  /// 
  /// Returns: 削除すべき画像URLリスト
  List<String> detectImagesToDelete({
    required List<String> oldUrls,
    required List<String> newUrls,
  }) {
    debugPrint('🔍 差分削除対象を検出中...');
    debugPrint('   古い画像: ${oldUrls.length}件');
    debugPrint('   新しい画像: ${newUrls.length}件');

    // 新しいURLのセット
    final newUrlSet = newUrls.toSet();

    // 古いURLで、新しいURLに含まれないものが削除対象
    final urlsToDelete = oldUrls.where((url) => !newUrlSet.contains(url)).toList();

    debugPrint('   削除対象: ${urlsToDelete.length}件');
    if (kDebugMode && urlsToDelete.isNotEmpty) {
      for (int i = 0; i < urlsToDelete.length; i++) {
        debugPrint('   [$i] ${urlsToDelete[i]}');
      }
    }

    return urlsToDelete;
  }

  /// 🎨 白抜き画像・マスク画像の差分削除対象を特定
  /// 
  /// [allImageUrls] - 全画像URLリスト
  /// [oldWhiteUrls] - 古い白抜き画像URLリスト
  /// [oldMaskUrls] - 古いマスク画像URLリスト
  /// 
  /// Returns:
  /// - whiteUrlsToDelete: 削除すべき白抜き画像URLリスト
  /// - maskUrlsToDelete: 削除すべきマスク画像URLリスト
  WhiteMaskDiffResult detectWhiteMaskImagesToDelete({
    required List<String> allImageUrls,
    required List<String> oldWhiteUrls,
    required List<String> oldMaskUrls,
  }) {
    debugPrint('🎨 Phase 4: 白抜き・マスク画像の差分削除対象を検出');

    // 期待される白抜き画像URL（通常画像のURLから生成）
    final expectedWhiteUrls = <String>{};
    for (var url in allImageUrls) {
      if (!url.contains('_white.jpg') && url.endsWith('.jpg')) {
        final whiteUrl = url.replaceFirst('.jpg', '_white.jpg');
        expectedWhiteUrls.add(whiteUrl);
      }
    }

    // 期待されるマスク画像URL（通常画像のURLから生成）
    final expectedMaskUrls = <String>{};
    for (var url in allImageUrls) {
      if (!url.contains('_mask.png') && (url.endsWith('.jpg') || url.endsWith('.jpeg'))) {
        final extension = url.endsWith('.jpg') ? '.jpg' : '.jpeg';
        final maskUrl = url.replaceFirst(extension, '_mask.png');
        expectedMaskUrls.add(maskUrl);
      }
    }

    debugPrint('🎨 Phase 4: 期待される白抜き画像: ${expectedWhiteUrls.length}件');
    debugPrint('🎭 Phase 4: 期待されるマスク画像: ${expectedMaskUrls.length}件');
    debugPrint('🎨 Phase 4: DBの古い白抜き画像: ${oldWhiteUrls.length}件');
    debugPrint('🎭 Phase 4: DBの古いマスク画像: ${oldMaskUrls.length}件');

    // 削除対象を計算（古いURLで、期待されるURLに含まれないもの）
    final oldWhiteUrlSet = oldWhiteUrls.toSet();
    final oldMaskUrlSet = oldMaskUrls.toSet();

    final whiteUrlsToDelete = oldWhiteUrlSet.difference(expectedWhiteUrls).toList();
    final maskUrlsToDelete = oldMaskUrlSet.difference(expectedMaskUrls).toList();

    debugPrint('🎨 Phase 4: 削除対象の白抜き画像: ${whiteUrlsToDelete.length}件');
    debugPrint('🎭 Phase 4: 削除対象のマスク画像: ${maskUrlsToDelete.length}件');

    return WhiteMaskDiffResult(
      whiteUrlsToDelete: whiteUrlsToDelete,
      maskUrlsToDelete: maskUrlsToDelete,
    );
  }

  /// 🗑️ R2から画像を削除
  /// 
  /// [urls] - 削除する画像URLリスト
  /// [sku] - SKUコード（ログ用）
  /// 
  /// Returns:
  /// - deletedCount: 削除成功件数
  /// - failedCount: 削除失敗件数
  Future<DeleteResult> deleteImagesFromR2({
    required List<String> urls,
    required String sku,
  }) async {
    if (urls.isEmpty) {
      debugPrint('📌 削除対象なし（画像変更なし）');
      return DeleteResult(deletedCount: 0, failedCount: 0);
    }

    debugPrint('🗑️ R2から画像削除開始: ${urls.length}件');
    debugPrint('   SKU: $sku');

    int deletedCount = 0;
    int failedCount = 0;

    for (int i = 0; i < urls.length; i++) {
      final url = urls[i];
      try {
        debugPrint('   🗑️ [$i/${urls.length}] 削除中: $url');
        await CloudflareStorageService.deleteImage(url);
        deletedCount++;
        debugPrint('   ✅ 削除成功');
      } catch (e) {
        failedCount++;
        debugPrint('   ❌ 削除失敗: $e');
      }
    }

    debugPrint('🗑️ R2削除完了: 成功${deletedCount}件、失敗${failedCount}件');

    return DeleteResult(
      deletedCount: deletedCount,
      failedCount: failedCount,
    );
  }

  /// 🗑️ 通常画像・白抜き画像・マスク画像を一括削除
  /// 
  /// [normalUrls] - 通常画像URLリスト
  /// [whiteUrls] - 白抜き画像URLリスト
  /// [maskUrls] - マスク画像URLリスト
  /// [sku] - SKUコード
  /// 
  /// Returns: 削除結果
  Future<CombinedDeleteResult> deleteAllImages({
    required List<String> normalUrls,
    required List<String> whiteUrls,
    required List<String> maskUrls,
    required String sku,
  }) async {
    debugPrint('🗑️ 全種類の画像削除開始');
    debugPrint('   通常画像: ${normalUrls.length}件');
    debugPrint('   白抜き画像: ${whiteUrls.length}件');
    debugPrint('   マスク画像: ${maskUrls.length}件');

    // 通常画像削除
    final normalResult = await deleteImagesFromR2(urls: normalUrls, sku: sku);

    // 白抜き画像削除
    final whiteResult = await deleteImagesFromR2(urls: whiteUrls, sku: sku);

    // マスク画像削除
    final maskResult = await deleteImagesFromR2(urls: maskUrls, sku: sku);

    final totalDeleted = normalResult.deletedCount + whiteResult.deletedCount + maskResult.deletedCount;
    final totalFailed = normalResult.failedCount + whiteResult.failedCount + maskResult.failedCount;

    debugPrint('🗑️ 全削除完了: 成功${totalDeleted}件、失敗${totalFailed}件');

    return CombinedDeleteResult(
      normalResult: normalResult,
      whiteResult: whiteResult,
      maskResult: maskResult,
      totalDeleted: totalDeleted,
      totalFailed: totalFailed,
    );
  }
}

/// 📦 白抜き・マスク画像差分削除結果
class WhiteMaskDiffResult {
  final List<String> whiteUrlsToDelete;
  final List<String> maskUrlsToDelete;

  WhiteMaskDiffResult({
    required this.whiteUrlsToDelete,
    required this.maskUrlsToDelete,
  });

  bool get hasImagesToDelete => whiteUrlsToDelete.isNotEmpty || maskUrlsToDelete.isNotEmpty;
}

/// 📦 削除結果
class DeleteResult {
  final int deletedCount;
  final int failedCount;

  DeleteResult({
    required this.deletedCount,
    required this.failedCount,
  });

  bool get hasFailures => failedCount > 0;
}

/// 📦 全種類画像削除結果
class CombinedDeleteResult {
  final DeleteResult normalResult;
  final DeleteResult whiteResult;
  final DeleteResult maskResult;
  final int totalDeleted;
  final int totalFailed;

  CombinedDeleteResult({
    required this.normalResult,
    required this.whiteResult,
    required this.maskResult,
    required this.totalDeleted,
    required this.totalFailed,
  });

  bool get hasFailures => totalFailed > 0;
}
