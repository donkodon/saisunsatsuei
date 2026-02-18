import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// 🖼️ 画像最適化サービス
/// 画像を圧縮してストレージ容量を節約
class ImageOptimizerService {
  /// 📸 画像を圧縮（容量を50-80%削減）
  /// 
  /// [imageFile] - 元の画像ファイル
  /// [quality] - 品質（0-100、デフォルト85）
  /// [maxWidth] - 最大幅（デフォルト1024px）
  /// [maxHeight] - 最大高さ（デフォルト1024px）
  /// 
  /// Returns: 圧縮後の画像ファイル
  static Future<File> compressImage(
    File imageFile, {
    int quality = 85,
    int maxWidth = 1024,
    int maxHeight = 1024,
  }) async {
    try {
      // Web環境では圧縮をスキップ
      if (kIsWeb) {
        return imageFile;
      }

      
      // 元のファイルサイズ
      final originalSize = await imageFile.length();
      
      // 一時ファイルパスを生成
      final tempDir = await getTemporaryDirectory();
      final targetPath = path.join(
        tempDir.path,
        'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      
      // 画像を圧縮
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        imageFile.path,
        targetPath,
        quality: quality,
        minWidth: maxWidth,
        minHeight: maxHeight,
        format: CompressFormat.jpeg,
      );
      
      if (compressedFile == null) {
        return imageFile;
      }
      
      // 圧縮後のファイルサイズ
      final compressedSize = await File(compressedFile.path).length();
      final _ = ((1 - compressedSize / originalSize) * 100).toStringAsFixed(1);
      
      
      return File(compressedFile.path);
      
    } catch (e) {
      // エラー時は元の画像を返す
      return imageFile;
    }
  }
  
  /// 📏 画像の品質プリセット
  
  /// 高品質（容量: 約50%削減）
  static Future<File> compressHighQuality(File imageFile) {
    return compressImage(
      imageFile,
      quality: 90,
      maxWidth: 1920,
      maxHeight: 1920,
    );
  }
  
  /// 中品質（容量: 約70%削減）- おすすめ
  static Future<File> compressMediumQuality(File imageFile) {
    return compressImage(
      imageFile,
      quality: 85,
      maxWidth: 1024,
      maxHeight: 1024,
    );
  }
  
  /// 低品質（容量: 約85%削減）
  static Future<File> compressLowQuality(File imageFile) {
    return compressImage(
      imageFile,
      quality: 70,
      maxWidth: 800,
      maxHeight: 800,
    );
  }
  
  /// 🎯 サムネイル用（容量: 約95%削減）
  static Future<File> compressThumbnail(File imageFile) {
    return compressImage(
      imageFile,
      quality: 70,
      maxWidth: 400,
      maxHeight: 400,
    );
  }
  
  /// 📊 画像情報を取得
  static Future<Map<String, dynamic>> getImageInfo(File imageFile) async {
    try {
      final size = await imageFile.length();
      
      return {
        'path': imageFile.path,
        'size': size,
        'sizeKB': (size / 1024).toStringAsFixed(2),
        'sizeMB': (size / 1024 / 1024).toStringAsFixed(2),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}

/// 📊 容量削減の目安
/// 
/// 元の画像: 3MB (スマホ撮影)
/// ↓
/// 高品質圧縮: 1.5MB (50%削減) ← 印刷品質
/// 中品質圧縮: 900KB (70%削減) ← Web表示に最適（おすすめ）
/// 低品質圧縮: 450KB (85%削減) ← モバイル向け
/// サムネイル: 150KB (95%削減) ← 一覧表示用
/// 
/// 10GBの場合:
/// - 中品質: 約10,000-15,000枚
/// - 低品質: 約20,000-30,000枚
