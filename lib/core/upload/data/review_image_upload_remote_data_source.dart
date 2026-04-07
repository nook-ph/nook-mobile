import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:nook/core/upload/data/review_image_upload_exception.dart';
import 'package:nook/core/upload/domain/entities/uploaded_review_image.dart';

class ReviewImageUploadRemoteDataSource {
  final http.Client httpClient;
  final String apiBaseUrl;
  final String presignPath;
  final String? Function()? authTokenGetter;
  final Future<String?> Function()? authTokenRefresher;
  final String? supabaseApikey;

  ReviewImageUploadRemoteDataSource({
    required this.httpClient,
    required this.apiBaseUrl,
    required this.presignPath,
    this.authTokenGetter,
    this.authTokenRefresher,
    this.supabaseApikey,
  });

  Future<List<UploadedReviewImage>> uploadReviewImages({
    required String cafeId,
    required String userId,
    required List<File> images,
    String? accessToken,
  }) async {
    if (images.isEmpty) {
      return const [];
    }

    final uploaded = <UploadedReviewImage>[];

    for (int index = 0; index < images.length; index++) {
      final file = images[index];
      final fileName = file.path.split(Platform.pathSeparator).last;
      final fileExt = fileName.contains('.') ? fileName.split('.').last : 'jpg';

      final presign = await _requestPresignedUpload(
        cafeId: cafeId,
        userId: userId,
        file: file,
        index: index,
        accessToken: accessToken,
      );

      await _uploadToS3(file: file, uploadUrl: presign.uploadUrl);

      uploaded.add(
        UploadedReviewImage(
          objectKey: presign.objectKey,
          publicUrl: presign.publicUrl,
        ),
      );
    }

    return uploaded;
  }

  Future<_PresignResponse> _requestPresignedUpload({
    required String cafeId,
    required String userId,
    required File file,
    required int index,
    String? accessToken,
  }) async {
    if (apiBaseUrl.trim().isEmpty) {
      throw const ReviewImageUploadException(
        'Missing UPLOAD_API_BASE_URL configuration.',
      );
    }

    final endpoint = _buildEndpoint(apiBaseUrl: apiBaseUrl, path: presignPath);
    final fileName = file.path.split(Platform.pathSeparator).last;
    final fileExt = fileName.contains('.') ? fileName.split('.').last : 'jpg';

    final payload = <String, dynamic>{
      'cafeId': cafeId,
      'userId': userId,
      'fileName': fileName,
      'fileExt': fileExt,
      'slot': index,
      'acl': 'public-read',
      'contentType': _contentTypeFor(fileExt),
    };

    try {
      final headers = await _buildJsonHeaders(accessTokenOverride: accessToken);

      final response = await httpClient
          .post(
            endpoint,
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ReviewImageUploadException(
          'Unable to get upload URL. HTTP ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const ReviewImageUploadException('Invalid upload URL response.');
      }

      final uploadUrl = decoded['uploadUrl']?.toString() ?? '';
      final objectKey = decoded['objectKey']?.toString() ?? '';
      final publicUrl = _normalizePublicUrl(
        decoded['publicUrl']?.toString() ?? '',
      );

      if (uploadUrl.isEmpty || objectKey.isEmpty || publicUrl.isEmpty) {
        throw const ReviewImageUploadException(
          'Upload response is missing required fields.',
        );
      }

      return _PresignResponse(
        uploadUrl: uploadUrl,
        objectKey: objectKey,
        publicUrl: publicUrl,
      );
    } on ReviewImageUploadException {
      rethrow;
    } catch (e, st) {
      throw ReviewImageUploadException(
        'Unable to prepare image upload.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _uploadToS3({
    required File file,
    required String uploadUrl,
  }) async {
    final uri = Uri.parse(uploadUrl);
    final bytes = await file.readAsBytes();
    final fileName = file.path.split(Platform.pathSeparator).last;
    final fileExt = fileName.contains('.') ? fileName.split('.').last : 'jpg';

    try {
      final response = await httpClient
          .put(
            uri,
            headers: <String, String>{
              'Content-Type': _contentTypeFor(fileExt),
              'x-amz-acl': 'public-read',
            },
            body: bytes,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ReviewImageUploadException(
          'Image upload failed. HTTP ${response.statusCode}.',
        );
      }
    } on ReviewImageUploadException {
      rethrow;
    } catch (e, st) {
      throw ReviewImageUploadException(
        'Image upload failed.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  Future<Map<String, String>> _buildJsonHeaders({
    String? accessTokenOverride,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};

    String? authToken = accessTokenOverride;
    authToken ??= authTokenGetter?.call();
    if (authToken == null || authToken.isEmpty) {
      try {
        authToken = await authTokenRefresher?.call();
      } catch (_) {
        // Ignore token refresh errors and proceed with available credentials.
      }
    }

    if (authToken != null && authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }

    return headers;
  }

  Uri _buildEndpoint({required String apiBaseUrl, required String path}) {
    final base = apiBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final normalizedPath = path.trim().replaceAll(RegExp(r'^/+'), '');
    return Uri.parse('$base/$normalizedPath');
  }

  String _contentTypeFor(String fileExt) {
    final ext = fileExt.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }

  String _normalizePublicUrl(String raw) {
    var candidate = raw.trim();
    if (candidate.isEmpty) return '';

    while (true) {
      final lowered = candidate.toLowerCase();
      if (lowered.startsWith('https://https://')) {
        candidate = 'https://${candidate.substring('https://https://'.length)}';
        continue;
      }
      if (lowered.startsWith('http://http://')) {
        candidate = 'http://${candidate.substring('http://http://'.length)}';
        continue;
      }
      if (lowered.startsWith('http://https://')) {
        candidate = 'https://${candidate.substring('http://https://'.length)}';
        continue;
      }
      if (lowered.startsWith('https://http://')) {
        candidate = 'https://${candidate.substring('https://http://'.length)}';
        continue;
      }
      break;
    }

    Uri parsed;
    try {
      parsed = Uri.parse(candidate);
    } catch (_) {
      return candidate;
    }

    if ((parsed.host == 'https' || parsed.host == 'http') &&
        parsed.path.startsWith('//')) {
      candidate = 'https:${parsed.path}';
      try {
        parsed = Uri.parse(candidate);
      } catch (_) {
        return candidate;
      }
    }

    if (parsed.scheme == 'http' &&
        parsed.host.isNotEmpty &&
        parsed.host != 'localhost' &&
        parsed.host != '127.0.0.1') {
      parsed = parsed.replace(scheme: 'https');
    }

    return parsed.toString();
  }
}

class _PresignResponse {
  final String uploadUrl;
  final String objectKey;
  final String publicUrl;

  const _PresignResponse({
    required this.uploadUrl,
    required this.objectKey,
    required this.publicUrl,
  });
}
