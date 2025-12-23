import 'package:hive/hive.dart';

part 'item.g.dart';

@HiveType(typeId: 0)
class InventoryItem {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String name;
  
  @HiveField(2)
  final String brand;
  
  @HiveField(3)
  final String imageUrl;
  
  @HiveField(4)
  final String category;
  
  @HiveField(5)
  final String status; // 'Ready', 'Draft', 'Sold'
  
  @HiveField(6)
  final DateTime date;
  
  @HiveField(7)
  final double? length; // cm
  
  @HiveField(8)
  final double? width; // cm
  
  @HiveField(9)
  final String? size; // e.g. M, L
  
  @HiveField(10)
  final bool hasAlert; // e.g. "Photo missing"
  
  // 🆕 API連携用の追加フィールド
  @HiveField(11)
  final String? barcode;      // A列: バーコード
  
  @HiveField(12)
  final String? sku;          // B列: SKU（商品管理ID）
  
  @HiveField(13)
  final String? color;        // G列: カラー
  
  @HiveField(14)
  final String? productRank;  // L列: 商品ランク
  
  @HiveField(15)
  final int? salePrice;       // Y列: 現状売価（販売価格）
  
  // 商品詳細情報
  @HiveField(16)
  final String? condition;    // 商品の状態
  
  @HiveField(17)
  final String? description;  // 商品の説明

  InventoryItem({
    required this.id,
    required this.name,
    this.brand = '',
    required this.imageUrl,
    this.category = 'Tops',
    this.status = 'Draft',
    required this.date,
    this.length,
    this.width,
    this.size,
    this.hasAlert = false,
    // 新しいフィールド
    this.barcode,
    this.sku,
    this.color,
    this.productRank,
    this.salePrice,
    this.condition,
    this.description,
  });
}
