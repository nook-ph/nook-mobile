import 'dart:async';

import 'package:flutter/foundation.dart';

/// The label of a filter sheet's primary button: "Show 12 cafes" once the
/// count is known, and "Apply" while it is loading, failed, or cannot be
/// counted exactly. Never a number that might be wrong.
String showCafesLabel(int? count) {
  if (count == null) return 'Apply';
  return count == 1 ? 'Show 1 cafe' : 'Show $count cafes';
}

/// A count that follows a draft filter: each [request] waits out [delay],
/// then runs its fetch; a newer request drops the older one's answer.
///
/// [value] is null while a count is pending, when the fetch threw, and when
/// the fetch itself returned null (it could not count exactly).
class DebouncedCount {
  DebouncedCount({this.delay = const Duration(milliseconds: 300)});

  final Duration delay;
  final ValueNotifier<int?> value = ValueNotifier<int?>(null);

  Timer? _timer;
  int _seq = 0;
  bool _disposed = false;

  void request(Future<int?> Function() fetch) {
    if (_disposed) return;
    final id = ++_seq;
    _timer?.cancel();
    value.value = null;
    _timer = Timer(delay, () async {
      int? result;
      try {
        result = await fetch();
      } catch (_) {
        result = null;
      }
      if (_disposed || id != _seq) return;
      value.value = result;
    });
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    value.dispose();
  }
}
