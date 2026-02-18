import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:measure_master/core/services/image_cache_service.dart';
import 'package:measure_master/core/utils/app_feedback.dart';
import 'package:measure_master/features/auth/logic/company_service.dart';
import 'package:measure_master/features/inventory/domain/image_item.dart';
import 'package:measure_master/features/inventory/domain/item.dart';
import 'package:measure_master/features/inventory/logic/image_diff_manager.dart';
import 'package:measure_master/features/inventory/logic/image_upload_coordinator.dart';
import 'package:measure_master/features/inventory/logic/inventory_provider.dart';
import 'package:measure_master/features/inventory/logic/inventory_saver.dart';
import 'package:measure_master/features/measurement/logic/measurement_service.dart';

/// 💾 詳細画面の保存ロジック mixin
///
/// 責務:
/// - _saveProduct（Phase 1〜7: アップロード→差分削除→保存→AI採寸）
/// - _retryD1Sync（D1 再同期リトライ）
/// - _show* フィードバックヘルパー
///
/// 利用側 State が提供すべき getter:
///   - widget.sku / itemName / brand / category / etc.
///   - _skuController / _sizeController / _barcodeController / _descriptionController
///   - _selectedMaterial / _selectedColor
///   - _uploadCoordinator / _diffManager / _inventorySaver / _measurementService
///   - _companyService / _inventoryProvider
///   - _uploadProgress / _uploadTotal (setState で更新)
mixin DetailSaveMixin<T extends StatefulWidget> on State<T> {
  // ─── 親 State から公開する必要があるメンバー ───────────────
  CompanyService get companyService;
  InventoryProvider get inventoryProvider;
  ImageUploadCoordinator get uploadCoordinator;
  ImageDiffManager get diffManager;
  InventorySaver get inventorySaver;
  MeasurementService get measurementService;

  // widget フィールド
  String get widgetSku;
  String get widgetItemName;
  String get widgetBrand;
  String get widgetCategory;
  String get widgetCondition;
  String get widgetPrice;
  String get widgetProductRank;
  String? get widgetLength;
  String? get widgetWidth;
  String? get widgetShoulder;
  String? get widgetSleeve;
  bool get widgetAiMeasureEnabled;
  List<ImageItem>? get widgetImages;

  // コントローラ
  TextEditingController get skuController;
  TextEditingController get sizeController;
  TextEditingController get barcodeController;
  TextEditingController get descriptionController;

  // 選択値
  String get selectedMaterial;
  String get selectedColor;

  // プログレス更新コールバック
  void onUploadProgress(int current, int total);

  // ─── 保存処理 ───────────────────────────────────────────────

  /// 商品確定ボタンから呼ばれるメインの保存処理
  Future<void> saveProduct(BuildContext context) async {
    if (kDebugMode) {
      debugPrint('🚀 saveProduct() 開始');
    }

    try {
      // ========== Phase 1: 古い画像URL取得（差分削除用） ==========
      List<String> oldImageUrls = [];
      List<String> oldWhiteUrls = [];
      List<String> oldMaskUrls = [];
      List<String> oldPImageUrls = [];
      List<String> oldFImageUrls = [];

      if (widgetSku.isNotEmpty) {
        final oldItem = inventoryProvider.findBySku(widgetSku);
        if (oldItem?.imageUrls != null) {
          oldImageUrls = oldItem!.imageUrls!;
          oldWhiteUrls = oldImageUrls
              .where((url) => url.contains('_white.jpg'))
              .toList();
          oldMaskUrls = oldImageUrls
              .where((url) => url.contains('_mask.png'))
              .toList();

          if (kDebugMode) {
            debugPrint('📂 古い画像: ${oldImageUrls.length}件'
                '（白抜き${oldWhiteUrls.length}件, マスク${oldMaskUrls.length}件）');
          }

          final companyIdForDerived =
              (await companyService.getCompanyId()) ?? '';
          final oldOriginalUrls = oldImageUrls.where((url) =>
              !url.contains('_white.jpg') &&
              !url.contains('_mask.png') &&
              !url.contains('_p.png') &&
              !url.contains('_P.jpg') &&
              !url.contains('_f.png') &&
              !url.contains('_F.jpg')).toList();

          oldPImageUrls = ImageDiffManager.buildPUrlsFromOriginals(
            originalUrls: oldOriginalUrls,
            companyId: companyIdForDerived,
            sku: widgetSku,
          );
          oldFImageUrls = ImageDiffManager.buildFUrlsFromOriginals(
            originalUrls: oldOriginalUrls,
            companyId: companyIdForDerived,
            sku: widgetSku,
          );
        }
      }

      if (!mounted) return;

      // ========== Phase 2: プログレスダイアログ表示 ==========
      // ignore: use_build_context_synchronously
      showDialog(
        context: context, // ignore: use_build_context_synchronously
        barrierDismissible: false,
        builder: (_) => _UploadProgressDialog(
          getProgress: () => _uploadProgressValue,
          getTotal: () => _uploadTotalValue,
        ),
      );

      // ========== Phase 3: 画像アップロード ==========
      final images = widgetImages ?? [];
      final companyId = await companyService.getCompanyId();

      final uploadResult = await uploadCoordinator.uploadImages(
        images: images,
        sku: widgetSku.isNotEmpty ? widgetSku : 'NOSKU',
        companyId: companyId,
        onProgress: onUploadProgress,
      );

      // ========== Phase 4: 差分削除 ==========
      int deleteFailureCount = 0;

      final urlsToDelete = diffManager.detectImagesToDelete(
        oldUrls: oldImageUrls
            .where((url) =>
                !url.contains('_white.jpg') &&
                !url.contains('_mask.png'))
            .toList(),
        newUrls: uploadResult.allUrls,
      );

      final whiteMaskDiff = diffManager.detectWhiteMaskImagesToDelete(
        allImageUrls: uploadResult.allUrls,
        oldWhiteUrls: oldWhiteUrls,
        oldMaskUrls: oldMaskUrls,
        oldPImageUrls: oldPImageUrls,
        oldFImageUrls: oldFImageUrls,
        companyId: companyId ?? '',
        sku: widgetSku,
      );

      if (urlsToDelete.isNotEmpty || whiteMaskDiff.hasImagesToDelete) {
        final deleteResult = await diffManager.deleteAllImages(
          normalUrls: urlsToDelete,
          whiteUrls: whiteMaskDiff.whiteUrlsToDelete,
          maskUrls: whiteMaskDiff.maskUrlsToDelete,
          pImageUrls: whiteMaskDiff.pImageUrlsToDelete,
          fImageUrls: whiteMaskDiff.fImageUrlsToDelete,
          sku: widgetSku,
        );
        deleteFailureCount = deleteResult.totalFailed;

        final allDeletedUrls = [
          ...urlsToDelete,
          ...whiteMaskDiff.whiteUrlsToDelete,
          ...whiteMaskDiff.maskUrlsToDelete,
          ...whiteMaskDiff.pImageUrlsToDelete,
          ...whiteMaskDiff.fImageUrlsToDelete,
        ];
        if (allDeletedUrls.isNotEmpty) {
          await ImageCacheService.invalidateCaches(allDeletedUrls);
        }
      }

      // ========== Phase 5: InventoryItem 作成 ==========
      final mainImageUrl = uploadResult.allUrls.isNotEmpty
          ? uploadResult.allUrls.first
          : 'https://via.placeholder.com/150';

      final uniqueId =
          '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';

      // 通常画像 + 白抜き画像を合算
      final seen = <String>{};
      final allImageUrlsWithDerived = <String>[];
      for (final url in uploadResult.allUrls) {
        if (seen.add(url)) allImageUrlsWithDerived.add(url);
      }
      if (widgetImages != null) {
        for (final img in widgetImages!) {
          if (img.whiteUrl != null && seen.add(img.whiteUrl!)) {
            allImageUrlsWithDerived.add(img.whiteUrl!);
          }
        }
      }

      if (kDebugMode) {
        debugPrint('📦 保存URLリスト: ${allImageUrlsWithDerived.length}件'
            '（通常${uploadResult.allUrls.length}件'
            ' + 白抜き${allImageUrlsWithDerived.length - uploadResult.allUrls.length}件）');
      }

      final newItem = InventoryItem(
        id: uniqueId,
        name: widgetItemName,
        brand: widgetBrand,
        imageUrl: mainImageUrl,
        category: _emptyToNull(widgetCategory) ?? '',
        status: 'Ready',
        date: DateTime.now(),
        length: 68,
        width: 52,
        size: sizeController.text.isEmpty ? 'M' : sizeController.text,
        barcode: barcodeController.text.isEmpty
            ? null
            : barcodeController.text,
        sku: skuController.text.isEmpty ? null : skuController.text,
        productRank: _emptyToNull(widgetProductRank),
        condition: _emptyToNull(widgetCondition),
        description: descriptionController.text.isEmpty
            ? null
            : descriptionController.text,
        color: _emptyToNull(selectedColor),
        material: _emptyToNull(selectedMaterial),
        salePrice: widgetPrice.isNotEmpty
            ? int.tryParse(widgetPrice)
            : null,
        imageUrls: allImageUrlsWithDerived,
      );

      // ========== Phase 6: Hive + D1 保存 ==========
      final saveResult = await inventorySaver.saveToHiveAndD1(
        item: newItem,
        imageUrls: allImageUrlsWithDerived,
        additionalData: {
          'length': widgetLength,
          'width': widgetWidth,
          'shoulder': widgetShoulder,
          'sleeve': widgetSleeve,
        },
      );

      if (!mounted) return;
      // ignore: use_build_context_synchronously
      Navigator.pop(context); // プログレスダイアログを閉じる

      // ========== Phase 6.5: AI自動採寸（Fire & Forget） ==========
      if (widgetAiMeasureEnabled && uploadResult.allUrls.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('📏 AI自動採寸開始: ${uploadResult.allUrls.first}');
        }
        final cId = await companyService.getCompanyId() ?? '';
        try {
          await measurementService.measureGarmentAsync(
            imageUrl: uploadResult.allUrls.first,
            sku: widgetSku.isNotEmpty ? widgetSku : 'NOSKU',
            companyId: cId,
            category: widgetCategory,
          );
          if (kDebugMode) debugPrint('✅ AI採寸リクエスト送信成功');
        } catch (e) {
          if (kDebugMode) debugPrint('❌ AI採寸リクエスト送信エラー: $e');
        }
      }

      // ========== Phase 7: 結果表示 ==========
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      onSaveComplete(context, saveResult, deleteFailureCount, newItem);
    } catch (e, stackTrace) {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      Navigator.pop(context);
      if (kDebugMode) {
        debugPrint('❌ saveProduct() エラー: $e\n$stackTrace');
      }
      // ignore: use_build_context_synchronously
      AppFeedback.showError(context, '保存エラー: $e');
    }
  }

  /// 保存完了後の画面遷移・フィードバック（override 可能）
  void onSaveComplete(
    BuildContext context,
    dynamic saveResult,
    int deleteFailureCount,
    InventoryItem newItem,
  );

  /// D1 再同期リトライ
  Future<void> retryD1Sync(BuildContext context, InventoryItem item) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator()),
    );

    final saveResult = await inventorySaver.saveToHiveAndD1(
      item: item,
      imageUrls: item.imageUrls ?? [],
      additionalData: {},
    );

    if (!mounted) return;
    // ignore: use_build_context_synchronously
    Navigator.pop(context);

    if (saveResult.bothSuccess) {
      // ignore: use_build_context_synchronously
      AppFeedback.showSuccess(context, '✅ クラウド同期完了');
    } else {
      // ignore: use_build_context_synchronously
      AppFeedback.showError(context, '❌ 同期失敗。後で再試行してください。');
    }
  }

  // ─── プログレス値（子クラスが setState で更新） ──────────────
  int _uploadProgressValue = 0;
  int _uploadTotalValue = 0;

  void updateUploadProgress(int current, int total) {
    setState(() {
      _uploadProgressValue = current;
      _uploadTotalValue = total;
    });
  }
}

/// 空文字・「選択してください」を null に変換するユーティリティ関数
String? _emptyToNull(String? v) =>
    (v == null || v.isEmpty || v == '選択してください') ? null : v;

// ── アップロード中ダイアログ（内部 Widget） ─────────────────────
class _UploadProgressDialog extends StatelessWidget {
  final int Function() getProgress;
  final int Function() getTotal;

  const _UploadProgressDialog({
    required this.getProgress,
    required this.getTotal,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          const Text('画像アップロード中...',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            '${getProgress()} / ${getTotal()}',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
