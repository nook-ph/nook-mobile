import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nook/features/guest_saves/domain/sign_up_ask_rules.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A guest's engagement score and ask history, kept on this phone.
class EngagementStore {
  static const _key = 'signup_ask_engagement_v1';

  /// Empty on a fresh phone, or when the stored value cannot be read.
  Future<EngagementState> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return const EngagementState();
      return EngagementState.fromJson(jsonDecode(raw));
    } catch (e) {
      debugPrint('[EngagementStore] read failed: $e');
      return const EngagementState();
    }
  }

  Future<void> write(EngagementState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(state.toJson()));
    } catch (e) {
      debugPrint('[EngagementStore] write failed: $e');
    }
  }
}
