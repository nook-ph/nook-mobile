import 'package:shared_preferences/shared_preferences.dart';

import 'review_draft.dart';

class ReviewDraftStore {
  static const _textKeyPrefix = 'review_draft_text_';
  static const _ratingKeyPrefix = 'review_draft_rating_';
  static const _updatedAtKeyPrefix = 'review_draft_updated_at_';

  Future<ReviewDraft?> load(String cafeId) async {
    final id = cafeId.trim();
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
  }) async {
    final id = cafeId.trim();
    if (id.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final updatedAt = DateTime.now().millisecondsSinceEpoch;

    await prefs.setString('$_textKeyPrefix$id', text);
    await prefs.setInt('$_ratingKeyPrefix$id', rating);
    await prefs.setInt('$_updatedAtKeyPrefix$id', updatedAt);
  }

  Future<void> clear(String cafeId) async {
    final id = cafeId.trim();
    if (id.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_textKeyPrefix$id');
    await prefs.remove('$_ratingKeyPrefix$id');
    await prefs.remove('$_updatedAtKeyPrefix$id');
  }
}
