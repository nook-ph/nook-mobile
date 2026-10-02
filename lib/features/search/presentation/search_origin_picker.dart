import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import 'package:nook/core/location/device_location.dart';
import 'package:nook/features/search/data/search_places.dart';
import 'package:nook/features/search/data/search_recents_store.dart';
import 'package:nook/features/search/domain/entities/search_origin.dart';
import 'package:nook/features/search/presentation/pages/search_pick_on_map_page.dart';
import 'package:nook/features/search/presentation/widgets/search_origin_sheet.dart';

/// What the "Search near" flow ended with: a place, or the phone's location
/// when [origin] is null.
class SearchOriginPick {
  const SearchOriginPick(this.origin);

  final SearchOrigin? origin;
}

const _cebu = LatLng(10.3157, 123.8854);

/// Opens the "Search near" sheet and, from it, the pick-on-map page. Search
/// and the map both go through here, so they offer the same choices.
///
/// Null when the sheet (or the map) was dismissed without choosing.
Future<SearchOriginPick?> pickSearchOrigin(
  BuildContext context, {
  required SearchOrigin? current,
  required SearchPlaces places,
  required SearchRecentsStore recents,
}) async {
  final label = await places.currentLocationLabel();
  final recentPlaces = await recents.places();
  if (!context.mounted) return null;
  final choice = await showSearchOriginSheet(
    context,
    current: current,
    currentLocationLabel: label,
    recentPlaces: recentPlaces,
    places: places.index(),
  );
  if (choice == null) return null;
  switch (choice) {
    case UseCurrentLocation():
      return const SearchOriginPick(null);
    case UsePlace(:final place):
      await recents.addPlace(place);
      return SearchOriginPick(place);
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
              builder: (_) =>
                  SearchPickOnMapPage(start: start, places: places.index()),
            ),
          );
      return pin == null ? null : SearchOriginPick(pin);
  }
}
