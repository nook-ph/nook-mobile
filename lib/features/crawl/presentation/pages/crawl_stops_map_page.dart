import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/presentation/widgets/app_bar_circle_icon_button.dart';
import 'package:nook/core/presentation/widgets/cafe_overlay_card.dart';
import 'package:nook/core/presentation/widgets/slide_up_overlay.dart';
import 'package:nook/features/crawl/domain/entities/crawl_stop.dart';
import 'package:nook/features/crawl/presentation/cubit/crawl_stops_map_cubit.dart';
import 'package:nook/features/crawl/presentation/cubit/crawl_stops_map_state.dart';
import 'package:nook/features/map/domain/use_cases/get_cafe_cards_usecase.dart';
import 'package:nook/injection_container.dart';
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

  static const double _overlaySpacing = 16.0;

  bool _styleResolved = false;
  String? _styleJson;
  MapLibreMapController? _mapController;
  final Completer<MapLibreMapController> _controllerCompleter =
      Completer<MapLibreMapController>();

  Map<String, CafeSummary> _cafeById = {};
  CafeSummary? _selectedCafe;
  Symbol? _selectedSymbol;
  bool _overlayDismissed = false;

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
          {'id': stop.cafeId},
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

    if (_selectedSymbol != null && _selectedSymbol!.id != symbol.id) {
      _mapController?.updateSymbol(
        _selectedSymbol!,
        const SymbolOptions(iconSize: 0.17),
      );
    }
    _mapController?.updateSymbol(symbol, const SymbolOptions(iconSize: 0.23));
    _selectedSymbol = symbol;

    final selectedCafe = _cafeById[cafeId];
    if (selectedCafe == null) return;

    setState(() {
      _selectedCafe = selectedCafe;
      _overlayDismissed = false;
    });
  }

  void _dismissOverlay() {
    if (_overlayDismissed) return;
    if (_selectedSymbol != null) {
      _mapController?.updateSymbol(
        _selectedSymbol!,
        const SymbolOptions(iconSize: 0.17),
      );
    }
    setState(() {
      _overlayDismissed = true;
      _selectedSymbol = null;
    });
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
    return BlocProvider(
      create: (_) => CrawlStopsMapCubit(sl<GetCafeCardUseCase>())
        ..loadCafes(widget.stops),
      child: BlocListener<CrawlStopsMapCubit, CrawlStopsMapState>(
        listener: (context, state) {
          if (state is CrawlStopsMapLoaded) {
            setState(() => _cafeById = state.cafeById);
          }
        },
        child: Scaffold(
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
              Positioned(
                left: 16,
                right: 16,
                bottom: 90 + _overlaySpacing,
                child: SlideUpOverlay(
                  visible: _selectedCafe != null && !_overlayDismissed,
                  child: _selectedCafe != null
                      ? CafeOverlayCard(
                          key: ValueKey(_selectedCafe!.id),
                          cafe: _selectedCafe!,
                          onClose: _dismissOverlay,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
