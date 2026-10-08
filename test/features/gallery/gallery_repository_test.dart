import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nook/core/upload/domain/entities/uploaded_file.dart';
import 'package:nook/features/gallery/data/gallery_repository_impl.dart';
import 'package:nook/features/gallery/domain/entities/gallery_photo.dart';
import 'package:nook/features/gallery/domain/i_gallery_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'gallery_fakes.dart';

const _me = 'aaaaaaaa-0000-4000-8000-000000000001';

/// A session that needs no network: a JWT for [_me] that expires in a day.
String _session() {
  String part(Map<String, Object> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(days: 1));
  final seconds = exp.millisecondsSinceEpoch ~/ 1000;
  final token =
      '${part({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${part({'sub': _me, 'exp': seconds, 'role': 'authenticated'})}.sig';
  return jsonEncode({
    'access_token': token,
    'expires_in': 86400,
    'expires_at': seconds,
    'refresh_token': 'r',
    'token_type': 'bearer',
    'user': {
      'id': _me,
      'aud': 'authenticated',
      'app_metadata': <String, Object>{},
      'user_metadata': <String, Object>{},
      'created_at': '2026-01-01T00:00:00Z',
    },
  });
}

/// Deleting a gallery photo used to delete only its row; the public-read
/// file stayed on the CDN. A failed save left its uploads behind, and "Try
/// again" uploaded them a second time.
void main() {
  late List<http.Request> requests;
  late List<String> uploads;

  /// Answers PostgREST with [rest] (or [restStatus]) and the functions
  /// endpoint with `{}`.
  Future<GalleryRepositoryImpl> repo({
    Object rest = const <Object>[],
    int restStatus = 200,
    Set<String> failUploads = const {},
  }) async {
    final client = SupabaseClient(
      'http://localhost:54321',
      'anon',
      httpClient: MockClient((request) async {
        requests.add(request);
        final isFunction = request.url.path.startsWith('/functions/');
        return http.Response(
          jsonEncode(
            isFunction
                ? <String, Object>{}
                : restStatus == 200
                ? rest
                : {'code': '42501', 'message': 'denied'},
          ),
          isFunction ? 200 : restStatus,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await client.auth.recoverSession(_session());
    return GalleryRepositoryImpl(
      client: client,
      upload: ({required File file, required String cafeId}) async {
        final name = file.uri.pathSegments.last;
        if (failUploads.contains(name)) throw const SocketException('offline');
        uploads.add(name);
        return UploadedFile(
          objectKey: 'gallery/$_me/$cafeId/$name',
          publicUrl: 'https://cdn/gallery/$_me/$cafeId/$name',
        );
      },
    );
  }

  List<http.Request> functionCalls() => [
    for (final r in requests)
      if (r.url.path == '/functions/v1/$deleteGalleryObjectFunction') r,
  ];

  List<Object?> deletedKeys() => [
    for (final r in functionCalls())
      ...(jsonDecode(r.body) as Map)['objectKeys'] as List,
  ];

  setUp(() {
    requests = [];
    uploads = [];
  });

  test('deleting a photo deletes its file too', () async {
    final r = await repo(
      rest: [
        {'object_key': 'gallery/$_me/c1/f1.jpg'},
      ],
    );
    await r.deletePhoto('p1');
    await pumpEventQueue(times: 200);

    final delete = requests.firstWhere((q) => q.method == 'DELETE');
    expect(delete.url.queryParameters['id'], 'eq.p1');
    expect(delete.url.queryParameters['select'], 'object_key');
    expect(deletedKeys(), ['gallery/$_me/c1/f1.jpg']);
  });

  test('a photo without a file (a review photo) calls nothing', () async {
    final r = await repo(
      rest: [
        {'object_key': null},
      ],
    );
    await r.deletePhoto('p1');
    await pumpEventQueue(times: 200);
    expect(functionCalls(), isEmpty);
  });

  test('a failed save deletes the files it just uploaded', () async {
    final r = await repo(restStatus: 403);
    await expectLater(
      r.addPhotos(
        cafeId: 'c1',
        photos: [pickedPhoto('a'), pickedPhoto('b')],
        source: GalleryPhotoSource.gallery,
      ),
      throwsA(isA<GalleryException>()),
    );
    await pumpEventQueue(times: 200);
    expect(deletedKeys(), ['gallery/$_me/c1/a.jpg', 'gallery/$_me/c1/b.jpg']);
  });

  test('a failed upload deletes the ones that made it', () async {
    final r = await repo(failUploads: {'b.jpg'});
    await expectLater(
      r.addPhotos(
        cafeId: 'c1',
        photos: [pickedPhoto('a'), pickedPhoto('b')],
        source: GalleryPhotoSource.gallery,
      ),
      throwsA(isA<SocketException>()),
    );
    await pumpEventQueue(times: 200);
    expect(uploads, ['a.jpg']);
    expect(deletedKeys(), ['gallery/$_me/c1/a.jpg']);
    // Nothing was saved.
    expect(
      requests.where(
        (q) => q.method == 'POST' && q.url.path.contains('user_photos'),
      ),
      isEmpty,
    );
  });

  test('a successful save deletes nothing', () async {
    final r = await repo(
      rest: [
        {
          'id': 'p1',
          'user_id': _me,
          'cafe_id': 'c1',
          'image_url': 'https://cdn/x.jpg',
          'taken_at': '2026-10-01T00:00:00Z',
          'source': 'gallery',
          'cafes': {'name': 'Kamp'},
        },
      ],
    );
    final added = await r.addPhotos(
      cafeId: 'c1',
      photos: [pickedPhoto('a')],
      source: GalleryPhotoSource.gallery,
    );
    await pumpEventQueue(times: 200);
    expect(added.single.id, 'p1');
    expect(functionCalls(), isEmpty);
  });

  test('reads moderation_status; anything but visible is moderated', () {
    Map<String, dynamic> row(String? status) => {
      'id': 'p1',
      'user_id': _me,
      'cafe_id': 'c1',
      'image_url': 'https://cdn/x.jpg',
      'taken_at': '2026-10-01T00:00:00Z',
      'source': 'gallery',
      'moderation_status': ?status,
    };
    expect(galleryPhotoFromRow(row('visible')).isModerated, isFalse);
    expect(galleryPhotoFromRow(row(null)).isModerated, isFalse);
    expect(galleryPhotoFromRow(row('hidden')).isModerated, isTrue);
    expect(galleryPhotoFromRow(row('removed')).isModerated, isTrue);
  });

  test('the gallery read asks for moderation_status', () async {
    final r = await repo();
    await r.getMyPhotos();
    final get = requests.firstWhere((q) => q.method == 'GET');
    expect(get.url.queryParameters['select'], contains('moderation_status'));
  });

  // The note field counts characters as people see them (grapheme
  // clusters), and the DB counts code points. Cutting at 150 UTF-16 units
  // dropped emoji the counter allowed, and could split one into "\uFFFD".
  group('notes and drinks keep whole characters', () {
    Future<Map<String, dynamic>> saved({String? drink, String? note}) async {
      final r = await repo();
      await r.setDetails('p1', drinkName: drink, caption: note);
      final patch = requests.firstWhere((q) => q.method == 'PATCH');
      return jsonDecode(patch.body) as Map<String, dynamic>;
    }

    test('a note the field allowed is saved whole', () async {
      final note = '${'a' * 100}${'😀' * 50}'; // 150 characters
      expect((await saved(note: note))['caption'], note);
    });

    test('a long note is cut at 150 characters, never inside one', () async {
      final note = '${'a' * 149}${'😀' * 3}';
      final caption = (await saved(note: note))['caption'] as String;
      expect(caption, '${'a' * 149}😀');
      expect(caption.contains('\uFFFD'), isFalse);
      expect(caption.runes.length, lessThanOrEqualTo(150));
    });

    test('never more code points than the DB check allows', () async {
      // One family emoji is one character but seven code points.
      const family = '👨‍👩‍👧‍👦';
      final caption =
          (await saved(note: '${'a' * 145}$family'))['caption'] as String;
      expect(caption, 'a' * 145);
    });

    test('the drink name is cut at 60 characters the same way', () async {
      final drink = '${'b' * 59}${'🍵' * 2}';
      expect((await saved(drink: drink))['drink_name'], '${'b' * 59}🍵');
    });
  });
}
