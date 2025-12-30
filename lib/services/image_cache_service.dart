import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// 📸 画像キャッシュサービス
/// R2にアップロードした画像をBase64でローカルにキャッシュ
/// CORSエラーを回避するためのフォールバック用
class ImageCacheService {
  static const String _boxName = 'image_cache';
  static Box<String>? _box;
  
  /// キャッシュを初期化
  static Future<void> initialize() async {
    _box = await Hive.openBox<String>(_boxName);
    if (kDebugMode) {
      debugPrint('📸 ImageCacheService初期化完了: ${_box?.length ?? 0}件のキャッシュ');
    }
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
      
      if (kDebugMode) {
        debugPrint('✅ 画像キャッシュ保存: $key (${imageBytes.length} bytes)');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 画像キャッシュ保存エラー: $e');
      }
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
        if (kDebugMode) {
          debugPrint('✅ キャッシュヒット: $key');
        }
        return base64Decode(base64Data);
      }
      
      if (kDebugMode) {
        debugPrint('⚠️ キャッシュミス: $key');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ キャッシュ取得エラー: $e');
      }
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
  
  /// キャッシュをクリア
  static Future<void> clearCache() async {
    if (_box != null) {
      await _box!.clear();
      if (kDebugMode) {
        debugPrint('🗑️ 画像キャッシュをクリアしました');
      }
    }
  }
  
  /// キャッシュサイズを取得
  static int get cacheSize => _box?.length ?? 0;
}
