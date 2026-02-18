import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:measure_master/core/services/image_cache_service.dart';
import 'dart:typed_data';
import 'dart:io';

/// 🧪 Phase 7: キャッシュ完全整合性テスト
/// 
/// UUID変更時のキャッシュ無効化を検証
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  setUpAll(() async {
    // テスト用の一時ディレクトリを作成
    final tempDir = Directory.systemTemp.createTempSync('hive_test');
    // Hiveの初期化（テスト用パス指定）
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    // テスト後のクリーンアップ
    try {
      await Hive.close();
    } catch (e) {
      // エラーは無視
    }
  });

  group('Phase 7: キャッシュ完全整合性', () {
    setUp(() async {
      // 各テスト前にキャッシュをクリア
      await ImageCacheService.initialize();
      await ImageCacheService.clearCache();
    });

    test('🎯 UUID変更でキャッシュ無効化', () async {
      // 旧URL（UUID1）
      const oldUrl = 'https://image-upload-api.jinkedon2.workers.dev/SKU-A/SKU-A_a1b2c3d4-e5f6-7890-abcd-ef1234567890.jpg';
      
      // 新URL（UUID2）
      const newUrl = 'https://image-upload-api.jinkedon2.workers.dev/SKU-A/SKU-A_f9e8d7c6-b5a4-3210-fedc-ba0987654321.jpg';
      
      // テストデータ
      final bytes1 = Uint8List.fromList([1, 2, 3, 4, 5]);
      final bytes2 = Uint8List.fromList([6, 7, 8, 9, 10]);
      
      // 1. oldUrlをキャッシュ
      await ImageCacheService.cacheImage(oldUrl, bytes1);
      
      // 2. oldUrlのキャッシュを確認
      final cachedOld = ImageCacheService.getCachedImage(oldUrl);
      expect(cachedOld, isNotNull, reason: '旧URLのキャッシュが存在する');
      expect(cachedOld, equals(bytes1), reason: '旧URLのキャッシュデータが一致');
      
      // 3. newURLは別キー → キャッシュミス
      final cachedNew = ImageCacheService.getCachedImage(newUrl);
      expect(cachedNew, isNull, reason: '新URL（UUID2）は別キー → キャッシュミス ✅');
      
      // 4. newURLをキャッシュ
      await ImageCacheService.cacheImage(newUrl, bytes2);
      
      // 5. 両方のキャッシュが独立して存在
      final cachedOld2 = ImageCacheService.getCachedImage(oldUrl);
      final cachedNew2 = ImageCacheService.getCachedImage(newUrl);
      
      expect(cachedOld2, equals(bytes1), reason: '旧URLのキャッシュが保持されている');
      expect(cachedNew2, equals(bytes2), reason: '新URLのキャッシュが保存されている');
      expect(cachedOld2, isNot(equals(cachedNew2)), reason: '異なるUUID → 異なるキャッシュ');
    });

    test('🎯 ファイル名からキャッシュキーを抽出', () async {
      // UUID形式のファイル名
      const url1 = 'https://image-upload-api.jinkedon2.workers.dev/1025L280001/1025L280001_a1b2c3d4-e5f6-7890-abcd-ef1234567890.jpg';
      const url2 = 'https://image-upload-api.jinkedon2.workers.dev/1025L280001/1025L280001_f9e8d7c6-b5a4-3210-fedc-ba0987654321.jpg';
      
      // 同じSKU、異なるUUID
      final bytes1 = Uint8List.fromList([1, 2, 3]);
      final bytes2 = Uint8List.fromList([4, 5, 6]);
      
      await ImageCacheService.cacheImage(url1, bytes1);
      await ImageCacheService.cacheImage(url2, bytes2);
      
      // 両方のキャッシュが独立して存在
      final cached1 = ImageCacheService.getCachedImage(url1);
      final cached2 = ImageCacheService.getCachedImage(url2);
      
      expect(cached1, isNotNull, reason: 'UUID1のキャッシュが存在');
      expect(cached2, isNotNull, reason: 'UUID2のキャッシュが存在');
      expect(cached1, isNot(equals(cached2)), reason: '異なるUUID → 異なるキャッシュデータ');
    });

    test('🎯 キャッシュバスティングパラメータを除去してキー生成', () async {
      // キャッシュバスティング付きURL
      const baseUrl = 'https://image-upload-api.jinkedon2.workers.dev/1025L280001/1025L280001_a1b2c3d4-e5f6-7890-abcd-ef1234567890.jpg';
      const cacheBustedUrl1 = '$baseUrl?t=1768057805750';
      const cacheBustedUrl2 = '$baseUrl?t=1768057999999';
      
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      
      // 1. cacheBustedUrl1でキャッシュ
      await ImageCacheService.cacheImage(cacheBustedUrl1, bytes);
      
      // 2. cacheBustedUrl2（異なるタイムスタンプ）で取得できるか
      final cached = ImageCacheService.getCachedImage(cacheBustedUrl2);
      
      // Note: 現在の実装では?t=パラメータ付きでもファイル名を正しく抽出できる
      expect(cached, isNotNull, reason: 'タイムスタンプが異なっても同じファイル名 → 同じキャッシュ');
    });

    test('🎯 白抜き画像と元画像のキャッシュ分離', () async {
      // 元画像
      const originalUrl = 'https://image-upload-api.jinkedon2.workers.dev/1025L280001/1025L280001_a1b2c3d4-e5f6-7890-abcd-ef1234567890.jpg';
      
      // 白抜き画像（_white.jpgサフィックス）
      const whiteUrl = 'https://image-upload-api.jinkedon2.workers.dev/1025L280001/1025L280001_a1b2c3d4-e5f6-7890-abcd-ef1234567890_white.jpg';
      
      final bytesOriginal = Uint8List.fromList([1, 2, 3]);
      final bytesWhite = Uint8List.fromList([4, 5, 6]);
      
      // 両方をキャッシュ
      await ImageCacheService.cacheImage(originalUrl, bytesOriginal);
      await ImageCacheService.cacheImage(whiteUrl, bytesWhite);
      
      // 両方のキャッシュが独立して存在
      final cachedOriginal = ImageCacheService.getCachedImage(originalUrl);
      final cachedWhite = ImageCacheService.getCachedImage(whiteUrl);
      
      expect(cachedOriginal, isNotNull, reason: '元画像のキャッシュが存在');
      expect(cachedWhite, isNotNull, reason: '白抜き画像のキャッシュが存在');
      expect(cachedOriginal, isNot(equals(cachedWhite)), reason: '異なるファイル名 → 異なるキャッシュ');
    });

    test('🎯 SKU単位でのキャッシュクリア', () async {
      // SKU-A の画像
      const urlA1 = 'https://image-upload-api.jinkedon2.workers.dev/SKU-A/SKU-A_uuid1.jpg';
      const urlA2 = 'https://image-upload-api.jinkedon2.workers.dev/SKU-A/SKU-A_uuid2.jpg';
      
      // SKU-B の画像
      const urlB1 = 'https://image-upload-api.jinkedon2.workers.dev/SKU-B/SKU-B_uuid3.jpg';
      
      final bytes = Uint8List.fromList([1, 2, 3]);
      
      // すべてキャッシュ
      await ImageCacheService.cacheImage(urlA1, bytes);
      await ImageCacheService.cacheImage(urlA2, bytes);
      await ImageCacheService.cacheImage(urlB1, bytes);
      
      // SKU-A のキャッシュをクリア
      await ImageCacheService.clearCacheForSku('SKU-A');
      
      // SKU-A は削除、SKU-B は保持
      final cachedA1 = ImageCacheService.getCachedImage(urlA1);
      final cachedA2 = ImageCacheService.getCachedImage(urlA2);
      final cachedB1 = ImageCacheService.getCachedImage(urlB1);
      
      expect(cachedA1, isNull, reason: 'SKU-A_uuid1 のキャッシュが削除されている');
      expect(cachedA2, isNull, reason: 'SKU-A_uuid2 のキャッシュが削除されている');
      expect(cachedB1, isNotNull, reason: 'SKU-B_uuid3 のキャッシュは保持されている');
    });

    test('🎯 Phase 1: 旧命名規則と新命名規則のキャッシュ分離', () async {
      // 旧命名規則（連番）
      const oldUrl = 'https://image-upload-api.jinkedon2.workers.dev/1025L280001/1025L280001_1.jpg';
      
      // 新命名規則（UUID）
      const newUrl = 'https://image-upload-api.jinkedon2.workers.dev/1025L280001/1025L280001_a1b2c3d4-e5f6-7890-abcd-ef1234567890.jpg';
      
      final bytesOld = Uint8List.fromList([1, 2, 3]);
      final bytesNew = Uint8List.fromList([4, 5, 6]);
      
      // 両方をキャッシュ
      await ImageCacheService.cacheImage(oldUrl, bytesOld);
      await ImageCacheService.cacheImage(newUrl, bytesNew);
      
      // 両方のキャッシュが独立して存在
      final cachedOld = ImageCacheService.getCachedImage(oldUrl);
      final cachedNew = ImageCacheService.getCachedImage(newUrl);
      
      expect(cachedOld, isNotNull, reason: '旧命名規則のキャッシュが存在');
      expect(cachedNew, isNotNull, reason: '新命名規則のキャッシュが存在');
      expect(cachedOld, isNot(equals(cachedNew)), reason: '異なるファイル名 → 異なるキャッシュ');
    });
  });
}
