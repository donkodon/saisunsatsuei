import 'package:flutter/material.dart';
import 'package:measure_master/models/item.dart';
import 'package:hive_flutter/hive_flutter.dart';

class InventoryProvider with ChangeNotifier {
  static const String _boxName = 'inventory_items';
  Box<InventoryItem>? _box;
  
  List<InventoryItem> _items = [
    InventoryItem(
      id: '1',
      name: "Levi's 501 Original Fit",
      category: "Men / Denim / W32",
      brand: "Levi's",
      imageUrl: 'assets/images/jeans_folded.jpg',
      status: 'Ready',
      date: DateTime.now(),
      width: 82,
      length: 76,
      size: 'W32',
    ),
    InventoryItem(
      id: '2',
      name: "Uniqlo U Crew Neck T",
      category: "Ladies / Tops / M",
      brand: "Uniqlo",
      imageUrl: 'assets/images/tshirt_hanger.jpg',
      status: 'Draft',
      date: DateTime.now().subtract(Duration(days: 1)),
      hasAlert: true,
      size: 'M',
    ),
    InventoryItem(
      id: '3',
      name: "Nike Air Max 90",
      category: "Shoes / 27.5cm",
      brand: "Nike",
      imageUrl: 'assets/images/sneakers.jpg',
      status: 'Sold',
      date: DateTime(2023, 10, 24),
      size: '27.5',
    ),
  ];

  // 🔄 Hive初期化
  Future<void> initialize() async {
    _box = await Hive.openBox<InventoryItem>(_boxName);
    _loadItemsFromBox();
  }
  
  // 📦 Hiveから商品データを読み込み
  void _loadItemsFromBox() {
    if (_box != null && _box!.isNotEmpty) {
      _items = _box!.values.toList();
    }
    notifyListeners();
  }
  
  List<InventoryItem> get items => _items;
  
  int get readyCount => _items.where((i) => i.status == 'Ready').length;
  int get draftCount => _items.where((i) => i.status == 'Draft').length;

  // 💾 商品を追加してHiveに保存
  Future<void> addItem(InventoryItem item) async {
    _items.insert(0, item);
    if (_box != null) {
      await _box!.put(item.sku ?? item.id, item); // SKUまたはIDをキーとして保存
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
