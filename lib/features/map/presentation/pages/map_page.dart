import 'dart:async';
import 'dart:math' show Point;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:flutter/services.dart' show PlatformException, rootBundle;
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';
import 'package:nook/features/map/presentation/widgets/bottom_modal_sheet.dart';
import 'package:nook/features/map/presentation/widgets/cafe_overlay_card.dart';
import 'package:nook/features/map/presentation/widgets/map_updating_chip.dart';
import 'package:nook/features/map/presentation/utils/map_fit_padding.dart';
import 'package:nook/features/map/presentation/utils/map_pin_images.dart';
import 'package:nook/features/map/bloc/map_bloc.dart';
import 'package:nook/features/map/bloc/map_event.dart';
import 'package:nook/features/map/bloc/map_states.dart';
import 'package:nook/injection_container.dart';
import 'package:nook/core/preferences/location_prompt_store.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/filters/cubit/filter_cubit.dart';
import 'package:nook/core/filters/models/cafe_filter.dart';
import 'package:nook/core/utils/geo.dart' as geo;
import 'package:nook/features/search/presentation/widgets/search_entry_button.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/core/utils/error_info.dart';
import 'package:nook/core/widgets/error/full_page_error_widget.dart';
import 'package:nook/core/bloc/features/navigation/bloc/navigation_bloc.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final _controllerCompleter = Completer<MapLibreMapController>();

  /// On the map's own render box, not the page's: the fit has to be measured
  /// against the rectangle MapLibre actually draws into, which is shorter than
  /// the screen by the bottom navigation bar.
  final _mapBoxKey = GlobalKey();
  String? _styleJson;
  MapLibreMapController? _mapController;
  MapBloc? _mapBloc;
  bool _styleLoaded = false;
  late final CafeFilter _initialFilter;

  /// Pin selection + overlay animation state. Held in a [ValueNotifier] so
  /// tapping a pin rebuilds only the overlay card (via [ValueListenableBuilder])
  /// instead of the whole page — the map platform view, the sliding sheet, and
  /// its cafe list all stay untouched on the tap frame.
  final _selection = ValueNotifier<_MapSelection>(const _MapSelection());

  bool _myLocationEnabled = false;

  static bool _hasRequestedPermission = false;

  final _sheetMetrics = ValueNotifier<BottomSheetMetrics?>(null);

  Map<String, CafeSummary> _cafeById = {};

  // Pin rendering state — one GeoJSON source + style layers (see
  // docs/plans/map-refactor.md and the webapp's CafeMap.tsx).
  MapPinImages? _pinImages;
  bool _layersAdded = false;
  bool _cameraFitted = false;
  List<CafeSummary>? _lastSyncedCafes;
  Future<void> _syncQueue = Future.value();

  static const double _overlaySpacing = 16.0;

  static const _cafeSourceId = 'cafes';
  static const _dotLayerId = 'cafe-dots';
  static const _pillLayerId = 'cafe-pills';
  static const _selectedPillLayerId = 'cafe-pills-selected';
  static const _selectedCoffeeLayerId = 'cafe-coffee-selected';
  static const _pinLayerIds = [
    _dotLayerId,
    _pillLayerId,
    _selectedPillLayerId,
    _selectedCoffeeLayerId,
  ];

  static const double _selectedPillScale = 1.16;

  /// Rated pins are supersampled at this factor for crisp rendering.
  static const double _pinRasterScale = 3.0;

  /// Enlarges the rendered pins above their logical raster size. Stays well
  /// under [_pinRasterScale] so icons keep downsampling (crisp, not blurry).
  static const double _pinSizeBoost = 2.2;

  /// Matches nothing — the resting filter for the selected-pin layers.
  static const _noSelectionFilter = [
    '==',
    ['get', 'id'],
    '',
  ];

  /// Dots only render for unrated cafes: a rated cafe shows its pill instead,
  /// so a dot beneath it would be redundant.
  static const _dotBaseFilter = [
    '<=',
    ['get', 'ratingNumber'],
    0,
  ];

  static const _initial = CameraPosition(
    target: LatLng(10.3167, 123.8907),
    zoom: 10,
  );

  /// icon-size that renders a [_pinRasterScale]x raster at logical size.
  /// Both platforms register images in raw pixels treated as density-
  /// independent units, so the raster scale is the only compensation needed.
  double get _pillIconSize => _pinSizeBoost / _pinRasterScale;

  @override
  void initState() {
    super.initState();
    _initialFilter = sl<FilterCubit>().state;
    rootBundle.loadString('assets/mapstyle.json').then((s) {
      if (mounted) setState(() => _styleJson = s);
    });
    _syncLocationEnabledFromPermission();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final navBloc = context.read<NavigationBloc>();
        if (navBloc.state.tabIndex == 1) {
          _maybeRequestPermissionOnce();
        }
      } catch (_) {
        // NavigationBloc not available in this context; nothing to do.
      }
    });
  }

  Future<void> _maybeRequestPermissionOnce() async {
    if (_hasRequestedPermission) return;
    _hasRequestedPermission = true;

    final store = sl<LocationPromptStore>();
    if (await store.hasRequested()) return;
    await store.markRequested();

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        return;
      }
      await Geolocator.requestPermission();
    } catch (_) {
      // Best-effort: the user can re-enable via Settings.
    }
  }

  Future<void> _syncLocationEnabledFromPermission() async {
    try {
      final permission = await Geolocator.checkPermission();
      final granted =
          permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
      if (!mounted) return;
      if (granted != _myLocationEnabled) {
        setState(() => _myLocationEnabled = granted);
      }
    } catch (_) {
      // Best-effort: leave myLocationEnabled at its default (false).
    }
  }

  @override
  void dispose() {
    sl<FilterCubit>().reset();
    _mapController?.onFeatureTapped.remove(_onCafeFeatureTapped);
    _sheetMetrics.dispose();
    _selection.dispose();
    super.dispose();
  }

  void _onSheetMetricsChanged(BottomSheetMetrics metrics) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _sheetMetrics.value = metrics;
    });
  }

  bool get _isSheetExpanded {
    final m = _sheetMetrics.value;
    if (m == null) return false;
    return m.extent > m.minExtent + 0.01;
  }

  bool get _shouldShowOverlay {
    final m = _sheetMetrics.value;
    final sel = _selection.value;
    return sel.cafe != null &&
        !sel.dismissed &&
        !_isSheetExpanded &&
        (m?.topFromBottom ?? 0.0) > 0;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<MapBloc>()
        ..add(LoadMapDataEvent(filter: _initialFilter))
        ..add(LoadFilterTagsEvent()),
      child: Scaffold(
        body: BlocConsumer<MapBloc, MapState>(
          listener: (context, state) {
            if (state is MapLoadedState) {
              _cafeById = {for (final c in state.cafes) c.id: c};
              _refreshSelectionFrom(state.cafes);
              if (_styleLoaded) {
                _queueSyncMapData(state.cafes);
              }
            }
          },
          builder: (context, state) {
            _mapBloc = context.read<MapBloc>();
            return Stack(
              children: [
                if (_styleJson != null)
                  MapLibreMap(
                    key: _mapBoxKey,
                    initialCameraPosition: _initial,
                    compassEnabled: false,
                    trackCameraPosition: true,
                    myLocationEnabled: _myLocationEnabled,
                    myLocationRenderMode: MyLocationRenderMode.normal,
                    myLocationTrackingMode: MyLocationTrackingMode.none,
                    styleString: _styleJson!,
                    onMapCreated: (c) {
                      _mapController = c;
                      _controllerCompleter.complete(c);
                      c.onFeatureTapped.add(_onCafeFeatureTapped);
                    },
                    onCameraIdle: _onCameraIdle,
                    onStyleLoadedCallback: () {
                      if (!mounted) return;
                      setState(() => _styleLoaded = true);
                      final s = context.read<MapBloc>().state;
                      if (s is MapLoadedState) {
                        _queueSyncMapData(s.cafes);
                      }
                    },
                  )
                else
                  const Center(child: CircularProgressIndicator()),

                if (_styleLoaded)
                  Positioned(
                    right: 16,
                    bottom: 90,
                    child: FloatingActionButton(
                      heroTag: 'fab-map-recenter',
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

                ValueListenableBuilder<BottomSheetMetrics?>(
                  valueListenable: _sheetMetrics,
                  builder: (context, metrics, _) {
                    return ValueListenableBuilder<_MapSelection>(
                      valueListenable: _selection,
                      builder: (context, selection, _) {
                        final topFromBottom = metrics?.topFromBottom ?? 0.0;
                        final extent = metrics?.extent ?? 0.0;
                        final minExtent = metrics?.minExtent ?? 0.0;
                        final isExpanded = extent > minExtent + 0.01;
                        final cafe = selection.cafe;
                        final shouldShow =
                            cafe != null &&
                            !selection.dismissed &&
                            !isExpanded &&
                            topFromBottom > 0;

                        final animateOverlayIn =
                            shouldShow && !selection.suppressAnimation;
                        final animateOverlay =
                            animateOverlayIn || selection.animateDismiss;

                        return Positioned(
                          left: 16,
                          right: 16,
                          bottom: topFromBottom + _overlaySpacing,
                          child: AnimatedSwitcher(
                            duration: animateOverlay
                                ? const Duration(milliseconds: 260)
                                : Duration.zero,
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) {
                              if (!animateOverlay) return child;
                              final isExiting =
                                  animation.status == AnimationStatus.reverse;
                              final offsetAnimation = isExiting
                                  ? Tween<Offset>(
                                      begin: Offset.zero,
                                      end: const Offset(0, 1.1),
                                    ).animate(ReverseAnimation(animation))
                                  : Tween<Offset>(
                                      begin: const Offset(0, 1.1),
                                      end: Offset.zero,
                                    ).animate(animation);
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: offsetAnimation,
                                  child: child,
                                ),
                              );
                            },
                            child: shouldShow
                                ? CafeOverlayCard(
                                    key: ValueKey(cafe.id),
                                    cafe: cafe,
                                    onClose: _dismissOverlay,
                                  )
                                : const SizedBox.shrink(),
                          ),
                        );
                      },
                    );
                  },
                ),

                if (_styleLoaded)
                  Positioned(
                    top: SearchEntryButton.mapBottomSheetTop(context),
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: state is MapLoadingState
                        ? BottomModalSheet(
                            cafes: const [],
                            tags: const [],
                            isLoadingCafes: true,
                            onMetricsChanged: _onSheetMetricsChanged,
                          )
                        : state is MapLoadedState
                        ? BottomModalSheet(
                            cafes: state.cafes,
                            tags: state.tags,
                            isLoadingCafes: false,
                            onMetricsChanged: _onSheetMetricsChanged,
                          )
                        : state is MapError
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Builder(
                                builder: (ctx) {
                                  final info = AppErrorCopy.fromException(
                                    state.error,
                                  );
                                  final filter = ctx.read<FilterCubit>().state;
                                  return FullPageErrorWidget(
                                    error: info,
                                    onRetry:
                                        info.type == ErrorType.sessionExpired
                                        ? () => ctx.push('/login')
                                        : () => ctx.read<MapBloc>().add(
                                            LoadMapDataEvent(filter: filter),
                                          ),
                                  );
                                },
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                // Floating "Updating" chip while a viewport refetch runs.
                Positioned(
                  top: SearchEntryButton.mapBottomSheetTop(context),
                  left: 0,
                  right: 0,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: state is MapLoadedState && state.isRefreshing
                          ? const MapUpdatingChip()
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),

                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(22, 8, 22, 0),
                          child: SearchEntryButton(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- Viewport-driven fetching -------------------------------------------

  void _onCameraIdle() {
    final controller = _mapController;
    if (controller == null || !_styleLoaded) return;
    unawaited(_emitViewport(controller));
  }

  Future<void> _emitViewport(MapLibreMapController controller) async {
    try {
      final region = await controller.getVisibleRegion();
      final camera = controller.cameraPosition;
      if (!mounted) return;
      final center =
          camera?.target ??
          LatLng(
            (region.southwest.latitude + region.northeast.latitude) / 2,
            (region.southwest.longitude + region.northeast.longitude) / 2,
          );
      _mapBloc?.add(
        MapViewportChangedEvent(
          geo.MapViewport(
            center: geo.GeoPoint(lat: center.latitude, lng: center.longitude),
            bounds: geo.MapBounds(
              north: region.northeast.latitude,
              east: region.northeast.longitude,
              south: region.southwest.latitude,
              west: region.southwest.longitude,
            ),
            zoom: camera?.zoom ?? 0,
          ),
        ),
      );
    } catch (_) {
      // Visible region unavailable (e.g. map tearing down) — skip this tick.
    }
  }

  // --- Pin rendering --------------------------------------------------------

  /// Serializes data syncs so source/layer setup never races a data update.
  void _queueSyncMapData(List<CafeSummary> cafes) {
    if (identical(_lastSyncedCafes, cafes)) return;
    _lastSyncedCafes = cafes;
    _syncQueue = _syncQueue.then((_) => _syncMapData(cafes));
  }

  Future<void> _syncMapData(List<CafeSummary> cafes) async {
    final controller = await _controllerCompleter.future;
    if (!mounted) return;

    final validCafes = cafes
        .where((c) => c.lat != null && c.lng != null)
        .toList();

    _pinImages ??= MapPinImages(scale: _pinRasterScale);
    try {
      await _pinImages!.ensureImages(controller, validCafes);

      final geojson = _featureCollection(validCafes);
      if (_layersAdded) {
        await controller.setGeoJsonSource(_cafeSourceId, geojson);
      } else {
        await _addSourceAndLayers(controller, geojson);
        _layersAdded = true;
      }
    } catch (_) {
      // Style went away mid-update (page tear-down); nothing to render.
      return;
    }

    if (!_cameraFitted) {
      _cameraFitted = await _fitCameraToCafes(controller, validCafes);
    }
  }

  Future<void> _addSourceAndLayers(
    MapLibreMapController controller,
    Map<String, dynamic> geojson,
  ) async {
    await controller.addGeoJsonSource(_cafeSourceId, geojson, promoteId: 'id');

    // Unrated cafes render a dot; rated cafes render a pill (no dot) instead.
    await controller.addCircleLayer(
      _cafeSourceId,
      _dotLayerId,
      const CircleLayerProperties(
        circleRadius: 4,
        circleColor: '#2D6A4F',
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 1.25,
        circleOpacity: 0.95,
      ),
      filter: _dotBaseFilter,
    );

    // Rating pills compete for space: overlap is disallowed and the sort key
    // prefers the highest-rated (then most-reviewed) cafe, so in dense areas
    // only the best pill wins.
    await controller.addSymbolLayer(
      _cafeSourceId,
      _pillLayerId,
      SymbolLayerProperties(
        iconImage: ['get', 'pillIcon'],
        iconAnchor: 'bottom',
        iconAllowOverlap: false,
        iconIgnorePlacement: false,
        iconSize: _pillIconSize,
        symbolSortKey: [
          '-',
          [
            '+',
            [
              '*',
              ['get', 'ratingNumber'],
              1000,
            ],
            ['get', 'reviewCount'],
          ],
        ],
      ),
      filter: [
        '>',
        ['get', 'ratingNumber'],
        0,
      ],
    );

    // Selected-pin layers: an enlarged duplicate pinned to the selected id
    // via setFilter (maplibre_gl has no setFeatureState). Rated cafes grow
    // their pill; unrated ones get the coffee badge.
    await controller.addSymbolLayer(
      _cafeSourceId,
      _selectedPillLayerId,
      SymbolLayerProperties(
        iconImage: ['get', 'pillIcon'],
        iconAnchor: 'bottom',
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
        iconSize: _pillIconSize * _selectedPillScale,
      ),
      filter: _noSelectionFilter,
    );
    await controller.addSymbolLayer(
      _cafeSourceId,
      _selectedCoffeeLayerId,
      SymbolLayerProperties(
        iconImage: MapPinImages.coffeeImageId,
        iconAnchor: 'bottom',
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
        iconSize: _pillIconSize,
      ),
      filter: _noSelectionFilter,
    );
  }

  Map<String, dynamic> _featureCollection(List<CafeSummary> cafes) {
    return {
      'type': 'FeatureCollection',
      'features': [
        for (final cafe in cafes)
          {
            'type': 'Feature',
            'id': cafe.id,
            'geometry': {
              'type': 'Point',
              'coordinates': [cafe.lng, cafe.lat],
            },
            'properties': {
              'id': cafe.id,
              'ratingNumber': cafe.rating,
              'reviewCount': cafe.reviewCount,
              'pillIcon': MapPinImages.pillIconFor(cafe),
            },
          },
      ],
    };
  }

  /// Height of the map the sheet is sitting on top of, in logical pixels.
  ///
  /// Metrics arrive from a post-frame callback, so on the very first fit they
  /// can still be null — fall back to the sheet's resting fraction rather than
  /// treating the map as fully visible.
  double get _sheetOcclusion {
    final measured = _sheetMetrics.value?.topFromBottom;
    if (measured != null && measured > 0) return measured;
    return MediaQuery.sizeOf(context).height * 0.45;
  }

  /// The map's laid-out size, or null before it has one.
  ///
  /// [_sheetOcclusion] falls back to a fraction of the *screen*, which is
  /// taller than the map by the bottom navigation bar — so the padding built
  /// from it has to be checked against this, not against MediaQuery.
  Size? get _mapViewportSize {
    final box = _mapBoxKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.size.isEmpty ? null : box.size;
  }

  /// Returns whether the camera was actually moved, so the one-shot fit is
  /// not spent on a sync that arrived before the map had a size.
  Future<bool> _fitCameraToCafes(
    MapLibreMapController controller,
    List<CafeSummary> cafes,
  ) async {
    if (cafes.isEmpty) return false;

    // The map is built on every tab (MainScreen keeps all four in an
    // IndexedStack), so this can run while it has never been laid out. There
    // is no viewport to fit into yet, and guessing one is what crashed.
    final viewport = _mapViewportSize;
    if (viewport == null) return false;

    var minLat = cafes.first.lat!, maxLat = cafes.first.lat!;
    var minLng = cafes.first.lng!, maxLng = cafes.first.lng!;
    for (final cafe in cafes) {
      if (cafe.lat! < minLat) minLat = cafe.lat!;
      if (cafe.lat! > maxLat) maxLat = cafe.lat!;
      if (cafe.lng! < minLng) minLng = cafe.lng!;
      if (cafe.lng! > maxLng) maxLng = cafe.lng!;
    }

    if (cafes.length == 1) {
      // Give a lone pin a box so the padding below applies to it too —
      // newLatLngZoom would centre it in the full viewport, i.e. behind the
      // sheet. ~450m each way lands around the old zoom of 15.5.
      const delta = 0.004;
      minLat -= delta;
      maxLat += delta;
      minLng -= delta;
      maxLng += delta;
    }

    // Web Mercator has no latitude past ~85.05, and the delta above can push a
    // single far-north cafe over it. An out-of-range bound is the other way
    // this call aborts the process.
    minLat = minLat.clamp(-85.0, 85.0);
    maxLat = maxLat.clamp(-85.0, 85.0);
    minLng = minLng.clamp(-180.0, 180.0);
    maxLng = maxLng.clamp(-180.0, 180.0);

    // The sheet covers the bottom half of the map. Fitting to the *whole*
    // viewport therefore parks every pin behind it, and the strip the user can
    // actually see shows empty coastline north of the metro — which reads as
    // "54 cafes in view" next to a map with nothing on it.
    //
    // But that bottom inset is only ever a request. Padding taller than the
    // map leaves MapLibre solving for a negative viewport, and it throws a C++
    // exception out of setCamera that kills the process rather than the call
    // (see resolveMapFitPadding). So fit the request to the map first.
    final padding = resolveMapFitPadding(
      viewport: viewport,
      left: 40,
      top: 60,
      right: 40,
      bottom: _sheetOcclusion + 24,
    );

    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          left: padding.left,
          top: padding.top,
          right: padding.right,
          bottom: padding.bottom,
        ),
      );
    } on PlatformException {
      // Style or platform view went away mid-fit (page tear-down).
      return false;
    }

    return true;
  }

  // --- Selection ------------------------------------------------------------

  void _onCafeFeatureTapped(
    Point<double> point,
    LatLng coordinates,
    String id,
    String layerId,
    Annotation? annotation,
  ) {
    if (!_pinLayerIds.contains(layerId)) return;

    final selectedCafe = _cafeById[id];
    if (selectedCafe == null) return;

    unawaited(_applySelectionFilters(selectedCafe.id));

    final wasVisible = _shouldShowOverlay;
    // Only the overlay's ValueListenableBuilder listens to this — the map,
    // sheet, and cafe list are not rebuilt on tap.
    _selection.value = _MapSelection(
      cafe: selectedCafe,
      suppressAnimation: wasVisible,
    );

    if (wasVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final s = _selection.value;
        if (s.suppressAnimation) {
          _selection.value = s.copyWith(suppressAnimation: false);
        }
      });
    }
  }

  Future<void> _applySelectionFilters(String? cafeId) async {
    final controller = _mapController;
    if (controller == null || !_layersAdded) return;

    final idFilter = cafeId == null
        ? _noSelectionFilter
        : [
            '==',
            ['get', 'id'],
            cafeId,
          ];
    try {
      // Fire all three concurrently: they target independent layers and the
      // native side applies them in order regardless, so awaiting each in turn
      // just adds serial platform-channel round-trips to the pin-enlarge.
      await Future.wait([
        // A pressed unrated cafe shows the coffee badge, so drop its dot too.
        controller.setFilter(
          _dotLayerId,
          cafeId == null
              ? _dotBaseFilter
              : [
                  'all',
                  _dotBaseFilter,
                  [
                    '!=',
                    ['get', 'id'],
                    cafeId,
                  ],
                ],
        ),
        controller.setFilter(_selectedPillLayerId, [
          'all',
          idFilter,
          [
            '>',
            ['get', 'ratingNumber'],
            0,
          ],
        ]),
        controller.setFilter(_selectedCoffeeLayerId, [
          'all',
          idFilter,
          [
            '<=',
            ['get', 'ratingNumber'],
            0,
          ],
        ]),
      ]);
    } catch (_) {
      // Layers gone (style reload/teardown); selection styling is cosmetic.
    }
  }

  /// After a viewport refetch, keep the selection alive if the cafe is still
  /// in view; otherwise clear it (and its enlarged pin).
  void _refreshSelectionFrom(List<CafeSummary> cafes) {
    final selected = _selection.value.cafe;
    if (selected == null) return;
    CafeSummary? refreshed;
    for (final cafe in cafes) {
      if (cafe.id == selected.id) {
        refreshed = cafe;
        break;
      }
    }
    if (refreshed != null) {
      _selection.value = _selection.value.copyWith(cafe: refreshed);
      return;
    }
    _selection.value = const _MapSelection();
    unawaited(_applySelectionFilters(null));
  }

  void _dismissOverlay() {
    if (_selection.value.dismissed) return;
    unawaited(_applySelectionFilters(null));
    _selection.value = _selection.value.copyWith(
      dismissed: true,
      animateDismiss: true,
    );
    Future.delayed(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      if (_selection.value.animateDismiss) {
        _selection.value = _selection.value.copyWith(animateDismiss: false);
      }
    });
  }

  // --- Location -------------------------------------------------------------

  Future<void> _defaultView() async {
    await _requestLocationAccess();
  }

  Future<void> _requestLocationAccess() async {
    final permission = await Geolocator.checkPermission();
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Turn on Location Services to center the map on you.',
            ),
          ),
        );
        return;
      }
      await _enterTrackingMode();
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return;
    }

    final updated = await Geolocator.requestPermission();
    if (!mounted) return;
    if (updated == LocationPermission.whileInUse ||
        updated == LocationPermission.always) {
      setState(() => _myLocationEnabled = true);
      if (await Geolocator.isLocationServiceEnabled()) {
        await _enterTrackingMode();
        if (!mounted) return;
        _mapBloc?.add(LoadMapDataEvent(filter: _initialFilter));
      }
    }
  }

  Future<void> _enterTrackingMode() async {
    final c = await _controllerCompleter.future;
    await c.updateMyLocationTrackingMode(MyLocationTrackingMode.tracking);
  }
}

/// Immutable pin-selection + overlay-animation state driven through a
/// [ValueNotifier] so selection changes rebuild only the overlay card.
class _MapSelection {
  const _MapSelection({
    this.cafe,
    this.dismissed = false,
    this.suppressAnimation = false,
    this.animateDismiss = false,
  });

  /// Currently selected cafe, or null when nothing is selected.
  final CafeSummary? cafe;

  /// The user closed the overlay for [cafe] (pin stays selected on the map).
  final bool dismissed;

  /// Skip the slide/fade-in (used when re-selecting while already visible).
  final bool suppressAnimation;

  /// Play the slide/fade-out for a dismissal in progress.
  final bool animateDismiss;

  _MapSelection copyWith({
    CafeSummary? cafe,
    bool? dismissed,
    bool? suppressAnimation,
    bool? animateDismiss,
  }) {
    return _MapSelection(
      cafe: cafe ?? this.cafe,
      dismissed: dismissed ?? this.dismissed,
      suppressAnimation: suppressAnimation ?? this.suppressAnimation,
      animateDismiss: animateDismiss ?? this.animateDismiss,
    );
  }
}
