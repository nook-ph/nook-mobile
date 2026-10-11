import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/gallery/presentation/cubit/cafe_photos_cubit.dart';

import 'community_photos_fakes.dart';

void main() {
  late FakeCommunityPhotosRepository repo;

  CafePhotosCubit cubit({int pageSize = 3, CafePhotosState? seed}) =>
      CafePhotosCubit(
        repository: repo,
        cafeId: 'cafe-1',
        pageSize: pageSize,
        seed: seed,
      );

  setUp(() {
    repo = FakeCommunityPhotosRepository([
      for (var i = 0; i < 7; i++) communityPhoto('p$i'),
    ]);
  });

  test('loads the first page with the total and whether more follow', () async {
    final c = cubit();
    final states = <CafePhotosState>[];
    final sub = c.stream.listen(states.add);
    await c.load();
    await sub.cancel();

    expect(states.first.status, CafePhotosStatus.loading);
    expect(c.state.status, CafePhotosStatus.loaded);
    expect(c.state.photos.map((p) => p.id), ['p0', 'p1', 'p2']);
    expect(c.state.total, 7);
    expect(c.state.hasMore, isTrue);
    expect(c.state.nextOffset, 3);
  });

  test('a cafe with no photos is loaded and empty', () async {
    repo.photos = [];
    final c = cubit()..load();
    await c.stream.firstWhere((s) => s.status == CafePhotosStatus.loaded);
    expect(c.state.isEmpty, isTrue);
    expect(c.state.hasMore, isFalse);
  });

  test('a failed load is failed, with the error for the copy', () async {
    repo.failure = offline;
    final c = cubit();
    await c.load();
    expect(c.state.status, CafePhotosStatus.failed);
    expect(c.state.error, offline);
    expect(c.state.photos, isEmpty);
  });

  test('a failed refresh keeps the photos already shown', () async {
    final c = cubit();
    await c.load();
    repo.failure = offline;
    await c.load(refresh: true);
    expect(c.state.status, CafePhotosStatus.loaded);
    expect(c.state.photos, hasLength(3));
  });

  test('loadMore appends the next page from the row offset', () async {
    final c = cubit();
    await c.load();
    await c.loadMore();
    expect(c.state.photos.map((p) => p.id), [
      'p0',
      'p1',
      'p2',
      'p3',
      'p4',
      'p5',
    ]);
    await c.loadMore();
    expect(c.state.photos, hasLength(7));
    expect(c.state.hasMore, isFalse);
    expect(repo.offsets, [0, 3, 6]);

    // Nothing more to ask for.
    await c.loadMore();
    expect(repo.offsets, [0, 3, 6]);
  });

  test('a failed next page keeps the photos and can be retried', () async {
    final c = cubit();
    await c.load();
    repo.failure = offline;
    await c.loadMore();
    expect(c.state.loadMoreFailed, isTrue);
    expect(c.state.loadingMore, isFalse);
    expect(c.state.photos, hasLength(3));

    // Scroll events near the end don't ask again after a failure.
    final asked = repo.offsets.length;
    await c.loadMore();
    expect(repo.offsets, hasLength(asked));

    repo.failure = null;
    await c.loadMore(retry: true);
    expect(c.state.loadMoreFailed, isFalse);
    expect(c.state.photos, hasLength(6));
  });

  test('a refresh that fails while a next page loads does not leave paging '
      'stuck', () async {
    final c = cubit();
    await c.load();
    final more = c.loadMore();
    expect(c.state.loadingMore, isTrue);
    repo.failure = offline;
    await c.load(refresh: true);
    await more;
    expect(c.state.status, CafePhotosStatus.loaded);
    expect(c.state.loadingMore, isFalse);
  });

  test('a repeat across pages is shown once', () async {
    final c = cubit();
    await c.load();
    // A photo added since the first page pushes p2 into the next one.
    repo.photos.insert(0, communityPhoto('new'));
    await c.loadMore();
    final ids = c.state.photos.map((p) => p.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
    expect(ids, ['p0', 'p1', 'p2', 'p3', 'p4']);
  });

  test('the grid starts from the strip and pages on from its offset', () async {
    final strip = cubit();
    await strip.load();
    final grid = cubit(pageSize: 24, seed: strip.state);
    expect(grid.state.photos, hasLength(3));

    await grid.loadMore();
    expect(repo.offsets.last, 3);
    expect(grid.state.photos, hasLength(7));
    expect(grid.state.hasMore, isFalse);
  });
}
