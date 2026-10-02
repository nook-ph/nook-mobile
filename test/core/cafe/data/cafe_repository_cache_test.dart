import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/data/cafe_remote_data_source.dart';
import 'package:nook/core/cafe/data/cafe_repository_impl.dart';
import 'package:nook/core/cafe/data/cafe_store.dart';
import 'package:nook/core/cafe/domain/entities/cafe_bundle.dart';
import 'package:nook/core/cafe/domain/entities/cafe_details.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/cafe/domain/use_cases/get_cafe_details_usecase.dart';

/// Nothing here reaches the network: every test works on the store alone.
class _UnusedRemote implements CafeRemoteDataSource {
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
