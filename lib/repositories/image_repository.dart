import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product_image.dart';
import '../models/result.dart';
import '../services/cloudflare_storage_service.dart';
import '../services/image_cache_service.dart';

/// 🖼️ 画像リポジトリ（統一管理層）
/// 
/// すべての画像操作を一元管理するリポジトリ。
/// - Cloudflare R2へのアップロード/削除
/// - ローカルキャッシュへの保存/読み込み
/// - メタデータの管理
/// - エラーハンドリングの一元化
class ImageRepository {
  final _uuid = Uuid();
  final CloudflareWorkersStorageService _cloudflareService;
  final ImageCacheService _cacheService;

  ImageRepository({
    CloudflareWorkersStorageService? cloudflareService,
    ImageCacheService? cacheService,
  })  : _cloudflareService = cloudflareService ?? CloudflareWorkersStorageService(),
        _cacheService = cacheService ?? ImageCacheService();

  /// 📸 画像を保存（アップロード + キャッシュ）
  /// 
  /// - Cloudflare R2にアップロード
  /// - ローカルキャッシュに保存
  /// - ProductImageオブジェクトを返す
  /// 
  /// [imageBytes] - 画像データ
  /// [sku] - SKUコード（フォルダ分けに使用）
  /// [sequence] - 連番（表示順序用、ファイル名には使用しない）
  /// [imageId] - 画像UUID（オプション、未指定時は自動生成）
  /// [source] - 画像ソース（カメラ/ギャラリー）
  /// [isMain] - メイン画像フラグ
  Future<Result<ProductImage>> saveImage({
    required Uint8List imageBytes,
    required String sku,
    required int sequence,
    String? imageId,
    ImageSource source = ImageSource.camera,
    bool isMain = false,
    String? localPath,
  }) async {
    try {
      debugPrint('🔧 ImageRepository.saveImage 開始');
      debugPrint('  📦 SKU: $sku, 連番: $sequence');
      
      // 🎯 Phase 1: UUID導入 - ファイル名を ${sku}_${uuid}.jpg 形式に変更
      final uuid = imageId ?? _uuid.v4();
      final fileId = '${sku}_$uuid';
      final fileName = '$fileId.jpg';
      
      debugPrint('  🆔 UUID: $uuid');
      debugPrint('  📁 fileId: $fileId');
      debugPrint('  📁 ファイル名: $fileName');

      // Step 1: Cloudflareにアップロード
      debugPrint('  ⏳ Step 1: Cloudflareにアップロード中...');
      final uploadResult = await _uploadToCloudflare(
        imageBytes: imageBytes,
        fileId: fileId,
        sku: sku,
      );

      if (uploadResult is Failure<String>) {
        return Failure(
          'Cloudflareアップロード失敗: ${uploadResult.message}',
          exception: uploadResult.exception,
        );
      }

      final imageUrl = (uploadResult as Success<String>).data;
      debugPrint('  ✅ Step 1完了: $imageUrl');

      // Step 2: ローカルキャッシュに保存
      debugPrint('  ⏳ Step 2: ローカルキャッシュに保存中...');
      final cacheResult = await _saveToCache(
        imageUrl: imageUrl,
        imageBytes: imageBytes,
      );

      if (cacheResult is Failure) {
        debugPrint('  ⚠️ キャッシュ保存失敗（続行）: ${cacheResult.message}');
      } else {
        debugPrint('  ✅ Step 2完了: キャッシュ保存成功');
      }

      // Step 3: ProductImageオブジェクトの作成
      final productImage = ProductImage(
        id: uuid,  // 🎯 UUIDを使用（ファイル名と一致）
        url: imageUrl,
        localPath: localPath,
        fileName: fileName,
        sequence: sequence,
        isMain: isMain,
        capturedAt: DateTime.now(),
        source: source,
        uploadStatus: UploadStatus.uploaded,
        isDeleted: false,
      );

      debugPrint('  ✅ ImageRepository.saveImage 完了');
      debugPrint('  📸 ProductImage: ${productImage.toString()}');

      return Success(productImage);

    } catch (e, stackTrace) {
      debugPrint('❌ ImageRepository.saveImage エラー: $e');
      return Failure(
        '画像保存エラー: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      );
    }
  }

  /// 🗑️ 画像を削除（Cloudflare + キャッシュ）
  /// 
  /// - Cloudflare R2から削除
  /// - ローカルキャッシュから削除
  /// - 削除済みフラグを立てたProductImageを返す
  /// 
  /// [productImage] - 削除する画像
  Future<Result<ProductImage>> deleteImage(ProductImage productImage) async {
    try {
      debugPrint('🗑️ ImageRepository.deleteImage 開始');
      debugPrint('  📦 削除対象: ${productImage.fileName}');

      // Step 1: Cloudflareから削除
      debugPrint('  ⏳ Step 1: Cloudflareから削除中...');
      final deleteResult = await _deleteFromCloudflare(productImage.url);

      if (deleteResult is Failure) {
        debugPrint('  ⚠️ Cloudflare削除失敗（続行）: ${deleteResult.message}');
      } else {
        debugPrint('  ✅ Step 1完了: Cloudflareから削除成功');
      }

      // Step 2: キャッシュから削除
      debugPrint('  ⏳ Step 2: キャッシュから削除中...');
      final cacheDeleteResult = await _deleteFromCache(productImage.url);

      if (cacheDeleteResult is Failure) {
        debugPrint('  ⚠️ キャッシュ削除失敗（続行）: ${cacheDeleteResult.message}');
      } else {
        debugPrint('  ✅ Step 2完了: キャッシュから削除成功');
      }

      // Step 3: 削除済みフラグを立てる
      final deletedImage = productImage.copyWith(
        isDeleted: true,
        deletedAt: DateTime.now(),
      );

      debugPrint('  ✅ ImageRepository.deleteImage 完了');
      return Success(deletedImage);

    } catch (e, stackTrace) {
      debugPrint('❌ ImageRepository.deleteImage エラー: $e');
      return Failure(
        '画像削除エラー: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      );
    }
  }

  /// 📥 画像データを取得（キャッシュ優先）
  /// 
  /// - ローカルキャッシュをチェック
  /// - なければネットワークから取得してキャッシュ
  /// 
  /// [imageUrl] - 画像URL
  Future<Result<Uint8List>> getImageData(String imageUrl) async {
    try {
      debugPrint('📥 ImageRepository.getImageData: $imageUrl');

      // Step 1: キャッシュから取得を試みる
      final cachedData = await ImageCacheService.getCachedImage(imageUrl);
      if (cachedData != null) {
        debugPrint('  ✅ キャッシュヒット');
        return Success(cachedData);
      }

      debugPrint('  ⚠️ キャッシュミス、ネットワークから取得...');

      // Step 2: ネットワークから取得（実装は省略 - 必要に応じて追加）
      return Failure('ネットワークからの画像取得は未実装です');

    } catch (e, stackTrace) {
      debugPrint('❌ ImageRepository.getImageData エラー: $e');
      return Failure(
        '画像データ取得エラー: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      );
    }
  }

  /// 🔍 次の連番を取得（SKU内で利用可能な連番）
  /// 
  /// [sku] - SKUコード
  /// [existingImages] - 既存の画像リスト
  Future<Result<int>> getNextSequence(String sku, List<ProductImage> existingImages) async {
    try {
      debugPrint('🔍 ImageRepository.getNextSequence: $sku');

      // 既存画像から最大連番を取得
      final maxSequence = existingImages
          .where((img) => !img.isDeleted && img.skuFromFileName == sku)
          .fold<int>(0, (max, img) => img.sequence > max ? img.sequence : max);

      final nextSequence = maxSequence + 1;
      debugPrint('  ✅ 次の連番: $nextSequence (最大連番: $maxSequence)');

      return Success(nextSequence);

    } catch (e, stackTrace) {
      debugPrint('❌ ImageRepository.getNextSequence エラー: $e');
      return Failure(
        '連番取得エラー: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      );
    }
  }

  /// 📋 画像リストを連番順にソート
  /// 
  /// [images] - ソート対象の画像リスト
  /// [ascending] - 昇順 (true) or 降順 (false)
  List<ProductImage> sortImagesBySequence(
    List<ProductImage> images, {
    bool ascending = true,
  }) {
    final sortedImages = List<ProductImage>.from(images);
    sortedImages.sort((a, b) {
      final comparison = a.sequence.compareTo(b.sequence);
      return ascending ? comparison : -comparison;
    });
    return sortedImages;
  }

  /// 🔧 メイン画像を取得（最初の画像 or isMain=trueの画像）
  /// 
  /// [images] - 画像リスト
  ProductImage? getMainImage(List<ProductImage> images) {
    if (images.isEmpty) return null;

    // isMain=trueの画像を優先
    final mainImage = images.firstWhere(
      (img) => img.isMain && !img.isDeleted,
      orElse: () => images.firstWhere(
        (img) => !img.isDeleted,
        orElse: () => images.first,
      ),
    );

    return mainImage;
  }

  // ========================================
  // プライベートメソッド
  // ========================================

  /// Cloudflareにアップロード
  Future<Result<String>> _uploadToCloudflare({
    required Uint8List imageBytes,
    required String fileId,
    required String sku,
  }) async {
    try {
      // 🏢 ログインした企業IDを取得
      String? companyId;
      try {
        final prefs = await SharedPreferences.getInstance();
        companyId = prefs.getString('company_id');
        debugPrint('🏢 ログインした企業ID: $companyId');
      } catch (e) {
        debugPrint('⚠️ 企業ID取得エラー（デフォルト値を使用）: $e');
      }
      
      final imageUrl = await CloudflareWorkersStorageService.uploadImage(
        imageBytes,
        fileId,
        sku: sku,
        companyId: companyId,  // 🏢 企業IDを渡す
      );
      return Success(imageUrl);
    } catch (e, stackTrace) {
      return Failure(
        'Cloudflareアップロード失敗: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      );
    }
  }

  /// キャッシュに保存
  /// 
  /// 🔧 v2.0 改善点:
  /// - updateCachedImage を使用して既存キャッシュを削除してから新規保存
  /// - キャッシュバスティングパラメータを除去したクリーンなURLでキャッシュ
  Future<Result<void>> _saveToCache({
    required String imageUrl,
    required Uint8List imageBytes,
  }) async {
    try {
      // キャッシュバスティングパラメータを除去したクリーンなURLを使用
      final cleanUrl = ImageCacheService.removeCacheBusting(imageUrl);
      
      // 既存キャッシュを削除してから新規保存（updateCachedImage）
      await ImageCacheService.updateCachedImage(cleanUrl, imageBytes);
      
      debugPrint('✅ キャッシュ保存完了: $cleanUrl');
      return Success(null);
    } catch (e, stackTrace) {
      return Failure(
        'キャッシュ保存失敗: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      );
    }
  }

  /// Cloudflareから削除
  Future<Result<void>> _deleteFromCloudflare(String imageUrl) async {
    try {
      final success = await CloudflareWorkersStorageService.deleteImage(imageUrl);
      if (success) {
        return Success(null);
      } else {
        return Failure('Cloudflare削除に失敗しました');
      }
    } catch (e, stackTrace) {
      return Failure(
        'Cloudflare削除エラー: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      );
    }
  }

  /// キャッシュから削除
  /// 
  /// 🔧 v2.0 改善点:
  /// - ImageCacheService.invalidateCache を使用して個別キャッシュを削除
  Future<Result<void>> _deleteFromCache(String imageUrl) async {
    try {
      await ImageCacheService.invalidateCache(imageUrl);
      debugPrint('✅ キャッシュ削除完了: $imageUrl');
      return Success(null);
    } catch (e, stackTrace) {
      return Failure(
        'キャッシュ削除エラー: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      );
    }
  }
}
