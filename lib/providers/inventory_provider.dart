import 'package:flutter/material.dart';
import 'package:measure_master/models/item.dart';
import 'package:hive_flutter/hive_flutter.dart';

class InventoryProvider with ChangeNotifier {
  static const String _boxName = 'inventory_items';
  Box<InventoryItem>? _box;
  
  List<InventoryItem> _items = [];

  // 🔄 Hive初期化
  Future<void> initialize() async {
    _box = await Hive.openBox<InventoryItem>(_boxName);
    _loadItemsFromBox();
  }
  
  // 📦 Hiveから商品データを読み込み
  void _loadItemsFromBox() {
    if (_box != null && _box!.isNotEmpty) {
      // Hiveからすべてのアイテムを取得
      final loadedItems = _box!.values.toList();
      
      // 🔍 重複排除: IDでユニークなアイテムのみを保持
      final uniqueItems = <String, InventoryItem>{};
      for (var item in loadedItems) {
        uniqueItems[item.id] = item;
      }
      
      _items = uniqueItems.values.toList();
      
      // 日付順にソート（新しい順）
      _items.sort((a, b) => b.date.compareTo(a.date));
      
      print('📦 Hiveから読み込み完了: ${_items.length}件');
    }
    notifyListeners();
  }
  

  
  List<InventoryItem> get items => _items;
  
  int get readyCount => _items.where((i) => i.status == 'Ready').length;
  int get draftCount => _items.where((i) => i.status == 'Draft').length;

  // 💾 商品を追加してHiveに保存（SKUベースの上書き保存）
  Future<void> addItem(InventoryItem item) async {
    // 🔍 SKUで既存アイテムを検索
    final existingItem = _items.cast<InventoryItem?>().firstWhere(
      (existingItem) => 
        existingItem != null &&
        existingItem.sku != null && 
        existingItem.sku!.isNotEmpty && 
        existingItem.sku == item.sku,
      orElse: () => null,
    );
    
    if (existingItem != null) {
      // 🔄 既存アイテムを更新（SKUが同じ場合）
      print('🔄 既存のSKU (${item.sku}) を更新します');
      print('   古いID: ${existingItem.id}');
      print('   新しいデータで上書きします');
      
      // Hiveから古いエントリをすべて削除（念のため全検索）
      if (_box != null) {
        final keysToDelete = <dynamic>[];
        for (var key in _box!.keys) {
          final boxItem = _box!.get(key);
          if (boxItem != null && boxItem.sku == item.sku) {
            keysToDelete.add(key);
          }
        }
        
        for (var key in keysToDelete) {
          await _box!.delete(key);
          print('🗑️ 古いHiveエントリを削除: $key');
        }
      }
      
      // リストから古いアイテムを削除
      _items.removeWhere((i) => i.sku == item.sku);
      
      // 新しいアイテムを先頭に追加
      _items.insert(0, item);
    } else {
      // ✨ 新規アイテムとしてリストの先頭に追加
      print('✨ 新規アイテムとして追加します（SKU: ${item.sku}）');
      _items.insert(0, item);
    }
    
    // ローカル保存 (Hive) - IDをキーとして使用
    if (_box != null) {
      await _box!.put(item.id, item);
      print('✅ Hiveに保存成功: ID=${item.id}');
      print('📦 保存データ:');
      print('   - 商品名: ${item.name}');
      print('   - カテゴリ: ${item.category}');
      print('   - 商品の状態: ${item.condition}');
      print('   - 説明: ${item.description}');
      print('   - SKU: ${item.sku}');
      print('   - バーコード: ${item.barcode}');
      print('   - 画像URL: ${item.imageUrl}');
    }
    
    notifyListeners();
  }
  
  // 🔍 SKUまたはバーコードで商品を検索
  InventoryItem? findBySku(String sku) {
    try {
      return _items.firstWhere(
        (item) => item.sku == sku || item.barcode == sku,
      );
    } catch (e) {
      return null;
    }
  }
}
