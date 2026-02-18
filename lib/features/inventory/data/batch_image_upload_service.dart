import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart' hide ImageSource;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../domain/product_image.dart';
import '../../../core/utils/result.dart';
import '../domain/image_item.dart';
import './image_repository.dart';

/// 📤 一括画像アップロードサービス
/// 
/// DetailScreen（商品確定画面）で使用する一括アップロード機能。
/// - 複数画像を順次アップロード
/// - 進捗通知
/// - エラーハンドリング
/// - ProductImageリストを返却
class BatchImageUploadService {
  final ImageRepository _repository;

  BatchImageUploadService({ImageRepository? repository})
      : _repository = repository ?? ImageRepository();

  /// 🎯 Phase 3: ImageItemから一括アップロード（UUID完全対応）
  /// 
  /// `imageItems` - ImageItemのリスト（UUIDを含む）
  /// `sku` - SKUコード
  /// `companyId` - 企業ID（R2フォルダ構造用）
  /// `onProgress` - 進捗コールバック (current, total)
  /// 
  /// Returns: `Result<List<ProductImage>>`
  Future<Result<List<ProductImage>>> uploadImagesFromImageItems({
    required List<ImageItem> imageItems,
    required String sku,
    String? companyId,  // 🏢 企業ID追加
    void Function(int current, int total)? onProgress,
  }) async {
    try {
      // 新規画像（未アップロード）が1枚もない場合は空リストで正常終了
      // ※ 既存画像のみの場合はImageUploadCoordinator側で管理するため
      final hasNewImages = imageItems.any((img) => img.isNew);
      if (imageItems.isEmpty || !hasNewImages) {
        return Success(const []);
      }


      final uploadedImages = <ProductImage>[];

      for (int i = 0; i < imageItems.length; i++) {
        final imageItem = imageItems[i];
        
        // 🧪 Phase 3 デバッグ: ImageItemの処理状況を出力
        
        // 既存画像の場合はスキップ（再アップロード不要）
        // ✅ 既存画像はDetailScreenの existingUrls で管理されているため
        //    ここでは uploadedImages に追加しない
        if (imageItem.isExisting) {
          
          onProgress?.call(i + 1, imageItems.length);
          continue;
        }
        
        // 新規画像の場合

        try {
          // 進捗通知
          onProgress?.call(i + 1, imageItems.length);


          // 画像バイトデータを取得
          Uint8List imageBytes;
          if (imageItem.bytes != null) {
            imageBytes = imageItem.bytes!;
          } else if (imageItem.file != null) {
            imageBytes = await imageItem.file!.readAsBytes();
          } else {
            throw Exception('画像データがありません');
          }

          // ImageRepositoryを使ってアップロード（ImageItem.idを渡す）
          
          final result = await _repository.saveImage(
            imageBytes: imageBytes,
            sku: sku,
            imageId: imageItem.id, // 🎯 Phase 3: ImageItem.idをUUIDとして渡す
            companyId: companyId,  // 🏢 企業IDを渡す
            sequence: imageItem.sequence,
            source: ImageSource.camera,
            isMain: imageItem.isMain,
          );

          if (result is Success<ProductImage>) {
            uploadedImages.add(result.data);
          } else if (result is Failure<ProductImage>) {
            throw Exception(result.message);
          }

        } catch (e) {
          return Failure('画像アップロード失敗: $e');
        }
      }

      
      // 🧪 Phase 3 最終確認: アップロード結果の詳細
      for (int i = 0; i < uploadedImages.length; i++) {
        final _ = uploadedImages[i];
      }
      
      return Success(uploadedImages);

    } catch (e) {
      return Failure('一括アップロード失敗: $e');
    }
  }

