import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/utils/debounced_count.dart';

void main() {
  test('label is Apply until there is a number', () {
    expect(showCafesLabel(null), 'Apply');
    expect(showCafesLabel(0), 'Show 0 cafes');
    expect(showCafesLabel(1), 'Show 1 cafe');
    expect(showCafesLabel(54), 'Show 54 cafes');
  });

  const delay = Duration(milliseconds: 20);
  Future<void> settle() =>
      Future<void>.delayed(delay + const Duration(milliseconds: 30));

  test('waits out the delay, then holds the fetched count', () async {
    final count = DebouncedCount(delay: delay);
    addTearDown(count.dispose);

    count.request(() async => 12);
    expect(count.value.value, isNull);
    await settle();
    expect(count.value.value, 12);
  });

  test('a burst of requests runs only the last fetch', () async {
    final count = DebouncedCount(delay: delay);
    addTearDown(count.dispose);
    var runs = 0;

    for (final n in [1, 2, 3]) {
      count.request(() async {
        runs++;
        return n;
      });
    }
    await settle();
    expect(runs, 1);
    expect(count.value.value, 3);
  });

  test('an answer that arrives after a newer request is dropped', () async {
    final count = DebouncedCount(delay: delay);
    addTearDown(count.dispose);
    final slow = Completer<int?>();

    count.request(() => slow.future);
    await settle();
    count.request(() async => 7);
    // Back to Apply while the new count is pending.
    expect(count.value.value, isNull);
    await settle();
    expect(count.value.value, 7);

    slow.complete(99);
    await Future<void>.delayed(Duration.zero);
    expect(count.value.value, 7);
  });

  test('a failed or inexact fetch leaves the count null', () async {
    final count = DebouncedCount(delay: delay);
    addTearDown(count.dispose);

    count.request(() async => 5);
    await settle();
    count.request(() async => throw Exception('offline'));
    await settle();
    expect(count.value.value, isNull);

    count.request(() async => null);
    await settle();
    expect(count.value.value, isNull);
  });

  test('disposing mid-flight does not throw', () async {
    final count = DebouncedCount(delay: delay);
    final slow = Completer<int?>();
    count.request(() => slow.future);
    await settle();
    count.dispose();
    slow.complete(3);
    await Future<void>.delayed(Duration.zero);
  });
}
