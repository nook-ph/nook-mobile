import 'dart:async';
import 'dart:math' show Point;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:flutter/services.dart' show PlatformException, rootBundle;
import 'package:nook/features/search/domain/repositories/i_place_search_repository.dart';
import 'package:nook/features/search/domain/repositories/i_saved_places_repository.dart';
import 'package:nook/features/map/presentation/widgets/bottom_modal_sheet.dart';
import 'package:nook/features/map/presentation/widgets/cafe_overlay_card.dart';
import 'package:nook/features/map/presentation/widgets/map_search_pill.dart';
import 'package:nook/features/map/presentation/widgets/map_updating_chip.dart';
import 'package:nook/features/map/presentation/utils/map_camera_fit.dart';
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
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/map/presentation/widgets/map_sheet_states.dart';
import 'package:nook/core/bloc/features/navigation/bloc/navigation_bloc.dart';
import 'package:nook/features/search/data/search_origin_store.dart';
import 'package:nook/features/search/data/search_places.dart';
import 'package:nook/features/search/data/search_recents_store.dart';
import 'package:nook/features/search/domain/entities/search_origin.dart';
import 'package:nook/features/search/presentation/search_origin_picker.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key, this.isActive = true});

  /// Whether the map is the tab currently on screen.
  ///
  /// MainScreen keeps every tab alive in an IndexedStack, so this page runs
  /// with a laid-out Flutter box but a native MLNMapView that is not on screen
  /// and has no usable size. Camera work in that state makes MapLibre divide
  /// by a zero viewport, and the NaN it derives aborts the process.
  final bool isActive;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with WidgetsBindingObserver {
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

  /// True while the camera follows the user; the recenter button turns green.
  /// MapLibre drops tracking as soon as the user pans the map.
  final ValueNotifier<bool> _following = ValueNotifier(false);

  static bool _hasRequestedPermission = false;

  final _sheetMetrics = ValueNotifier<BottomSheetMetrics?>(null);

  /// Measured height of the pin preview card; it hugs its content, so the
  /// recenter button reads this to stay 12pt above it.
  final _overlayHeight = ValueNotifier<double>(CafeOverlayCard.minHeight);

  Map<String, CafeSummary> _cafeById = {};

  // Pin rendering state — one GeoJSON source + style layers (see
  // docs/plans/map-refactor.md and the webapp's CafeMap.tsx).
  MapPinImages? _pinImages;
  bool _layersAdded = false;
  bool _cameraFitted = false;

  /// Whether MapLibre has reported a settled camera at least once.
  ///
  /// The fit aborts the process when it runs on the frame the map becomes
  /// visible: the platform view is being created and sized on that same frame,
  /// and the plugin derives its altitude from the native view. A camera-idle
  /// event is the only signal Dart gets that the native map has a real
  /// transform, so nothing moves the camera before one arrives.
  bool _mapIdleSeen = false;
  List<CafeSummary>? _lastSyncedCafes;
  Future<void> _syncQueue = Future.value();

  /// The place being searched near, shared with search. While one is chosen
  /// the map centres on it, marks it with a pin, hides the blue dot and
  /// measures distances from it.
  final SearchOriginStore _originStore = sl<SearchOriginStore>();
  bool _originLayerAdded = false;

  SearchOrigin? get _origin => _originStore.value;

  /// Figma: the preview card sits 12 above the sheet.
  static const double _overlaySpacing = 12.0;

  static const _originSourceId = 'search-origin';
  static const _originLayerId = 'search-origin-pin';

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
    WidgetsBinding.instance.addObserver(this);
    _originStore.origin.addListener(_onOriginChanged);
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
      await _syncLocationEnabledFromPermission();
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

  /// Back from Settings or a system prompt: permission may have been granted
  /// outside this page, and the blue dot follows it.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncLocationEnabledFromPermission();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    sl<FilterCubit>().reset();
    _originStore.origin.removeListener(_onOriginChanged);
    _mapController?.onFeatureTapped.remove(_onCafeFeatureTapped);
    _sheetMetrics.dispose();
    _overlayHeight.dispose();
    _selection.dispose();
    _following.dispose();
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
  void didUpdateWidget(MapPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      // The tabs are built together at app start, on Home, so initState never
      // sees the map tab selected; this is the first time the map is opened.
      unawaited(_maybeRequestPermissionOnce());
      unawaited(_syncLocationEnabledFromPermission());
      // The tab is built hidden at app start, so its first camera idle comes
      // while inactive and was dropped: nothing fitted the camera or fetched
      // the viewport until the person panned, which left the first load's 20
      // hour-less rows ("20+ cafes", Open now with nothing to filter). Replay
      // the idle once the tab has been on screen for a moment; the delay
      // keeps the camera fit off the frame the native view is created on.
      unawaited(_replayFirstIdle());
      final cafes = _lastSyncedCafes;
      if (!_cameraFitted && cafes != null && _mapController != null) {
        unawaited(
          _fitCameraToCafes(
            _mapController!,
            cafes.where((c) => c.lat != null && c.lng != null).toList(),
          ).then((fitted) => _cameraFitted = fitted),
        );
      }
    }
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
                    // No blue dot while searching near a chosen place:
                    // distances no longer start from the phone.
                    myLocationEnabled: _myLocationEnabled && _origin == null,
                    myLocationRenderMode: MyLocationRenderMode.normal,
                    myLocationTrackingMode: MyLocationTrackingMode.none,
                    styleString: _styleJson!,
                    onMapCreated: (c) {
                      _mapController = c;
                      _controllerCompleter.complete(c);
                      c.onFeatureTapped.add(_onCafeFeatureTapped);
                    },
                    onCameraIdle: _onCameraIdle,
                    onCameraTrackingDismissed: () => _following.value = false,
                    onCameraTrackingChanged: (mode) =>
                        _following.value = mode != MyLocationTrackingMode.none,
                    onStyleLoadedCallback: () {
                      if (!mounted) return;
                      setState(() => _styleLoaded = true);
                      final s = context.read<MapBloc>().state;
                      if (s is MapLoadedState) {
                        _queueSyncMapData(s.cafes);
                      }
                      _queueApplyOrigin(moveCamera: _origin != null);
                      // The camera's first idle often lands before the style
                      // and is dropped; run it now instead.
                      if (widget.isActive && !_mapIdleSeen) {
                        unawaited(_replayFirstIdle());
                      }
                    },
                  )
                else
                  const Center(child: CircularProgressIndicator()),

                // Recenter sits 16 above the sheet, or 12 above the pin
                // preview when one is showing.
                if (_styleLoaded)
                  ValueListenableBuilder<BottomSheetMetrics?>(
                    valueListenable: _sheetMetrics,
                    builder: (context, metrics, _) {
                      return ValueListenableBuilder<_MapSelection>(
                        valueListenable: _selection,
                        builder: (context, selection, _) {
                          final top = metrics?.topFromBottom ?? 0.0;
                          final expanded =
                              (metrics?.extent ?? 0) >
                              (metrics?.minExtent ?? 0) + 0.01;
                          final preview =
                              selection.cafe != null &&
                              !selection.dismissed &&
                              !expanded &&
                              top > 0;
                          return ValueListenableBuilder<double>(
                            valueListenable: _overlayHeight,
                            builder: (context, cardHeight, _) => Positioned(
                              right: 16,
                              bottom:
                                  top +
                                  (preview
                                      ? _overlaySpacing + cardHeight + 12
                                      : 16),
                              child: ValueListenableBuilder<bool>(
                                valueListenable: _following,
                                builder: (context, following, _) =>
                                    MapRecenterButton(
                                      onTap: _defaultView,
                                      active: following,
                                    ),
                              ),
                            ),
                          );
                        },
                      );
                    },
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
                                    onHeight: (h) => _overlayHeight.value = h,
                                    distanceFrom: _originPoint,
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
                            isCapped: state.isCapped,
                            distanceFrom: _originPoint,
                            onMetricsChanged: _onSheetMetricsChanged,
                          )
                        : state is MapError
                        // The failure sits in the sheet, so the map and the
                        // search field stay usable above it.
                        ? BottomModalSheet(
                            cafes: const [],
                            tags: const [],
                            error: state.error,
                            onRetry: () => context.read<MapBloc>().add(
                              LoadMapDataEvent(
                                filter: context.read<FilterCubit>().state,
                              ),
                            ),
                            onMetricsChanged: _onSheetMetricsChanged,
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
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                          child: MapSearchPill(
                            origin: _origin?.fullLabel ?? 'Current location',
                            onOriginTap: _chooseOrigin,
                          ),
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

  /// Runs the first camera idle once the opened tab's map is ready: its style
  /// can still be loading when the tab appears, so this waits for it (up to
  /// ten seconds) and steps aside if a real idle got there first.
  Future<void> _replayFirstIdle() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted || !widget.isActive || _mapIdleSeen) return;
      if (_mapController != null && _styleLoaded) {
        _onCameraIdle();
        return;
      }
    }
  }

  void _onCameraIdle() {
    final controller = _mapController;
    if (controller == null || !_styleLoaded || !widget.isActive) return;
    if (!_mapIdleSeen) {
      _mapIdleSeen = true;
      final cafes = _lastSyncedCafes;
      if (!_cameraFitted && cafes != null) {
        unawaited(
          _fitCameraToCafes(
            controller,
            cafes.where((c) => c.lat != null && c.lng != null).toList(),
          ).then((fitted) => _cameraFitted = fitted),
        );
      }
    }
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

    if (!_cameraFitted && widget.isActive) {
      // With a place chosen the map opens on the place, not on the cafes.
      _cameraFitted =
          _origin != null || await _fitCameraToCafes(controller, validCafes);
    }
  }

  // --- Search origin --------------------------------------------------------

  geo.GeoPoint? get _originPoint {
    final origin = _origin;
    return origin == null
        ? null
        : geo.GeoPoint(lat: origin.lat, lng: origin.lng);
  }

  /// The "Near …" line: the same sheet search opens.
  Future<void> _chooseOrigin() async {
    final pick = await pickSearchOrigin(
      context,
      current: _origin,
      places: sl<SearchPlaces>(),
      recents: SearchRecentsStore(),
      placeSearch: sl<IPlaceSearchRepository>(),
      savedPlaces: sl<ISavedPlacesRepository>(),
    );
    if (pick == null || !mounted) return;
    _originStore.set(pick.origin);
    // "Current location" recentres on the phone, asking for access if needed.
    if (pick.origin == null) {
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) await _requestLocationAccess();
    }
  }

  /// The place changed, here or in search.
  void _onOriginChanged() {
    if (!mounted) return;
    // The pill's label, the blue dot and the distances all follow it.
    setState(() {});
    _queueApplyOrigin(moveCamera: true);
  }

  void _queueApplyOrigin({required bool moveCamera}) {
    _syncQueue = _syncQueue.then((_) => _applyOrigin(moveCamera: moveCamera));
  }

  /// Draws (or removes) the place pin and, with [moveCamera], centres the
  /// map on the place — or back on the phone when the place was reset.
  Future<void> _applyOrigin({required bool moveCamera}) async {
    final controller = _mapController;
    if (controller == null || !_styleLoaded || !mounted) return;
    final origin = _origin;
    if (origin == null && !_originLayerAdded) {
      // Nothing was ever drawn; only a reset needs the camera.
      if (moveCamera) await _returnToMyLocation();
      return;
    }

    final data = {
      'type': 'FeatureCollection',
      'features': [
        if (origin != null)
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [origin.lng, origin.lat],
            },
            'properties': <String, dynamic>{},
          },
      ],
    };
    try {
      _pinImages ??= MapPinImages(scale: _pinRasterScale);
      await _pinImages!.ensurePlacePin(controller);
      if (_originLayerAdded) {
        await controller.setGeoJsonSource(_originSourceId, data);
      } else {
        await controller.addGeoJsonSource(_originSourceId, data);
        await controller.addSymbolLayer(
          _originSourceId,
          _originLayerId,
          SymbolLayerProperties(
            iconImage: MapPinImages.placePinImageId,
            // The pin's tip marks the place.
            iconAnchor: 'bottom',
            iconAllowOverlap: true,
            iconIgnorePlacement: true,
            iconSize: _pillIconSize,
          ),
        );
        _originLayerAdded = true;
      }
    } catch (_) {
      // Style went away mid-update (page tear-down).
      return;
    }

    if (!moveCamera) return;
    if (origin == null) {
      await _returnToMyLocation();
      return;
    }
    try {
      await controller.updateMyLocationTrackingMode(
        MyLocationTrackingMode.none,
      );
      _following.value = false;
      await _centerOn(controller, LatLng(origin.lat, origin.lng));
    } catch (_) {
      // Camera unavailable (tear-down); the pin is drawn regardless.
    }
  }

  /// Centres [point] in the strip of map above the sheet, about 450m each
  /// way (the same framing a lone cafe gets).
  Future<void> _centerOn(MapLibreMapController controller, LatLng point) {
    const delta = 0.004;
    return controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(point.latitude - delta, point.longitude - delta),
          northeast: LatLng(point.latitude + delta, point.longitude + delta),
        ),
        left: 40,
        top: 60,
        right: 40,
        bottom: _sheetOcclusion.round() + 24,
      ),
    );
  }

  /// After a reset: follow the phone again if it may be read. Never prompts.
  Future<void> _returnToMyLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      final granted =
          permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
      if (!granted || !await Geolocator.isLocationServiceEnabled()) return;
      // Let the blue dot come back before following it.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      await _enterTrackingMode();
    } catch (_) {
      // Best-effort: the map simply stays where it is.
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
        iconAnchor: 'center',
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
        iconImage: [
          'concat',
          MapPinImages.selectedPrefix,
          ['get', 'pillIcon'],
        ],
        iconAnchor: 'center',
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
        iconSize: _pillIconSize,
      ),
      filter: _noSelectionFilter,
    );
    await controller.addSymbolLayer(
      _cafeSourceId,
      _selectedCoffeeLayerId,
      SymbolLayerProperties(
        iconImage: MapPinImages.selectedCoffeeImageId,
        // No tail: the badge is centred on the cafe, like the pills.
        iconAnchor: 'center',
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
    cafes = mapCoreCafes(cafes);

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
    // That bottom inset is only ever a request, though: an expanded sheet can
    // ask for more than the map is tall, and the solver below divides by what
    // is left. Fit the request to the map first.
    final padding = resolveMapFitPadding(
      viewport: viewport,
      left: 40,
      top: 60,
      right: 40,
      bottom: _sheetOcclusion + 24,
    );

    final fit = resolveMapCameraFit(
      southLatitude: minLat,
      westLongitude: minLng,
      northLatitude: maxLat,
      eastLongitude: maxLng,
      viewport: viewport,
      padding: padding,
    );
    if (fit == null) return false;

    // Never move the camera before MapLibre has reported a settled one. The
    // plugin builds its altitude from the native view's size, and on the frame
    // the tab becomes visible that view is still being created — what it
    // derives there is what mbgl rejects with std::domain_error, killing the
    // process outright. Traced on device: every fit that aborted ran on the tap
    // frame; the one that survived ran on a map that was already live.
    if (!_mapIdleSeen) return false;

    try {
      // newCameraPosition, not newLatLngZoom. Both reach the same
      // `-[MLNMapView setCamera:]`, but newLatLngZoom derives its altitude from
      // `mapView.camera.pitch` and `mapView.camera.centerCoordinate.latitude` —
      // the native camera. newCameraPosition takes pitch, bearing and latitude
      // from this dictionary, leaving the view's size as the only native input.
      await controller.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(fit.latitude, fit.longitude),
            zoom: fit.zoom,
            tilt: 0,
            bearing: 0,
          ),
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

  /// Recenter. With a place chosen, that means going back to the phone:
  /// the blue dot is hidden while a place is in force.
  Future<void> _defaultView() async {
    if (_origin != null) {
      _originStore.set(null);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    await _requestLocationAccess();
  }

  /// Geolocator and the map plugin both throw (a second permission request
  /// while one is open, a platform error); a tap on recenter must not turn
  /// that into an unhandled error.
  Future<void> _requestLocationAccess() async {
    try {
      await _requestLocationAccessUnguarded();
    } catch (e) {
      debugPrint('MapPage: location access failed: $e');
    }
  }

  Future<void> _requestLocationAccessUnguarded() async {
    final permission = await Geolocator.checkPermission();
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      if (!serviceEnabled) {
        if (!mounted) return;
        showPrimaryToast(
          context,
          'Turn on Location Services to center the map on you.',
          bottomOffset: _sheetMetrics.value?.topFromBottom ?? 0,
        );
        return;
      }
      // Permission granted somewhere else (search, a crawl, Settings) never
      // went through the branch below, so the location layer is still off;
      // tracking does nothing without it.
      if (!_myLocationEnabled) {
        if (!mounted) return;
        setState(() => _myLocationEnabled = true);
        await WidgetsBinding.instance.endOfFrame;
      }
      await _enterTrackingMode();
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      // Say why before leaving the app; the system won't ask again.
      if (await showMapLocationDeniedDialog(context)) {
        await Geolocator.openAppSettings();
      }
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
        // The filter in force now, not the one captured when the app
        // started: the chips still show whatever the user has since chosen.
        _mapBloc?.add(LoadMapDataEvent(filter: sl<FilterCubit>().state));
      }
    }
  }

  Future<void> _enterTrackingMode() async {
    final c = await _controllerCompleter.future;
    await c.updateMyLocationTrackingMode(MyLocationTrackingMode.tracking);
    _following.value = true;
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

/// The cafes the first view frames: those within 10 km of the median cafe,
/// when they are most of the set. Fitting every cafe let one outlying town
/// zoom the map out to the whole region, with the city's pins merged into one
/// blob (docs/ux/find-a-cafe.md, finding 3). Mirrors the web map.
List<CafeSummary> mapCoreCafes(List<CafeSummary> cafes) {
  if (cafes.length < 3) return cafes;
  double median(Iterable<double> values) {
    final sorted = values.toList()..sort();
    return sorted[sorted.length ~/ 2];
  }

  final lat = median(cafes.map((c) => c.lat!));
  final lng = median(cafes.map((c) => c.lng!));
  final core = cafes
      .where(
        (c) => Geolocator.distanceBetween(lat, lng, c.lat!, c.lng!) <= 10000,
      )
      .toList();
  return core.length >= cafes.length * 0.6 ? core : cafes;
}
