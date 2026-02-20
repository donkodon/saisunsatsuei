import 'package:flutter/foundation.dart';
import 'package:measure_master/features/inventory/domain/item.dart';
import 'package:measure_master/features/inventory/logic/inventory_provider.dart';
import 'package:measure_master/core/services/api_service.dart';
import 'package:measure_master/features/auth/logic/company_service.dart';
import 'package:measure_master/core/utils/date_utils.dart';

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

  /// [companyService] は必ず Provider 経由のインスタンスを渡すこと
  InventorySaver({
    required InventoryProvider inventoryProvider,
    required CompanyService companyService,
    ApiService? apiService,
  })  : _inventoryProvider = inventoryProvider,
        _companyService = companyService,
        _apiService = apiService ?? ApiService();

  /// 💾 Hiveに保存
  /// 
  /// [item] - 保存するInventoryItem
  /// 
  /// Returns: true if successful
  Future<bool> saveToHive(InventoryItem item) async {
    try {

      await _inventoryProvider.addItem(item);
      

      return true;
    } catch (e) {
      return false;
    }
  }

  /// 🌐 D1に保存（リトライ機能付き）
  /// 
  /// [item] - 保存するInventoryItem
  /// [imageUrls] - 画像URLリスト
  /// [userDisplayName] - ユーザー表示名（photographed_by用）
  /// [additionalData] - 追加データ（実寸データなど）
  /// [maxRetries] - 最大リトライ回数（デフォルト: 3回）
  /// 
  /// Returns: SaveToD1Result
  Future<SaveToD1Result> saveToD1WithRetry({
    required InventoryItem item,
    required List<String> imageUrls,
    String? userDisplayName,
    Map<String, dynamic>? additionalData,
    int maxRetries = 3,
  }) async {
    // ✅ item_code はループ外で1度だけ生成する
    // リトライのたびに新しい item_code を生成すると、
    // 1回目の INSERT が成功済みなのに2回目以降で UNIQUE 制約違反になる
    final itemCode = '${item.sku}_${DateTime.now().millisecondsSinceEpoch}';

    for (int retryCount = 0; retryCount < maxRetries; retryCount++) {
      try {

        // 🏢 企業IDを取得（null時は空文字）
        final companyId = await _companyService.getCompanyId() ?? '';

        // ベースデータ
        final photographedByValue = userDisplayName ?? (companyId.isNotEmpty ? companyId : 'unknown');
        
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
          'photographedBy': photographedByValue,  // 👤 ユーザー名優先
          'status': 'available',
          'company_id': companyId.isNotEmpty ? companyId : 'unknown',  // 🔥 company_id を追加
        };

        // 追加データをマージ
        if (additionalData != null) {
          itemData.addAll(additionalData);
        }
        
        // ✅ タイムスタンプは最後に設定（additionalDataで上書きされないように）
        itemData['photographedAt'] = DateTimeUtils.getJstNow();
        itemData['created_at'] = DateTimeUtils.getJstNow();
        itemData['updated_at'] = DateTimeUtils.getJstNow();

        // 📏 実寸データ（length/width/shoulder/sleeve）を
        // actual_measurements JSON に変換して Workers に渡す
        // Workers の INSERT 文は actualMeasurements キーで受け取る設計
        final length   = itemData['length']?.toString() ?? '';
        final width    = itemData['width']?.toString() ?? '';
        final shoulder = itemData['shoulder']?.toString() ?? '';
        final sleeve   = itemData['sleeve']?.toString() ?? '';

        if (length.isNotEmpty || width.isNotEmpty || shoulder.isNotEmpty || sleeve.isNotEmpty) {
          itemData['actualMeasurements'] = {
            if (length.isNotEmpty)   'body_length':     double.tryParse(length)   ?? length,
            if (width.isNotEmpty)    'body_width':      double.tryParse(width)    ?? width,
            if (shoulder.isNotEmpty) 'shoulder_width':  double.tryParse(shoulder) ?? shoulder,
            if (sleeve.isNotEmpty)   'sleeve_length':   double.tryParse(sleeve)   ?? sleeve,
          };
        }

        // バラキーは Workers に不要なので除去
        itemData.remove('length');
        itemData.remove('width');
        itemData.remove('shoulder');
        itemData.remove('sleeve');

        // 🔍 デバッグ: 送信データの確認
        if (kDebugMode) {
          debugPrint('📤 D1送信データ:');
          debugPrint('   photographedAt: ${itemData['photographedAt']}');
          debugPrint('   created_at: ${itemData['created_at']}');
          debugPrint('   updated_at: ${itemData['updated_at']}');
        }

        // D1保存API呼び出し
        final success = await _apiService.saveProductItemToD1(itemData);

        if (success) {
          return SaveToD1Result(
            success: true,
            retryCount: retryCount + 1,
            companyId: companyId,
          );
        } else {
          throw Exception('D1保存API returned false');
        }
      } catch (e, stackTrace) {
        if (retryCount < maxRetries - 1) {
          await Future.delayed(Duration(seconds: retryCount + 1));
        } else {
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
  /// [userDisplayName] - ユーザー表示名（photographed_by用）
  /// [additionalData] - 追加データ
  /// 
  /// Returns: CombinedSaveResult
  Future<CombinedSaveResult> saveToHiveAndD1({
    required InventoryItem item,
    required List<String> imageUrls,
    String? userDisplayName,
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
      userDisplayName: userDisplayName,  // 👤 ユーザー名を渡す
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
