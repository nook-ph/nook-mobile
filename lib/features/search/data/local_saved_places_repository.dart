import 'dart:convert';

import 'package:nook/features/search/domain/entities/saved_place.dart';
import 'package:nook/features/search/domain/repositories/i_saved_places_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// DEBUG ONLY (see `kPlaceSearchDirect`): saved places kept on the device,
/// for trying the feature before the `saved_places` table is deployed.
class LocalSavedPlacesRepository implements ISavedPlacesRepository {
  LocalSavedPlacesRepository({this.key = 'debug.savedPlaces'});

  final String key;

  @override
  bool get canSave => true;

  @override
  Future<List<SavedPlace>> list() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(key) ?? const <String>[])
        .map((raw) {
          try {
            return SavedPlace.fromJson(jsonDecode(raw));
          } catch (_) {
            return null;
          }
        })
        .whereType<SavedPlace>()
        .toList();
  }

  Future<void> _write(List<SavedPlace> places) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      key,
      places.map((p) => jsonEncode(p.toJson())).toList(),
    );
  }

  @override
  Future<SavedPlace> save(SavedPlace place) async {
    final places = await list();
    final id = place.id;
    if (id == null) {
      if (places.length >= ISavedPlacesRepository.maxPlaces) {
        throw const SavedPlacesLimitReached();
      }
      final stored = place.copyWith(id: const Uuid().v4());
      await _write([...places, stored]);
      return stored;
    }
    await _write([for (final p in places) p.id == id ? place : p]);
    return place;
  }

  @override
  Future<void> delete(String id) async {
    await _write((await list()).where((p) => p.id != id).toList());
  }
}
