import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class CloudinaryUploadResult {
  CloudinaryUploadResult({
    required this.secureUrl,
    required this.publicId,
    required this.bytes,
    required this.width,
    required this.height,
    required this.format,
  });

  final String secureUrl;
  final String publicId;
  final int bytes;
  final int? width;
  final int? height;
  final String? format;
}

/// Minimal Cloudinary unsigned uploader.
///
/// Uses: POST https://api.cloudinary.com/v1_1/{cloudName}/{resourceType}/upload
/// Fields: upload_preset, file
class CloudinaryUploader {
  CloudinaryUploader({
    required this.cloudName,
    required this.unsignedUploadPreset,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String cloudName;
  final String unsignedUploadPreset;
  final http.Client _client;

  Uri _uploadUri(String resourceType) => 
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload');

  Future<CloudinaryUploadResult> uploadImageBytes({
    required Uint8List bytes,
    required String filename,
    String? folder,
  }) async {
    return _uploadBytes(
      bytes: bytes,
      filename: filename,
      folder: folder,
      resourceType: 'image',
    );
  }

  /// Uploads audio/video bytes to Cloudinary.
  /// 
  /// Use resourceType 'video' for audio files (Cloudinary treats audio as video).
  Future<CloudinaryUploadResult> uploadAudioBytes({
    required Uint8List bytes,
    required String filename,
    String? folder,
  }) async {
    return _uploadBytes(
      bytes: bytes,
      filename: filename,
      folder: folder,
      resourceType: 'video', // Cloudinary uses 'video' for audio files
    );
  }

  Future<CloudinaryUploadResult> _uploadBytes({
    required Uint8List bytes,
    required String filename,
    required String resourceType,
    String? folder,
  }) async {
    final req = http.MultipartRequest('POST', _uploadUri(resourceType));
    req.fields['upload_preset'] = unsignedUploadPreset;
    if (folder != null && folder.trim().isNotEmpty) {
      req.fields['folder'] = folder.trim();
    }

    req.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
      ),
    );

    final streamed = await _client.send(req);
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('Cloudinary upload failed (${resp.statusCode}): ${resp.body}');
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Unexpected Cloudinary response: ${resp.body}');
    }

    final secureUrl = decoded['secure_url'] as String?;
    final publicId = decoded['public_id'] as String?;
    if (secureUrl == null || publicId == null) {
      throw StateError('Unexpected Cloudinary response (missing secure_url/public_id): ${resp.body}');
    }

    return CloudinaryUploadResult(
      secureUrl: secureUrl,
      publicId: publicId,
      bytes: (decoded['bytes'] as num?)?.toInt() ?? bytes.length,
      width: (decoded['width'] as num?)?.toInt(),
      height: (decoded['height'] as num?)?.toInt(),
      format: decoded['format'] as String?,
    );
  }
}
