import 'dart:convert';
import 'dart:typed_data'; // Uint8List用
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// レガシーの CloudflareStorageService（直接R2アクセス・CORS問題あり）は
// services/cloudflare_storage_service_legacy.dart に移動しました。
// 新規コードでは以下の CloudflareWorkersStorageService を使用してください。

/// Workers経由でR2にアクセスするストレージサービス（現行）
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
  
  /// ユニークなファイル名を生成（タイムスタンプ付き）
  /// ⚠️ 非推奨: Phase 1以降はUUID使用を推奨
  /// [sku] - SKUコード
  /// [sequence] - 連番
  /// Returns: ユニークなファイル名（拡張子なし）
  /// 例: "ABC123_1_1704067200000"
  @Deprecated('Use UUID-based file naming instead')
  static String generateUniqueFileId(String sku, int sequence) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final uniqueId = '${sku}_${sequence}_$timestamp';
    debugPrint('🔑 ユニークファイルID生成（旧形式）: $uniqueId');
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
        };
      }
      
      // URLからフルパス（company_id/SKU/filename）を抽出
      // pathSegmentsから正しいパスを構築
      // 例: ["test_company", "1025L280001", "1025L280001_uuid.jpg"] → "test_company/1025L280001/1025L280001_uuid.jpg"
      String filePath;
      if (uri.pathSegments.length >= 3) {
        // ✅ company_id + SKU + fileName（現在の正規形式）
        final companyId = uri.pathSegments[uri.pathSegments.length - 3];
        final sku = uri.pathSegments[uri.pathSegments.length - 2];
        final fileName = uri.pathSegments.last;
        filePath = '$companyId/$sku/$fileName';
        debugPrint('🔧 フルパス（company_id含む）: $filePath');
      } else if (uri.pathSegments.length == 2) {
        // 🔄 SKU + fileName（古い形式：company_idなし）
        filePath = '${uri.pathSegments[0]}/${uri.pathSegments[1]}';
        debugPrint('🔄 SKUフォルダパス（company_idなし）: $filePath');
      } else {
        // 🔄 fileName のみ（最古の形式）
        filePath = uri.pathSegments.last;
        debugPrint('🔄 ファイル名のみ: $filePath');
      }
      
      // ✅ Workers削除エンドポイント（URLエンコーディング対応）
      final encodedFilePath = Uri.encodeComponent(filePath);
      final deleteUrl = Uri.parse('$workerBaseUrl/delete?filename=$encodedFilePath');
      
      debugPrint('🗑️ Cloudflare削除リクエスト: $deleteUrl');
      debugPrint('📁 削除するファイルパス: $filePath');
      debugPrint('🔒 エンコード後パス: $encodedFilePath');
      
      // 🌐 Web版: CORS問題を回避するため、Workers経由で削除
      // Workers側で適切なCORSヘッダーが設定されている必要があります
      http.Response response;
      
      if (kIsWeb) {
        try {
          // Web版: より柔軟なCORS処理
          response = await http.delete(
            deleteUrl,
            headers: {
              'Accept': 'application/json',
            },
          ).timeout(
            Duration(seconds: 15),
            onTimeout: () => http.Response('{"error":"タイムアウト"}', 408),
          );
        } catch (e) {
          debugPrint('⚠️ Web版削除エラー（CORS問題の可能性）: $e');
          // CORS問題の場合、Workers側の設定を確認する必要があります
          debugPrint('💡 対処方法:');
          debugPrint('   1. Workers側で DELETE メソッドのCORSヘッダーを設定');
          debugPrint('   2. Access-Control-Allow-Origin: * を追加');
          debugPrint('   3. Access-Control-Allow-Methods: DELETE を追加');
          
          return {
            'success': false,
            'reason': 'CORS問題: Workers側でDELETEメソッドのCORSヘッダー設定が必要です',
            'statusCode': null,
          };
        }
      } else {
        // Android/iOS: 通常のHTTPリクエスト
        response = await http.delete(
          deleteUrl,
          headers: {
            'Content-Type': 'application/json',
          },
        ).timeout(
          Duration(seconds: 15),
          onTimeout: () => http.Response('{"error":"タイムアウト"}', 408),
        );
      }
      
      debugPrint('📨 削除レスポンス: ${response.statusCode}');
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        debugPrint('✅ 画像削除成功: $filePath');
        return {
          'success': true,
          'reason': null,
          'statusCode': response.statusCode,
        };
      } else if (response.statusCode == 404) {
        debugPrint('⚠️ 画像削除失敗（404: ファイルが存在しないか、削除エンドポイント未実装）: $filePath');
        return {
          'success': false,
          'reason': 'ファイルが存在しないか、削除エンドポイント未実装',
          'statusCode': 404,
        };
      } else {
        debugPrint('⚠️ 画像削除失敗（${response.statusCode}）: $filePath');
        debugPrint('   レスポンス: ${response.body}');
        return {
          'success': false,
          'reason': 'HTTP ${response.statusCode}: ${response.body}',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      debugPrint('❌ Cloudflare画像削除エラー: $e');
      return {
        'success': false,
        'reason': '例外エラー: $e',
        'statusCode': null,
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

  /// 📸 Workers経由で画像をアップロード（SKUフォルダ対応）
  /// [imageBytes] - 画像のバイトデータ
  /// [itemId] - ファイル名（SKU_連番形式: 例 "1025L190003_1"）
  /// [sku] - SKUコード（フォルダ名として使用: 例 "1025L190003"）
  /// [useUniqueFileName] - ユニークファイル名を使用するか（デフォルト: true）
  static Future<String> uploadImage(
    Uint8List imageBytes, 
    String itemId, 
    {String? sku, String? companyId, bool useUniqueFileName = true}
  ) async {
    try {
      // 🆕 SKU情報を取得（itemIdから抽出 or 引数から取得）
      String skuFolder = sku ?? itemId.split('_')[0];
      
      // 🏢 企業ID（未指定の場合は"default"を使用）
      String company = companyId ?? 'default';
      
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
        final uniqueId = generateUniqueFileId(skuFolder, sequence);
        fileName = '$uniqueId.jpg';
        debugPrint('🔢 タイムスタンプ形式のファイル名を生成: $fileName');
      } else {
        // 従来通りのファイル名（上書きモード）
        fileName = '$itemId.jpg';
      }
      
      debugPrint('📤 Cloudflare Workers アップロード開始');
      debugPrint('🏢 Company ID: $company (パラメータ名: company_id)');
      debugPrint('📦 SKU: $skuFolder');
      debugPrint('📄 ファイル名: $fileName');
      debugPrint('📊 ファイルサイズ: ${imageBytes.length} bytes');
      debugPrint('🔑 ユニークモード: $useUniqueFileName');
      
      // Multipartリクエストを作成
      final request = http.MultipartRequest('POST', Uri.parse(uploadEndpoint));
      
      // 🏢 企業ID、SKU情報をフォームデータに追加
      request.fields['company_id'] = company;  // Workers側のパラメータ名に合わせる
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
        
        // 🔍 URLから保存パスを確認（R2フォルダ構造検証）
        final expectedPath = '$company/$skuFolder/$fileName';
        if (imageUrl.contains('$company/$skuFolder/')) {
          debugPrint('✅ アップロード成功 (Company: $company, SKU: $skuFolder)');
          debugPrint('   R2パス: $expectedPath');
          debugPrint('   公開URL: $imageUrl');
        } else {
          debugPrint('⚠️ 企業IDフォルダが作成されていない可能性');
          debugPrint('   期待パス: $expectedPath');
          debugPrint('   実際URL: $imageUrl');
          debugPrint('   → Workers側でcompany_idが正しく受信されているか確認が必要');
        }
        
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
