import 'package:flutter/foundation.dart';
import 'package:measure_master/features/inventory/domain/image_item.dart';
import 'package:measure_master/features/inventory/domain/product_image.dart';
import 'package:measure_master/core/utils/result.dart';
import 'package:measure_master/features/inventory/data/batch_image_upload_service.dart';

/// 📤 画像アップロード調整クラス
/// 
/// 責任:
/// - 既存画像と新規画像を区別
/// - 新規画像のみをアップロード
/// - アップロード進捗の管理
/// - 最終的な画像URLリストの生成（重複なし）
class ImageUploadCoordinator {
  final BatchImageUploadService _uploadService;

  ImageUploadCoordinator({
    BatchImageUploadService? uploadService,
  }) : _uploadService = uploadService ?? BatchImageUploadService();

  /// 🎯 画像アップロード処理（既存画像と新規画像を区別）
  /// 
  /// [images] - 全ImageItemリスト（既存 + 新規）
  /// [sku] - SKUコード
  /// [companyId] - 企業ID
  /// [onProgress] - 進捗コールバック
  /// 
  /// Returns:
  /// - existingUrls: 既存画像のURLリスト
  /// - newUrls: 新規アップロードされた画像のURLリスト
  /// - allUrls: 全画像URLリスト（重複除去済み）
  Future<ImageUploadResult> uploadImages({
    required List<ImageItem> images,
    required String sku,
    String? companyId,
    void Function(int current, int total)? onProgress,
  }) async {
    try {

      // 既存画像と新規画像を分離
      final existingImages = images.where((img) => img.isExisting).toList();
      final newImages = images.where((img) => img.isNew).toList();


      // 既存画像のURLを取得
      final existingUrls = existingImages
          .where((img) => img.url != null)
          .map((img) => img.url!)
          .toList();

      if (kDebugMode) {
        for (int i = 0; i < existingUrls.length; i++) {
        }
      }

      // 新規画像のみアップロード
      List<String> newUrls = [];
      if (newImages.isNotEmpty) {
        
        final result = await _uploadService.uploadImagesFromImageItems(
          imageItems: newImages,
          sku: sku,
          companyId: companyId,
          onProgress: onProgress,
        );

        if (result is Success<List<ProductImage>>) {
          // sequence順にソート
          final sortedImages = result.data..sort((a, b) => a.sequence.compareTo(b.sequence));
          newUrls = sortedImages.map((img) => img.url).toList();
          
          if (kDebugMode) {
            for (int i = 0; i < newUrls.length; i++) {
            }
          }
        } else if (result is Failure<List<ProductImage>>) {
          throw Exception(result.message);
        }
      } else {
      }

      // 既存URLと新規URLを結合（順序保持 + 重複除去）
      // ⚠️ Set変換すると順序が崩れるため、LinkedHashSetで順序を保持する
      final seen = <String>{};
      final allUrls = <String>[];
      for (final url in [...existingUrls, ...newUrls]) {
        if (seen.add(url)) {
          allUrls.add(url);
        }
      }


      // 🔍 デバッグ: 最終画像リスト全件ダンプ
      if (kDebugMode) {
        for (int i = 0; i < allUrls.length; i++) {
          final url = allUrls[i];
          String type = '通常';  // ignore: unused_local_variable
          if (url.contains('_white.jpg')) {
            type = '白抜き';
          } else if (url.contains('_mask.png')) {
            type = 'マスク';
          }
        }
      }

      return ImageUploadResult(
        existingUrls: existingUrls,
        newUrls: newUrls,
        allUrls: allUrls,
      );

    } catch (e) {
      rethrow;
    }
  }

}

/// 📦 画像アップロード結果
class ImageUploadResult {
  final List<String> existingUrls;  // 既存画像URL
  final List<String> newUrls;       // 新規画像URL
  final List<String> allUrls;       // 全画像URL（重複除去済み）

  ImageUploadResult({
    required this.existingUrls,
    required this.newUrls,
    required this.allUrls,
  });

  int get existingCount => existingUrls.length;
  int get newCount => newUrls.length;
  int get totalCount => allUrls.length;
}
