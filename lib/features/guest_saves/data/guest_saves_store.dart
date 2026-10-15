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
  static const _firstSaveKey = 'saves_first_save_logged';
  static const _keepPromptKey = 'saves_keep_prompt_shown';

  Future<List<GuestSave>> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_savesKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded.map(GuestSave.fromJson).whereType<GuestSave>().toList();
    } catch (e) {
      // A corrupt entry must not take the Saved tab down with it.
      debugPrint('[GuestSavesStore] read failed: $e');
      return const [];
    }
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

  /// True the first time it is called on this phone, false after.
  Future<bool> claimKeepSavesPrompt() => _claim(_keepPromptKey);

  Future<bool> _claim(String key) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(key) ?? false) return false;
    await prefs.setBool(key, true);
    return true;
  }
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
      return decoded
          .map(RecentlyViewedCafe.fromJson)
          .whereType<RecentlyViewedCafe>()
          .take(maxEntries)
          .toList();
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
