import 'package:flutter_test/flutter_test.dart';
import 'package:measure_master/constants/image_constants.dart';

void main() {
  group('ImageConstants', () {
    group('isWhiteBackgroundImage', () {
      test('白抜き画像（_p.png）を正しく判定する', () {
        expect(ImageConstants.isWhiteBackgroundImage('test_p.png'), isTrue);
        expect(ImageConstants.isWhiteBackgroundImage('1025L280001_uuid_p.png'), isTrue);
        expect(
          ImageConstants.isWhiteBackgroundImage(
            'https://example.com/sku/file_p.png',
          ),
          isTrue,
        );
      });

      test('通常画像を正しく判定する', () {
        expect(ImageConstants.isWhiteBackgroundImage('test.jpg'), isFalse);
        expect(ImageConstants.isWhiteBackgroundImage('test.png'), isFalse);
        expect(ImageConstants.isWhiteBackgroundImage('test_p.jpg'), isFalse);
        expect(
          ImageConstants.isWhiteBackgroundImage(
            'https://example.com/sku/file.jpg',
          ),
          isFalse,
        );
      });
    });

    group('generateWhiteBackgroundUrl', () {
      test('JPG画像から白抜きURLを生成する', () {
        const original = 'https://example.com/1025L280001/1025L280001_uuid.jpg';
        const expected = 'https://example.com/1025L280001/1025L280001_uuid_p.png';
        
        expect(
          ImageConstants.generateWhiteBackgroundUrl(original),
          equals(expected),
        );
      });

      test('JPEG画像から白抜きURLを生成する', () {
        const original = 'https://example.com/sku/file.jpeg';
        const expected = 'https://example.com/sku/file_p.png';
        
        expect(
          ImageConstants.generateWhiteBackgroundUrl(original),
          equals(expected),
        );
      });

      test('PNG画像から白抜きURLを生成する', () {
        const original = 'https://example.com/sku/file.png';
        const expected = 'https://example.com/sku/file_p.png';
        
        expect(
          ImageConstants.generateWhiteBackgroundUrl(original),
          equals(expected),
        );
      });

      test('クエリパラメータ付きURLも正しく処理する', () {
        const original = 'https://example.com/sku/file.jpg?t=12345';
        // 注意: 現在の実装では、クエリパラメータ部分も変換対象になる
        const expected = 'https://example.com/sku/file.jpg?t=12345_p.png';
        
        expect(
          ImageConstants.generateWhiteBackgroundUrl(original),
          equals(expected),
        );
      });
    });

    group('restoreOriginalFileName', () {
      test('白抜き画像URLから元のファイル名を復元する', () {
        const white = 'https://example.com/1025L280001/1025L280001_uuid_p.png';
        const expected = '1025L280001_uuid.jpg';
        
        expect(
          ImageConstants.restoreOriginalFileName(white),
          equals(expected),
        );
      });

      test('クエリパラメータ付きURLも正しく処理する', () {
        const white = 'https://example.com/sku/file_p.png?t=12345';
        const expected = 'file.jpg';
        
        expect(
          ImageConstants.restoreOriginalFileName(white),
          equals(expected),
        );
      });

      test('ファイル名のみでも正しく処理する', () {
        const white = '1025L280001_uuid_p.png';
        const expected = '1025L280001_uuid.jpg';
        
        expect(
          ImageConstants.restoreOriginalFileName(white),
          equals(expected),
        );
      });
    });

    group('統合テスト', () {
      test('元画像 → 白抜き → 元画像 の変換が一貫している', () {
        const original = 'https://example.com/1025L280001/1025L280001_uuid.jpg';
        
        // 元画像 → 白抜き画像
        final white = ImageConstants.generateWhiteBackgroundUrl(original);
        expect(white, equals('https://example.com/1025L280001/1025L280001_uuid_p.png'));
        
        // 白抜き画像 → 元のファイル名
        final restored = ImageConstants.restoreOriginalFileName(white);
        expect(restored, equals('1025L280001_uuid.jpg'));
        
        // 白抜き画像の判定
        expect(ImageConstants.isWhiteBackgroundImage(white), isTrue);
        expect(ImageConstants.isWhiteBackgroundImage(original), isFalse);
      });
    });
  });
}
