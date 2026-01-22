import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// 🗑️ Phase 1: クリーンアップヘルパー
/// 
/// 既存Hiveデータを削除してクリーンスタートするためのユーティリティ
class CleanupHelper {
  /// 🗑️ 全てのHiveデータを削除
  /// 
  /// Phase 1実装前の既存データを削除します。
  /// ⚠️ この操作は取り消せません！
  static Future<bool> clearAllHiveData() async {
    try {
      debugPrint('🗑️ Hiveデータ削除を開始...');
      
      // inventory_boxを削除
      try {
        final inventoryBox = await Hive.openBox('inventory_box');
        await inventoryBox.clear();
        await inventoryBox.close();
        debugPrint('  ✅ inventory_box を削除しました');
      } catch (e) {
        debugPrint('  ⚠️ inventory_box の削除に失敗: $e');
      }
      
      debugPrint('🎉 Hiveデータの削除が完了しました');
      return true;
    } catch (e) {
      debugPrint('❌ Hiveデータ削除エラー: $e');
      return false;
    }
  }
  
  /// 📊 現在のHiveデータ件数を確認
  static Future<Map<String, int>> getHiveDataCount() async {
    try {
      final result = <String, int>{};
      
      // inventory_boxの件数
      final inventoryBox = await Hive.openBox('inventory_box');
      result['inventory_box'] = inventoryBox.length;
      
      debugPrint('📊 Hiveデータ件数:');
      result.forEach((boxName, count) {
        debugPrint('  - $boxName: $count件');
      });
      
      return result;
    } catch (e) {
      debugPrint('❌ Hiveデータ件数取得エラー: $e');
      return {};
    }
  }
  
  /// 🔍 Phase 1移行前の確認事項を表示
  static Future<void> showMigrationChecklist() async {
    debugPrint('');
    debugPrint('═══════════════════════════════════════');
    debugPrint('🚀 Phase 1: 企業分離の実装');
    debugPrint('═══════════════════════════════════════');
    debugPrint('');
    debugPrint('📋 実施事項:');
    debugPrint('  1. ✅ api_service.dart を修正（company_id追加）');
    debugPrint('  2. ✅ cloudflare_storage_service.dart を修正');
    debugPrint('  3. 🔄 既存Hiveデータを削除（これから実施）');
    debugPrint('  4. 🔄 D1に新規データを保存（company_id付き）');
    debugPrint('');
    
    final dataCount = await getHiveDataCount();
    
    debugPrint('⚠️ 注意事項:');
    debugPrint('  - 既存データ: ${dataCount['inventory_box'] ?? 0}件が削除されます');
    debugPrint('  - この操作は取り消せません');
    debugPrint('  - Phase 1完了後に商品を再登録してください');
    debugPrint('');
    debugPrint('═══════════════════════════════════════');
    debugPrint('');
  }
}