  /// 🔧 画像バイトデータを一括アップロード（blob URL問題回避版）
  /// 
  /// `imageBytesList` - Uint8Listのリスト（画像バイトデータ）
  /// `sku` - SKUコード
  /// `onProgress` - 進捗コールバック (current, total)
  /// 
  /// Returns: `Result<List<ProductImage>>`
  /// 
  /// ⚠️ 非推奨: uploadImagesFromImageItems() を使用してください
  @Deprecated('Use uploadImagesFromImageItems() instead')
  Future<Result<List<ProductImage>>> uploadImagesFromBytes({
    required List<Uint8List> imageBytesList,
    required String sku,
    void Function(int current, int total)? onProgress,
  }) async {
    try {
      if (imageBytesList.isEmpty) {
        return Failure('アップロードする画像がありません');
      }


      final uploadedImages = <ProductImage>[];

      for (int i = 0; i < imageBytesList.length; i++) {
        final imageBytes = imageBytesList[i];
        final sequence = i + 1;

        try {
          // 進捗通知
          onProgress?.call(i + 1, imageBytesList.length);


          // ImageRepositoryを使ってアップロード
          final result = await _repository.saveImage(
            imageBytes: imageBytes,
            sku: sku,
            sequence: sequence,
            source: ImageSource.camera,
            isMain: i == 0,
          );

          if (result is Success<ProductImage>) {
            uploadedImages.add(result.data);
          } else if (result is Failure<ProductImage>) {
            throw Exception(result.message);
          }

        } catch (e) {
          return Failure('画像アップロード失敗: $e');
        }
      }

      return Success(uploadedImages);

    } catch (e) {
      return Failure('一括アップロード失敗: $e');
    }
  }

