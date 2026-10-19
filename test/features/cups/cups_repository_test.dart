import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nook/core/cafe/domain/entities/cafe_details.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/upload/domain/entities/uploaded_file.dart';
import 'package:nook/features/cups/data/cups_backend.dart';
import 'package:nook/features/cups/data/cups_repository_impl.dart';
import 'package:nook/features/cups/domain/entities/cup.dart';
import 'package:nook/features/cups/domain/i_cups_repository.dart';
import 'package:nook/features/gallery/domain/entities/gallery_photo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../gallery/community_photos_fakes.dart';
import '../gallery/gallery_fakes.dart';
import '../public_profile/public_profile_fakes.dart';

const _me = 'aaaaaaaa-0000-4000-8000-000000000001';

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

/// What production answers today for any Cups RPC (read 2026-10-11).
http.Response _missing(http.Request request) => http.Response(
  jsonEncode({
    'code': 'PGRST202',
    'details': 'Searched for the function ...',
    'hint': null,
    'message':
        'Could not find the function public.${request.url.pathSegments.last}'
        '(p_cafe_id) in the schema cache',
  }),
  404,
  headers: {'content-type': 'application/json'},
  request: request,
);

/// Reviews for the legacy path; everything else throws.
class _Cafes implements ICafeRepository {
  _Cafes(this.reviews);

  final List<Review> reviews;
  final added = <({int rating, String content})>[];

  @override
  Future<List<Review>> getCafeReviewsById(
    String cafeId, {
    String sort = 'recommended',
    int? ratingFilter,
  }) async => reviews;

