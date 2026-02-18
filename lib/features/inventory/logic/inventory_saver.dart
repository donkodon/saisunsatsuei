import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:measure_master/models/item.dart';
import 'package:measure_master/providers/inventory_provider.dart';
import 'package:measure_master/services/api_service.dart';
import 'package:measure_master/auth/company_service.dart';

/// 💾 在庫保存クラス
/// 
/// 責任:
/// - Hive（ローカルDB）への保存
/// - D1（クラウドDB）への保存
/// - D1保存のリトライ処理
/// - エラーハンドリング
class InventorySaver {
  final InventoryProvider _inventoryProvider;
  final ApiService _apiService;
  final CompanyService _companyService;

  InventorySaver({
    required InventoryProvider inventoryProvider,
    ApiService? apiService,
    CompanyService? companyService,
  })  : _inventoryProvider = inventoryProvider,
        _apiService = apiService ?? ApiService(),
        _companyService = companyService ?? CompanyService();

  /// 💾 Hiveに保存
  /// 
  /// [item] - 保存するInventoryItem
  /// 
  /// Returns: true if successful
  Future<bool> saveToHive(InventoryItem item) async {
    try {
      debugPrint('💾 Hive保存開始');
      debugPrint('   SKU: ${item.sku}');
      debugPrint('   画像枚数: ${item.imageUrls?.length ?? 0}');

      await _inventoryProvider.addItem(item);
      
      debugPrint('✅ Hive保存完了');

      // 🔍 Hive保存後の確認（読み込んで検証）
      if (kDebugMode && item.sku != null && item.sku!.isNotEmpty) {
        final savedItem = _inventoryProvider.findBySku(item.sku!);
        if (savedItem != null) {
          debugPrint('🔍 Hive保存後の確認:');
          debugPrint('   savedItem.imageUrls件数: ${savedItem.imageUrls?.length ?? 0}件');
          if (savedItem.imageUrls != null && kDebugMode) {
            for (int i = 0; i < savedItem.imageUrls!.length; i++) {
              debugPrint('     [$i] ${savedItem.imageUrls![i]}');
            }
          }
        }
      }

      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Hive保存エラー: $e');
      debugPrint('スタックトレース: $stackTrace');
      return false;
    }
  }

