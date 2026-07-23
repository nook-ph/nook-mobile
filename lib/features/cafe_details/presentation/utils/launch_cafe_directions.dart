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

/// Opens the platform maps app with directions to [cafe] and logs the
/// `get_directions` funnel event. Shared by the sticky actions bar and the
/// Location & Contacts section.
Future<void> launchCafeDirections(
  BuildContext context,
  CafeDetailsResult? cafe,
) async {
  final details = cafe?.cafeDetails;
  final platform = Theme.of(context).platform;
  final analytics = sl<AnalyticsService>();
  final cafeId = details?.id;

  if (details == null || cafeId == null || cafeId.isEmpty) {
    showPrimaryToast(context, 'Cafe details are not available yet.');
    return;
  }

  final lat = details.lat;
  final lng = details.lng;

  if (!MapsDirectionsLauncher.hasValidCoordinates(lat, lng)) {
    showPrimaryToast(
      context,
      'Directions are unavailable for this cafe right now.',
    );
    return;
  }

  final mapAppMeta = _mapAppMetadata(platform);
  unawaited(
    analytics.track(
      cafeId,
      AnalyticsService.getDirections,
      metadata: {
        AnalyticsMetadataKeys.latitude: lat,
        AnalyticsMetadataKeys.longitude: lng,
        AnalyticsMetadataKeys.mapApp: mapAppMeta,
        AnalyticsMetadataKeys.screen: 'cafe_details',
      },
    ),
  );

  final label = details.name.isNotEmpty ? details.name : details.locationLabel;
  final launched = await MapsDirectionsLauncher.launchDirections(
    lat: lat,
    lng: lng,
    label: label,
    platform: platform,
  );

  if (!context.mounted) return;
  if (!launched) {
    showPrimaryToast(context, 'Unable to open map directions.');
  }
}
