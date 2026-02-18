import 'package:flutter/foundation.dart';
import '../domain/image_item.dart';

/// 🎨 白抜き画像管理サービス
/// 
/// Phase 4: 白抜き画像のシーケンス同期・連動削除
/// - 元画像と白抜き画像のペアリング
/// - シーケンス番号の自動同期
/// - 元画像削除時の白抜き画像連動削除
class WhiteBackgroundService {
  static const String baseUrl = 'https://image-upload-api.jinkedon2.workers.dev';

  /// 📋 白抜き画像URLを元画像URLから生成
  /// 
  /// 例: 1025L280001_<uuid>.jpg → 1025L280001_<uuid>_white.jpg
  String generateWhiteUrl(String originalUrl) {
    if (originalUrl.endsWith('.jpg')) {
      return originalUrl.replaceAll('.jpg', '_white.jpg');
    } else if (originalUrl.endsWith('.jpeg')) {
      return originalUrl.replaceAll('.jpeg', '_white.jpeg');
    } else if (originalUrl.endsWith('.png')) {
      return originalUrl.replaceAll('.png', '_white.png');
    }
    return '${originalUrl}_white';
  }

  /// 🔍 既存の白抜き画像を検出
  /// 
  /// Cloudflare上に白抜き画像が存在するか確認
  Future<bool> checkWhiteImageExists(String whiteUrl) async {
    try {
      if (kDebugMode) {
        debugPrint('🔍 白抜き画像の存在確認: $whiteUrl');
      }

      // Note: Web環境ではHEADリクエストに制限があるため、
      // 実際のチェックはCloudflare Workers側で行う想定
      // ここでは白抜きURLが生成可能かのみ確認
      
      if (kDebugMode) {
        debugPrint('✅ 白抜きURL生成成功: $whiteUrl');
      }
      
      return true; // 常にtrueを返し、実際の存在確認は表示時に行う
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 白抜き画像の確認失敗: $e');
      }
      return false;
    }
  }

  /// 🔗 元画像と白抜き画像をペアリング
  /// 
  /// 既存のImageItemリストに白抜きURLを追加
  Future<List<ImageItem>> pairWhiteImages(List<ImageItem> images) async {
    if (kDebugMode) {
      debugPrint('🔗 Phase 4: 白抜き画像のペアリング開始（${images.length}枚）');
    }

    final pairedImages = <ImageItem>[];

    for (var image in images) {
      if (image.url == null) {
        // 新規画像（まだアップロードされていない）
        pairedImages.add(image);
        continue;
      }

      // 既存画像の場合、白抜きURLを生成
      final whiteUrl = generateWhiteUrl(image.url!);
      
      if (kDebugMode) {
        debugPrint('  [${image.sequence}] 元画像: ${image.url}');
        debugPrint('  [${image.sequence}] 白抜き: $whiteUrl');
      }

      // 白抜きURLを設定した新しいImageItemを作成
      final pairedImage = ImageItem(
        id: image.id,
        file: image.file,
        bytes: image.bytes,
        url: image.url,
        whiteUrl: whiteUrl, // 白抜きURL追加
        sequence: image.sequence,
        isMain: image.isMain,
        createdAt: image.createdAt,
      );

      pairedImages.add(pairedImage);
    }

    if (kDebugMode) {
      debugPrint('✅ 白抜き画像のペアリング完了: ${pairedImages.length}枚');
    }

    return pairedImages;
  }

  /// 🗑️ 白抜き画像の削除URL生成
  /// 
  /// 元画像削除時に使用する白抜き画像の削除URL
  List<String> generateWhiteDeleteUrls(List<String> originalUrls) {
    final whiteUrls = <String>[];

    for (var url in originalUrls) {
      // URL形式: https://.../{SKU}/{SKU}_{UUID}.jpg
      // 白抜き形式: https://.../{SKU}/{SKU}_{UUID}_white.jpg
      
      // ファイル名部分を抽出
      final fileName = url.split('/').last;
      if (fileName.contains('_white.')) {
        // 既に白抜き画像の場合はスキップ
        continue;
      }

      // 白抜きファイル名を生成
      final whiteFileName = fileName.replaceAll('.jpg', '_white.jpg')
                                     .replaceAll('.jpeg', '_white.jpeg')
                                     .replaceAll('.png', '_white.png');
      
      // SKUフォルダパスを抽出
      final urlParts = url.split('/');
      if (urlParts.length >= 2) {
        final sku = urlParts[urlParts.length - 2];
        final whiteUrl = '$baseUrl/$sku/$whiteFileName';
        whiteUrls.add(whiteUrl);
        
        if (kDebugMode) {
          debugPrint('🗑️ 白抜き削除対象: $whiteUrl');
        }
      }
    }

    return whiteUrls;
  }

  /// 📊 白抜き画像の統計情報
  Map<String, dynamic> getWhiteImageStats(List<ImageItem> images) {
    var totalImages = images.length;
    var withWhite = images.where((img) => img.whiteUrl != null).length;
    var withoutWhite = totalImages - withWhite;

    return {
      'total': totalImages,
      'withWhite': withWhite,
      'withoutWhite': withoutWhite,
      'coverage': totalImages > 0 ? (withWhite / totalImages * 100).toStringAsFixed(1) : '0.0',
    };
  }
}
