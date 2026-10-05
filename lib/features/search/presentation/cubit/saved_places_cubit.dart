import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/features/search/domain/entities/saved_place.dart';
import 'package:nook/features/search/domain/repositories/i_saved_places_repository.dart';

enum SavedPlacesStatus { loading, ready, error }

class SavedPlacesState extends Equatable {
  const SavedPlacesState({
    this.status = SavedPlacesStatus.loading,
    this.places = const [],
    this.canSave = false,
  });

  final SavedPlacesStatus status;
  final List<SavedPlace> places;

  /// False for a guest.
  final bool canSave;

  SavedPlace? get home => _first(SavedPlaceKind.home);
  SavedPlace? get work => _first(SavedPlaceKind.work);
  List<SavedPlace> get custom =>
      places.where((p) => p.kind == SavedPlaceKind.custom).toList();

  bool get atLimit => places.length >= ISavedPlacesRepository.maxPlaces;

  SavedPlace? _first(SavedPlaceKind kind) {
    for (final p in places) {
      if (p.kind == kind) return p;
    }
    return null;
  }

  @override
  List<Object?> get props => [status, places, canSave];
}

/// The user's saved places, loaded once per sheet and kept in step with
/// every save and delete.
class SavedPlacesCubit extends Cubit<SavedPlacesState> {
  SavedPlacesCubit(this._repository)
    : super(SavedPlacesState(canSave: _repository.canSave));

  final ISavedPlacesRepository _repository;

  /// Places changed while this cubit was open, as (before, after), so a
  /// search near the old version can follow the edit.
  final List<(SavedPlace, SavedPlace)> edits = [];

  Future<void> load() async {
    if (!_repository.canSave) {
      emit(const SavedPlacesState(status: SavedPlacesStatus.ready));
      return;
    }
    try {
      final places = await _repository.list();
      if (!isClosed) {
        emit(
          SavedPlacesState(
            status: SavedPlacesStatus.ready,
            places: places,
            canSave: true,
          ),
        );
      }
    } catch (_) {
      if (!isClosed) {
        emit(
          SavedPlacesState(
            status: SavedPlacesStatus.error,
            places: state.places,
            canSave: true,
          ),
        );
      }
    }
  }

  /// Saves [place] and returns what was stored. A new Home (or Work)
  /// replaces the old one rather than adding a second.
  ///
  /// Throws what the repository throws, [SavedPlacesLimitReached] included,
  /// for the editor to explain.
  Future<SavedPlace> save(SavedPlace place) async {
    var toSave = place;
    if (place.id == null && place.kind != SavedPlaceKind.custom) {
      final existing = place.kind == SavedPlaceKind.home
          ? state.home
          : state.work;
      if (existing != null) toSave = place.copyWith(id: existing.id);
    }
    final before = state.places.where((p) => p.id == toSave.id).firstOrNull;
    final stored = await _repository.save(toSave);
    if (before != null && before != stored) edits.add((before, stored));
    if (!isClosed) {
      final replaced = state.places.any((p) => p.id == stored.id);
      emit(
        SavedPlacesState(
          status: SavedPlacesStatus.ready,
          places: replaced
              ? [for (final p in state.places) p.id == stored.id ? stored : p]
              : [...state.places, stored],
          canSave: true,
        ),
      );
    }
    return stored;
  }

  Future<void> delete(SavedPlace place) async {
    final id = place.id;
    if (id == null) return;
    await _repository.delete(id);
    if (!isClosed) {
      emit(
        SavedPlacesState(
          status: SavedPlacesStatus.ready,
          places: state.places.where((p) => p.id != id).toList(),
          canSave: true,
        ),
      );
    }
  }
}
