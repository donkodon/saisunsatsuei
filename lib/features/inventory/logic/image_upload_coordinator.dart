import 'package:flutter/foundation.dart';
import 'package:measure_master/models/image_item.dart';
import 'package:measure_master/models/product_image.dart';
import 'package:measure_master/models/result.dart';
import 'package:measure_master/services/batch_image_upload_service.dart';

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
      debugPrint('📤 ImageUploadCoordinator: アップロード開始');
      debugPrint('   総画像数: ${images.length}');

      // 既存画像と新規画像を分離
      final existingImages = images.where((img) => img.isExisting).toList();
      final newImages = images.where((img) => img.isNew).toList();

      debugPrint('   既存画像: ${existingImages.length}枚');
      debugPrint('   新規画像: ${newImages.length}枚');

      // 既存画像のURLを取得
      final existingUrls = existingImages
          .where((img) => img.url != null)
          .map((img) => img.url!)
          .toList();

      debugPrint('🔍 既存画像URL取得完了: ${existingUrls.length}件');
      if (kDebugMode) {
        for (int i = 0; i < existingUrls.length; i++) {
          debugPrint('   [$i] ${existingUrls[i]}');
        }
      }

      // 新規画像のみアップロード
      List<String> newUrls = [];
      if (newImages.isNotEmpty) {
        debugPrint('🚀 新規画像アップロード開始: ${newImages.length}枚');
        
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
          
          debugPrint('✅ 新規画像アップロード完了: ${newUrls.length}件');
          if (kDebugMode) {
            for (int i = 0; i < newUrls.length; i++) {
              debugPrint('   [$i] ${newUrls[i]}');
            }
          }
        } else if (result is Failure<List<ProductImage>>) {
          throw Exception(result.message);
        }
      } else {
        debugPrint('⏭️ 新規画像なし、アップロードスキップ');
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

      debugPrint('📊 最終画像リスト: ${allUrls.length}件（既存${existingUrls.length} + 新規${newUrls.length} → 重複除去後${allUrls.length}）');

      // 🔍 デバッグ: 最終画像リスト全件ダンプ
      if (kDebugMode) {
        debugPrint('🔍 最終画像リスト全件ダンプ（全${allUrls.length}件）:');
        for (int i = 0; i < allUrls.length; i++) {
          final url = allUrls[i];
          String type = '通常';
          if (url.contains('_white.jpg')) {
            type = '白抜き';
          } else if (url.contains('_mask.png')) {
            type = 'マスク';
          }
          debugPrint('   [$i] ($type) $url');
        }
      }

      return ImageUploadResult(
        existingUrls: existingUrls,
        newUrls: newUrls,
        allUrls: allUrls,
      );

    } catch (e, stackTrace) {
      debugPrint('❌ ImageUploadCoordinator エラー: $e');
      debugPrint('スタックトレース: $stackTrace');
      rethrow;
    }
  }

  /// 🔍 画像の種類を判定
  String _getImageType(String url) {
    if (url.contains('_white.jpg')) {
      return '白抜き';
    } else if (url.contains('_mask.png')) {
      return 'マスク';
    } else {
      return '通常';
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
