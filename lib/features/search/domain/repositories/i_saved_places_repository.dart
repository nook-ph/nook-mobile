import 'package:nook/features/search/domain/entities/saved_place.dart';

/// The signed-in user's saved places. Only the owner can read them.
abstract class ISavedPlacesRepository {
  /// Matches the database cap.
  static const maxPlaces = 10;

  /// False for a guest: saving needs an account.
  bool get canSave;

  Future<List<SavedPlace>> list();

  /// Inserts (no id) or updates (with id). Returns the stored place.
  ///
  /// Throws [SavedPlacesLimitReached] past [maxPlaces].
  Future<SavedPlace> save(SavedPlace place);

  Future<void> delete(String id);
}

class SavedPlacesLimitReached implements Exception {
  const SavedPlacesLimitReached();
}