  /// 🌐 D1に保存（リトライ機能付き）
  /// 
  /// [item] - 保存するInventoryItem
  /// [imageUrls] - 画像URLリスト
  /// [additionalData] - 追加データ（実寸データなど）
  /// [maxRetries] - 最大リトライ回数（デフォルト: 3回）
  /// 
  /// Returns: SaveToD1Result
  Future<SaveToD1Result> saveToD1WithRetry({
    required InventoryItem item,
    required List<String> imageUrls,
    Map<String, dynamic>? additionalData,
    int maxRetries = 3,
  }) async {
    // ✅ item_code はループ外で1度だけ生成する
    // リトライのたびに新しい item_code を生成すると、
    // 1回目の INSERT が成功済みなのに2回目以降で UNIQUE 制約違反になる
    final itemCode = '${item.sku}_${DateTime.now().millisecondsSinceEpoch}';

    for (int retryCount = 0; retryCount < maxRetries; retryCount++) {
      try {
        debugPrint('🌐 D1保存試行 ${retryCount + 1}/$maxRetries');

        // 🏢 企業IDを取得（null時は空文字）
        final companyId = await _companyService.getCompanyId() ?? '';

        // 🔍 デバッグログ: 企業ID取得結果
        debugPrint('═══════════════════════════════════════');
        debugPrint('🏢 D1保存時の企業ID検証');
        debugPrint('   企業ID (companyId): "$companyId"');
        debugPrint('   SKU: "${item.sku}"');
        debugPrint('   Firebase UID: "${FirebaseAuth.instance.currentUser?.uid}"');
        debugPrint('   Firebase Email: "${FirebaseAuth.instance.currentUser?.email}"');
        debugPrint('═══════════════════════════════════════');

        // ベースデータ
        final itemData = <String, dynamic>{
          'sku': item.sku ?? '',
          'itemCode': itemCode,
          'upsert': true,  // ✅ 既存レコードがあれば UPDATE、なければ INSERT
          'name': item.name,
          'barcode': item.barcode,
          'brand': item.brand,
          'category': item.category,
          'color': item.color,
          'size': item.size,
          'material': item.material,
          'price': item.salePrice,
          'condition': item.condition,
          'productRank': item.productRank,
          'imageUrls': imageUrls,
          'description': item.description,
          'photographed': 1,
          'photographedBy': companyId.isNotEmpty ? companyId : 'unknown',
          'photographedAt': DateTime.now().toIso8601String(),
          'status': 'available',
          'company_id': companyId.isNotEmpty ? companyId : 'unknown',  // 🔥 company_id を追加
        };

        // 追加データをマージ
        if (additionalData != null) {
          itemData.addAll(additionalData);
        }

        // 📏 実寸データ（length/width/shoulder/sleeve）を
        // actual_measurements JSON に変換して Workers に渡す
        // Workers の INSERT 文は actualMeasurements キーで受け取る設計
        final length   = itemData['length']?.toString() ?? '';
        final width    = itemData['width']?.toString() ?? '';
        final shoulder = itemData['shoulder']?.toString() ?? '';
        final sleeve   = itemData['sleeve']?.toString() ?? '';

        // 🔥 強制デバッグログ（リリースビルドでも出力）
        print('📏 ======== サイズデータ確認 ========');
        print('📏 additionalData に含まれる値:');
        print('   length   = "$length"   (isEmpty: ${length.isEmpty})');
        print('   width    = "$width"    (isEmpty: ${width.isEmpty})');
        print('   shoulder = "$shoulder" (isEmpty: ${shoulder.isEmpty})');
        print('   sleeve   = "$sleeve"   (isEmpty: ${sleeve.isEmpty})');

        if (length.isNotEmpty || width.isNotEmpty || shoulder.isNotEmpty || sleeve.isNotEmpty) {
          itemData['actualMeasurements'] = {
            if (length.isNotEmpty)   'body_length':     double.tryParse(length)   ?? length,
            if (width.isNotEmpty)    'body_width':      double.tryParse(width)    ?? width,
            if (shoulder.isNotEmpty) 'shoulder_width':  double.tryParse(shoulder) ?? shoulder,
            if (sleeve.isNotEmpty)   'sleeve_length':   double.tryParse(sleeve)   ?? sleeve,
          };
          print('📏 actualMeasurements 変換完了: ${itemData['actualMeasurements']}');
        } else {
          print('⚠️ サイズデータがすべて空のため actualMeasurements は送信しません');
        }
        print('📏 =====================================');

        // バラキーは Workers に不要なので除去
        itemData.remove('length');
        itemData.remove('width');
        itemData.remove('shoulder');
        itemData.remove('sleeve');

        // D1保存API呼び出し
        final success = await _apiService.saveProductItemToD1(itemData);

        if (success) {
          debugPrint('✅ D1保存成功（試行${retryCount + 1}回目）');
          debugPrint('   Company ID: $companyId');
          debugPrint('   SKU: ${item.sku}');
          debugPrint('   Item Code: $itemCode');

          return SaveToD1Result(
            success: true,
            retryCount: retryCount + 1,
            companyId: companyId,
          );
        } else {
          throw Exception('D1保存API returned false');
        }
      } catch (e, stackTrace) {
        debugPrint('❌ D1保存失敗（試行${retryCount + 1}回目）: $e');
        
        if (retryCount < maxRetries - 1) {
          debugPrint('   ⏳ ${retryCount + 1}秒後にリトライします...');
          await Future.delayed(Duration(seconds: retryCount + 1));
        } else {
          debugPrint('❌ D1保存リトライ上限に達しました');
          debugPrint('スタックトレース: $stackTrace');
          
          return SaveToD1Result(
            success: false,
            retryCount: maxRetries,
            error: e.toString(),
            stackTrace: stackTrace,
          );
        }
      }
    }

    return SaveToD1Result(
      success: false,
      retryCount: maxRetries,
      error: 'リトライ上限到達',
    );
  }

  /// 💾 Hive + D1 に両方保存
  /// 
  /// [item] - 保存するInventoryItem
  /// [imageUrls] - 画像URLリスト
  /// [additionalData] - 追加データ
  /// 
  /// Returns: CombinedSaveResult
  Future<CombinedSaveResult> saveToHiveAndD1({
    required InventoryItem item,
    required List<String> imageUrls,
    Map<String, dynamic>? additionalData,
  }) async {
    // 1. Hive保存
    final hiveSuccess = await saveToHive(item);

    if (!hiveSuccess) {
      return CombinedSaveResult(
        hiveSuccess: false,
        d1Result: SaveToD1Result(success: false, retryCount: 0, error: 'Hive保存失敗'),
      );
    }

    // 2. D1保存（リトライ付き）
    final d1Result = await saveToD1WithRetry(
      item: item,
      imageUrls: imageUrls,
      additionalData: additionalData,
    );

    return CombinedSaveResult(
      hiveSuccess: true,
      d1Result: d1Result,
    );
  }
}

/// 📦 D1保存結果
class SaveToD1Result {
  final bool success;
  final int retryCount;
  final String? companyId;
  final String? error;
  final StackTrace? stackTrace;

  SaveToD1Result({
    required this.success,
    required this.retryCount,
    this.companyId,
    this.error,
    this.stackTrace,
  });
}

/// 📦 Hive + D1 保存結果
class CombinedSaveResult {
  final bool hiveSuccess;
  final SaveToD1Result d1Result;

  CombinedSaveResult({
    required this.hiveSuccess,
    required this.d1Result,
  });

  bool get bothSuccess => hiveSuccess && d1Result.success;
  bool get hiveOnlySuccess => hiveSuccess && !d1Result.success;
}
