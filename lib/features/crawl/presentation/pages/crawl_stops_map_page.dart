import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:nook/core/presentation/widgets/app_bar_circle_icon_button.dart';
import 'package:nook/features/crawl/domain/entities/crawl_stop.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';

class CrawlStopsMapPage extends StatefulWidget {
  final String slug;
  final List<CrawlStop> stops;

  const CrawlStopsMapPage({
    super.key,
    required this.slug,
    required this.stops,
  });

  @override
  State<CrawlStopsMapPage> createState() => _CrawlStopsMapPageState();
}

class _CrawlStopsMapPageState extends State<CrawlStopsMapPage> {
  static const String _fallbackStyle =
      'https://tiles.openfreemap.org/styles/bright';

  static const _cebuDefault = LatLng(10.3167, 123.8907);
  static const _cebuDefaultZoom = 9.0;

  bool _styleResolved = false;
  String? _styleJson;
  MapLibreMapController? _mapController;
  final Completer<MapLibreMapController> _controllerCompleter =
      Completer<MapLibreMapController>();

  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/mapstyle.json').then((s) {
      if (mounted) {
        setState(() {
          _styleJson = s;
          _styleResolved = true;
        });
      }
    }).catchError((Object _) {
      if (mounted) {
        setState(() {
          _styleJson = null;
          _styleResolved = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _mapController?.onSymbolTapped.remove(_onSymbolTapped);
    super.dispose();
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

  LatLngBounds _computeBounds() {
    final valid = widget.stops
        .where((s) => s.cafeLat != 0 || s.cafeLng != 0)
        .toList();

    if (valid.isEmpty) {
      return LatLngBounds(
        southwest: LatLng(9.5, 123.0),
        northeast: LatLng(11.5, 124.5),
      );
    }

    if (valid.length == 1) {
      final lat = valid.first.cafeLat;
      final lng = valid.first.cafeLng;
      return LatLngBounds(
        southwest: LatLng(lat - 0.05, lng - 0.05),
        northeast: LatLng(lat + 0.05, lng + 0.05),
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

      if (valid.length >= 2) {
        await controller.moveCamera(
          CameraUpdate.newLatLngBounds(
            _computeBounds(),
            left: 60,
            top: 60,
            right: 60,
            bottom: 60,
          ),
        );
      }
    } catch (_) {}
  }

  void _onSymbolTapped(Symbol symbol) {
    final cafeId = symbol.data?['id'];
    if (cafeId == null) return;
  }

  Future<void> _defaultView() async {
    final c = await _controllerCompleter.future;
    final valid = widget.stops
        .where((s) => s.cafeLat != 0 || s.cafeLng != 0)
        .toList();

    if (valid.length >= 2) {
      await c.moveCamera(
        CameraUpdate.newLatLngBounds(
          _computeBounds(),
          left: 60,
          top: 60,
          right: 60,
          bottom: 60,
        ),
      );
    } else if (valid.length == 1) {
      await c.moveCamera(
        CameraUpdate.newLatLng(LatLng(valid.first.cafeLat, valid.first.cafeLng)),
      );
    } else {
      await c.moveCamera(
        CameraUpdate.newLatLngZoom(_cebuDefault, _cebuDefaultZoom),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leadingWidth: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 22.0),
          child: Center(
            child: AppBarCircleIconButton(
              icon: Icons.arrow_back,
              iconSize: 18,
              onTap: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(
          'Crawl Map',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Stack(
        children: [
          if (!_styleResolved)
            const Center(child: CircularProgressIndicator())
          else
            MapLibreMap(
              initialCameraPosition: _initialCamera(),
              compassEnabled: false,
              styleString: _styleJson ?? _fallbackStyle,
              onMapCreated: (c) {
                _mapController = c;
                if (!_controllerCompleter.isCompleted) {
                  _controllerCompleter.complete(c);
                }
                c.onSymbolTapped.add(_onSymbolTapped);
              },
              onStyleLoadedCallback: _onStyleLoaded,
            ),
          if (_styleResolved)
            Positioned(
              right: 16,
              bottom: 32,
              child: FloatingActionButton(
                backgroundColor: Colors.white,
                foregroundColor: Theme.of(context).colorScheme.primary100,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Colors.white, width: 1.5),
                ),
                onPressed: _defaultView,
                child: const Icon(Icons.my_location),
              ),
            ),
        ],
      ),
    );
  }
}
