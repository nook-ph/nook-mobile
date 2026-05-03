import 'package:shared_preferences/shared_preferences.dart';

/// Persists which list the user last **saved a café into** (bookmark quick-save or
/// Save to… sheet add). Removing a café, renaming a list, or other metadata changes
/// do not update this. Keys are scoped by [userId] so switching accounts does not
/// reuse another user's id.
class LastSavedListStore {
  static const _keyPrefix = 'last_saved_list_';

  Future<String?> getLastSavedListId(String userId) async {
    final trimmed = userId.trim();
    if (trimmed.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('$_keyPrefix$trimmed')?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Future<void> setLastSavedListId(String userId, String listId) async {
    final uid = userId.trim();
    final lid = listId.trim();
    if (uid.isEmpty || lid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keyPrefix$uid', lid);
  }
}
