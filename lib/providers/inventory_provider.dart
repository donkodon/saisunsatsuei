import 'package:flutter/material.dart';
import 'package:measure_master/models/item.dart';
import 'package:hive_flutter/hive_flutter.dart';

class InventoryProvider with ChangeNotifier {
  static const String _boxName = 'inventory_items';
  Box<InventoryItem>? _box;
  
  List<InventoryItem> _items = [];
  String? _currentCompanyId;  // 🏢 現在の企業ID

  // 🔄 Hive初期化
  Future<void> initialize({String? companyId}) async {
    _box = await Hive.openBox<InventoryItem>(_boxName);
    _currentCompanyId = companyId;
    _loadItemsFromBox();
  }
  
  // 🏢 企業IDを設定して再読み込み
  void setCompanyId(String companyId) {
    _currentCompanyId = companyId;
    _loadItemsFromBox();
  }
  
  // 📦 Hiveから商品データを読み込み（企業IDでフィルタリング）
  void _loadItemsFromBox() {
    if (_box != null && _box!.isNotEmpty) {
      // Hiveからすべてのアイテムを取得
      final loadedItems = _box!.values.toList();
      
      // 🔍 重複排除: IDでユニークなアイテムのみを保持
      final uniqueItems = <String, InventoryItem>{};
      for (var item in loadedItems) {
        uniqueItems[item.id] = item;
      }
      
      var filteredItems = uniqueItems.values.toList();
      
      // 🏢 企業IDでフィルタリング
      if (_currentCompanyId != null && _currentCompanyId!.isNotEmpty) {
        filteredItems = filteredItems.where((item) {
          return item.companyId == _currentCompanyId;
        }).toList();
        
        debugPrint('📦 Hiveから読み込み完了（企業ID: $_currentCompanyId）: ${filteredItems.length}件');
      } else {
        debugPrint('📦 Hiveから読み込み完了（全データ）: ${filteredItems.length}件');
      }
      
      _items = filteredItems;
      
      // 日付順にソート（新しい順）
      _items.sort((a, b) => b.date.compareTo(a.date));
    }
    notifyListeners();
  }
  

  
  List<InventoryItem> get items => _items;
  
  int get readyCount => _items.where((i) => i.status == 'Ready').length;
  int get draftCount => _items.where((i) => i.status == 'Draft').length;