  @override
  Future<Review> addCafeReview({
    required String cafeId,
    required String userId,
    required int rating,
    required String content,
    List<String> imageUrls = const [],
  }) async {
    added.add((rating: rating, content: content));
    return Review(
      id: 'new',
      cafeId: cafeId,
      userId: userId,
      rating: rating,
      content: content,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

Review _review(String id, String user, {int rating = 5, String text = ''}) =>
    Review(
      id: id,
      cafeId: 'cafe-1',
      userId: user,
      rating: rating,
      content: text,
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
      name: user,
    );

void main() {
  late List<http.Request> requests;
  late http.Response Function(http.Request) answer;
  late CupsBackend backend;
  late _Cafes cafes;
  late List<String> uploads;

  setUp(() {
    requests = [];
    uploads = [];
    backend = CupsBackend();
    cafes = _Cafes([_review('r1', 'user-lia', rating: 4, text: 'Silky.')]);
    answer = _missing;
  });

  Future<CupsRepositoryImpl> repo() async {
    final client = SupabaseClient(
      'http://localhost:54321',
      'anon',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path.startsWith('/functions/')) {
          return http.Response('{}', 200, request: request);
        }
        if (request.url.path == '/rest/v1/user_photos') {
          return http.Response('[]', 201, request: request);
        }
        return answer(request);
      }),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await client.auth.recoverSession(_session());
    return CupsRepositoryImpl(
      client: client,
      backend: backend,
      upload: ({required File file, required String cafeId}) async {
        final name = file.uri.pathSegments.last;
        uploads.add(name);
        return UploadedFile(
          objectKey: 'gallery/$_me/$cafeId/$name',
          publicUrl: 'https://cdn/gallery/$_me/$cafeId/$name',
        );
      },
      cafes: cafes,
      legacyPhotos: FakeCommunityPhotosRepository([
        communityPhoto('p1', username: 'sai', takenAt: DateTime(2026, 10, 2)),
        communityPhoto('p2', username: 'sai', takenAt: DateTime(2026, 10, 2)),
      ]),
      gallery: FakeGalleryRepository(),
      profiles: FakePublicProfileRepository(),
    );
  }

  List<String> rpcCalls() => [
    for (final r in requests)
      if (r.url.path.startsWith('/rest/v1/rpc/')) r.url.pathSegments.last,
  ];

  group('missing-RPC detection', () {
    test('PGRST202 and 42883 are a missing function; others are not', () {
      expect(
        isMissingRpc(const PostgrestException(message: 'x', code: 'PGRST202')),
        isTrue,
      );
      expect(
        isMissingRpc(const PostgrestException(message: 'x', code: '42883')),
        isTrue,
      );
      expect(
        isMissingRpc(
          const PostgrestException(
            message: 'Could not find the function public.post_cup',
          ),
        ),
        isTrue,
      );
      expect(
        isMissingRpc(const PostgrestException(message: 'no', code: '42501')),
        isFalse,
      );
      expect(isMissingRpc(const SocketException('offline')), isFalse);
    });

    test('a backend without Cups falls back once, then stays on the '
        'legacy reads', () async {
      final r = await repo();
      final page = await r.getCafeCups('cafe-1');

      expect(r.mode, CupsMode.legacy);
      expect(rpcCalls(), ['get_cafe_cups']);
      // The review is one cup with its stars; sai's two photos of one day
      // are another, with no stars.
      expect(page.cards, hasLength(2));
      final lia = page.cards.firstWhere((c) => c.userId == 'user-lia');
      expect(lia.rating, 4);
      expect(lia.note, 'Silky.');
      final sai = page.cards.firstWhere((c) => c.userId == 'user-sai');
      expect(sai.rating, isNull);
      expect(sai.photos, hasLength(2));
      expect(page.stats.cupCount, 2);
      expect(page.stats.ratedCount, 1);
      expect(page.stats.rating, 4);

      await r.getCafeCups('cafe-1');
      // Not asked again.
      expect(rpcCalls(), ['get_cafe_cups']);
    });

    test('other failures are not taken for a missing RPC', () async {
      answer = (request) => http.Response(
        jsonEncode({'code': '42501', 'message': 'permission denied'}),
        403,
        headers: {'content-type': 'application/json'},
        request: request,
      );
      final r = await repo();
      await expectLater(r.getCafeCups('cafe-1'), throwsA(isA<CupsException>()));
      expect(r.mode, CupsMode.unknown);
    });
  });

  group('on the Cups backend', () {
    setUp(() {
      answer = (request) {
        final name = request.url.pathSegments.last;
        final body = switch (name) {
          'get_cafe_cups' => {
            'cafe_id': 'cafe-1',
            'stats': {
              'cup_count': 1,
              'people_count': 1,
              'photo_count': 1,
              'coffee_photo_count': 0,
              'drink_photo_count': 0,
              'food_photo_count': 1,
              'space_photo_count': 0,
              'rated_people_count': 0,
              'rating': null,
            },
            'cards': [
              {
                'id': 'cup-1',
                'source': 'cup',
                'is_virtual': false,
                'user_id': 'user-mae',
                'username': 'mae',
                'rating': null,
                'note': null,
                'visited_at': '2026-10-09T03:00:00Z',
                'helpful_count': 0,
                'visits_by_author': 2,
                'items': [
                  {
                    'id': 'item-1',
                    'kind': 'food',
                    'item_name': 'Ensaymada',
                    'menu_item_id': null,
                    'photo': {
                      'id': 'photo-1',
                      'image_url': 'https://cdn/x.jpg',
                      'taken_at': '2026-10-09T03:00:00Z',
                    },
                  },
                ],
              },
            ],
            'total': 1,
            'has_more': false,
          },
          'post_cup' => {
            'cup': {'id': 'cup-2', 'user_id': _me, 'items': []},
            'marked_been': true,
          },
          _ => null,
        };
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      };
    });

    test('maps a photo-only cup without inventing stars', () async {
      final r = await repo();
      final page = await r.getCafeCups('cafe-1', kind: CupItemKind.food);

      expect(r.mode, CupsMode.cups);
      // The kind is filtered here, from the cards, not by the server (which
      // counts legacy photos as coffee).
      final body = jsonDecode(requests.single.body) as Map;
      expect(body['p_kind_filter'], isNull);
      expect(body['p_limit'], CupsRepositoryImpl.kindScanLimit);
      final cup = page.cards.single;
      expect(cup.cupId, 'cup-1');
      expect(cup.rating, isNull);
      expect(cup.visitsByAuthor, 2);
      expect(cup.items.single.kind, CupItemKind.food);
      expect(cup.items.single.label, 'Ensaymada');
      expect(cup.items.single.photoId, 'photo-1');
      expect(cup.items.single.imageUrl, 'https://cdn/x.jpg');
      expect(page.stats.hasRatings, isFalse);
      expect(page.stats.kindCounts, {CupItemKind.food: 1});
      expect(page.total, 1);
    });

    test('chip counts are cups, not photos, and a kind filters the cups', () {
      // Three cups: two coffees in one, a coffee and a food in another, and
      // a legacy review read as coffee by the server.
      Map<String, Object?> cup(
        String id,
        List<String> kinds, {
        bool virtual = false,
      }) => {
        'id': id,
        'source': virtual ? 'review' : 'cup',
        'is_virtual': virtual,
        'review_id': virtual ? 'r-$id' : null,
        'user_id': 'user-$id',
        'visited_at': '2026-10-09',
        'items': [
          for (var i = 0; i < kinds.length; i++)
            {
              'id': '$id-$i',
              'kind': kinds[i],
              'photo': {'id': '$id-$i', 'image_url': 'https://cdn/$id$i.jpg'},
            },
        ],
      };
      final cards = [
        cup('a', ['coffee', 'coffee']),
        cup('b', ['coffee', 'food']),
        cup('c', ['coffee'], virtual: true),
      ];
      answer = (request) => http.Response(
        jsonEncode({
          'cafe_id': 'cafe-1',
          'stats': {'cup_count': 3, 'coffee_photo_count': 4},
          'cards': cards,
          'total': 3,
          'has_more': false,
        }),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
      return () async {
        final r = await repo();
        final all = await r.getCafeCups('cafe-1', limit: 3);
        expect(all.stats.kindCounts, {
          CupItemKind.coffee: 2,
          CupItemKind.food: 1,
        });
        // The whole cafe came in one page: no second read to count.
        expect(rpcCalls(), ['get_cafe_cups']);

        final coffee = await r.getCafeCups('cafe-1', kind: CupItemKind.coffee);
        expect([for (final c in coffee.cards) c.id], ['a', 'b']);
        expect(coffee.total, all.stats.kindCounts[CupItemKind.coffee]);
      }();
    });

    test('post_cup gets the items, kinds and names, and no stars', () async {
      final r = await repo();
      final uploaded = <int>[];
      final result = await r.postCup(
        cafeId: 'cafe-1',
        note: '  Good for work.  ',
        visitedAt: DateTime(2026, 10, 10),
        items: [
          CupItemDraft(
            file: File('/tmp/a.jpg'),
            kind: CupItemKind.coffee,
            name: 'Cortado',
          ),
          const CupItemDraft(kind: CupItemKind.food, name: 'Banana bread'),
        ],
        onPhotoUploaded: uploaded.add,
      );

      expect(result.markedBeen, isTrue);
      expect(uploaded, [0]);
      final post = requests.firstWhere(
        (r) => r.url.pathSegments.last == 'post_cup',
      );
      final body = jsonDecode(post.body) as Map;
      expect(body['p_rating'], isNull);
      expect(body['p_note'], 'Good for work.');
      expect(body['p_visited_at'], '2026-10-10');
      final items = body['p_items'] as List;
      expect(items[0]['kind'], 'coffee');
      expect(items[0]['item_name'], 'Cortado');
      expect(items[0]['object_key'], 'gallery/$_me/cafe-1/a.jpg');
      expect(items[1], {'kind': 'food', 'item_name': 'Banana bread'});
    });

    group('a post_cup that gets no answer', () {
      late List<Map<String, Object?>> myCups;

      setUp(() {
        myCups = [];
        final cups = answer;
        answer = (request) {
          final name = request.url.pathSegments.last;
          if (name == 'post_cup') {
            // The server took it, but the answer never arrives.
            myCups.add({
              'id': 'cup-new',
              'rating': 4,
              'note': 'Good for work.',
              'visited_at': '2026-10-10T00:00:00Z',
              'items': [],
            });
            throw http.ClientException('Connection closed');
          }
          if (name == 'get_cafe_cups') {
            return http.Response(
              jsonEncode({
                'cafe_id': 'cafe-1',
                'cards': [],
                'my_cups': [...myCups],
              }),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          return cups(request);
        };
      });

      test('is the cup when it landed, and keeps its files', () async {
        myCups.add({
          'id': 'cup-old',
          'rating': 4,
          'note': 'Good for work.',
          'visited_at': '2026-09-01T00:00:00Z',
          'items': [],
        });
        final r = await repo();
        final result = await r.postCup(
          cafeId: 'cafe-1',
          rating: 4,
          note: 'Good for work.',
          items: [
            CupItemDraft(file: File('/tmp/e.jpg'), kind: CupItemKind.coffee),
          ],
        );

        expect(result.cup?.id, 'cup-new');
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(
          requests.where((r) => r.url.path.startsWith('/functions/')),
          isEmpty,
        );
      });

      test('fails as before when nothing landed', () async {
        final r = await repo();
        await expectLater(
          r.postCup(
            cafeId: 'cafe-1',
            rating: 5,
            note: 'Different cup.',
            items: [
              CupItemDraft(file: File('/tmp/f.jpg'), kind: CupItemKind.coffee),
            ],
          ),
          throwsA(isA<CupsException>()),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(
          requests.where((r) => r.url.path.startsWith('/functions/')),
          isNotEmpty,
        );
      });
    });
  });

  group('posting on the legacy backend', () {
    test('photos land in the gallery with their names; no review without '
        'stars', () async {
      final r = await repo();
      await r.postCup(
        cafeId: 'cafe-1',
        items: [
          CupItemDraft(
            file: File('/tmp/a.jpg'),
            kind: CupItemKind.coffee,
            name: 'Cortado',
          ),
        ],
      );

      expect(r.mode, CupsMode.legacy);
      final insert = requests.firstWhere(
        (r) => r.url.path == '/rest/v1/user_photos',
      );
      final rows = jsonDecode(insert.body) as List;
      expect(rows.single['drink_name'], 'Cortado');
      expect(rows.single['source'], GalleryPhotoSource.gallery.wire);
      expect(rows.single['object_key'], 'gallery/$_me/cafe-1/a.jpg');
      expect(cafes.added, isEmpty);
    });

    test(
      'a note without stars is refused there, and its upload removed',
      () async {
        backend.mode = CupsMode.legacy;
        final r = await repo();
        await expectLater(
          r.postCup(
            cafeId: 'cafe-1',
            note: 'Nice',
            items: [CupItemDraft(file: File('/tmp/a.jpg'))],
          ),
          throwsA(
            isA<CupsException>().having(
              (e) => e.code,
              'code',
              'legacy_needs_rating',
            ),
          ),
        );
        expect(uploads, ['a.jpg']);
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(
          requests.where((r) => r.url.path.startsWith('/functions/')),
          hasLength(1),
        );
      },
    );

    test('stars and a note become the 1.1.x review', () async {
      backend.mode = CupsMode.legacy;
      cafes = _Cafes(const []);
      final r = await repo();
      await r.postCup(
        cafeId: 'cafe-1',
        rating: 5,
        note: 'Best cortado.',
        items: const [],
      );
      expect(cafes.added, [(rating: 5, content: 'Best cortado.')]);
    });
  });

  group('editing a cup on the Cups backend', () {
    const virtualId = 'virt-review-1';
    const realId = 'cup-real-1';
    late String? failOn;

    setUp(() {
      failOn = null;
      answer = (request) {
        final name = request.url.pathSegments.last;
        if (name == failOn) {
          return http.Response(
            jsonEncode({'code': '22023', 'message': 'cup_empty'}),
            400,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        // Like the server: the first write copies the legacy visit into
        // cups, and its virtual id no longer resolves after that.
        final body = jsonDecode(request.body) as Map;
        if (body['p_cup_id'] != virtualId && body['p_cup_id'] != realId) {
          return http.Response(
            jsonEncode({'code': 'P0002', 'message': 'cup_not_found'}),
            404,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        return http.Response(
          jsonEncode({
            'cup': {'id': realId, 'user_id': _me, 'items': []},
            'object_keys': <String>[],
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      };
    });

    CupCard legacyVisit() => CupCard(
      id: virtualId,
      cupId: virtualId,
      reviewId: 'r1',
      cafeId: 'cafe-1',
      source: 'review',
      isVirtual: true,
      userId: _me,
      username: 'me',
      visitedAt: DateTime(2026, 10, 1),
      rating: 4,
      isMine: true,
    );

    List<Object?> cupIdsSent() => [
      for (final r in requests)
        if (r.url.path.startsWith('/rest/v1/rpc/'))
          (jsonDecode(r.body) as Map)['p_cup_id'],
    ];

    test('a legacy visit: later calls use the id the copy came back with; '
        'items go in before the stars and note', () async {
      final r = await repo();
      await r.updateCup(
        legacyVisit(),
        rating: 5,
        note: 'Better now.',
        addItems: [
          CupItemDraft(file: File('/tmp/b.jpg'), kind: CupItemKind.coffee),
        ],
        removeItemIds: const ['photo-9'],
      );

      expect(rpcCalls(), ['add_cup_items', 'update_cup', 'remove_cup_item']);
      expect(cupIdsSent(), [virtualId, realId, realId]);
    });

    test('a failure after the items went in keeps their files', () async {
      failOn = 'update_cup';
      final r = await repo();
      await expectLater(
        r.updateCup(
          legacyVisit(),
          rating: 5,
          addItems: [
            CupItemDraft(file: File('/tmp/c.jpg'), kind: CupItemKind.coffee),
          ],
        ),
        throwsA(isA<CupsException>()),
      );
      // The clean-up is fire-and-forget.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        requests.where((r) => r.url.path.startsWith('/functions/')),
        isEmpty,
      );
    });

    test(
      'a failure before anything points at the files cleans them up',
      () async {
        failOn = 'add_cup_items';
        final r = await repo();
        await expectLater(
          r.updateCup(
            legacyVisit(),
            rating: 5,
            addItems: [
              CupItemDraft(file: File('/tmp/d.jpg'), kind: CupItemKind.coffee),
            ],
          ),
          throwsA(isA<CupsException>()),
        );
        // The clean-up is fire-and-forget.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(
          requests.where((r) => r.url.path.startsWith('/functions/')),
          isNotEmpty,
        );
      },
    );
  });
}
