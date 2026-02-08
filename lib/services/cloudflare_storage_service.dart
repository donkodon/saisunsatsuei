import 'dart:io';
import 'dart:convert';
import 'dart:typed_data'; // Uint8List用
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:measure_master/config/cloudflare_config.dart';

/// 📦 Cloudflare R2 ストレージサービス
/// 無料で画像を保存・共有できる（10GB/月の無料枠）
class CloudflareStorageService {
  // ✅ 設定を外部ファイルから読み込み（セキュリティ向上）
  static String get accountId => CloudflareConfig.accountId;
  static String get bucketName => CloudflareConfig.bucketName;
  static String get apiToken => CloudflareConfig.apiToken;
  static String get publicDomain => CloudflareConfig.publicDomain;
  
  /// 📸 画像をCloudflare R2にアップロード
  /// 
  /// [imageFile] - アップロードする画像ファイル
  /// [itemId] - 商品ID（一意な識別子）
  /// 
  /// Returns: 画像の公開URL
  static Future<String> uploadImage(File imageFile, String itemId) async {
    try {
      // ファイル名を生成
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${itemId}_$timestamp.jpg';
      
      // 画像データを読み込み
      final imageBytes = await imageFile.readAsBytes();
      
      // R2 API エンドポイント
      final url = Uri.parse(
        'https://api.cloudflare.com/client/v4/accounts/$accountId/r2/buckets/$bucketName/objects/$fileName'
      );
      
      // アップロード
      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $apiToken',
          'Content-Type': 'image/jpeg',
        },
        body: imageBytes,
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        // 成功: 公開URLを返す
        final imageUrl = 'https://$publicDomain/$fileName';
        debugPrint('✅ Cloudflare R2にアップロード成功: $imageUrl');
        return imageUrl;
      } else {
        debugPrint('❌ アップロード失敗: ${response.statusCode} ${response.body}');
        throw Exception('アップロードに失敗しました: ${response.statusCode}');
      }
      
    } catch (e) {
      debugPrint('❌ Cloudflare R2アップロードエラー: $e');
      rethrow;
    }
  }
  
  /// 🗑️ 画像を削除
  static Future<void> deleteImage(String fileName) async {
    try {
      final url = Uri.parse(
        'https://api.cloudflare.com/client/v4/accounts/$accountId/r2/buckets/$bucketName/objects/$fileName'
      );
      
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $apiToken',
        },
      );
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        debugPrint('✅ 画像を削除しました: $fileName');
      } else {
        debugPrint('❌ 削除失敗: ${response.statusCode}');
      }
      
    } catch (e) {
      debugPrint('❌ 画像削除エラー: $e');
    }
  }
  
  /// 🔍 設定が正しいか確認
  static bool isConfigured() {
    return CloudflareConfig.isConfigured;
  }
}

/// 📦 簡易版: Cloudflare Workers経由でアップロード
/// Workers経由なら、APIトークンを公開せずに安全にアップロード可能
/// 
/// 🔧 v2.0 改善点:
/// - ユニークファイル名生成（タイムスタンプ付き）
/// - ファイル名衝突を完全に防止
/// - 再アップロード時の上書き問題を解決
class CloudflareWorkersStorageService {
  // Workers APIエンドポイント（スクリーンショットの設定から）
  static const String workerBaseUrl = 'https://image-upload-api.jinkedon2.workers.dev';
  static const String uploadEndpoint = '$workerBaseUrl/upload';  // ✅ /upload パスを追加
  static const String checkEndpoint = '$workerBaseUrl/check';    // 🔍 ファイル存在チェック用
  
  // 🏢 Phase 1: 固定company_id（Phase 2で動的に変更）
  static const String TEST_COMPANY_ID = "test_company";
  
  // ============================================
  // 🔧 ユニークファイル名生成
  // ============================================
  
  /// 🎯 Phase 1: UUID形式かどうかを判定
  /// [fileId] - ファイルID（例: "1025L280001_a3f2e4b8-9c1d-4e2a-b5c6-7d8e9f0a1b2c"）
  /// Returns: true = UUID形式, false = 旧形式
  static bool _isUuidFormat(String fileId) {
    // UUID形式のパターン: ${sku}_${uuid} or ${uuid}
    // UUID部分: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    final uuidPattern = RegExp(
      r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
      caseSensitive: false,
    );
    
