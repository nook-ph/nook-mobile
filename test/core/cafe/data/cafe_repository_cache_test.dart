import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/data/cafe_remote_data_source.dart';
import 'package:nook/core/cafe/data/cafe_repository_impl.dart';
import 'package:nook/core/cafe/data/cafe_store.dart';
import 'package:nook/core/cafe/domain/entities/cafe_bundle.dart';
import 'package:nook/core/cafe/domain/entities/cafe_details.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/cafe/domain/use_cases/get_cafe_details_usecase.dart';
import 'package:nook/features/cafe_details/data/models/cafe_details_model.dart';

/// Nothing here reaches the network: every test works on the store alone.
class _UnusedRemote implements CafeRemoteDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// Accepts review writes, or throws when [fail] is set.
class _ReviewRemote implements CafeRemoteDataSource {
  _ReviewRemote({this.fail = false});

  final bool fail;

  @override
  Future<ReviewModel> insertReview({
    required String cafeId,
    required String userId,
    required int rating,
    required String content,
    List<String> imageUrls = const [],
  }) async {
    if (fail) throw Exception('offline');
    return ReviewModel(
      id: 'r1',
      cafeId: cafeId,
      userId: userId,
      rating: rating,
      content: content,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
  }

  @override
  Future<void> deleteReview(String reviewId) async {
    if (fail) throw Exception('offline');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _BundleRepository implements ICafeRepository {
  _BundleRepository(this.bundle);

  final CafeBundle bundle;

  @override
  Future<CafeBundle> getCafeBundleById(
    String cafeId, {
    bool includeMenu = true,
    bool includeReviews = true,
  }) async => bundle;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

CafeDetails _details({required DateTime createdAt, List<Tag> tags = const []}) {
  return CafeDetails(
    id: 'cafe-1',
    createdAt: createdAt,
    name: 'Volte',
    description: 'Specialty coffee',
    address: 'Lahug',
    neighborhood: 'Lahug',
    lat: 10.3,
    lng: 123.9,
    rating: 4.2,
    reviewCount: 10,
    isNew: false,
    tags: tags,
  );
}

MenuItem _item(String id, {required bool highlight}) => MenuItem(
  id: id,
  cafeId: 'cafe-1',
  name: 'Item $id',
  price: 120,
  isHighlight: highlight,
);

const _summary = CafeSummary(
  id: 'cafe-1',
  name: 'Volte',
  rating: 4.6,
  reviewCount: 12,
  tags: ['Quiet'],
  isFeatured: true,
);

void main() {
  group('GetCafeDetailsUseCase', () {
    test('keeps the whole menu, not only the highlights', () async {
      final useCase = GetCafeDetailsUseCase(
        _BundleRepository(
          CafeBundle(
            details: _details(createdAt: DateTime(2025)),
            menu: [
              _item('a', highlight: true),
              _item('b', highlight: false),
              _item('c', highlight: false),
            ],
            reviews: const [],
          ),
        ),
      );

      final bundle = await useCase('cafe-1');

      expect(bundle.menu!.map((item) => item.id), ['a', 'b', 'c']);
    });
  });

  group('CafeRepositoryImpl.warmCache', () {
    late CafeStore store;
    late CafeRepositoryImpl repository;

    setUp(() {
      store = CafeStore();
      repository = CafeRepositoryImpl(_UnusedRemote(), store);
    });

    test(
      'keeps a full bundle\'s tags and refreshes its summary fields',
      () async {
        const amenity = Tag(id: 't1', name: 'Wifi', category: 'amenities');
        const payment = Tag(id: 't2', name: 'GCash', category: 'payments');
        store.set(
          'cafe-1',
          CafeBundle(
            details: _details(
              createdAt: DateTime(2025),
              tags: const [amenity, payment],
            ),
            menu: const [],
            reviews: const [],
          ),
        );

        await repository.warmCache(const [_summary]);

        final details = store.get('cafe-1')!.details;
        expect(details.tags, const [amenity, payment]);
        expect(details.rating, 4.6);
        expect(details.reviewCount, 12);
      },
    );

    test('does not renew a full bundle\'s TTL', () async {
      store.set(
        'cafe-1',
        CafeBundle(
          details: _details(createdAt: DateTime(2025)),
          menu: const [],
          reviews: const [],
        ),
      );
      final writtenAt = store.writtenAt('cafe-1');
      await Future<void>.delayed(const Duration(milliseconds: 5));

      await repository.warmCache(const [_summary]);

      expect(store.writtenAt('cafe-1'), writtenAt);
    });

    test('still refreshes a summary seed from the newer summary', () async {
      await repository.warmCache(const [
        CafeSummary(id: 'cafe-1', name: 'Volte', rating: 4.0, tags: ['Cozy']),
      ]);

      await repository.warmCache(const [_summary]);

      final details = store.get('cafe-1')!.details;
      expect(details.createdAt.millisecondsSinceEpoch, 0);
      expect(details.tags.map((tag) => tag.name), ['Quiet']);
      expect(details.rating, 4.6);
    });
  });

  group('reviews bust the cache', () {
    CafeBundle full() => CafeBundle(
      details: _details(createdAt: DateTime(2025)),
      menu: const [],
      reviews: const [],
    );

    test('posting a review drops that cafe\'s bundle', () async {
      final store = CafeStore()
        ..set('cafe-1', full())
        ..set('cafe-2', full());
      final repository = CafeRepositoryImpl(_ReviewRemote(), store);

      await repository.addCafeReview(
        cafeId: 'cafe-1',
        userId: 'u1',
        rating: 5,
        content: 'Lovely',
      );

      expect(store.get('cafe-1'), isNull);
      expect(store.get('cafe-2'), isNotNull);
    });

    test('a failed post leaves the cache alone', () async {
      final store = CafeStore()..set('cafe-1', full());
      final repository = CafeRepositoryImpl(_ReviewRemote(fail: true), store);

      await expectLater(
        repository.addCafeReview(
          cafeId: 'cafe-1',
          userId: 'u1',
          rating: 5,
          content: 'Lovely',
        ),
        throwsException,
      );

      expect(store.get('cafe-1'), isNotNull);
    });

    test('deleting a review drops the cached cafes', () async {
      final store = CafeStore()..set('cafe-1', full());
      final repository = CafeRepositoryImpl(_ReviewRemote(), store);

      await repository.deleteReview('r1');

      expect(store.get('cafe-1'), isNull);
    });
  });

  group('CafeStore.replace', () {
    test('is a no-op for an entry that was never written', () {
      final store = CafeStore();

      store.replace(
        'cafe-1',
        CafeBundle(details: _details(createdAt: DateTime(2025))),
      );

      expect(store.get('cafe-1'), isNull);
    });
  });
}
