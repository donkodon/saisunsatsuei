/// OCR解析結果モデル
/// 
/// タグ画像から抽出された商品情報
class OcrResult {
  final String? brand;           // ブランド名
  final String? material;        // 素材（例: 綿100%）
  final String? country;         // 原産国
  final String? size;            // サイズ
  final double confidence;       // 信頼度 (0.0 - 1.0)
  final String? rawText;         // OCR生テキスト（デバッグ用）
  
  OcrResult({
    this.brand,
    this.material,
    this.country,
    this.size,
    required this.confidence,
    this.rawText,
  });
  
  factory OcrResult.fromJson(Map<String, dynamic> json) {
    return OcrResult(
      brand: json['brand'] as String?,
      material: json['material'] as String?,
      country: json['country'] as String?,
      size: json['size'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      rawText: json['raw_text'] as String?,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'brand': brand,
      'material': material,
      'country': country,
      'size': size,
      'confidence': confidence,
      'raw_text': rawText,
    };
  }
  
  /// 有効なデータが含まれているか
  bool get hasValidData {
    return brand != null || material != null || country != null || size != null;
  }
  
  /// デバッグ用の文字列表現
  @override
  String toString() {
    return 'OcrResult(brand: $brand, material: $material, country: $country, size: $size, confidence: $confidence)';
  }
}