  // 💾 商品を追加してHiveに保存（SKUベースの上書き保存）
  Future<void> addItem(InventoryItem item) async {
    // 🏢 企業IDが未設定の場合は現在の企業IDを設定
    final itemToSave = (item.companyId == null || item.companyId!.isEmpty)
        ? InventoryItem(
            id: item.id,
            name: item.name,
            brand: item.brand,
            imageUrl: item.imageUrl,
            category: item.category,
            status: item.status,
            date: item.date,
            length: item.length,
            width: item.width,
            size: item.size,
            hasAlert: item.hasAlert,
            barcode: item.barcode,
            sku: item.sku,
            color: item.color,
            productRank: item.productRank,
            salePrice: item.salePrice,
            condition: item.condition,
            description: item.description,
            material: item.material,
            imageUrls: item.imageUrls,
            imagesJson: item.imagesJson,
            companyId: _currentCompanyId,  // 🏢 現在の企業IDを設定
          )
        : item;
    
    // 🔍 SKUで既存アイテムを検索
    final existingItem = _items.cast<InventoryItem?>().firstWhere(
      (existingItem) => 
        existingItem != null &&
        existingItem.sku != null && 
        existingItem.sku!.isNotEmpty && 
        existingItem.sku == itemToSave.sku,
      orElse: () => null,
    );
    
    if (existingItem != null) {
      // 🔄 既存アイテムを更新（SKUが同じ場合）
      debugPrint('🔄 既存のSKU (${itemToSave.sku}) を更新します');
      debugPrint('   古いID: ${existingItem.id}');
      debugPrint('   新しいデータで上書きします');
      
      // Hiveから古いエントリをすべて削除（念のため全検索）
      if (_box != null) {
        final keysToDelete = <dynamic>[];
        for (var key in _box!.keys) {
          final boxItem = _box!.get(key);
          if (boxItem != null && boxItem.sku == itemToSave.sku) {
            keysToDelete.add(key);
          }
        }
        
        for (var key in keysToDelete) {
          await _box!.delete(key);
          debugPrint('🗑️ 古いHiveエントリを削除: $key');
        }
      }
      
      // リストから古いアイテムを削除
      _items.removeWhere((i) => i.sku == itemToSave.sku);
      
      // 新しいアイテムを先頭に追加
      _items.insert(0, itemToSave);
    } else {
      // ✨ 新規アイテムとしてリストの先頭に追加
      debugPrint('✨ 新規アイテムとして追加します（SKU: ${itemToSave.sku}）');
      _items.insert(0, itemToSave);
    }
    
    // ローカル保存 (Hive) - IDをキーとして使用
    if (_box != null) {
      await _box!.put(itemToSave.id, itemToSave);
      debugPrint('✅ Hiveに保存成功: ID=${itemToSave.id}');
      debugPrint('📦 保存データ:');
      debugPrint('   - 商品名: ${itemToSave.name}');
      debugPrint('   - カテゴリ: ${itemToSave.category}');
      debugPrint('   - 商品の状態: ${itemToSave.condition}');
      debugPrint('   - 説明: ${itemToSave.description}');
      debugPrint('   - SKU: ${itemToSave.sku}');
      debugPrint('   - バーコード: ${itemToSave.barcode}');
      debugPrint('   - 企業ID: ${itemToSave.companyId}');  // 🏢 企業ID表示
      debugPrint('   - 画像URL: ${itemToSave.imageUrl}');
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
  
  // 📸 商品の画像URLを更新
  Future<void> updateItemImages(String sku, List<String> newImageUrls) async {
    if (sku.isEmpty) return;
    
    // SKUで既存アイテムを検索
    final index = _items.indexWhere((item) => item.sku == sku);
    if (index == -1) {
      debugPrint('⚠️ 画像更新: SKU $sku が見つかりません');
      return;
    }
    
    final existingItem = _items[index];
    
    // 新しいアイテムを作成（画像URLのみ更新）
    final updatedItem = InventoryItem(
      id: existingItem.id,
      name: existingItem.name,
      brand: existingItem.brand,
      imageUrl: newImageUrls.isNotEmpty ? newImageUrls.first : existingItem.imageUrl,
      category: existingItem.category,
      status: existingItem.status,
      date: existingItem.date,
      length: existingItem.length,
      width: existingItem.width,
      size: existingItem.size,
      hasAlert: existingItem.hasAlert,
      barcode: existingItem.barcode,
      sku: existingItem.sku,
      color: existingItem.color,
      productRank: existingItem.productRank,
      salePrice: existingItem.salePrice,
      condition: existingItem.condition,
      description: existingItem.description,
      material: existingItem.material,
      imageUrls: newImageUrls,  // 📸 新しい画像リスト
      companyId: existingItem.companyId,  // 🏢 企業IDを保持
    );
    
    // リストを更新
    _items[index] = updatedItem;
    
    // Hiveを更新
    if (_box != null) {
      await _box!.put(existingItem.id, updatedItem);
      debugPrint('📸 画像URL更新完了: SKU=$sku, 画像数=${newImageUrls.length}');
    }
    
    notifyListeners();
  }
  
  // 🗑️ 商品から特定の画像を削除
  Future<void> removeImageFromItem(String sku, String imageUrl) async {
    if (sku.isEmpty) return;
    
    final existingItem = findBySku(sku);
    if (existingItem == null) {
      debugPrint('⚠️ 画像削除: SKU $sku が見つかりません');
      return;
    }
    
    // 現在の画像リストから指定の画像を削除
    final currentImages = List<String>.from(existingItem.imageUrls ?? []);
    currentImages.remove(imageUrl);
    
    // 更新
    await updateItemImages(sku, currentImages);
    debugPrint('🗑️ 画像を削除しました: $imageUrl');
  }
}