    // fileIdにUUID部分が含まれているかチェック
    final hasUuid = uuidPattern.hasMatch(fileId);
    
    if (hasUuid) {
      debugPrint('🆔 UUID形式を検出: $fileId');
    } else {
      debugPrint('🔢 旧形式を検出: $fileId');
    }
    
    return hasUuid;
  }
  
  /// ✅ ユニークなファイル名を生成（タイムスタンプ付き）
  /// [sku] - SKUコード
  /// [sequence] - 連番
  /// Returns: ユニークなファイル名（拡張子なし）
  /// 例: "ABC123_1_1704067200000"
  static String _generateTimestampBasedFileId(String sku, int sequence) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final uniqueId = '${sku}_${sequence}_$timestamp';
    debugPrint('🔑 ユニークファイルID生成（タイムスタンプ形式）: $uniqueId');
    return uniqueId;
  }
  
  /// ファイル名からSKUを抽出
  /// [fileName] - ファイル名（例: "ABC123_1_1704067200000.jpg"）
  /// Returns: SKUコード
  static String? extractSkuFromFileName(String fileName) {
    // .jpg を除去
    final nameWithoutExt = fileName.replaceAll('.jpg', '').replaceAll('.jpeg', '').replaceAll('.png', '');
    final parts = nameWithoutExt.split('_');
    if (parts.isNotEmpty) {
      return parts.first;
    }
    return null;
  }
  
  /// ファイル名から連番を抽出
  /// [fileName] - ファイル名（例: "ABC123_1_1704067200000.jpg"）
  /// Returns: 連番
  static int? extractSequenceFromFileName(String fileName) {
    final nameWithoutExt = fileName.replaceAll('.jpg', '').replaceAll('.jpeg', '').replaceAll('.png', '');
    final parts = nameWithoutExt.split('_');
    if (parts.length >= 2) {
      return int.tryParse(parts[1]);
    }
    return null;
  }
  
  /// 🔍 ファイルが既に存在するかチェック
  /// [fileName] - チェックするファイル名（例: "SKU_1.jpg"）
  /// Returns: true = 存在する, false = 存在しない
  static Future<bool> checkFileExists(String fileName) async {
    try {
      final checkUrl = Uri.parse('$checkEndpoint?filename=$fileName');
      
      final response = await http.get(checkUrl).timeout(
        Duration(seconds: 10),
        onTimeout: () => http.Response('timeout', 408),
      );
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return jsonResponse['exists'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('⚠️ ファイル存在チェックエラー: $e');
      return false;  // エラー時は存在しないと見なす
    }
  }
  
  /// 🔢 SKUに対して使用可能な次の連番を取得
  /// [sku] - SKUコード
  /// [startFrom] - 検索開始の連番（デフォルト: 1）
  /// Returns: 使用可能な連番
  static Future<int> getNextAvailableCounter(String sku, {int startFrom = 1}) async {
    int counter = startFrom;
    const maxAttempts = 100;  // 無限ループ防止
    
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final fileName = '${sku}_$counter.jpg';
      final exists = await checkFileExists(fileName);
      
      if (!exists) {
        debugPrint('✅ 使用可能な連番: $counter (ファイル名: $fileName)');
        return counter;
      }
      
      debugPrint('⚠️ 連番 $counter は既に使用中、次をチェック...');
      counter++;
    }
    
    // 最大試行回数を超えた場合はタイムスタンプベースに
    debugPrint('⚠️ 連番が見つからないため、タイムスタンプを使用');
    return DateTime.now().millisecondsSinceEpoch;
  }
  
  /// 🗑️ Workers経由で画像を削除（詳細結果付き）
  /// [imageUrl] - 削除する画像のURL
  /// Returns: (success: bool, reason: String?, statusCode: int?)
  /// 🗑️ Workers経由で画像と関連ファイルを削除（4ファイル対応）
  /// 
  /// 削除対象:
  /// - {SKU}/{baseFileName}.jpg          (元画像)
  /// - {SKU}/{baseFileName}_p.png        (白抜き画像)
  /// - {SKU}/{baseFileName}_f.png        (編集済み画像)
  /// - {SKU}/{baseFileName}_settings.json (編集設定)
  /// 
  /// 戻り値:
  /// - success: 最低1ファイル削除成功でtrue
  /// - totalDeleted: 削除成功ファイル数
  /// - totalNotFound: 存在しなかったファイル数
  /// - deletedFiles: 削除成功したファイル名リスト
  /// - statusCode: 200（成功）または最後のエラーコード
  static Future<Map<String, dynamic>> deleteImageWithDetails(String imageUrl) async {
    try {
      // URLからファイル名を抽出
      final uri = Uri.tryParse(imageUrl);
      if (uri == null || uri.pathSegments.isEmpty) {
        debugPrint('⚠️ 無効なURL: $imageUrl');
        return {
          'success': false,
          'reason': '無効なURL形式',
          'statusCode': null,
          'totalDeleted': 0,
          'totalNotFound': 0,
          'deletedFiles': [],
        };
      }
      
      // URLからcompany_id、SKU、ファイル名を抽出
      // 例: "https://.../test_company/1025L280001/1025L280001_uuid.jpg"
      //  → companyId="test_company", sku="1025L280001", fileName="1025L280001_uuid.jpg"
      String companyId = '';
      String sku = '';
      String fileName;
      
      if (uri.pathSegments.length >= 3) {
        // 新形式: company_id/sku/filename
        companyId = uri.pathSegments[uri.pathSegments.length - 3];
        sku = uri.pathSegments[uri.pathSegments.length - 2];
        fileName = uri.pathSegments.last;
        debugPrint('🔍 新形式URL検出: company_id=$companyId, sku=$sku, fileName=$fileName');
      } else if (uri.pathSegments.length >= 2) {
        // 旧形式: sku/filename（後方互換性）
        sku = uri.pathSegments[uri.pathSegments.length - 2];
        fileName = uri.pathSegments.last;
        debugPrint('🔍 旧形式URL検出: sku=$sku, fileName=$fileName');
      } else {
        // フォルダなしの場合（後方互換性）
        fileName = uri.pathSegments.last;
        debugPrint('🔍 フォルダなしURL検出: fileName=$fileName');
      }
      
      // ファイル名から拡張子を除去してbaseFileNameを取得
      // 例: "1025L280001_uuid.jpg" → "1025L280001_uuid"
      final baseFileName = fileName.replaceAll(RegExp(r'\.(jpg|jpeg|png)$', caseSensitive: false), '');
      
      // 削除対象の5ファイルを定義
      final filesToDelete = [
        '$baseFileName.jpg',           // 元画像
        '${baseFileName}_p.png',       // 白抜き画像
        '${baseFileName}_mask.png',    // マスク画像（白抜き処理時に生成）
        '${baseFileName}_f.png',       // 編集済み画像
        '${baseFileName}_settings.json', // 編集設定
      ];
      
      debugPrint('🗑️ 完全削除開始: $baseFileName');
      debugPrint('🏢 Company ID: $companyId');
      debugPrint('📁 SKU: $sku');
      debugPrint('📋 削除対象: ${filesToDelete.length}ファイル（元画像 + 白抜き + mask + 編集済み + 設定）');
      
      int totalDeleted = 0;
      int totalNotFound = 0;
      List<String> deletedFiles = [];
      List<Map<String, dynamic>> deleteResults = [];
      
      // 各ファイルを順次削除
      for (final fileToDelete in filesToDelete) {
        // 🏢 company_id/sku/filename の完全なパスを構築
        String filePath;
        if (companyId.isNotEmpty && sku.isNotEmpty) {
          filePath = '$companyId/$sku/$fileToDelete';  // ✅ 新形式
        } else if (sku.isNotEmpty) {
          filePath = '$sku/$fileToDelete';  // 旧形式（後方互換性）
        } else {
          filePath = fileToDelete;  // フォルダなし
        }
        
        final deleteUrl = Uri.parse('$workerBaseUrl/delete?filename=$filePath');
        debugPrint('  🗑️ 削除URL: $deleteUrl');
        
        try {
          debugPrint('  🔄 削除試行: $fileToDelete');
          
          final response = await http.delete(deleteUrl).timeout(
            Duration(seconds: 10),
            onTimeout: () => http.Response('{"error":"タイムアウト"}', 408),
          );
          
          if (response.statusCode == 200 || response.statusCode == 204) {
            totalDeleted++;
            deletedFiles.add(fileToDelete);
            debugPrint('    ✅ 削除成功: $fileToDelete');
            deleteResults.add({
              'file': fileToDelete,
              'status': 'deleted',
              'statusCode': response.statusCode,
            });
          } else if (response.statusCode == 404) {
            totalNotFound++;
            debugPrint('    ⚠️ ファイル未検出（スキップ）: $fileToDelete');
            deleteResults.add({
              'file': fileToDelete,
              'status': 'not_found',
              'statusCode': 404,
            });
          } else {
            debugPrint('    ❌ 削除失敗（${response.statusCode}）: $fileToDelete');
            deleteResults.add({
              'file': fileToDelete,
              'status': 'failed',
              'statusCode': response.statusCode,
              'reason': response.body,
            });
          }
        } catch (e) {
          debugPrint('    ❌ 削除エラー: $fileToDelete - $e');
          deleteResults.add({
            'file': fileToDelete,
            'status': 'error',
            'reason': e.toString(),
          });
        }
      }
      
      debugPrint('🎯 完全削除完了: 削除=$totalDeleted, 未検出=$totalNotFound, 失敗=${filesToDelete.length - totalDeleted - totalNotFound}');
      debugPrint('   削除成功: ${deletedFiles.join(", ")}');
      
      // 🔑 重要: 元の画像ファイル（.jpg）が削除されたかチェック
      final originalFileName = '$baseFileName.jpg';
      final originalFileDeleted = deletedFiles.contains(originalFileName);
      
      // 元画像が削除されていれば success: true
      final success = originalFileDeleted;
      
      if (!success) {
        debugPrint('⚠️ 元画像（$originalFileName）の削除に失敗');
      }
      
      return {
        'success': success,
        'totalDeleted': totalDeleted,
        'totalNotFound': totalNotFound,
        'deletedFiles': deletedFiles,
        'deleteResults': deleteResults,
        'originalFileDeleted': originalFileDeleted,  // 元画像削除フラグ
        'statusCode': success ? 200 : 404,
        'reason': success ? null : '元画像ファイルの削除に失敗しました',
      };
      
    } catch (e) {
      debugPrint('❌ Cloudflare画像削除エラー: $e');
      return {
        'success': false,
        'reason': '例外エラー: $e',
        'statusCode': null,
        'totalDeleted': 0,
        'totalNotFound': 0,
        'deletedFiles': [],
      };
    }
  }

  /// 🗑️ Workers経由で画像を削除（後方互換用）
  /// [imageUrl] - 削除する画像のURL
  /// Returns: true = 削除成功, false = 削除失敗
  static Future<bool> deleteImage(String imageUrl) async {
    final result = await deleteImageWithDetails(imageUrl);
    return result['success'] as bool;
  }

  /// 📸 Workers経由で画像をアップロード（企業ID + SKUフォルダ対応）
  /// [imageBytes] - 画像のバイトデータ
  /// [itemId] - ファイル名（SKU_連番形式: 例 "1025L190003_1"）
  /// [sku] - SKUコード（フォルダ名として使用: 例 "1025L190003"）
  /// [companyId] - 企業ID（省略時はTEST_COMPANY_ID）
  /// [useUniqueFileName] - ユニークファイル名を使用するか（デフォルト: true）
  static Future<String> uploadImage(
    Uint8List imageBytes, 
    String itemId, 
    {String? sku, String? companyId, bool useUniqueFileName = true}
  ) async {
    try {
      // 🏢 企業IDを取得（Phase 1: 固定値）
      final effectiveCompanyId = companyId ?? TEST_COMPANY_ID;
      
      // 🆕 SKU情報を取得（itemIdから抽出 or 引数から取得）
      String skuFolder = sku ?? itemId.split('_')[0];
      
      // 🎯 Phase 1: UUID形式の場合はそのまま使用、旧形式のみタイムスタンプ付与
      String fileName;
      if (_isUuidFormat(itemId)) {
        // ✅ UUID形式: そのまま使用（Phase 1対応）
        fileName = '$itemId.jpg';
        debugPrint('🆔 UUID形式のファイル名を使用: $fileName');
      } else if (useUniqueFileName) {
        // 🔢 旧形式: タイムスタンプを付与（後方互換性）
        final parts = itemId.split('_');
        final sequence = parts.length >= 2 ? (int.tryParse(parts[1]) ?? 1) : 1;
        final uniqueId = _generateTimestampBasedFileId(skuFolder, sequence);
        fileName = '$uniqueId.jpg';
        debugPrint('🔢 タイムスタンプ形式のファイル名を生成: $fileName');
      } else {
        // 従来通りのファイル名（上書きモード）
        fileName = '$itemId.jpg';
      }
      
      debugPrint('📤 Uploading to Cloudflare Workers: $uploadEndpoint');
      debugPrint('🏢 Company ID: $effectiveCompanyId');
      debugPrint('📁 SKU Folder: $skuFolder');
      debugPrint('📦 File name: $fileName');
      debugPrint('📊 File size: ${imageBytes.length} bytes');
      debugPrint('🔑 Unique mode: $useUniqueFileName');
      
      // Multipartリクエストを作成
      final request = http.MultipartRequest('POST', Uri.parse(uploadEndpoint));
      
      // 🏢 企業IDをフォームデータに追加（Phase 1）
      request.fields['company_id'] = effectiveCompanyId;
      
      // 🆕 SKU情報をフォームデータに追加
      request.fields['sku'] = skuFolder;
      request.fields['fileName'] = fileName;
      
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: fileName,
        ),
      );
      
      // タイムアウトを設定（30秒）
      final streamedResponse = await request.send().timeout(
        Duration(seconds: 30),
        onTimeout: () {
          throw Exception('アップロードがタイムアウトしました（30秒）');
        },
      );
      
      final response = await http.Response.fromStream(streamedResponse);
      
      debugPrint('📨 Response status: ${response.statusCode}');
      debugPrint('📨 Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final imageUrl = jsonResponse['url'] as String;
        debugPrint('✅ Workers経由でアップロード成功（$effectiveCompanyId/$skuFolder）: $imageUrl');
        return imageUrl;
      } else {
        throw Exception('アップロードに失敗しました: ${response.statusCode} - ${response.body}');
      }
      
    } catch (e) {
      debugPrint('❌ Workersアップロードエラー: $e');
      rethrow;
    }
  }
  
  /// 🗑️ 複数の画像を一括削除（詳細結果付き）
  /// [imageUrls] - 削除する画像URLのリスト
  /// Returns: DeleteResult（成功/失敗の詳細）
  static Future<Map<String, dynamic>> deleteImagesWithDetails(List<String> imageUrls) async {
    final List<String> successUrls = [];
    final List<Map<String, dynamic>> failureDetails = [];
    
    debugPrint('🗑️ 一括削除開始: ${imageUrls.length}件');
    
    for (final url in imageUrls) {
      final result = await deleteImageWithDetails(url);
      
      if (result['success'] as bool) {
        successUrls.add(url);
      } else {
        failureDetails.add({
          'url': url,
          'reason': result['reason'],
          'statusCode': result['statusCode'],
        });
        debugPrint('   ❌ 削除失敗: $url');
        debugPrint('      理由: ${result['reason']}');
      }
    }
    
    debugPrint('🗑️ 一括削除完了: ${successUrls.length}/${imageUrls.length}件成功');
    if (failureDetails.isNotEmpty) {
      debugPrint('   ⚠️ ${failureDetails.length}件の削除に失敗');
    }
    
    return {
      'total': imageUrls.length,
      'successes': successUrls.length,
      'failures': failureDetails.length,
      'successUrls': successUrls,
      'failureDetails': failureDetails,
    };
  }

  /// 🗑️ 複数の画像を一括削除（後方互換用）
  /// [imageUrls] - 削除する画像URLのリスト
  /// Returns: 成功した削除数
  static Future<int> deleteImages(List<String> imageUrls) async {
    final result = await deleteImagesWithDetails(imageUrls);
    return result['successes'] as int;
  }
}
