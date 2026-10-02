import 'dart:convert';

import 'package:nook/features/search/domain/entities/search_origin.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Recent searches and recent "search near" places, kept on the device only.
class SearchRecentsStore {
  static const _searchesKey = 'search.recentSearches';
  static const _placesKey = 'search.recentPlaces';
  static const maxItems = 5;

  Future<List<String>> searches() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_searchesKey) ?? const [];
  }

  /// Puts [query] first; a repeat moves up instead of duplicating.
  Future<List<String>> addSearch(String query) async {
    final text = query.trim();
    if (text.isEmpty) return searches();
    final prefs = await SharedPreferences.getInstance();
    final list = [
      text,
      ...(prefs.getStringList(_searchesKey) ?? const <String>[]).where(
        (s) => s.toLowerCase() != text.toLowerCase(),
      ),
    ].take(maxItems).toList();
    await prefs.setStringList(_searchesKey, list);
    return list;
  }

  Future<List<String>> removeSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final list = (prefs.getStringList(_searchesKey) ?? const <String>[])
        .where((s) => s != query)
        .toList();
    await prefs.setStringList(_searchesKey, list);
    return list;
  }

  /// Forgets every recent search. Returns what was there, so the caller can
  /// offer Undo and hand it back to [restoreSearches].
  Future<List<String>> clearSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getStringList(_searchesKey) ?? const <String>[];
    await prefs.remove(_searchesKey);
    return previous;
  }

  /// Puts back a list taken by [clearSearches]. Searches made since then
  /// stay on top; the restored ones follow, without duplicates.
  Future<List<String>> restoreSearches(List<String> previous) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_searchesKey) ?? const <String>[];
    final seen = {for (final s in current) s.toLowerCase()};
    final list = [
      ...current,
      ...previous.where((s) => seen.add(s.toLowerCase())),
    ].take(maxItems).toList();
    await prefs.setStringList(_searchesKey, list);
    return list;
  }

  Future<List<SearchOrigin>> places() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_placesKey) ?? const <String>[])
        .map((raw) {
          try {
            return SearchOrigin.fromJson(jsonDecode(raw));
          } catch (_) {
            return null;
          }
        })
        .whereType<SearchOrigin>()
        .toList();
  }

  /// Pins are not kept: "Pinned location" twice in a list says nothing.
  Future<List<SearchOrigin>> addPlace(SearchOrigin place) async {
    if (place.isPin) return places();
    final prefs = await SharedPreferences.getInstance();
    final current = await places();
    final list = [
      place,
      ...current.where(
        (p) => p.label != place.label || p.subtitle != place.subtitle,
      ),
    ].take(maxItems).toList();
    await prefs.setStringList(
      _placesKey,
      list.map((p) => jsonEncode(p.toJson())).toList(),
    );
    return list;
  }
}
