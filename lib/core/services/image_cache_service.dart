import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

/// 📸 画像キャッシュサービス
/// R2にアップロードした画像をBase64でローカルにキャッシュ
/// CORSエラーを回避するためのフォールバック用
/// 
/// 🔧 v2.0 改善点:
/// - キャッシュバスティング機能追加
/// - 個別キャッシュ無効化機能追加
/// - SKU単位でのキャッシュクリア機能追加
class ImageCacheService {
  static const String _boxName = 'image_cache';
  static Box<String>? _box;
  
  /// キャッシュを初期化
  static Future<void> initialize() async {
    _box = await Hive.openBox<String>(_boxName);
  }
  
  // ============================================
  // 🔧 キャッシュバスティング機能
  // ============================================
  
  /// URLにタイムスタンプを追加してキャッシュを無効化
  /// [url] - 元の画像URL
  /// Returns: キャッシュバスティング付きURL
  static String getCacheBustedUrl(String url) {
    if (url.isEmpty) return url;
    
    // タイムスタンプをクエリパラメータとして追加
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final separator = url.contains('?') ? '&' : '?';
    final cacheBustedUrl = '$url${separator}t=$timestamp';
    
    
    return cacheBustedUrl;
  }
  
  /// URLからキャッシュバスティングパラメータを除去
  /// [url] - キャッシュバスティング付きURL
  /// Returns: クリーンなURL
  static String removeCacheBusting(String url) {
    if (url.isEmpty) return url;
    
    // ?t= または &t= パラメータを除去
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    
    final cleanParams = Map<String, String>.from(uri.queryParameters)
      ..remove('t');
    
    if (cleanParams.isEmpty) {
      return uri.replace(query: null).toString();
    }
    
    return uri.replace(queryParameters: cleanParams).toString();
  }
  
  /// 画像をキャッシュに保存
  /// [imageUrl] - R2の画像URL（キーとして使用）
  /// [imageBytes] - 画像のバイトデータ
  static Future<void> cacheImage(String imageUrl, Uint8List imageBytes) async {
    if (_box == null) {
      await initialize();
    }
    
    try {
      // URLからファイル名を抽出してキーとして使用
      final key = _extractFileName(imageUrl);
      final base64Data = base64Encode(imageBytes);
      
      await _box!.put(key, base64Data);
      
    } catch (e) {
      debugPrint('⚠️ ImageCacheService.cacheImage 失敗: $e');
    }
  }
  
  /// キャッシュから画像を取得
  /// [imageUrl] - R2の画像URL
  /// Returns: Base64デコードされた画像バイトデータ、またはnull
  static Uint8List? getCachedImage(String imageUrl) {
    if (_box == null) {
      return null;
    }
    
    try {
      final key = _extractFileName(imageUrl);
      final base64Data = _box!.get(key);
      
      if (base64Data != null) {
        return base64Decode(base64Data);
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// キャッシュが存在するか確認
  static bool hasCachedImage(String imageUrl) {
    if (_box == null) {
      return false;
    }
    final key = _extractFileName(imageUrl);
    return _box!.containsKey(key);
  }
  
  /// URLからファイル名を抽出
  static String _extractFileName(String url) {
    // URLから最後のパス部分を抽出
    final uri = Uri.tryParse(url);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last;
    }
    // フォールバック: URLそのものをハッシュ化
    return url.hashCode.toString();
  }
  
  /// キャッシュをクリア（全体）
  static Future<void> clearCache() async {
    if (_box != null) {
      await _box!.clear();
    }
  }
  
  /// キャッシュサイズを取得
  static int get cacheSize => _box?.length ?? 0;
  
  // ============================================
  // 🔧 個別キャッシュ無効化機能
  // ============================================
  
  /// 特定の画像キャッシュを無効化（削除）
  /// [imageUrl] - 削除する画像のURL
  static Future<void> invalidateCache(String imageUrl) async {
    if (_box == null) {
      await initialize();
    }
    
    try {
      final key = _extractFileName(imageUrl);
      if (_box!.containsKey(key)) {
        await _box!.delete(key);
      }
    } catch (e) {
      debugPrint('⚠️ ImageCacheService.invalidateCache 失敗: $e');
    }
  }
  
  /// 複数の画像キャッシュを一括無効化
  /// [imageUrls] - 削除する画像URLのリスト
  static Future<void> invalidateCaches(List<String> imageUrls) async {
    if (_box == null) {
      await initialize();
    }
    
    int deletedCount = 0;
    for (final url in imageUrls) {
      try {
        final key = _extractFileName(url);
        if (_box!.containsKey(key)) {
          await _box!.delete(key);
          deletedCount++;
        }
      } catch (e) {
        debugPrint('⚠️ ImageCacheService.invalidateCaches 失敗 ($url): $e');
      }
    }
    debugPrint('🗁️ ImageCacheService: $deletedCount件キャッシュを削除しました');
    
  }
  
  /// SKU単位でキャッシュをクリア
  /// [sku] - SKUコード
  static Future<void> clearCacheForSku(String sku) async {
    if (_box == null) {
      await initialize();
    }
    
    try {
      final keysToDelete = _box!.keys
          .where((key) => key.toString().startsWith(sku))
          .toList();
      
      for (final key in keysToDelete) {
        await _box!.delete(key);
      }
      
    } catch (e) {
      debugPrint('⚠️ ImageCacheService.clearCacheForSku 失敗: $e');
    }
  }
  
  /// 画像を更新（既存キャッシュを削除してから新規保存）
  /// [imageUrl] - R2の画像URL
  /// [imageBytes] - 新しい画像のバイトデータ
  static Future<void> updateCachedImage(String imageUrl, Uint8List imageBytes) async {
    // 1. 既存キャッシュを削除
    await invalidateCache(imageUrl);
    
    // 2. 新しい画像をキャッシュ
    await cacheImage(imageUrl, imageBytes);
    
  }
  
  /// 【NEW】キャッシュから画像ファイルを取得
  /// [imageUrl] - R2の画像URL
  /// Returns: キャッシュされた画像のFileオブジェクト、またはnull
  static Future<File?> getCachedFile(String imageUrl) async {
    final cachedBytes = getCachedImage(imageUrl);
    if (cachedBytes == null) {
      return null;
    }
    
    try {
      // 一時ファイルとして保存
      final tempDir = await getTemporaryDirectory();
      final fileName = _extractFileName(imageUrl);
      final file = File('${tempDir.path}/cached_$fileName');
      
      await file.writeAsBytes(cachedBytes);
      
      
      return file;
    } catch (e) {
      return null;
    }
  }
  
  /// 🔍 デバッグ: キャッシュの全キーを出力
  static void debugPrintAllCacheKeys() {
    if (!kDebugMode) return;
    if (_box == null) {
      return;
    }
    
    
    int index = 1;  // ignore: unused_local_variable
    for (var key in _box!.keys) {
      // UUID形式かどうか判定
      final isUuid = RegExp(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', caseSensitive: false).hasMatch(key.toString());
      final _ = isUuid ? '🆔' : '🔢';
      index++;
    }
  }
}
