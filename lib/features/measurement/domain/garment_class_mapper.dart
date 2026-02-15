/// カテゴリ選択値をReplicate APIの garment_class パラメータに変換
/// 
/// Flutterアプリで選択されたカテゴリ（日本語）を、
/// Replicate API（donkodon/garment-iq-saisun）が要求する
/// 英語の衣類タイプに変換します。
class GarmentClassMapper {
  /// Flutterアプリのカテゴリ選択値をReplicate APIの garment_class パラメータに変換
  /// 
  /// **入力例:** "Tシャツ", "長袖シャツ", "ジャケット", "パンツ", "スカート"
  /// 
  /// **出力例:**
  /// - "short sleeve top" (半袖トップス)
  /// - "long sleeve top" (長袖トップス)
  /// - "jacket" (ジャケット・アウター)
  /// - "pants" (パンツ)
  /// - "skirt" (スカート)
  /// 
  /// **パラメータ:**
  /// - `category`: Flutterアプリで選択されたカテゴリ（nullまたは空文字の場合はデフォルト値）
  /// 
  /// **戻り値:** Replicate APIの garment_class パラメータ（英語）
  static String categoryToGarmentClass(String? category) {
    // nullまたは空文字の場合はデフォルト値
    if (category == null || category.isEmpty) {
      return 'long sleeve top';
    }
    
    final categoryLower = category.toLowerCase();
    
    // ========================================
    // トップス系（半袖）
    // ========================================
    if (categoryLower.contains('tシャツ') || 
        categoryLower.contains('半袖') ||
        categoryLower.contains('タンクトップ') ||
        categoryLower.contains('キャミソール') ||
        categoryLower.contains('ノースリーブ')) {
      return 'short sleeve top';
    }
    
    // ========================================
    // トップス系（長袖）
    // ========================================
    if (categoryLower.contains('長袖') || 
        categoryLower.contains('ロンt') ||
        categoryLower.contains('ロングスリーブ') ||
        categoryLower.contains('カットソー') ||
        categoryLower.contains('シャツ') ||
        categoryLower.contains('ブラウス') ||
        categoryLower.contains('セーター') ||
        categoryLower.contains('ニット') ||
        categoryLower.contains('パーカー') ||
        categoryLower.contains('スウェット')) {
      return 'long sleeve top';
    }
    
    // ========================================
    // アウター系
    // ========================================
    if (categoryLower.contains('ジャケット') ||
        categoryLower.contains('コート') ||
        categoryLower.contains('ブルゾン') ||
        categoryLower.contains('ダウン') ||
        categoryLower.contains('アウター') ||
        categoryLower.contains('カーディガン')) {
      return 'jacket';
    }
    
    // ========================================
    // ボトムス系（パンツ）
    // ========================================
    if (categoryLower.contains('パンツ') ||
        categoryLower.contains('ジーンズ') ||
        categoryLower.contains('デニム') ||
        categoryLower.contains('チノパン') ||
        categoryLower.contains('スラックス') ||
        categoryLower.contains('ショートパンツ') ||
        categoryLower.contains('レギンス')) {
      return 'pants';
    }
    
    // ========================================
    // ボトムス系（スカート）
    // ========================================
    if (categoryLower.contains('スカート')) {
      return 'skirt';
    }
    
    // ========================================
    // ワンピース系
    // ========================================
    if (categoryLower.contains('ワンピース') ||
        categoryLower.contains('ドレス')) {
      return 'long sleeve top';  // ワンピースは長袖トップスとして扱う
    }
    
    // ========================================
    // デフォルト値
    // ========================================
    // 上記のどれにも該当しない場合は長袖トップスをデフォルトとする
    return 'long sleeve top';
  }
  
  /// サポートされている衣類タイプの一覧
  static const List<String> supportedGarmentClasses = [
    'short sleeve top',
    'long sleeve top',
    'jacket',
    'pants',
    'skirt',
  ];
  
  /// 衣類タイプの日本語表示名を取得
  static String getDisplayName(String garmentClass) {
    switch (garmentClass) {
      case 'short sleeve top':
        return '半袖トップス';
      case 'long sleeve top':
        return '長袖トップス';
      case 'jacket':
        return 'ジャケット・アウター';
      case 'pants':
        return 'パンツ';
      case 'skirt':
        return 'スカート';
      default:
        return garmentClass;
    }
  }
}
