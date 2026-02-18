import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// 🔍 キャッシュ検査ツール（デバッグ用）
/// 
/// キャッシュキーとデータの内容を確認するためのユーティリティ
class CacheInspector {
  static const String _boxName = 'image_cache';
  
  /// キャッシュの全キーを表示
  static Future<void> printAllCacheKeys() async {
    if (!kDebugMode) return;
    
    final box = await Hive.openBox<String>(_boxName);
    
    debugPrint('🔍 ========== キャッシュ検査 ==========');
    debugPrint('📊 キャッシュ総数: ${box.length}件');
    debugPrint('');
    
    int index = 1;
    for (var key in box.keys) {
      final value = box.get(key);
      final dataSize = value?.length ?? 0;
      
      // UUIDパターンかどうかを判定
      final isUuidPattern = _isUuidFileName(key.toString());
      final pattern = isUuidPattern ? '🆔 UUID形式' : '🔢 連番形式';
      
      debugPrint('[$index] $pattern');
      debugPrint('  キー: $key');
      debugPrint('  データサイズ: ${(dataSize / 1024).toStringAsFixed(2)} KB');
      debugPrint('');
      
      index++;
    }
    
    debugPrint('========================================');
  }
  
  /// ファイル名がUUID形式かどうかを判定
  static bool _isUuidFileName(String fileName) {
    // UUID形式: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    final uuidPattern = RegExp(
      r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
      caseSensitive: false,
    );
    return uuidPattern.hasMatch(fileName);
  }
  
  /// 特定のSKUに関連するキャッシュを表示
  static Future<void> printCacheForSku(String sku) async {
    if (!kDebugMode) return;
    
    final box = await Hive.openBox<String>(_boxName);
    
    debugPrint('🔍 ========== SKU: $sku のキャッシュ ==========');
    
    final skuKeys = box.keys
        .where((key) => key.toString().startsWith(sku))
        .toList();
    
    if (skuKeys.isEmpty) {
      debugPrint('⚠️ このSKUのキャッシュはありません');
      return;
    }
    
    debugPrint('📊 該当件数: ${skuKeys.length}件');
    debugPrint('');
    
    int index = 1;
    for (var key in skuKeys) {
      final isUuidPattern = _isUuidFileName(key.toString());
      final pattern = isUuidPattern ? '🆔 UUID' : '🔢 連番';
      
      debugPrint('[$index] $pattern: $key');
      index++;
    }
    
    debugPrint('==========================================');
  }
  
  /// Phase 1実装状況を確認
  static Future<void> verifyPhase1Implementation() async {
    if (!kDebugMode) return;
    
    final box = await Hive.openBox<String>(_boxName);
    
    debugPrint('🎯 ========== Phase 1 実装状況確認 ==========');
    
    int uuidCount = 0;
    int sequenceCount = 0;
    
    for (var key in box.keys) {
      if (_isUuidFileName(key.toString())) {
        uuidCount++;
      } else {
        sequenceCount++;
      }
    }
    
    final total = box.length;
    final uuidPercentage = total > 0 ? (uuidCount / total * 100).toStringAsFixed(1) : '0.0';
    
    debugPrint('📊 総キャッシュ数: $total件');
    debugPrint('🆔 UUID形式: $uuidCount件 ($uuidPercentage%)');
    debugPrint('🔢 連番形式: $sequenceCount件 (${100 - double.parse(uuidPercentage)}%)');
    debugPrint('');
    
    if (uuidCount > 0) {
      debugPrint('✅ Phase 1実装済み: UUID形式のキャッシュが存在します');
    } else {
      debugPrint('⚠️ Phase 1未適用: UUID形式のキャッシュがありません');
    }
    
    debugPrint('=============================================');
  }
}
