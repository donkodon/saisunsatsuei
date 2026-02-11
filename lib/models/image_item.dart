import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

/// 📸 画像アイテムモデル（UUID管理）
/// 
/// 削除・並び替え・部分更新に対応した画像管理クラス
/// ファイル名にUUIDを使用することで、連番管理の問題を解決
class ImageItem {
  final String id;           // UUID（一意識別子）
  final XFile? file;         // ローカルファイル（新規撮影の場合）
  final Uint8List? bytes;    // 画像バイトデータ（Web環境でのblob URL問題回避）
  final String? url;         // サーバーURL（既存画像の場合）
  final String? whiteUrl;    // 白抜き画像URL（既存画像の場合）
  final int sequence;        // 表示順序（1, 2, 3...）
  final bool isMain;         // メイン画像フラグ
  final DateTime createdAt;  // 作成日時
  
  ImageItem({
    String? id,
    this.file,
    this.bytes,
    this.url,
    this.whiteUrl,
    required this.sequence,
    this.isMain = false,
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();
  
  /// 既存の画像（サーバーから取得）を作成
  factory ImageItem.fromUrl({
    required String id,
    required String url,
    String? whiteUrl,
    required int sequence,
    bool isMain = false,
    DateTime? createdAt,
  }) {
    return ImageItem(
      id: id,
      url: url,
      whiteUrl: whiteUrl,
      sequence: sequence,
      isMain: isMain,
      createdAt: createdAt,
    );
  }
  
  /// 新規撮影の画像を作成
  factory ImageItem.fromFile({
    required XFile file,
    required int sequence,
    bool isMain = false,
  }) {
    return ImageItem(
      file: file,
      sequence: sequence,
      isMain: isMain,
    );
  }
  
  /// 画像バイトデータから作成（Web環境でのblob URL問題回避）
  factory ImageItem.fromBytes({
    required Uint8List bytes,
    required int sequence,
    bool isMain = false,
  }) {
    return ImageItem(
      bytes: bytes,
      sequence: sequence,
      isMain: isMain,
    );
  }
  
  /// 既存画像かどうか（サーバーにアップロード済み）
  bool get isExisting => url != null;
  
  /// 新規画像かどうか（まだアップロードされていない）
  bool get isNew => file != null && url == null;
  
  /// 順序を更新した新しいインスタンスを作成
  ImageItem copyWithSequence(int newSequence, {bool? isMain}) {
    return ImageItem(
      id: id,
      file: file,
      bytes: bytes,
      url: url,
      whiteUrl: whiteUrl,
      sequence: newSequence,
      isMain: isMain ?? this.isMain,
      createdAt: createdAt,
    );
  }
  
  /// URLを設定した新しいインスタンスを作成（アップロード後）
  ImageItem copyWithUrl(String newUrl, {String? newWhiteUrl}) {
    return ImageItem(
      id: id,
      file: file,
      bytes: bytes,
      url: newUrl,
      whiteUrl: newWhiteUrl,
      sequence: sequence,
      isMain: isMain,
      createdAt: createdAt,
    );
  }
  
  /// 🎯 Phase 6: ファイル名からUUIDを抽出
  /// 
  /// ファイル名形式: {SKU}_{UUID}.jpg
  /// 例: 1025L280001_a1b2c3d4-e5f6-7890-abcd-ef1234567890.jpg
  /// 
  /// Returns: UUID文字列、抽出失敗時は新規UUID生成
  static String extractUuidFromUrl(String url) {
    try {
      // URLからファイル名部分を抽出
      final fileName = url.split('/').last;
      
      // クエリパラメータを除去（例: ?t=timestamp）
      final cleanFileName = fileName.split('?').first;
      
      // _white.jpg サフィックスを除去
      final baseFileName = cleanFileName.replaceAll('_white.jpg', '.jpg');
      
      // ファイル名パターン: {SKU}_{UUID}.jpg
      // 正規表現: 最後のアンダースコア以降、拡張子の前まで
      final uuidPattern = RegExp(r'_([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\.', caseSensitive: false);
      final match = uuidPattern.firstMatch(baseFileName);
      
      if (match != null && match.groupCount >= 1) {
        return match.group(1)!;
      }
      
      // UUID抽出失敗時は新規UUID生成（フォールバック）
      return const Uuid().v4();
    } catch (e) {
      // エラー時も新規UUID生成
      return const Uuid().v4();
    }
  }
  
  @override
  String toString() {
    return 'ImageItem(id: $id, sequence: $sequence, isMain: $isMain, isNew: $isNew, isExisting: $isExisting)';
  }
}
