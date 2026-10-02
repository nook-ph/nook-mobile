import 'package:shared_preferences/shared_preferences.dart';

import 'review_draft.dart';

class ReviewDraftStore {
  static const _textKeyPrefix = 'review_draft_text_';
  static const _ratingKeyPrefix = 'review_draft_rating_';
  static const _updatedAtKeyPrefix = 'review_draft_updated_at_';

  /// A draft belongs to one account on this device: with a [userId] the key
  /// carries it, so the next person to sign in does not see it.
  static String _keyId(String cafeId, String? userId) {
    final cafe = cafeId.trim();
    final user = userId?.trim() ?? '';
    return cafe.isEmpty || user.isEmpty ? cafe : '${user}_$cafe';
  }

  Future<ReviewDraft?> load(String cafeId, {String? userId}) async {
    final id = _keyId(cafeId, userId);
    if (id.isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString('$_textKeyPrefix$id');
    final rating = prefs.getInt('$_ratingKeyPrefix$id');
    final updatedAtMs = prefs.getInt('$_updatedAtKeyPrefix$id');

    if (text == null && rating == null && updatedAtMs == null) return null;

    return ReviewDraft(
      text: text ?? '',
      rating: rating ?? 0,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMs ?? 0),
    );
  }

  Future<void> save(
    String cafeId, {
    required String text,
    required int rating,
    String? userId,
  }) async {
    final id = _keyId(cafeId, userId);
    if (id.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final updatedAt = DateTime.now().millisecondsSinceEpoch;

    await prefs.setString('$_textKeyPrefix$id', text);
    await prefs.setInt('$_ratingKeyPrefix$id', rating);
    await prefs.setInt('$_updatedAtKeyPrefix$id', updatedAt);
  }

  Future<void> clear(String cafeId, {String? userId}) async {
    final id = _keyId(cafeId, userId);
    if (id.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_textKeyPrefix$id');
    await prefs.remove('$_ratingKeyPrefix$id');
    await prefs.remove('$_updatedAtKeyPrefix$id');
  }
}
