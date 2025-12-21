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
      productRank: json['product_rank'] as String?,  // L列: 商品ランク
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
