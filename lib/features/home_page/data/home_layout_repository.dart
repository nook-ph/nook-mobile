import 'dart:convert';

import 'package:nook/core/cafe/data/cafe_summary_model.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/features/home_page/domain/home_layout.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The two RPCs behind the admin-controlled Home (nook-supabase
/// `docs/HOME_LAYOUT.md`).
class HomeLayoutRemoteSource {
  HomeLayoutRemoteSource(this.supabase);

  final SupabaseClient supabase;

  /// The raw `get_home_layout()` answer: a map, or null when nothing is
  /// published. Throws on a network or Postgrest error.
  Future<Object?> fetchLayout() => supabase.rpc('get_home_layout');

  /// Published cafes for [ids], in the order of [ids] (unknown or
  /// unpublished ones are skipped by the RPC). Rows have the `get_cafes`
  /// shape, so they map with [CafeSummaryModel.fromJson].
  ///
  /// Strings that aren't uuids are dropped first: `p_ids` is `uuid[]`, so
  /// one of them would fail the whole call.
  Future<List<CafeSummary>> fetchCafesByIds(List<String> ids) async {
    ids = uuidsOnly(ids);
    if (ids.isEmpty) return const [];
    final rows = await supabase.rpc('get_cafes_by_ids', params: {'p_ids': ids});
    if (rows is! List) return const [];
    final cafes = rows
        .whereType<Map>()
        .map((r) => CafeSummaryModel.fromJson(Map<String, dynamic>.from(r)))
        .toList();
    // Keep the admin's order even if the server ever stops guaranteeing it.
    final byId = {for (final c in cafes) c.id: c};
    return [for (final id in ids) ?byId[id]];
  }
}

/// The last good `get_home_layout()` answer, kept on the phone so Home can
/// draw its layout before the network answers.
class HomeLayoutCache {
  HomeLayoutCache({Future<SharedPreferences> Function()? prefs})
    : _prefs = prefs ?? SharedPreferences.getInstance;

  static const _key = 'homeLayoutCache';
  final Future<SharedPreferences> Function() _prefs;

  Future<String?> read() async {
    try {
      return (await _prefs()).getString(_key);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String? raw) async {
    try {
      final prefs = await _prefs();
      if (raw == null) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, raw);
      }
    } catch (_) {
      // A cache that cannot be written only costs the instant first paint.
    }
  }
}

/// The outcome of asking the server again.
typedef HomeLayoutRefresh = ({
  /// False when the fetch failed; Home keeps what it shows.
  bool ok,

  /// The layout to use now: null means the built-in Home.
  HomeLayout? layout,

  /// Whether [layout] differs from what [HomeLayoutRepository.cached]
  /// returned.
  bool changed,
});

/// Cache first, refresh behind it.
///
/// - [cached]: the last good layout, or null.
/// - [refresh]: asks the server. Nothing published, or a schema this app
///   does not understand, means the built-in Home and clears the cache. A
///   failed fetch changes nothing (`ok: false`): the cached layout stays,
///   or, with none, the built-in Home.
class HomeLayoutRepository {
  HomeLayoutRepository({
    required Future<Object?> Function() fetch,
    required HomeLayoutCache cache,
  }) : _fetch = fetch,
       _cache = cache;

  final Future<Object?> Function() _fetch;
  final HomeLayoutCache _cache;

  String? _cachedRaw;
  bool _cacheRead = false;

  Future<HomeLayout?> cached() async {
    final raw = await _readCache();
    if (raw == null) return null;
    try {
      return HomeLayout.fromRpc(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<HomeLayoutRefresh> refresh() async {
    final before = await _readCache();
    final Object? response;
    try {
      response = await _fetch();
    } catch (_) {
      return (ok: false, layout: await cached(), changed: false);
    }

    final layout = HomeLayout.fromRpc(response);
    final raw = layout == null ? null : _encode(response);
    _cachedRaw = raw;
    if (raw != before) await _cache.write(raw);
    return (ok: true, layout: layout, changed: raw != before);
  }

  Future<String?> _readCache() async {
    if (!_cacheRead) {
      _cachedRaw = await _cache.read();
      _cacheRead = true;
    }
    return _cachedRaw;
  }

  static String? _encode(Object? response) {
    try {
      return jsonEncode(response);
    } catch (_) {
      return null;
    }
  }
}
