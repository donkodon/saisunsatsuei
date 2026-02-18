import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// 📸 ローカル画像ファイルのラッパークラス
/// 
/// XFileとStringのURL形式を統一的に扱うためのヘルパークラス
class LocalImageFile {
  final XFile? xFile;      // ローカルファイル（撮影直後）
  final String? url;       // アップロード済みURL
  final int sequence;      // 連番

  LocalImageFile({
    this.xFile,
    this.url,
    required this.sequence,
  }) : assert(xFile != null || url != null, 'Either xFile or url must be provided');

  /// ファイルパスまたはURL
  String get path => xFile?.path ?? url!;

  /// アップロード済みかどうか
  bool get isUploaded => url != null;

  /// ローカルファイルかどうか
  bool get isLocal => xFile != null;

  /// 表示用Widget（Image.network / Image.file）
  Widget buildImage({
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
  }) {
    // 表示サイズの2倍でデコード（Retina対応・メモリ節約）
    final int? cW = width != null ? (width * 2).toInt() : null;
    final int? cH = height != null ? (height * 2).toInt() : null;

    if (url != null) {
      // アップロード済み: URLから表示
      return Image.network(
        url!,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: cW,    // 表示サイズに合わせてデコード解像度を制限
        cacheHeight: cH,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: width,
            height: height,
            color: Colors.grey[300],
            child: Icon(Icons.broken_image, color: Colors.grey),
          );
        },
      );
    } else if (xFile != null) {
      // ローカルファイル: ファイルパスから表示
      if (kIsWeb) {
        return Image.network(
          xFile!.path,
          width: width,
          height: height,
          fit: fit,
          cacheWidth: cW,
          cacheHeight: cH,
        );
      } else {
        return Image.file(
          File(xFile!.path),
          width: width,
          height: height,
          fit: fit,
        );
      }
    } else {
      // エラー（通常は到達しない）
      return Container(
        width: width,
        height: height,
        color: Colors.grey[300],
        child: Icon(Icons.error, color: Colors.red),
      );
    }
  }

  /// XFileから作成
  static LocalImageFile fromXFile(XFile file, int sequence) {
    return LocalImageFile(
      xFile: file,
      sequence: sequence,
    );
  }

  /// URLから作成（既存画像）
  static LocalImageFile fromUrl(String url, int sequence) {
    return LocalImageFile(
      url: url,
      sequence: sequence,
    );
  }

  /// アップロード済みの新しいインスタンスを返す
  LocalImageFile withUploadedUrl(String uploadedUrl) {
    return LocalImageFile(
      xFile: xFile,
      url: uploadedUrl,
      sequence: sequence,
    );
  }

  @override
  String toString() {
    return 'LocalImageFile(sequence: $sequence, isUploaded: $isUploaded, path: $path)';
  }
}
