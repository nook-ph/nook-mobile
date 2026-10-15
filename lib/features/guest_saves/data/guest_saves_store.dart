import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nook/features/guest_saves/domain/cafe_snapshot.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps a guest's Want to Try / Been on this phone (SharedPreferences, one
/// JSON list), plus the one-time flags around saving.
///
/// Not scoped to a user: the saves belong to whoever is holding the phone
/// without an account, and are cleared once they reach an account.
class GuestSavesStore {
  static const _savesKey = 'guest_saves_v1';
  static const _unreadableKey = 'guest_saves_v1_unreadable';
  static const _firstSaveKey = 'saves_first_save_logged';
  static const _keepPromptKey = 'saves_keep_prompt_shown';

  /// The saves on this phone. An entry that cannot be read is skipped, not
  /// the whole list. A value that is not a JSON list at all is set aside
  /// under [_unreadableKey] (so the next write cannot destroy it) and reads
  /// as empty.
  ///
  /// Throws [GuestSavesReadException] when the phone's storage itself could
  /// not be read: the saves may well be there, so the caller must not write
  /// over them.
  Future<List<GuestSave>> read() async {
    final SharedPreferences prefs;
    final String? raw;
    try {
      prefs = await SharedPreferences.getInstance();
      raw = prefs.getString(_savesKey);
    } catch (e) {
      debugPrint('[GuestSavesStore] read failed: $e');
      throw GuestSavesReadException(e);
    }
    if (raw == null || raw.isEmpty) return const [];

    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      decoded = null;
    }
    if (decoded is! List) {
      debugPrint('[GuestSavesStore] unreadable saves set aside');
      try {
        await prefs.setString(_unreadableKey, raw);
        await prefs.remove(_savesKey);
      } catch (e) {
        throw GuestSavesReadException(e);
      }
      return const [];
    }

    final saves = <GuestSave>[];
    for (final entry in decoded) {
      try {
        final save = GuestSave.fromJson(entry);
        if (save != null) saves.add(save);
      } catch (e) {
        // A corrupt entry must not take the Saved tab, or the other saves,
        // down with it.
        debugPrint('[GuestSavesStore] skipped an unreadable save: $e');
      }
    }
    return saves;
  }

  Future<void> write(List<GuestSave> saves) async {
    final prefs = await SharedPreferences.getInstance();
    if (saves.isEmpty) {
      await prefs.remove(_savesKey);
      return;
    }
    await prefs.setString(
      _savesKey,
      jsonEncode([for (final s in saves) s.toJson()]),
    );
  }

  /// True the first time it is called on this phone, false after.
  Future<bool> claimFirstSave() => _claim(_firstSaveKey);

  /// True the first time it is called on this phone, false after: whether
  /// a guest save shows "Saved on this phone. Sign in any time to keep it."
  /// The key predates that line (it once held a sign-in prompt), so a phone
  /// that saw the old prompt does not get the line again.
  Future<bool> claimFirstSaveLine() => _claim(_keepPromptKey);

  Future<bool> _claim(String key) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(key) ?? false) return false;
    await prefs.setBool(key, true);
    return true;
  }
}

/// The phone's storage could not be read, so the saves are unknown (not
/// empty).
class GuestSavesReadException implements Exception {
  const GuestSavesReadException(this.cause);

  final Object cause;

  @override
  String toString() => 'GuestSavesReadException: $cause';
}

/// The last [maxEntries] cafe pages opened on this phone, newest first.
class RecentlyViewedStore {
  static const _key = 'recently_viewed_cafes_v1';
  static const maxEntries = 10;

  Future<List<RecentlyViewedCafe>> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final entries = <RecentlyViewedCafe>[];
      for (final entry in decoded) {
        try {
          final cafe = RecentlyViewedCafe.fromJson(entry);
          if (cafe != null) entries.add(cafe);
        } catch (_) {
          // Skip just this one.
        }
        if (entries.length == maxEntries) break;
      }
      return entries;
    } catch (e) {
      debugPrint('[RecentlyViewedStore] read failed: $e');
      return const [];
    }
  }

  Future<void> write(List<RecentlyViewedCafe> entries) async {
    final prefs = await SharedPreferences.getInstance();
    if (entries.isEmpty) {
      await prefs.remove(_key);
      return;
    }
    await prefs.setString(
      _key,
      jsonEncode([for (final e in entries.take(maxEntries)) e.toJson()]),
    );
  }
}
