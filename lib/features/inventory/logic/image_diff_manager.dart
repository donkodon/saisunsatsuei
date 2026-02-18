import 'package:flutter/foundation.dart';
import 'package:measure_master/features/inventory/domain/image_item.dart';
import 'package:measure_master/features/inventory/data/cloudflare_storage_service.dart';
import 'package:measure_master/features/inventory/models/image_delete_result.dart';

/// 🗑️ 画像差分削除管理クラス
/// 
/// 責任:
/// - 古い画像と新しい画像を比較
/// - 削除対象の画像URLを特定
/// - R2から画像を削除（Workers経由）
/// - 白抜き画像・マスク画像も自動削除
/// - UID + companyId + SKU からP/F画像URLを構築して削除
class ImageDiffManager {
  // ✅ CloudflareWorkersStorageServiceを直接使用（静的メソッドのみ）
  ImageDiffManager();

  // ====================================================
  // 🔑 UID → R2 URL 変換ユーティリティ
  // ====================================================

  /// R2の公開ベースURL
  /// 例: https://image-upload-api.jinkedon2.workers.dev
  static const String _workerBaseUrl =
      CloudflareWorkersStorageService.workerBaseUrl;

  /// UIDからP画像のR2フルURLを生成
  ///
  /// [uid]       - processed_imagesカラムに保存されているUID
  ///               例: "1025L280001_3f8a1b2c-..."  または  "3f8a1b2c-..."
  /// [companyId] - 企業ID (例: "relight")
  /// [sku]       - SKU (例: "1025L280001")
  ///
  /// R2パス: companyId/sku/sku_uid_p.png
  /// 戻り値: https://image-upload-api.jinkedon2.workers.dev/companyId/sku/sku_uid_p.png
  static String buildPImageUrl({
    required String uid,
    required String companyId,
    required String sku,
  }) {
    // UIDがすでに "sku_uuid" 形式なら「sku_」部分を除去してuuidのみ取り出す
    final uuid = uid.startsWith('${sku}_') ? uid.substring(sku.length + 1) : uid;
    final fileName = '${sku}_${uuid}_p.png';
    return '$_workerBaseUrl/$companyId/$sku/$fileName';
  }

  /// UIDからF画像のR2フルURLを生成
  ///
  /// [uid]       - final_imagesカラムに保存されているUID
  /// [companyId] - 企業ID
  /// [sku]       - SKU
  static String buildFImageUrl({
    required String uid,
    required String companyId,
    required String sku,
  }) {
    final uuid = uid.startsWith('${sku}_') ? uid.substring(sku.length + 1) : uid;
    final fileName = '${sku}_${uuid}_f.png';
    return '$_workerBaseUrl/$companyId/$sku/$fileName';
  }

  /// UIDリストからP/F画像のURLリストを一括生成
  ///
  /// [uids]      - UIDリスト (processed_images または final_images カラムの値)
  /// [companyId] - 企業ID
  /// [sku]       - SKU
  /// [type]      - 'p'（P画像）または 'f'（F画像）
  static List<String> buildDerivedImageUrls({
    required List<String> uids,
    required String companyId,
    required String sku,
    required String type, // 'p' or 'f'
  }) {
    if (uids.isEmpty || companyId.isEmpty || sku.isEmpty) return [];

    return uids.map((uid) {
      if (type == 'p') {
        return buildPImageUrl(uid: uid, companyId: companyId, sku: sku);
      } else {
        return buildFImageUrl(uid: uid, companyId: companyId, sku: sku);
      }
    }).toList();
  }

  // ====================================================
  // 🔗 オリジナルURL → P/F URL 一括変換
  // ====================================================

