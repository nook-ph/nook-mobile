import 'package:flutter/foundation.dart';

/// Bumped whenever this user's writes change cafe numbers that lists show
/// (rating and review count): a review posted or deleted.
///
/// Search rows and Home shelves come from `get_cafes` and are held in their
/// pages' state, so after deleting a review a Search page still on the
/// stack showed the old "★ 4.0 (1)". Pages that show those numbers listen
/// and fetch again.
abstract final class CafeDataRevision {
  static final ValueNotifier<int> reviews = ValueNotifier<int>(0);

  static void reviewsChanged() => reviews.value++;
}
