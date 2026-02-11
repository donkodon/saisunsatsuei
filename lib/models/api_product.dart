class ApiProduct {
  final int id;
  final String sku;
  final String name;
  final String? brand;
  final String? size;
  final String? color;
  final int? priceSale;
  final int? stockQuantity;
  final String? status;
  final DateTime createdAt;
  final String? barcode;      // A列: バーコード
  final String? productRank;  // L列: 商品ランク (S/A/B/C/D/E/N)
  final String? category;     // カテゴリ
  final String? condition;    // 商品の状態
  final String? description;  // 商品の説明
  final String? material;     // 素材
  final List<String>? imageUrls;  // 📸 撮影画像のURL（保存済み商品データ復元用）
  
  // 🆕 product_masterから引き継ぐ追加フィールド
  final String? brandKana;       // ブランドカナ
  final String? categorySub;     // カテゴリサブ
  final int? priceCost;          // 価格_コスト
  final String? season;          // 季節
  final String? releaseDate;     // 発売日
  final String? buyer;           // 買い手
  final String? storeName;       // 店舗名
  final int? priceRef;           // 価格参照
  final int? priceList;          // 価格表
  final String? location;        // 位置

  ApiProduct({
    required this.id,
    required this.sku,
    required this.name,
    this.brand,
    this.size,
    this.color,
    this.priceSale,
    this.stockQuantity,
    this.status,
    required this.createdAt,
    this.barcode,
    this.productRank,
    this.category,
    this.condition,
    this.description,
    this.material,
    this.imageUrls,  // 📸 撮影画像
    // 🆕 追加フィールド
    this.brandKana,
    this.categorySub,
    this.priceCost,
    this.season,
    this.releaseDate,
    this.buyer,
    this.storeName,
    this.priceRef,
    this.priceList,
    this.location,
  });

  factory ApiProduct.fromJson(Map<String, dynamic> json) {
    return ApiProduct(
      id: json['id'] as int,
      sku: json['sku'] as String,
      name: json['name'] as String,
      brand: json['brand'] as String?,
      size: json['size'] as String?,
      color: json['color'] as String?,
      priceSale: json['price_sale'] as int?,
      stockQuantity: json['stock_quantity'] as int?,
      status: json['status'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      barcode: json['barcode'] as String?,           // A列: バーコード
      productRank: json['rank'] as String?,          // L列: 商品ランク (APIフィールド名: "rank")
      category: json['category'] as String?,
      condition: json['condition'] as String?,
      description: json['description'] as String?,
      material: json['material'] as String?,
      imageUrls: (json['image_urls'] as List<dynamic>?)?.cast<String>(),  // 📸 撮影画像
      // 🆕 追加フィールド
      brandKana: json['brand_kana'] as String?,
      categorySub: json['category_sub'] as String?,
      priceCost: json['price_cost'] as int?,
      season: json['season'] as String?,
      releaseDate: json['release_date'] as String?,
      buyer: json['buyer'] as String?,
      storeName: json['store_name'] as String?,
      priceRef: json['price_ref'] as int?,
      priceList: json['price_list'] as int?,
      location: json['location'] as String?
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sku': sku,
      'name': name,
      'brand': brand,
      'size': size,
      'color': color,
      'price_sale': priceSale,
      'stock_quantity': stockQuantity,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'barcode': barcode,
      'product_rank': productRank,
      'category': category,
      'condition': condition,
      'description': description,
      'material': material,
      'image_urls': imageUrls,  // 📸 撮影画像
      // 🆕 追加フィールド
      'brand_kana': brandKana,
      'category_sub': categorySub,
      'price_cost': priceCost,
      'season': season,
      'release_date': releaseDate,
      'buyer': buyer,
      'store_name': storeName,
      'price_ref': priceRef,
      'price_list': priceList,
      'location': location
    };
  }
}

class ApiProductResponse {
  final String source;
  final DateTime timestamp;
  final int count;
  final List<ApiProduct> products;

  ApiProductResponse({
    required this.source,
    required this.timestamp,
    required this.count,
    required this.products,
  });

  factory ApiProductResponse.fromJson(Map<String, dynamic> json) {
    var productsList = json['products'] as List;
    List<ApiProduct> products = productsList
        .map((productJson) => ApiProduct.fromJson(productJson))
        .toList();

    return ApiProductResponse(
      source: json['source'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      count: json['count'] as int,
      products: products,
    );
  }
}