  /// オリジナル画像 URL リストから対応する P画像URLリストを生成
  ///
  /// ファイル命名規則: {companyId}/{sku}/{sku}_{uuid}.jpg
  ///   → P画像:        {companyId}/{sku}/{sku}_{uuid}_p.png
  ///
  /// [originalUrls] - _white.jpg / _mask.png / _p.png / _f.png を除いた
  ///                  オリジナル画像 URL リスト
  /// [companyId]    - 企業ID
  /// [sku]          - SKU
  static List<String> buildPUrlsFromOriginals({
    required List<String> originalUrls,
    required String companyId,
    required String sku,
  }) {
    return originalUrls
        .where((url) =>
            !url.contains('_white.jpg') &&
            !url.contains('_mask.png') &&
            !url.contains('_p.png') &&
            !url.contains('_P.jpg') &&
            !url.contains('_f.png') &&
            !url.contains('_F.jpg'))
        .map((url) {
      final uuid = ImageItem.extractUuidFromUrl(url);
      return buildPImageUrl(uid: uuid, companyId: companyId, sku: sku);
    }).toList();
  }

  /// オリジナル画像 URL リストから対応する F画像URLリストを生成
  static List<String> buildFUrlsFromOriginals({
    required List<String> originalUrls,
    required String companyId,
    required String sku,
  }) {
    return originalUrls
        .where((url) =>
            !url.contains('_white.jpg') &&
            !url.contains('_mask.png') &&
            !url.contains('_p.png') &&
            !url.contains('_P.jpg') &&
            !url.contains('_f.png') &&
            !url.contains('_F.jpg'))
        .map((url) {
      final uuid = ImageItem.extractUuidFromUrl(url);
      return buildFImageUrl(uid: uuid, companyId: companyId, sku: sku);
    }).toList();
  }

  // ====================================================
  // 🗑️ UID ベースのP/F画像差分削除
  // ====================================================

  /// UID + companyId + SKU を使ってP/F画像を差分削除する
  ///
  /// [oldPUids]    - 削除前のprocessed_images UID リスト（D1から取得）
  /// [oldFUids]    - 削除前のfinal_images UID リスト（D1から取得）
  /// [newPUids]    - 保存後のprocessed_images UID リスト（今回残すもの）
  /// [newFUids]    - 保存後のfinal_images UID リスト（今回残すもの）
  /// [companyId]   - 企業ID
  /// [sku]         - SKU
  ///
  /// Returns: 削除されたP/F画像の合計件数
  Future<CombinedDeleteResult> deleteDerivedImagesByUid({
    required List<String> oldPUids,
    required List<String> oldFUids,
    required List<String> newPUids,
    required List<String> newFUids,
    required String companyId,
    required String sku,
  }) async {

    // 差分: 古いUIDのうち、新しいUIDに含まれないものが削除対象
    final newPUidSet = newPUids.toSet();
    final newFUidSet = newFUids.toSet();

    final pUidsToDelete = oldPUids.where((uid) => !newPUidSet.contains(uid)).toList();
    final fUidsToDelete = oldFUids.where((uid) => !newFUidSet.contains(uid)).toList();


    // UID → URL 変換
    final pUrlsToDelete = buildDerivedImageUrls(
      uids: pUidsToDelete, companyId: companyId, sku: sku, type: 'p',
    );
    final fUrlsToDelete = buildDerivedImageUrls(
      uids: fUidsToDelete, companyId: companyId, sku: sku, type: 'f',
    );

    if (kDebugMode) {
      for (final _ in pUrlsToDelete) {
      }
      for (final _ in fUrlsToDelete) {
      }
    }

    // R2から削除実行
    final pResult = await deleteImagesFromR2(urls: pUrlsToDelete, sku: sku);
    final fResult = await deleteImagesFromR2(urls: fUrlsToDelete, sku: sku);

    final emptyResult = ImageDeleteResult(deletedCount: 0, failedCount: 0);


    return CombinedDeleteResult(
      normalResult: emptyResult,
      whiteResult: emptyResult,
      maskResult: emptyResult,
      pImageResult: pResult,
      fImageResult: fResult,
      totalDeleted: pResult.deletedCount + fResult.deletedCount,
      totalFailed: pResult.failedCount + fResult.failedCount,
    );
  }

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

    // 新しいURLのセット
    final newUrlSet = newUrls.toSet();

    // 古いURLで、新しいURLに含まれないものが削除対象
    final urlsToDelete = oldUrls.where((url) => !newUrlSet.contains(url)).toList();

