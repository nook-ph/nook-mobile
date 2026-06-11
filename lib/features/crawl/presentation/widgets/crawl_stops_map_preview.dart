import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:nook/features/crawl/domain/entities/crawl_stop.dart';

class CrawlStopsMapPreview extends StatefulWidget {
  final List<CrawlStop> stops;

  const CrawlStopsMapPreview({super.key, required this.stops});

  @override
  State<CrawlStopsMapPreview> createState() => _CrawlStopsMapPreviewState();
}

class _CrawlStopsMapPreviewState extends State<CrawlStopsMapPreview> {
  static const double _previewHeight = 220;
  static const String _fallbackStyle =
      'https://tiles.openfreemap.org/styles/bright';

  static const _cebuDefault = LatLng(10.3167, 123.8907);
  static const _cebuDefaultZoom = 9.0;

  bool _styleResolved = false;
  String? _styleJson;
  final Completer<MapLibreMapController> _controllerCompleter =
      Completer<MapLibreMapController>();

  @override
  void initState() {
    super.initState();
    rootBundle
        .loadString('assets/mapstyle.json')
        .then((s) {
          if (!mounted) return;
          setState(() {
            _styleJson = s;
            _styleResolved = true;
          });
        })
        .catchError((Object _) {
          if (!mounted) return;
          setState(() {
            _styleJson = null;
            _styleResolved = true;
          });
        });
  }

  LatLngBounds _computeBounds() {
    final valid = widget.stops
        .where((s) => s.cafeLat != 0 || s.cafeLng != 0)
        .toList();

    if (valid.isEmpty) {
      return LatLngBounds(
        southwest: LatLng(10.0, 123.5),
        northeast: LatLng(10.6, 124.2),
      );
    }

    if (valid.length == 1) {
      final lat = valid.first.cafeLat;
      final lng = valid.first.cafeLng;
      return LatLngBounds(
        southwest: LatLng(lat - 0.01, lng - 0.01),
        northeast: LatLng(lat + 0.01, lng + 0.01),
      );
    }

    double minLat = double.infinity, maxLat = double.negativeInfinity;
    double minLng = double.infinity, maxLng = double.negativeInfinity;

    for (final s in valid) {
      minLat = min(minLat, s.cafeLat);
      maxLat = max(maxLat, s.cafeLat);
      minLng = min(minLng, s.cafeLng);
      maxLng = max(maxLng, s.cafeLng);
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  CameraPosition _initialCamera() {
    final valid = widget.stops
        .where((s) => s.cafeLat != 0 || s.cafeLng != 0)
        .toList();

    if (valid.isEmpty) {
      return const CameraPosition(
        target: _cebuDefault,
        zoom: _cebuDefaultZoom,
      );
    }

    if (valid.length == 1) {
      return CameraPosition(
        target: LatLng(valid.first.cafeLat, valid.first.cafeLng),
        zoom: 13.0,
      );
    }

    double minLat = double.infinity, maxLat = double.negativeInfinity;
    double minLng = double.infinity, maxLng = double.negativeInfinity;

    for (final s in valid) {
      minLat = min(minLat, s.cafeLat);
      maxLat = max(maxLat, s.cafeLat);
      minLng = min(minLng, s.cafeLng);
      maxLng = max(maxLng, s.cafeLng);
    }

    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;

    final latSpan = maxLat - minLat;
    final lngSpan = maxLng - minLng;
    final maxSpan = max(latSpan, lngSpan);

    double zoom;
    if (maxSpan <= 0.02) {
      zoom = 13.0;
    } else if (maxSpan <= 0.05) {
      zoom = 12.0;
    } else if (maxSpan <= 0.15) {
      zoom = 11.0;
    } else if (maxSpan <= 0.4) {
      zoom = 10.0;
    } else {
      zoom = 9.0;
    }

    return CameraPosition(
      target: LatLng(centerLat, centerLng),
      zoom: zoom,
    );
  }

  Future<void> _onStyleLoaded() async {
    try {
      final controller = await _controllerCompleter.future;
      if (!mounted) return;

      await controller.clearSymbols();
      if (!mounted) return;

      final ByteData bytes = await rootBundle.load('assets/images/MapPin.png');
      if (!mounted) return;
      await controller.addImage('map_pin', bytes.buffer.asUint8List());
      if (!mounted) return;

      final valid = widget.stops
          .where((s) => s.cafeLat != 0 || s.cafeLng != 0)
          .toList();

      for (final stop in valid) {
        await controller.addSymbol(
          SymbolOptions(
            geometry: LatLng(stop.cafeLat, stop.cafeLng),
            iconImage: 'map_pin',
            iconSize: 0.17,
          ),
        );
      }

      await controller.symbolManager?.setIconAllowOverlap(true);

      if (valid.length >= 2) {
        await controller.moveCamera(
          CameraUpdate.newLatLngBounds(
            _computeBounds(),
            left: 40,
            top: 20,
            right: 40,
            bottom: 20,
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (!_styleResolved) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: _previewHeight,
          width: double.infinity,
          child: ColoredBox(color: Colors.grey.shade200),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: RepaintBoundary(
        child: ClipRect(
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            height: _previewHeight,
            width: double.infinity,
            child: MapLibreMap(
              initialCameraPosition: _initialCamera(),
              styleString: _styleJson ?? _fallbackStyle,
              translucentTextureSurface: true,
              scrollGesturesEnabled: false,
              zoomGesturesEnabled: false,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
              dragEnabled: false,
              compassEnabled: false,
              onMapCreated: (c) {
                if (!_controllerCompleter.isCompleted) {
                  _controllerCompleter.complete(c);
                }
              },
              onStyleLoadedCallback: _onStyleLoaded,
            ),
          ),
        ),
      ),
    );
  }
}
