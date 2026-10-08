import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import 'package:nook/core/location/device_location.dart';
import 'package:nook/core/presentation/widgets/guest_sign_in_sheet.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/search/data/search_places.dart';
import 'package:nook/features/search/data/search_recents_store.dart';
import 'package:nook/features/search/data/spot_namer.dart';
import 'package:nook/features/search/domain/entities/saved_place.dart';
import 'package:nook/features/search/domain/entities/search_origin.dart';
import 'package:nook/features/search/domain/repositories/i_place_search_repository.dart';
import 'package:nook/features/search/domain/repositories/i_saved_places_repository.dart';
import 'package:nook/features/search/presentation/cubit/place_search_cubit.dart';
import 'package:nook/features/search/presentation/cubit/saved_places_cubit.dart';
import 'package:nook/features/search/presentation/pages/saved_place_editor_page.dart';
import 'package:nook/features/search/presentation/pages/search_pick_on_map_page.dart';
import 'package:nook/features/search/presentation/widgets/search_origin_sheet.dart';

/// What the "Search near" flow ended with: a place, or the phone's location
/// when [origin] is null.
class SearchOriginPick {
  const SearchOriginPick(this.origin);

  final SearchOrigin? origin;
}

const _cebu = LatLng(10.3157, 123.8854);

/// Opens the "Search near" sheet and, from it, the pick-on-map page and the
/// saved-place editor. Search and the map both go through here, so they
/// offer the same choices.
///
/// Null when the sheet (or the map) was dismissed without choosing.
Future<SearchOriginPick?> pickSearchOrigin(
  BuildContext context, {
  required SearchOrigin? current,
  required SearchPlaces places,
  required SearchRecentsStore recents,
  required IPlaceSearchRepository placeSearch,
  required ISavedPlacesRepository savedPlaces,
}) async {
  final label = await places.currentLocationLabel();
  final recentPlaces = await recents.places();
  if (!context.mounted) return null;

  ({double lat, double lng})? bias() {
    if (current != null) return (lat: current.lat, lng: current.lng);
    final d = DeviceLocation.instance.position.value;
    return d == null ? null : (lat: d.latitude, lng: d.longitude);
  }

  final search = PlaceSearchCubit(
    repository: placeSearch,
    places: places.index(),
    bias: bias,
  );
  final saved = SavedPlacesCubit(savedPlaces)..load();

  Future<SavedPlace?> openEditor(
    BuildContext sheetContext, {
    SavedPlace? place,
    required SavedPlaceKind kind,
  }) {
    return Navigator.of(sheetContext, rootNavigator: true).push<SavedPlace>(
      MaterialPageRoute(
        builder: (_) => SavedPlaceEditorPage(
          cubit: saved,
          kind: kind,
          place: place,
          search: placeSearch,
          places: places.index(),
        ),
      ),
    );
  }

  final SearchOriginChoice? choice;
  try {
    choice = await showSearchOriginSheet(
      context,
      current: current,
      currentLocationLabel: label,
      recentPlaces: recentPlaces,
      search: search,
      saved: saved,
      openEditor: openEditor,
    );
  } finally {
    await search.close();
    await saved.close();
  }
  if (choice == null) {
    // The place in use was edited (a new address for Home): search near
    // where it is now.
    for (final (before, after) in saved.edits.reversed) {
      if (current != null && before.toOrigin() == current) {
        return SearchOriginPick(after.toOrigin());
      }
    }
    return null;
  }
  switch (choice) {
    case UseCurrentLocation():
      return const SearchOriginPick(null);
    case UsePlace(:final place, :final justSaved):
      await recents.addPlace(place);
      if (justSaved && context.mounted) {
        showPrimaryToast(
          context,
          '${place.label} saved. Distances now measure from it.',
        );
      }
      return SearchOriginPick(place);
    case SignInToSave():
      if (context.mounted) {
        await GuestSignInSheet.show(
          context,
          icon: LucideIcons.house,
          title: 'Sign in to save places',
          reason:
              'Keep Home, School or work and your own places, and search '
              'near them in one tap. Only you can see them.',
        );
      }
      return null;
    case PickOnMap():
      if (!context.mounted) return null;
      final device = DeviceLocation.instance.position.value;
      final start = current != null
          ? LatLng(current.lat, current.lng)
          : device != null
          ? LatLng(device.latitude, device.longitude)
          : _cebu;
      // Over the tab bar when opened from the map tab.
      final pin = await Navigator.of(context, rootNavigator: true)
          .push<SearchOrigin>(
            MaterialPageRoute(
              builder: (_) => SearchPickOnMapPage(
                start: start,
                places: places.index(),
                namer: SpotNamer(placeSearch, places.index()),
              ),
            ),
          );
      return pin == null ? null : SearchOriginPick(pin);
  }
}
