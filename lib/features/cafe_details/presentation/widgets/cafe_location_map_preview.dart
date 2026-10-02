import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:nook/features/map/presentation/utils/map_pin_images.dart';

/// Non-interactive MapLibre preview centered on [lat]/[lng] with the same pin
/// the map page uses: a rating pill when the cafe has reviews, otherwise the
/// static coffee badge.
///
/// The preview sits well below the fold of the details page, and a MapLibre
/// view is a native GL surface with its own style parse and tile downloads.
/// So the map is only created once the preview is about to scroll into view;
/// until then it is the same grey block it shows while the style loads.
class CafeLocationMapPreview extends StatefulWidget {
  const CafeLocationMapPreview({
    super.key,
    required this.lat,
    required this.lng,
    this.rating = 0,
  });

  final double lat;
  final double lng;
  final double rating;

  @override
  State<CafeLocationMapPreview> createState() => _CafeLocationMapPreviewState();
}

class _CafeLocationMapPreviewState extends State<CafeLocationMapPreview> {
  static const double _previewHeight = 180;
  static const double _previewZoom = 15.5;
  static const String _fallbackStyle =
      'https://tiles.openfreemap.org/styles/bright';

  // Match the map page's pin rasterization so the badge renders at an
  // identical size and weight (see `map_page.dart`).
  static const double _pinRasterScale = 3.0;
  static const double _pinSizeBoost = 2.2;

  /// How far below the visible area the preview still counts as near, so the
  /// map has a moment to load before it is scrolled to.
  static const double _leadIn = 300;

  /// The page's scroll position, listened to until the preview comes near.
  ScrollPosition? _scroll;
  bool _nearViewport = false;

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_nearViewport) return;

    final scroll = Scrollable.maybeOf(context)?.position;
    if (scroll == null) {
      // Not in a scroll view: nothing to wait for.
      _nearViewport = true;
      return;
    }
    if (!identical(scroll, _scroll)) {
      _scroll?.removeListener(_checkNearViewport);
      _scroll = scroll..addListener(_checkNearViewport);
    }
    // Where the preview sits is only known once it has been laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkNearViewport());
  }

  @override
  void dispose() {
    _scroll?.removeListener(_checkNearViewport);
    super.dispose();
  }

  void _checkNearViewport() {
    if (_nearViewport || !mounted) return;
    // A scroll position can also notify from inside layout, where neither
    // the render tree nor setState may be touched. Look again after it.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkNearViewport());
      return;
    }
    final scroll = _scroll;
    final box = context.findRenderObject();
    if (scroll == null || box is! RenderBox || !box.attached) return;
    if (!scroll.hasPixels || !scroll.hasViewportDimension) return;

    final viewport = RenderAbstractViewport.maybeOf(box);
    final top = viewport?.getOffsetToReveal(box, 0).offset;
    if (top != null &&
        top > scroll.pixels + scroll.viewportDimension + _leadIn) {
      return;
    }

    scroll.removeListener(_checkNearViewport);
    _scroll = null;
    setState(() => _nearViewport = true);
  }

  Future<void> _onStyleLoaded() async {
    const iconSize = _pinSizeBoost / _pinRasterScale;

    try {
      final controller = await _controllerCompleter.future;
      if (!mounted) return;

      await controller.clearSymbols();
      if (!mounted) return;

      final pinImages = MapPinImages(scale: _pinRasterScale);
      final imageId = await pinImages.registerSingle(controller, widget.rating);
      if (!mounted) return;

      await controller.addSymbol(
        SymbolOptions(
          geometry: LatLng(widget.lat, widget.lng),
          iconImage: imageId,
          iconAnchor: 'center',
          iconSize: iconSize,
        ),
      );
    } catch (_) {
      // Pin or style setup can fail after dispose; ignore.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_styleResolved || !_nearViewport) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: _previewHeight,
          width: double.infinity,
          child: ColoredBox(color: Colors.grey.shade200),
        ),
      );
    }

    final target = LatLng(widget.lat, widget.lng);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: RepaintBoundary(
        child: ClipRect(
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            height: _previewHeight,
            width: double.infinity,
            child: MapLibreMap(
              initialCameraPosition: CameraPosition(
                target: target,
                zoom: _previewZoom,
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
