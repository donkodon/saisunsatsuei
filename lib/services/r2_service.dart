import 'dart:io';
import 'dart:typed_data'; // Uint8List
import 'package:minio/minio.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import '../config/r2_config.dart';

class R2Service {
  late Minio _minio;

  R2Service() {
    _initMinio();
  }

  void _initMinio() {
    _minio = Minio(
      endPoint: '${R2Config.accountId}.r2.cloudflarestorage.com',
      accessKey: R2Config.accessKey,
      secretKey: R2Config.secretKey,
      useSSL: true,
      // Cloudflare R2 doesn't use regions like AWS usually, but 'auto' is common
      region: 'auto', 
    );
  }

  /// Uploads an image file to R2 and returns the URL.
  /// If [publicDomain] is set in config, returns public URL.
  /// Otherwise, returns a presigned URL (valid for 1 hour by default).
  Future<String?> uploadImage(File file) async {
    if (R2Config.accountId == 'YOUR_ACCOUNT_ID') {
      print('⚠️ R2 Credentials not configured.');
      return null;
    }

    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
      
      // Reading file as stream and converting to Stream<Uint8List>
      final stream = file.openRead().map((chunk) => Uint8List.fromList(chunk));
      final length = await file.length();

      await _minio.putObject(
        R2Config.bucketName,
        fileName,
        stream,
        size: length,
        metadata: {
          'content-type': mimeType,
        },
      );

      print('✅ Upload successful: $fileName');

      if (R2Config.publicDomain.isNotEmpty) {
        // Construct public URL
        final domain = R2Config.publicDomain.endsWith('/') 
            ? R2Config.publicDomain.substring(0, R2Config.publicDomain.length - 1)
            : R2Config.publicDomain;
        return '$domain/$fileName';
      } else {
        // Generate presigned URL (valid for 7 days typically for long term, but usually better to have public access for app assets)
        // Here we default to a long expiry if it's meant to be persistent, or just use the presigned getter.
        // For now, let's get a presigned GET URL valid for 7 days (max).
        return await _minio.presignedGetObject(
          R2Config.bucketName,
          fileName,
          expires: 60 * 60 * 24 * 7, // 7 days
        );
      }
    } catch (e) {
      print('❌ R2 Upload failed: $e');
      return null;
    }
  }
}
