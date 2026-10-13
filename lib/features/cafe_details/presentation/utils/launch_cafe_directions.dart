import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nook/core/analytics/analytics_service.dart';
import 'package:nook/core/utils/maps_directions_launcher.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/cafe_details/domain/use_cases/get_cafe_details_usecase.dart';
import 'package:nook/injection_container.dart';

String _mapAppMetadata(TargetPlatform platform) {
  return platform == TargetPlatform.iOS ? 'apple_maps' : 'google_maps';
}

/// Where a directions tap came from, for the `source` property.
abstract final class DirectionsSource {
  static const actionsBar = 'actions_bar';
  static const location = 'location_section';
}

/// `directions_failed` — a directions tap that opened no maps app.
/// Properties: `reason` (`no_details`, `no_coordinates`, `launch_failed`),
/// `source`, `handoff_ms` when a launch was tried. Kept apart from
/// `directions_tapped`, which owner reporting counts as conversions.
const String directionsFailedEvent = 'directions_failed';

/// True while a maps hand-off is in flight. Opening the maps app can take a
/// second or more (the app is looked up first); taps in that window used to
/// queue more launches, and read as a dead button.
bool _launching = false;

/// Opens the platform maps app with directions to [cafe] and logs the
/// `get_directions` funnel event. Shared by the sticky actions bar and the
/// Location & Contacts section ([source]).
Future<void> launchCafeDirections(
  BuildContext context,
  CafeDetailsResult? cafe, {
  String source = DirectionsSource.actionsBar,
}) async {
  if (_launching) return;

  final details = cafe?.cafeDetails;
  final platform = Theme.of(context).platform;
  final analytics = sl<AnalyticsService>();
  final cafeId = details?.id;

  void failed(String reason, {int? handoffMs}) {
    unawaited(
      analytics.logEvent(
        directionsFailedEvent,
        properties: {
          'cafe_id': ?cafeId,
          'reason': reason,
          'source': source,
          'handoff_ms': ?handoffMs,
        },
      ),
    );
  }

  if (details == null || cafeId == null || cafeId.isEmpty) {
    failed('no_details');
    showPrimaryToast(context, 'Cafe details are not available yet.');
    return;
  }

  final lat = details.lat;
  final lng = details.lng;

  if (!MapsDirectionsLauncher.hasValidCoordinates(lat, lng)) {
    failed('no_coordinates');
    showPrimaryToast(
      context,
      'Directions are unavailable for this cafe right now.',
    );
    return;
  }

  final label = details.name.isNotEmpty ? details.name : details.locationLabel;
  final watch = Stopwatch()..start();
  _launching = true;
  final bool launched;
  try {
    launched = await MapsDirectionsLauncher.launchDirections(
      lat: lat,
      lng: lng,
      label: label,
      platform: platform,
    );
  } finally {
    _launching = false;
  }
  final handoffMs = watch.elapsedMilliseconds;

  if (!launched) {
    failed('launch_failed', handoffMs: handoffMs);
    if (!context.mounted) return;
    showPrimaryToast(context, 'Unable to open map directions.');
    return;
  }

  // Counted only once a maps app actually opened.
  unawaited(
    analytics.track(
      cafeId,
      AnalyticsService.getDirections,
      metadata: {
        AnalyticsMetadataKeys.latitude: lat,
        AnalyticsMetadataKeys.longitude: lng,
        AnalyticsMetadataKeys.mapApp: _mapAppMetadata(platform),
        AnalyticsMetadataKeys.screen: 'cafe_details',
        'source': source,
        'handoff_ok': true,
        'handoff_ms': handoffMs,
      },
    ),
  );
}
