class InventoryItem {
  final String id;
  final String name;
  final String brand;
  final String imageUrl;
  final String category;
  final String status; // 'Ready', 'Draft', 'Sold'
  final DateTime date;
  final double? length; // cm
  final double? width; // cm
  final String? size; // e.g. M, L
  final bool hasAlert; // e.g. "Photo missing"
  
  // 🆕 API連携用の追加フィールド
  final String? barcode;      // A列: バーコード
  final String? sku;          // B列: SKU（商品管理ID）
  final String? color;        // G列: カラー
  final String? productRank;  // L列: 商品ランク
  final int? salePrice;       // Y列: 現状売価（販売価格）
  
  // 商品詳細情報
  final String? condition;    // 商品の状態
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
