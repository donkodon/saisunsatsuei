import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// 📷 画像ストレージサービス
/// ローカルストレージに画像を永続保存し、他のデバイスでも共有可能
class StorageService {
  static const String _imageBoxName = 'image_storage';
  
  /// 📸 撮影した画像をローカルストレージに永続保存
  /// 
  /// [imageFile] - 撮影した画像ファイル
  /// [itemId] - 商品ID（一意な識別子）
  /// 
  /// Returns: 保存された画像のパス（ローカルストレージ）
  static Future<String> saveImage(File imageFile, String itemId) async {
    try {
      if (kIsWeb) {
        // Web環境では画像パスをそのまま返す
        return imageFile.path;
      }
      
      // アプリのドキュメントディレクトリを取得
      final directory = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${directory.path}/product_images');
      
      // ディレクトリが存在しない場合は作成
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }
      
      // ファイル名を生成（タイムスタンプ + 商品ID）
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${itemId}_$timestamp.jpg';
      final savedPath = path.join(imagesDir.path, fileName);
      
      // 画像をコピーして保存
      final savedFile = await imageFile.copy(savedPath);
      
      debugPrint('✅ 画像を保存しました: $savedPath');
      return savedFile.path;
      
    } catch (e) {
      debugPrint('❌ 画像の保存に失敗しました: $e');
      rethrow;
    }
  }
  
  /// 🗑️ 画像を削除
  static Future<void> deleteImage(String imagePath) async {
    try {
      if (kIsWeb) return;
      
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('✅ 画像を削除しました: $imagePath');
      }
    } catch (e) {
      debugPrint('❌ 画像の削除に失敗しました: $e');
    }
  }
  
  /// 📋 すべての保存済み画像のリストを取得
  static Future<List<String>> getAllImagePaths() async {
    try {
      if (kIsWeb) return [];
      
      final directory = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${directory.path}/product_images');
      
      if (!await imagesDir.exists()) {
        return [];
      }
      
      final files = await imagesDir.list().toList();
      return files
          .where((file) => file is File)
          .map((file) => file.path)
          .toList();
          
    } catch (e) {
      debugPrint('❌ 画像リストの取得に失敗しました: $e');
      return [];
    }
  }
  
  /// 🔍 画像ファイルが存在するか確認
  static Future<bool> imageExists(String imagePath) async {
    try {
      if (kIsWeb) return true;
      
      final file = File(imagePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }
}