    if (kDebugMode && urlsToDelete.isNotEmpty) {
      for (int i = 0; i < urlsToDelete.length; i++) {
      }
    }

    return urlsToDelete;
  }

  /// 🎨 白抜き画像・マスク画像・P画像・F画像の差分削除対象を特定
  /// 
  /// [allImageUrls] - 全画像URLリスト（通常画像+派生画像すべて）
  /// [oldWhiteUrls] - 古い白抜き画像URLリスト
  /// [oldMaskUrls] - 古いマスク画像URLリスト
  /// [oldPImageUrls] - 古いP画像（採寸用）URLリスト
  /// [oldFImageUrls] - 古いF画像（平置き）URLリスト
  /// [companyId] - 企業ID（フィルタリング用）
  /// [sku] - SKUコード（フィルタリング用）
  /// 
  /// Returns:
  /// - whiteUrlsToDelete: 削除すべき白抜き画像URLリスト
  /// - maskUrlsToDelete: 削除すべきマスク画像URLリスト
  /// - pImageUrlsToDelete: 削除すべきP画像URLリスト
  /// - fImageUrlsToDelete: 削除すべきF画像URLリスト
  WhiteMaskDiffResult detectWhiteMaskImagesToDelete({
    required List<String> allImageUrls,
    required List<String> oldWhiteUrls,
    required List<String> oldMaskUrls,
    List<String>? oldPImageUrls,
    List<String>? oldFImageUrls,
    String? companyId,
    String? sku,
  }) {

    // ✅ 修正: 実際にアップロードされた派生画像URLを抽出（企業ID/SKUでフィルタリング）
    final newWhiteUrls = allImageUrls.where((url) {
      if (!url.contains('_white.jpg')) return false;
      // 企業ID/SKUチェック
      if (companyId != null && !url.contains('/$companyId/')) return false;
      if (sku != null && !url.contains('/$sku/')) return false;
      return true;
    }).toSet();
    
    final newMaskUrls = allImageUrls.where((url) {
      if (!url.contains('_mask.png')) return false;
      if (companyId != null && !url.contains('/$companyId/')) return false;
      if (sku != null && !url.contains('/$sku/')) return false;
      return true;
    }).toSet();
    
    final newPImageUrls = allImageUrls.where((url) {
      // P画像は _p.png または _P.jpg の両方に対応
      if (!url.contains('_p.png') && !url.contains('_P.jpg')) return false;
      if (companyId != null && !url.contains('/$companyId/')) return false;
      if (sku != null && !url.contains('/$sku/')) return false;
      return true;
    }).toSet();
    
    final newFImageUrls = allImageUrls.where((url) {
      // F画像は _f.png または _F.jpg の両方に対応
      if (!url.contains('_f.png') && !url.contains('_F.jpg')) return false;
      if (companyId != null && !url.contains('/$companyId/')) return false;
      if (sku != null && !url.contains('/$sku/')) return false;
      return true;
    }).toSet();

    
    // 🔍 デバッグ: P画像の詳細チェック
    if (kDebugMode) {
      for (var url in allImageUrls) {
        if (url.contains('_p.png') || url.contains('_P.jpg') || url.contains('_p.') || url.contains('_P.')) {
          if (companyId != null) debugPrint('      contains(/$companyId/): ${url.contains('/$companyId/')}');
          if (sku != null) debugPrint('      contains(/$sku/): ${url.contains('/$sku/')}');
        }
      }
      
      for (var _ in oldPImageUrls ?? []) {
      }
    }

    // ✅ 修正: 古いURLで新しいURLに含まれないものを削除対象とする
    final oldWhiteUrlSet = oldWhiteUrls.toSet();
    final oldMaskUrlSet = oldMaskUrls.toSet();
    final oldPImageUrlSet = (oldPImageUrls ?? []).toSet();
    final oldFImageUrlSet = (oldFImageUrls ?? []).toSet();

    final whiteUrlsToDelete = oldWhiteUrlSet.difference(newWhiteUrls).toList();
    final maskUrlsToDelete = oldMaskUrlSet.difference(newMaskUrls).toList();
    final pImageUrlsToDelete = oldPImageUrlSet.difference(newPImageUrls).toList();
    final fImageUrlsToDelete = oldFImageUrlSet.difference(newFImageUrls).toList();

    if (whiteUrlsToDelete.isNotEmpty && kDebugMode) {
      for (var _ in whiteUrlsToDelete) {
      }
    }
    
    if (maskUrlsToDelete.isNotEmpty && kDebugMode) {
      for (var _ in maskUrlsToDelete) {
      }
    }
    
    if (pImageUrlsToDelete.isNotEmpty && kDebugMode) {
      for (var _ in pImageUrlsToDelete) {
      }
    }
    
    if (fImageUrlsToDelete.isNotEmpty && kDebugMode) {
      for (var _ in fImageUrlsToDelete) {
      }
    }

    return WhiteMaskDiffResult(
      whiteUrlsToDelete: whiteUrlsToDelete,
      maskUrlsToDelete: maskUrlsToDelete,
      pImageUrlsToDelete: pImageUrlsToDelete,
      fImageUrlsToDelete: fImageUrlsToDelete,
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
  Future<ImageDeleteResult> deleteImagesFromR2({
    required List<String> urls,
    required String sku,
  }) async {
    if (urls.isEmpty) {
      return ImageDeleteResult(deletedCount: 0, failedCount: 0);
    }


    int deletedCount = 0;
    int failedCount = 0;

    for (int i = 0; i < urls.length; i++) {
      final url = urls[i];
      try {
        // ✅ Workers経由の削除メソッドを使用
        await CloudflareWorkersStorageService.deleteImage(url);
        deletedCount++;
      } catch (e) {
        failedCount++;
      }
    }


    return ImageDeleteResult(
      deletedCount: deletedCount,
      failedCount: failedCount,
    );
  }

  /// 🗑️ 通常画像・白抜き画像・マスク画像・P画像・F画像を一括削除
  /// 
  /// [normalUrls] - 通常画像URLリスト
  /// [whiteUrls] - 白抜き画像URLリスト
  /// [maskUrls] - マスク画像URLリスト
  /// [pImageUrls] - P画像（採寸用）URLリスト
  /// [fImageUrls] - F画像（平置き）URLリスト
  /// [sku] - SKUコード
  /// 
  /// Returns: 削除結果
  Future<CombinedDeleteResult> deleteAllImages({
    required List<String> normalUrls,
    required List<String> whiteUrls,
    required List<String> maskUrls,
    List<String>? pImageUrls,
    List<String>? fImageUrls,
    required String sku,
  }) async {

    // 通常画像削除
    final normalResult = await deleteImagesFromR2(urls: normalUrls, sku: sku);

    // 白抜き画像削除
    final whiteResult = await deleteImagesFromR2(urls: whiteUrls, sku: sku);

    // マスク画像削除
    final maskResult = await deleteImagesFromR2(urls: maskUrls, sku: sku);

    // P画像削除
    final pImageResult = await deleteImagesFromR2(urls: pImageUrls ?? [], sku: sku);

    // F画像削除
    final fImageResult = await deleteImagesFromR2(urls: fImageUrls ?? [], sku: sku);

    final totalDeleted = normalResult.deletedCount + 
                         whiteResult.deletedCount + 
                         maskResult.deletedCount +
                         pImageResult.deletedCount +
                         fImageResult.deletedCount;
    final totalFailed = normalResult.failedCount + 
                        whiteResult.failedCount + 
                        maskResult.failedCount +
                        pImageResult.failedCount +
                        fImageResult.failedCount;


    return CombinedDeleteResult(
      normalResult: normalResult,
      whiteResult: whiteResult,
      maskResult: maskResult,
      pImageResult: pImageResult,
      fImageResult: fImageResult,
      totalDeleted: totalDeleted,
      totalFailed: totalFailed,
    );
  }
}

// データクラスは features/inventory/models/image_delete_result.dart に移動しました。
// WhiteMaskDiffResult / ImageDeleteResult / CombinedDeleteResult を参照してください。