  /// 📤 複数画像を一括アップロード
  /// 
  /// `imageFiles` - XFileのリスト（ローカルファイル）
  /// `sku` - SKUコード
  /// `onProgress` - 進捗コールバック (current, total)
  /// 
  /// Returns: `Result<List<ProductImage>>`
  Future<Result<List<ProductImage>>> uploadImages({
    required List<XFile> imageFiles,
    required String sku,
    void Function(int current, int total)? onProgress,
  }) async {
    try {
      if (imageFiles.isEmpty) {
        return Failure('アップロードする画像がありません');
      }


      final uploadedImages = <ProductImage>[];

      for (int i = 0; i < imageFiles.length; i++) {
        final imageFile = imageFiles[i];
        final sequence = i + 1;

        try {
          // 進捗通知
          onProgress?.call(i + 1, imageFiles.length);


          // 画像データを読み込み
          Uint8List imageBytes;
          
          if (kIsWeb) {
            // Web環境：blob URLから画像データを取得
            final response = await http.get(Uri.parse(imageFile.path));
            if (response.statusCode == 200) {
              imageBytes = response.bodyBytes;
            } else {
              throw Exception('blob画像の読み込みに失敗しました: ${response.statusCode}');
            }
          } else {
            // モバイル環境：ファイルパスから画像を読み込み
            final file = File(imageFile.path);
            imageBytes = await file.readAsBytes();
          }

          // ImageRepositoryを使ってアップロード
          final result = await _repository.saveImage(
            imageBytes: imageBytes,
            sku: sku,
            sequence: sequence,
            source: ImageSource.camera,  // 現時点では全てカメラ扱い
            isMain: i == 0,  // 最初の画像をメインに設定
          );

          if (result is Success<ProductImage>) {
            uploadedImages.add(result.data);
          } else if (result is Failure<ProductImage>) {
            
            // エラーだが、処理を続行するか判断
            // 現時点では失敗全体を返す
            return Failure(
              '画像 $sequence/${imageFiles.length} のアップロードに失敗しました: ${result.message}',
              exception: result.exception,
            );
          }

        } catch (e, stackTrace) {
          return Failure(
            '画像 $sequence/${imageFiles.length} の処理中にエラーが発生しました: $e',
            exception: e is Exception ? e : Exception(e.toString()),
            stackTrace: stackTrace,
          );
        }
      }

      return Success(uploadedImages);

    } catch (e, stackTrace) {
      return Failure(
        '一括アップロード中にエラーが発生しました: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      );
    }
  }

  /// 📤 既存URL + 新規ファイルの混在アップロード（並列処理 + Sequence保証）
  /// 
  /// 編集モードで使用。既にアップロード済みの画像と新規撮影画像を統合。
  /// 
  /// **フロー**:
  /// 1. バリデーション
  /// 2. 既存画像を再ダウンロード
  /// 3. 新規ファイルを読み込み
  /// 4. 全ファイルを結合
  /// 5. 並列アップロード（3枚ずつバッチ処理）
  /// 6. Sequenceでソートして順序保証
  /// 
  /// `existingUrls` - 既存のアップロード済みURL
  /// `newImageFiles` - 新規撮影画像
  /// `sku` - SKUコード
  /// `onProgress` - 進捗コールバック (current, total)
  Future<Result<List<ProductImage>>> uploadMixedImages({
    required List<String> existingUrls,
    required List<XFile> newImageFiles,
    required String sku,
    void Function(int current, int total)? onProgress,
  }) async {
    try {
      // 1) バリデーション
      if (existingUrls.isEmpty && newImageFiles.isEmpty) {
        return Failure('アップロードする画像がありません');
      }

      final totalImages = existingUrls.length + newImageFiles.length;

      // 2) 既存画像を再ダウンロード
      List<Uint8List> existingFiles = [];
      for (int i = 0; i < existingUrls.length; i++) {
        onProgress?.call(i + 1, totalImages);
        final bytes = await _downloadImage(existingUrls[i]);
        existingFiles.add(bytes);
      }

      // 3) 新規ファイルを読み込み
      List<Uint8List> newFiles = [];
      for (int i = 0; i < newImageFiles.length; i++) {
        Uint8List imageBytes;
        
        if (kIsWeb) {
          final response = await http.get(Uri.parse(newImageFiles[i].path));
          if (response.statusCode == 200) {
            imageBytes = response.bodyBytes;
          } else {
            throw Exception('blob画像読み込み失敗: ${response.statusCode}');
          }
        } else {
          imageBytes = await File(newImageFiles[i].path).readAsBytes();
        }
        
        newFiles.add(imageBytes);
      }

      // 4) 全ファイルを結合
      final allFiles = [...existingFiles, ...newFiles];

      // 5) 並列アップロード（3枚ずつバッチ処理）
      final uploadedImages = await _uploadInBatches(
        allFiles: allFiles,
        sku: sku,
        startOffset: existingUrls.length,
        onProgress: onProgress,
        totalImages: totalImages,
      );

      return Success(uploadedImages);

    } catch (e, stackTrace) {
      return Failure(
        '混在アップロード失敗: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      );
    }
  }

  /// 並列アップロード（3枚ずつバッチ処理）+ Sequence保証
  Future<List<ProductImage>> _uploadInBatches({
    required List<Uint8List> allFiles,
    required String sku,
    required int startOffset,
    void Function(int current, int total)? onProgress,
    required int totalImages,
  }) async {
    const batchSize = 3; // 同時に3枚まで
    List<ProductImage> results = [];
    final uuid = const Uuid();

    for (int i = 0; i < allFiles.length; i += batchSize) {
      final batch = allFiles.skip(i).take(batchSize).toList();
      
      // ✅ Sequence保証: batch.asMap()でインデックスを保持
      final futures = batch.asMap().entries.map((entry) {
        final globalIndex = i + entry.key;  // グローバルインデックス
        final sequence = globalIndex + 1;    // 連番は1から開始
        final fileBytes = entry.value;
        
        return _uploadSingleImage(
          fileBytes: fileBytes,
          sku: sku,
          sequence: sequence,
          globalIndex: globalIndex,
          uuid: uuid,
        );
      }).toList();

      try {
        // ✅ Future.wait は「投げた順」に結果を返す
        final batchResults = await Future.wait(futures);
        results.addAll(batchResults);
        
        // 進捗通知
        final currentProgress = startOffset + i + batch.length;
        onProgress?.call(currentProgress, totalImages);
        
        
      } catch (e) {
        // ❌ バッチ内の1枚でも失敗したら全体を失敗扱い
        throw Exception('バッチアップロード失敗（${i + 1}枚目付近）: $e');
      }
    }

    // ✅ Sequenceでソートして順序を保証
    results.sort((a, b) => a.sequence.compareTo(b.sequence));
    
    return results;
  }

  /// 1枚の画像をアップロード
  Future<ProductImage> _uploadSingleImage({
    required Uint8List fileBytes,
    required String sku,
    required int sequence,
    required int globalIndex,
    required Uuid uuid,
  }) async {
    try {
      final _ = '${sku}_$sequence';
      
      // ImageRepositoryを使用してアップロード
      final result = await _repository.saveImage(
        imageBytes: fileBytes,
        sku: sku,
        sequence: sequence,
        source: ImageSource.camera,
        isMain: globalIndex == 0, // 最初の画像のみメイン
      );

      if (result is Success<ProductImage>) {
        return result.data;
      } else if (result is Failure<ProductImage>) {
        throw Exception(result.message);
      } else {
        throw Exception('不明なResult型');
      }
      
    } catch (e) {
      rethrow; // エラーを上位に伝播
    }
  }

  /// 既存画像をダウンロード
  Future<Uint8List> _downloadImage(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      throw Exception('HTTP ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }
}
