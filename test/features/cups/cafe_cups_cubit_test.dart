import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/cups/domain/entities/cup.dart';
import 'package:nook/features/cups/presentation/cubit/cafe_cups_cubit.dart';

import 'cups_fakes.dart';

/// The demo fixtures, with reads that can fail and a count of them.
class _Reads extends FakeCupsRepository {
  Object? readFailure;
  int reads = 0;
  int toggles = 0;
  Completer<void>? toggleGate;

  @override
  Future<CupCard> toggleHelpful(CupCard card) async {
    toggles++;
    await toggleGate?.future;
    return super.toggleHelpful(card);
  }

  @override
  Future<CafeCups> getCafeCups(
    String cafeId, {
    CupSort sort = CupSort.recommended,
    int? ratingFilter,
    CupItemKind? kind,
    int limit = 10,
    int offset = 0,
  }) async {
    reads++;
    final error = readFailure;
    if (error != null) throw error;
    return super.getCafeCups(
      cafeId,
      sort: sort,
      ratingFilter: ratingFilter,
      kind: kind,
      limit: limit,
      offset: offset,
    );
  }
}

void main() {
  late _Reads repo;

  setUp(() => repo = _Reads());

  CafeCupsCubit cubit() =>
      CafeCupsCubit(repository: repo, cafeId: 'cafe-1', pageSize: 1);

  test('after a failed next page, scrolling does not ask again; Try again '
      'does', () async {
    final c = cubit();
    await c.load();
    expect(c.state.hasMore, isTrue);

    repo.readFailure = Exception('offline');
    await c.loadMore();
    expect(c.state.loadMoreFailed, isTrue);
    final afterFailure = repo.reads;

    // What every scroll event near the end calls.
    await c.loadMore();
    await c.loadMore();
    expect(repo.reads, afterFailure);

    repo.readFailure = null;
    await c.loadMore(retry: true);
    expect(repo.reads, afterFailure + 1);
    expect(c.state.loadMoreFailed, isFalse);
    expect(c.state.cards, hasLength(2));
    await c.close();
  });

  test('a refresh that fails while a next page loads does not leave paging '
      'stuck', () async {
    final c = cubit();
    await c.load();
    final more = c.loadMore();
    expect(c.state.loadingMore, isTrue);
    repo.readFailure = Exception('offline');
    await c.load(refresh: true);
    await more;
    expect(c.state.isLoaded, isTrue);
    expect(c.state.loadingMore, isFalse);
    await c.close();
  });

  test('a second Helpful tap while one is on its way is ignored', () async {
    final c = cubit();
    await c.load();
    final card = c.state.cards.first;
    repo.toggleGate = Completer<void>();

    final first = c.toggleHelpful(card);
    final second = await c.toggleHelpful(c.state.cards.first);
    expect(second, isFalse);
    repo.toggleGate!.complete();
    expect(await first, isTrue);
    expect(repo.toggles, 1);
    expect(c.state.cards.first.hasVoted, !card.hasVoted);

    // Once it's back, the next tap goes through.
    repo.toggleGate = null;
    expect(await c.toggleHelpful(c.state.cards.first), isTrue);
    expect(repo.toggles, 2);
    await c.close();
  });
}
