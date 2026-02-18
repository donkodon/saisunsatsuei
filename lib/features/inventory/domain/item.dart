import 'package:hive/hive.dart';
import 'product_image.dart';

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
  
  @HiveField(18)
  final String? material;     // 素材
  
  @HiveField(19)
  final List<String>? imageUrls;  // 📸 複数画像のURL（旧形式 - 後方互換用）

  @HiveField(20)
  final List<Map<String, dynamic>>? imagesJson;  // 📸 新形式: ProductImageのJSONリスト

  @HiveField(21)
  final String? companyId;  // 🏢 企業ID（マルチテナント対応）

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
    this.material,
    this.imageUrls,  // 📸 複数画像
    this.imagesJson,  // 📸 新形式画像データ
    this.companyId,  // 🏢 企業ID
  });

  /// 🔄 新形式の画像リストを取得（ProductImageオブジェクト）
  List<ProductImage> get images {
    if (imagesJson != null && imagesJson!.isNotEmpty) {
      // 新形式: imagesJsonから復元
      return imagesJson!.map((json) => ProductImage.fromJson(json)).toList();
    } else if (imageUrls != null && imageUrls!.isNotEmpty) {
      // 旧形式: imageUrlsからマイグレーション
      return imageUrls!.asMap().entries.map((entry) {
        final index = entry.key;
        final url = entry.value;
        return ProductImage(
          id: '${sku ?? id}_$index',  // 仮ID
          url: url,
          fileName: url.split('/').last,
          sequence: index + 1,
          capturedAt: date,
          source: ImageSource.camera,
          uploadStatus: UploadStatus.uploaded,
        );
      }).toList();
    }
    return [];
  }

  /// 🔄 任意フィールドを上書きした新しいInventoryItemを返す（immutableパターン）
  InventoryItem copyWith({
    String? id,
    String? name,
    String? brand,
    String? imageUrl,
    String? category,
    String? status,
    DateTime? date,
    double? length,
    double? width,
    String? size,
    bool? hasAlert,
    String? barcode,
    String? sku,
    String? color,
    String? productRank,
    int? salePrice,
    String? condition,
    String? description,
    String? material,
    List<String>? imageUrls,
    List<Map<String, dynamic>>? imagesJson,
    String? companyId,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      status: status ?? this.status,
      date: date ?? this.date,
      length: length ?? this.length,
      width: width ?? this.width,
      size: size ?? this.size,
      hasAlert: hasAlert ?? this.hasAlert,
      barcode: barcode ?? this.barcode,
      sku: sku ?? this.sku,
      color: color ?? this.color,
      productRank: productRank ?? this.productRank,
      salePrice: salePrice ?? this.salePrice,
      condition: condition ?? this.condition,
      description: description ?? this.description,
      material: material ?? this.material,
      imageUrls: imageUrls ?? this.imageUrls,
      imagesJson: imagesJson ?? this.imagesJson,
      companyId: companyId ?? this.companyId,
    );
  }

  /// 🔄 画像データを更新したInventoryItemを作成
  InventoryItem withImages(List<ProductImage> newImages) {
    return InventoryItem(
      id: id,
      name: name,
      brand: brand,
      imageUrl: newImages.isNotEmpty ? newImages.first.url : imageUrl,
      category: category,
      status: status,
      date: date,
      length: length,
      width: width,
      size: size,
      hasAlert: hasAlert,
      barcode: barcode,
      sku: sku,
      color: color,
      productRank: productRank,
      salePrice: salePrice,
      condition: condition,
      description: description,
      material: material,
      imageUrls: newImages.map((img) => img.url).toList(),
      imagesJson: newImages.map((img) => img.toJson()).toList(),
    );
  }
}
