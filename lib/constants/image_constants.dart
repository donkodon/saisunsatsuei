/// 画像ファイル命名規則とサフィックスの定数
/// 
/// WEBアプリ側の画像処理システムとの互換性を保つための定数定義
class ImageConstants {
  ImageConstants._(); // Private constructor to prevent instantiation
  
  /// 白抜き画像のサフィックス
  /// 
  /// WEBアプリ側で生成される白背景処理済み画像を識別するために使用
  /// 
  /// 命名規則:
  /// - 元画像: `{SKU}_{UUID}.jpg`
  /// - 白抜き画像: `{SKU}_{UUID}_p.png`
  /// 
  /// 例:
  /// ```
  /// 元画像: 1025L280001_42c9af37-a604-4b85-810b-a1057f917f9b.jpg
  /// 白抜き画像: 1025L280001_42c9af37-a604-4b85-810b-a1057f917f9b_p.png
  /// ```
  /// 
  /// 注意:
  /// - サフィックス `_p` は "processed" (処理済み) を意味する
  /// - WEBアプリ側との互換性のため、このサフィックスを維持
  /// - 拡張子は常に `.png` (白抜き処理時にPNGに変換される)
  static const String whiteBackgroundSuffix = '_p.png';
  
  /// 白抜き画像かどうかを判定
  /// 
  /// [fileName] ファイル名またはURL
  /// 
  /// Returns: 白抜き画像の場合 `true`
  /// 
  /// 例:
  /// ```dart
  /// ImageConstants.isWhiteBackgroundImage('test_p.png'); // true
  /// ImageConstants.isWhiteBackgroundImage('test.jpg');   // false
  /// ```
  static bool isWhiteBackgroundImage(String fileName) {
    return fileName.contains(whiteBackgroundSuffix);
  }
  
  /// 元画像URLから白抜き画像URLを生成
  /// 
  /// [originalUrl] 元画像のURL (例: https://.../sku_uuid.jpg)
  /// 
  /// Returns: 白抜き画像のURL (例: https://.../sku_uuid_p.png)
  /// 
  /// 例:
  /// ```dart
  /// final original = 'https://example.com/1025L280001_uuid.jpg';
  /// final white = ImageConstants.generateWhiteBackgroundUrl(original);
  /// // Result: 'https://example.com/1025L280001_uuid_p.png'
  /// ```
  /// 
  /// 注意:
  /// - 元画像の拡張子 (.jpg, .jpeg, .png) に関わらず、
  ///   白抜き画像は常に `_p.png` サフィックスを使用
  static String generateWhiteBackgroundUrl(String originalUrl) {
    // 既に白抜き画像の場合はそのまま返す
    if (isWhiteBackgroundImage(originalUrl)) {
      return originalUrl;
    }
    
    // 拡張子を _p.png に置き換え
    if (originalUrl.endsWith('.jpg')) {
      return originalUrl.substring(0, originalUrl.length - 4) + whiteBackgroundSuffix;
    } else if (originalUrl.endsWith('.jpeg')) {
      return originalUrl.substring(0, originalUrl.length - 5) + whiteBackgroundSuffix;
    } else if (originalUrl.endsWith('.png')) {
      return originalUrl.substring(0, originalUrl.length - 4) + whiteBackgroundSuffix;
    }
    
    // 拡張子がない場合は末尾に追加
    return originalUrl + whiteBackgroundSuffix;
  }
  
  /// 白抜き画像URLから元画像のファイル名を復元
  /// 
  /// [whiteBackgroundUrl] 白抜き画像のURL
  /// 
  /// Returns: 元画像のファイル名 (拡張子 .jpg)
  /// 
  /// 例:
  /// ```dart
  /// final white = 'https://example.com/1025L280001_uuid_p.png';
  /// final original = ImageConstants.restoreOriginalFileName(white);
  /// // Result: '1025L280001_uuid.jpg'
  /// ```
  static String restoreOriginalFileName(String whiteBackgroundUrl) {
    final fileName = whiteBackgroundUrl.split('/').last;
    final cleanFileName = fileName.split('?').first; // クエリパラメータを除去
    return cleanFileName.replaceAll(whiteBackgroundSuffix, '.jpg');
  }
}
