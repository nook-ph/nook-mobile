// lib/core/upload/data/upload_remote_data_source.dart

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:nook/core/upload/data/upload_exception.dart.dart';
import 'package:nook/core/upload/domain/entities/uploaded_avatar.dart';
import 'package:nook/core/upload/domain/entities/uploaded_review_image.dart';

class UploadRemoteDataSource {
  final http.Client httpClient;
  final String presignUrl;
  final String? Function()? authTokenGetter;
  final Future<String?> Function()? authTokenRefresher;

  const UploadRemoteDataSource({
    required this.httpClient,
    required this.presignUrl,
    this.authTokenGetter,
    this.authTokenRefresher,
  });

  // ── Review images ──────────────────────────────────────────────────────────

  Future<List<UploadedReviewImage>> uploadReviewImages({
    required String cafeId,
    required String userId,
    required List<File> images,
    String? accessToken,
  }) async {
    if (images.isEmpty) return const [];

    final uploaded = <UploadedReviewImage>[];

    for (int i = 0; i < images.length; i++) {
      final file = images[i];
      final contentType = _contentTypeFor(file);

      final presign = await _requestPresign(
        payload: {
          'uploadType': 'review_image',
          'cafeId': cafeId,
          'slot': i,
          'contentType': contentType,
        },
        accessToken: accessToken,
      );

      await _putToS3(
        file: file,
        uploadUrl: presign.uploadUrl,
        contentType: contentType,
      );

      uploaded.add(
        UploadedReviewImage(
          objectKey: presign.objectKey,
          publicUrl: presign.publicUrl,
          slot: i,
        ),
      );
    }

    return uploaded;
  }

  // ── Avatar ─────────────────────────────────────────────────────────────────

  Future<UploadedAvatar> uploadAvatar({
    required File file,
    String? accessToken,
  }) async {
    final contentType = _contentTypeFor(file);

    final presign = await _requestPresign(
      payload: {'uploadType': 'avatar', 'contentType': contentType},
      accessToken: accessToken,
    );

    await _putToS3(
      file: file,
      uploadUrl: presign.uploadUrl,
      contentType: contentType,
    );

    return UploadedAvatar(
      objectKey: presign.objectKey,
      publicUrl: presign.publicUrl,
    );
  }

  // ── Shared internals ───────────────────────────────────────────────────────

  Future<_PresignResponse> _requestPresign({
    required Map<String, dynamic> payload,
    String? accessToken,
  }) async {
    if (presignUrl.trim().isEmpty) {
      throw const UploadException('Missing UPLOAD_PRESIGN_URL configuration.');
    }

    try {
      final headers = await _buildJsonHeaders(accessTokenOverride: accessToken);
      final response = await httpClient
          .post(
            Uri.parse(presignUrl),
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw UploadException(
          'Unable to get upload URL. HTTP ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const UploadException('Invalid upload URL response.');
      }

      final uploadUrl = decoded['uploadUrl']?.toString() ?? '';
      final objectKey = decoded['objectKey']?.toString() ?? '';
      final publicUrl = _normalizePublicUrl(
        decoded['publicUrl']?.toString() ?? '',
      );

      if (uploadUrl.isEmpty || objectKey.isEmpty || publicUrl.isEmpty) {
        throw const UploadException(
          'Upload response is missing required fields.',
        );
      }

      return _PresignResponse(
        uploadUrl: uploadUrl,
        objectKey: objectKey,
        publicUrl: publicUrl,
      );
    } on UploadException {
      rethrow;
    } catch (e, st) {
      throw UploadException(
        'Unable to prepare upload.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _putToS3({
    required File file,
    required String uploadUrl,
    required String contentType,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      final response = await httpClient
          .put(
            Uri.parse(uploadUrl),
            headers: {'Content-Type': contentType, 'x-amz-acl': 'public-read'},
            body: bytes,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw UploadException(
          'Upload to S3 failed. HTTP ${response.statusCode}.',
        );
      }
    } on UploadException {
      rethrow;
    } catch (e, st) {
      throw UploadException('Upload to S3 failed.', cause: e, stackTrace: st);
    }
  }

  Future<Map<String, String>> _buildJsonHeaders({
    String? accessTokenOverride,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};

    String? token = accessTokenOverride ?? authTokenGetter?.call();
    if (token == null || token.isEmpty) {
      try {
        token = await authTokenRefresher?.call();
      } catch (_) {}
    }

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  String _contentTypeFor(File file) {
    final ext = file.path.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
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
