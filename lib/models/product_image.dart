
/// 📸 商品画像モデル（統一データ構造）
/// 
/// すべての画像データを一元管理するためのモデル。
/// - URL、ローカルパス、メタデータを含む
/// - 状態管理（アップロード状態、削除状態）
/// - 並び順・メイン画像の管理
class ProductImage {
  /// 一意なID（UUID推奨）
  final String id;
  
  /// CloudflareのURL（公開URL）
  final String url;
  
  /// モバイルのローカルパス（オプション）
  final String? localPath;
  
  /// ファイル名（例: 1025L280001_1.jpg）
  final String fileName;
  
  /// 並び順（1, 2, 3...）
  final int sequence;
  
  /// メイン画像フラグ
  final bool isMain;
  
  /// 撮影日時
  final DateTime capturedAt;
  
  /// 画像ソース（カメラ or ギャラリー）
  final ImageSource source;
  
  /// アップロード状態
  final UploadStatus uploadStatus;
  
  /// 削除フラグ
  final bool isDeleted;
  
  /// 削除日時（オプション）
  final DateTime? deletedAt;
  
  /// 画像説明（将来用・オプション）
  final String? description;

  ProductImage({
    required this.id,
    required this.url,
    this.localPath,
    required this.fileName,
    required this.sequence,
    this.isMain = false,
    required this.capturedAt,
    required this.source,
    this.uploadStatus = UploadStatus.uploaded,
    this.isDeleted = false,
    this.deletedAt,
    this.description,
  });

  /// 🔧 連番をファイル名から抽出
  int get sequenceFromFileName {
    final match = RegExp(r'_(\d+)\.jpg').firstMatch(fileName);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '0') ?? 0;
    }
    return sequence; // フォールバック
  }

  /// 🔧 SKUをファイル名から抽出
  String get skuFromFileName {
    // ファイル名形式: {SKU}_{連番}.jpg
    final parts = fileName.split('_');
    if (parts.isNotEmpty) {
      return parts[0];
    }
    return '';
  }

  /// 🔧 キャッシュされているか確認（ImageCacheService連携）
  bool get isCached {
    // 注: ImageCacheServiceへの依存を避けるため、
    // 実際のチェックはウィジェット側で行う
    return false;
  }

  /// 🔧 有効な画像データか検証
  bool get isValid {
    return url.isNotEmpty && 
           fileName.isNotEmpty && 
           sequence > 0 &&
           !isDeleted;
  }

  /// 📋 コピー（不変オブジェクトのため）
  ProductImage copyWith({
    String? id,
    String? url,
    String? localPath,
    String? fileName,
    int? sequence,
    bool? isMain,
    DateTime? capturedAt,
    ImageSource? source,
    UploadStatus? uploadStatus,
    bool? isDeleted,
    DateTime? deletedAt,
    String? description,
  }) {
    return ProductImage(
      id: id ?? this.id,
      url: url ?? this.url,
      localPath: localPath ?? this.localPath,
      fileName: fileName ?? this.fileName,
      sequence: sequence ?? this.sequence,
      isMain: isMain ?? this.isMain,
      capturedAt: capturedAt ?? this.capturedAt,
      source: source ?? this.source,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      description: description ?? this.description,
    );
  }

  /// 📤 JSON変換（Hive/D1保存用）
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'localPath': localPath,
      'fileName': fileName,
      'sequence': sequence,
      'isMain': isMain,
      'capturedAt': capturedAt.toIso8601String(),
      'source': source.toString(),
      'uploadStatus': uploadStatus.toString(),
      'isDeleted': isDeleted,
      'deletedAt': deletedAt?.toIso8601String(),
      'description': description,
    };
  }

  /// 📥 JSON復元
  factory ProductImage.fromJson(Map<String, dynamic> json) {
    return ProductImage(
      id: json['id'] as String,
      url: json['url'] as String,
      localPath: json['localPath'] as String?,
      fileName: json['fileName'] as String,
      sequence: json['sequence'] as int,
      isMain: json['isMain'] as bool? ?? false,
      capturedAt: DateTime.parse(json['capturedAt'] as String),
      source: _parseImageSource(json['source'] as String?),
      uploadStatus: _parseUploadStatus(json['uploadStatus'] as String?),
      isDeleted: json['isDeleted'] as bool? ?? false,
      deletedAt: json['deletedAt'] != null 
          ? DateTime.parse(json['deletedAt'] as String) 
          : null,
      description: json['description'] as String?,
    );
  }

  /// 🔄 ImageSourceをパース
  static ImageSource _parseImageSource(String? sourceString) {
    if (sourceString == null) return ImageSource.camera;
    
    for (var source in ImageSource.values) {
      if (source.toString() == sourceString) {
        return source;
      }
    }
    return ImageSource.camera;
  }

  /// 🔄 UploadStatusをパース
  static UploadStatus _parseUploadStatus(String? statusString) {
    if (statusString == null) return UploadStatus.uploaded;
    
    for (var status in UploadStatus.values) {
      if (status.toString() == statusString) {
        return status;
      }
    }
    return UploadStatus.uploaded;
  }

  @override
  String toString() {
    return 'ProductImage(id: $id, fileName: $fileName, sequence: $sequence, '
           'isMain: $isMain, uploadStatus: $uploadStatus, isDeleted: $isDeleted)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductImage && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// 📸 画像ソース（撮影元）
enum ImageSource {
  camera,   // カメラで撮影
  gallery,  // ギャラリーから選択
}

/// 📤 アップロード状態
enum UploadStatus {
  pending,    // アップロード待ち
  uploading,  // アップロード中
  uploaded,   // アップロード完了
  failed,     // アップロード失敗
}

/// 🔧 ImageSource拡張
extension ImageSourceExtension on ImageSource {
  String get displayName {
    switch (this) {
      case ImageSource.camera:
        return 'カメラ撮影';
      case ImageSource.gallery:
        return 'ギャラリー選択';
    }
  }
}

/// 🔧 UploadStatus拡張
extension UploadStatusExtension on UploadStatus {
  String get displayName {
    switch (this) {
      case UploadStatus.pending:
        return 'アップロード待ち';
      case UploadStatus.uploading:
        return 'アップロード中';
      case UploadStatus.uploaded:
        return 'アップロード完了';
      case UploadStatus.failed:
        return 'アップロード失敗';
    }
  }

  bool get isCompleted => this == UploadStatus.uploaded;
  bool get isProcessing => this == UploadStatus.uploading || this == UploadStatus.pending;
  bool get hasError => this == UploadStatus.failed;
}
