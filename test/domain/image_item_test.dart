import 'package:flutter_test/flutter_test.dart';
import 'package:measure_master/features/inventory/domain/image_item.dart';

void main() {
  group('ImageItem.extractUuidFromUrl', () {
    const validUuid = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';

    test('標準的なURL形式から正しくUUIDを抽出できる', () {
      final url = 'https://r2.example.com/relight/SKU001_$validUuid.jpg';
      final result = ImageItem.extractUuidFromUrl(url);
      expect(result, equals(validUuid));
    });

    test('クエリパラメータ付きURLからでも正しくUUIDを抽出できる', () {
      final url =
          'https://r2.example.com/relight/SKU001_$validUuid.jpg?v=123456';
      final result = ImageItem.extractUuidFromUrl(url);
      expect(result, equals(validUuid));
    });

    test('_white.jpg サフィックス付きURLからでも正しくUUIDを抽出できる', () {
      final url =
          'https://r2.example.com/relight/SKU001_${validUuid}_white.jpg';
      final result = ImageItem.extractUuidFromUrl(url);
      expect(result, equals(validUuid));
    });

    test('UUIDを含まないURLの場合、新規UUIDを返す（フォールバック）', () {
      const url = 'https://r2.example.com/relight/no_uuid_here.jpg';
      final result = ImageItem.extractUuidFromUrl(url);
      // フォールバック: 有効なUUID形式で返ってくることを確認
      final uuidRegex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false,
      );
      expect(uuidRegex.hasMatch(result), isTrue);
      // 元のURLに含まれるUUIDではない（新しく生成されたもの）
      expect(result, isNot(equals(validUuid)));
    });

    test('空文字列を渡した場合、新規UUIDを返す（フォールバック）', () {
      final result = ImageItem.extractUuidFromUrl('');
      final uuidRegex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false,
      );
      expect(uuidRegex.hasMatch(result), isTrue);
    });

    test('大文字UUIDを含むURLでも正しく抽出できる（大文字小文字不問）', () {
      const upperUuid = 'A1B2C3D4-E5F6-7890-ABCD-EF1234567890';
      final url = 'https://r2.example.com/relight/SKU001_$upperUuid.jpg';
      final result = ImageItem.extractUuidFromUrl(url);
      expect(result.toLowerCase(), equals(upperUuid.toLowerCase()));
    });

    test('複数のアンダースコアを含むSKUでも正しくUUIDを抽出できる', () {
      final url =
          'https://r2.example.com/relight/SKU_001_ITEM_$validUuid.jpg';
      final result = ImageItem.extractUuidFromUrl(url);
      expect(result, equals(validUuid));
    });
  });
}
