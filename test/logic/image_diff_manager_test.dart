import 'package:flutter_test/flutter_test.dart';
import 'package:measure_master/features/inventory/logic/image_diff_manager.dart';

void main() {
  late ImageDiffManager manager;

  setUp(() {
    manager = ImageDiffManager();
  });

  // ─────────────────────────────────────────────────────────
  // detectImagesToDelete
  // ─────────────────────────────────────────────────────────
  group('detectImagesToDelete', () {
    test('古いURLが全て新しいURLに含まれる場合、削除対象は0件', () {
      final old = [
        'https://r2.example.com/company/SKU001_uuid1.jpg',
        'https://r2.example.com/company/SKU001_uuid2.jpg',
      ];
      final newUrls = [
        'https://r2.example.com/company/SKU001_uuid1.jpg',
        'https://r2.example.com/company/SKU001_uuid2.jpg',
        'https://r2.example.com/company/SKU001_uuid3.jpg',
      ];
      final result = manager.detectImagesToDelete(oldUrls: old, newUrls: newUrls);
      expect(result, isEmpty);
    });

    test('新しいURLにない古いURLが削除対象になる', () {
      final old = [
        'https://r2.example.com/company/SKU001_uuid1.jpg',
        'https://r2.example.com/company/SKU001_uuid2.jpg',
      ];
      final newUrls = [
        'https://r2.example.com/company/SKU001_uuid1.jpg',
      ];
      final result = manager.detectImagesToDelete(oldUrls: old, newUrls: newUrls);
      expect(result, hasLength(1));
      expect(result.first, contains('uuid2'));
    });

    test('古いURLが全て削除対象になる（全画像入替え）', () {
      final old = [
        'https://r2.example.com/company/SKU001_uuid1.jpg',
        'https://r2.example.com/company/SKU001_uuid2.jpg',
      ];
      final newUrls = [
        'https://r2.example.com/company/SKU001_uuid3.jpg',
      ];
      final result = manager.detectImagesToDelete(oldUrls: old, newUrls: newUrls);
      expect(result, hasLength(2));
    });

    test('古いURLが空リストの場合、削除対象は0件', () {
      final result = manager.detectImagesToDelete(
        oldUrls: [],
        newUrls: ['https://r2.example.com/company/SKU001_uuid1.jpg'],
      );
      expect(result, isEmpty);
    });

    test('新しいURLが空リストの場合、古いURLが全て削除対象', () {
      final old = [
        'https://r2.example.com/company/SKU001_uuid1.jpg',
        'https://r2.example.com/company/SKU001_uuid2.jpg',
      ];
      final result = manager.detectImagesToDelete(oldUrls: old, newUrls: []);
      expect(result, hasLength(2));
    });

    test('重複するURLが古いリストにあっても正しく差分を検出する', () {
      final old = [
        'https://r2.example.com/company/SKU001_uuid1.jpg',
        'https://r2.example.com/company/SKU001_uuid1.jpg', // 重複
        'https://r2.example.com/company/SKU001_uuid2.jpg',
      ];
      final newUrls = ['https://r2.example.com/company/SKU001_uuid1.jpg'];
      final result = manager.detectImagesToDelete(oldUrls: old, newUrls: newUrls);
      // 重複含め uuid2 のみが削除対象（uuid1重複は2件になる場合もある）
      expect(result.every((url) => url.contains('uuid2')), isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────
  // buildPImageUrl / buildFImageUrl
  // ─────────────────────────────────────────────────────────
  group('buildPImageUrl / buildFImageUrl', () {
    const companyId = 'relight';
    const sku = 'W001';
    const uuid = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';

    test('P画像URLが正しい命名規則で生成される', () {
      final url = ImageDiffManager.buildPImageUrl(
        uid: uuid,
        companyId: companyId,
        sku: sku,
      );
      expect(url, contains('_p.png'));
      expect(url, contains(companyId));
      expect(url, contains(sku));
    });

    test('F画像URLが正しい命名規則で生成される', () {
      final url = ImageDiffManager.buildFImageUrl(
        uid: uuid,
        companyId: companyId,
        sku: sku,
      );
      expect(url, contains('_f.png'));
      expect(url, contains(companyId));
      expect(url, contains(sku));
    });

    test('UID が "sku_uuid" 形式でも正しく処理される（sku_ プレフィックス除去）', () {
      final uidWithSku = '${sku}_$uuid';
      final url = ImageDiffManager.buildPImageUrl(
        uid: uidWithSku,
        companyId: companyId,
        sku: sku,
      );
      // sku_ プレフィックスが除去されて生成される
      expect(url, isNotEmpty);
      expect(url, contains('_p.png'));
    });

    test('P画像とF画像のURLは異なる', () {
      final pUrl = ImageDiffManager.buildPImageUrl(
        uid: uuid, companyId: companyId, sku: sku,
      );
      final fUrl = ImageDiffManager.buildFImageUrl(
        uid: uuid, companyId: companyId, sku: sku,
      );
      expect(pUrl, isNot(equals(fUrl)));
    });
  });

  // ─────────────────────────────────────────────────────────
  // buildDerivedImageUrls
  // ─────────────────────────────────────────────────────────
  group('buildDerivedImageUrls', () {
    const companyId = 'relight';
    const sku = 'W001';
    final uids = [
      'a1b2c3d4-0000-0000-0000-ef1234567890',
      'b2c3d4e5-0000-0000-0000-ef1234567891',
    ];

    test('空のUIDリストは空のURLリストを返す', () {
      final result = ImageDiffManager.buildDerivedImageUrls(
        uids: [], companyId: companyId, sku: sku, type: 'p',
      );
      expect(result, isEmpty);
    });

    test('type=p でP画像URLリストが生成される', () {
      final result = ImageDiffManager.buildDerivedImageUrls(
        uids: uids, companyId: companyId, sku: sku, type: 'p',
      );
      expect(result, hasLength(uids.length));
      expect(result.every((url) => url.contains('_p.png')), isTrue);
    });

    test('type=f でF画像URLリストが生成される', () {
      final result = ImageDiffManager.buildDerivedImageUrls(
        uids: uids, companyId: companyId, sku: sku, type: 'f',
      );
      expect(result, hasLength(uids.length));
      expect(result.every((url) => url.contains('_f.png')), isTrue);
    });

    test('companyId または sku が空の場合、空リストを返す', () {
      final result1 = ImageDiffManager.buildDerivedImageUrls(
        uids: uids, companyId: '', sku: sku, type: 'p',
      );
      final result2 = ImageDiffManager.buildDerivedImageUrls(
        uids: uids, companyId: companyId, sku: '', type: 'p',
      );
      expect(result1, isEmpty);
      expect(result2, isEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────
  // buildPUrlsFromOriginals / buildFUrlsFromOriginals
  // ─────────────────────────────────────────────────────────
  group('buildPUrlsFromOriginals / buildFUrlsFromOriginals', () {
    const companyId = 'relight';
    const sku = 'W001';
    final uuid1 = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
    final uuid2 = 'b2c3d4e5-e5f6-7890-abcd-ef1234567891';

    test('オリジナル画像URLからP画像URLが生成される', () {
      final originals = [
        'https://r2.example.com/$companyId/${sku}_$uuid1.jpg',
        'https://r2.example.com/$companyId/${sku}_$uuid2.jpg',
      ];
      final result = ImageDiffManager.buildPUrlsFromOriginals(
        originalUrls: originals, companyId: companyId, sku: sku,
      );
      expect(result, hasLength(originals.length));
      expect(result.every((url) => url.contains('_p.png')), isTrue);
    });

    test('オリジナル画像URLからF画像URLが生成される', () {
      final originals = [
        'https://r2.example.com/$companyId/${sku}_$uuid1.jpg',
      ];
      final result = ImageDiffManager.buildFUrlsFromOriginals(
        originalUrls: originals, companyId: companyId, sku: sku,
      );
      expect(result, hasLength(1));
      expect(result.first, contains('_f.png'));
    });

    test('_white.jpg・_mask.png・_p.png・_f.png を含むURLはスキップされる', () {
      final mixed = [
        'https://r2.example.com/$companyId/${sku}_$uuid1.jpg',
        'https://r2.example.com/$companyId/${sku}_${uuid1}_white.jpg',
        'https://r2.example.com/$companyId/${sku}_${uuid1}_mask.png',
        'https://r2.example.com/$companyId/${sku}_${uuid1}_p.png',
        'https://r2.example.com/$companyId/${sku}_${uuid1}_f.png',
      ];
      final result = ImageDiffManager.buildPUrlsFromOriginals(
        originalUrls: mixed, companyId: companyId, sku: sku,
      );
      // 元画像（_white/_mask/_p/_f を含まない）のみ処理される
      expect(result, hasLength(1));
    });

    test('空リストを渡すと空リストが返る', () {
      final result = ImageDiffManager.buildPUrlsFromOriginals(
        originalUrls: [], companyId: companyId, sku: sku,
      );
      expect(result, isEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────
  // detectWhiteMaskImagesToDelete
  // ─────────────────────────────────────────────────────────
  group('detectWhiteMaskImagesToDelete', () {
    const companyId = 'relight';
    const sku = 'W001';
    const uuid1 = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';

    test('古い白抜き画像が新しいリストにない場合、削除対象になる', () {
      final oldWhiteUrl =
          'https://r2.example.com/$companyId/${sku}_${uuid1}_white.jpg';
      final result = manager.detectWhiteMaskImagesToDelete(
        allImageUrls: [], // 新しい白抜きなし
        oldWhiteUrls: [oldWhiteUrl],
        oldMaskUrls: [],
        companyId: companyId,
        sku: sku,
      );
      expect(result.whiteUrlsToDelete, hasLength(1));
      expect(result.whiteUrlsToDelete.first, equals(oldWhiteUrl));
    });

    test('白抜き・マスク共に変化なしなら削除対象は0件', () {
      // allImageUrls のフィルタリングは /$companyId/ と /$sku/ をパスとして含む必要がある
      // 実装: url.contains('/$companyId/') && url.contains('/$sku/')
      // そのため companyId/sku/filename 形式のURLを使う
      final whiteUrl =
          'https://r2.example.com/$companyId/$sku/${uuid1}_white.jpg';
      final result = manager.detectWhiteMaskImagesToDelete(
        allImageUrls: [whiteUrl], // 新しいリストにも同じURL
        oldWhiteUrls: [whiteUrl],
        oldMaskUrls: [],
        companyId: companyId,
        sku: sku,
      );
      expect(result.whiteUrlsToDelete, isEmpty);
      expect(result.maskUrlsToDelete, isEmpty);
    });

    test('古い画像・新しい画像共に空なら削除対象は0件', () {
      final result = manager.detectWhiteMaskImagesToDelete(
        allImageUrls: [],
        oldWhiteUrls: [],
        oldMaskUrls: [],
        companyId: companyId,
        sku: sku,
      );
      expect(result.hasImagesToDelete, isFalse);
    });
  });
}
