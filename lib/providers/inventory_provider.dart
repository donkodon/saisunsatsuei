import 'package:flutter/material.dart';
import 'package:measure_master/models/item.dart';

class InventoryProvider with ChangeNotifier {
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

  List<InventoryItem> get items => _items;
  
  int get readyCount => _items.where((i) => i.status == 'Ready').length;
  int get draftCount => _items.where((i) => i.status == 'Draft').length;

  void addItem(InventoryItem item) {
    _items.insert(0, item);
    notifyListeners();
  }
}
