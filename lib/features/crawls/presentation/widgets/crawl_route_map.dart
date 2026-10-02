import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:nook/features/crawls/domain/entities/crawl.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_widgets.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';

/// The crawl's route on a real map: a non-interactive MapLibre preview fitted
/// to the stops, with the straight-line route and a numbered badge per stop.
///
/// Until the map style is ready (and if it cannot load) the card shows the
/// plain [CrawlRoutePainter] trace instead, so the route is never blank.
class CrawlRouteMap extends StatefulWidget {
  const CrawlRouteMap({super.key, required this.stops, this.height = 180});

  final List<CrawlStop> stops;
  final double height;

  @override
  State<CrawlRouteMap> createState() => _CrawlRouteMapState();
}

class _CrawlRouteMapState extends State<CrawlRouteMap> {
  static const String _fallbackStyle =
      'https://tiles.openfreemap.org/styles/bright';

  /// Badges are rasterised at 3x and drawn at 1/3 so they stay sharp.
  static const double _badgeScale = 3;
  static const double _badgeSize = 24;
  static const double _fitPadding = 30;

  /// One stop, or several stacked on one point, has no bounds to fit.
  static const double _singlePointZoom = 15.5;

  String? _styleJson;
  bool _styleResolved = false;
  bool _mapReady = false;
  final Completer<MapLibreMapController> _controller =
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
          setState(() => _styleResolved = true);
        });
  }

  Future<void> _onStyleLoaded() async {
    final stops = widget.stops;
    if (stops.isEmpty) return;
    try {
      final controller = await _controller.future;
      if (!mounted) return;

      final points = [for (final s in stops) LatLng(s.lat, s.lng)];
      // MapLibre sizes symbol images in physical pixels, so a badge rastered
      // at [_badgeScale] needs the device ratio to land on [_badgeSize].
      final iconSize = MediaQuery.devicePixelRatioOf(context) / _badgeScale;
      await _fit(controller, points);
      if (!mounted) return;

      if (points.length > 1) {
        await controller.addLine(
          LineOptions(
            geometry: points,
            lineColor: '#3A5A40',
            lineWidth: 4,
            lineJoin: 'round',
          ),
        );
      }
      for (var i = 0; i < stops.length; i++) {
        if (!mounted) return;
        final imageId = 'crawl-stop-${i + 1}';
        await controller.addImage(imageId, await _badge(i + 1));
        await controller.addSymbol(
          SymbolOptions(
            geometry: points[i],
            iconImage: imageId,
            iconSize: iconSize,
            // Later stops draw above earlier ones where they overlap.
            zIndex: i,
          ),
        );
      }
      if (mounted) setState(() => _mapReady = true);
    } catch (_) {
      // Style or layer setup can fail after dispose; the painter stays up.
    }
  }

  Future<void> _fit(MapLibreMapController controller, List<LatLng> points) {
    final lats = points.map((p) => p.latitude);
    final lngs = points.map((p) => p.longitude);
    final south = lats.reduce(math.min), north = lats.reduce(math.max);
    final west = lngs.reduce(math.min), east = lngs.reduce(math.max);

    if (north - south < 1e-6 && east - west < 1e-6) {
      return controller.moveCamera(
        CameraUpdate.newLatLngZoom(points.first, _singlePointZoom),
      );
    }
    return controller.moveCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(south, west),
          northeast: LatLng(north, east),
        ),
        left: _fitPadding,
        top: _fitPadding,
        right: _fitPadding,
        bottom: _fitPadding,
      ),
    );
  }

  /// A filled brand circle with a white ring and the stop number.
  static Future<Uint8List> _badge(int number) async {
    const size = _badgeSize * _badgeScale;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const center = Offset(size / 2, size / 2);

    canvas.drawCircle(center, size / 2, Paint()..color = ListsTokens.surface);
    canvas.drawCircle(
      center,
      size / 2 - 2 * _badgeScale,
      Paint()..color = ListsTokens.brand,
    );
    final text = TextPainter(
      text: TextSpan(
        text: '$number',
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11 * _badgeScale,
          fontWeight: FontWeight.w600,
          color: ListsTokens.surface,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, center - Offset(text.width / 2, text.height / 2));

    final image = await recorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    final stops = widget.stops;
    final trace = Container(
      color: crawlTint,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      child: CustomPaint(
        size: Size.infinite,
        painter: CrawlRoutePainter(
          stops: stops,
          lineColor: ListsTokens.score,
          nodeColor: ListsTokens.brand,
          numberColor: ListsTokens.surface,
          nodeRadius: 10,
        ),
      ),
    );

    return Semantics(
      label: 'Map of the route through ${stops.length} stops',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ListsTokens.radius),
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: !_styleResolved || stops.isEmpty
              ? trace
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    RepaintBoundary(
                      child: MapLibreMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(stops.first.lat, stops.first.lng),
                          zoom: 13,
                        ),
                        styleString: _styleJson ?? _fallbackStyle,
                        translucentTextureSurface: true,
                        scrollGesturesEnabled: false,
                        zoomGesturesEnabled: false,
                        rotateGesturesEnabled: false,
                        tiltGesturesEnabled: false,
                        dragEnabled: false,
                        compassEnabled: false,
                        onMapCreated: (c) {
                          if (!_controller.isCompleted) _controller.complete(c);
                        },
                        onStyleLoadedCallback: _onStyleLoaded,
                      ),
                    ),
                    // Covers the map until the route is drawn on it, so the
                    // card never shows tiles without stops.
                    IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: _mapReady ? 0 : 1,
                        duration: const Duration(milliseconds: 200),
                        child: trace,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
