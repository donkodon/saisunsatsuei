import 'package:measure_master/features/inventory/domain/image_item.dart';

/// 🔄 画像並び替えヘルパー
///
/// 責務:
/// - 画像リストの並び替えロジック
/// - sequenceの自動更新
/// - メイン画像の自動設定
class ImageReorderHelper {
  /// ドラッグ&ドロップで画像を並び替え
  ///
  /// [images] 元の画像リスト
  /// [oldIndex] ドラッグ元のインデックス
  /// [newIndex] ドロップ先のインデックス
  ///
  /// Returns: 並び替え後の画像リスト
  static List<ImageItem> reorderImages(
    List<ImageItem> images,
    int oldIndex,
    int newIndex,
  ) {
    // ReorderableListViewの仕様: newIndexがoldIndexより大きい場合は-1する
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    // リストの順番を変更
    final mutableImages = List<ImageItem>.from(images);
    final item = mutableImages.removeAt(oldIndex);
    mutableImages.insert(newIndex, item);

    // 全画像のsequenceを再計算（1から始まる連番）
    return _updateSequences(mutableImages);
  }

  /// 全画像のsequenceを更新
  ///
  /// [images] 画像リスト
  ///
  /// Returns: sequence更新後の画像リスト
  static List<ImageItem> _updateSequences(List<ImageItem> images) {
    return images.asMap().entries.map((entry) {
      final index = entry.key;
      final imageItem = entry.value;
      
      return imageItem.copyWithSequence(
        index + 1,
        isMain: index == 0, // 最初の画像をメインに設定
      );
    }).toList();
  }

  /// 画像を削除してsequenceを更新
  ///
  /// [images] 元の画像リスト
  /// [index] 削除する画像のインデックス
  ///
  /// Returns: 削除後の画像リスト
  static List<ImageItem> removeImageAt(
    List<ImageItem> images,
    int index,
  ) {
    final mutableImages = List<ImageItem>.from(images);
    mutableImages.removeAt(index);
    return _updateSequences(mutableImages);
  }

  /// 画像を追加してsequenceを更新
  ///
  /// [images] 元の画像リスト
  /// [newImages] 追加する画像リスト
  ///
  /// Returns: 追加後の画像リスト
  static List<ImageItem> addImages(
    List<ImageItem> images,
    List<ImageItem> newImages,
  ) {
    final mutableImages = List<ImageItem>.from(images);
    mutableImages.addAll(newImages);
    return _updateSequences(mutableImages);
  }
}
