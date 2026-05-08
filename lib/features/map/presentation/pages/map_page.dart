import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';
import 'package:nook/features/map/presentation/widgets/bottom_modal_sheet.dart';
import 'package:nook/features/map/presentation/widgets/cafe_overlay_card.dart';
import 'package:nook/features/map/bloc/map_bloc.dart';
import 'package:nook/features/map/bloc/map_event.dart';
import 'package:nook/features/map/bloc/map_states.dart';
import 'package:nook/injection_container.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/filters/cubit/filter_cubit.dart';
import 'package:nook/core/filters/models/cafe_filter.dart';
import 'package:nook/features/search/presentation/widgets/search_entry_button.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/core/utils/error_info.dart';
import 'package:nook/core/widgets/error/full_page_error_widget.dart';
import 'package:nook/core/widgets/error/location_denied_banner.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final _controllerCompleter = Completer<MapLibreMapController>();
  String? _styleJson;
  MapLibreMapController? _mapController;
  bool _styleLoaded = false;
  late final CafeFilter _initialFilter;
  Symbol? _selectedSymbol;
  CafeSummary? _selectedCafe;
  bool _overlayDismissed = false;
  bool _suppressOverlayAnimation = false;
  bool _animateOverlayDismiss = false;
  double _sheetTopFromBottom = 0.0;
  double _sheetExtent = 0.0;
  double _sheetMinExtent = 0.0;
  List<CafeSummary> _cafes = const [];

  static const double _overlaySpacing = 16.0;

  @override
  void initState() {
    super.initState();
    _initialFilter = sl<FilterCubit>().state;
    rootBundle.loadString('assets/mapstyle.json').then((s) {
      if (mounted) setState(() => _styleJson = s);
    });
  }

  static const _initial = CameraPosition(
    target: LatLng(10.3167, 123.8907),
    zoom: 12,
  );

  @override
  void dispose() {
    sl<FilterCubit>().reset();
    _mapController?.onSymbolTapped.remove(_onSymbolTapped);
    super.dispose();
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
            if (state is MapLoadedState && _styleLoaded) {
              _cafes = state.cafes;
              _plotCafeMarkers(state.cafes);
            } else if (state is MapLoadedState) {
              _cafes = state.cafes;
            }
          },
          builder: (context, state) {
            if (_suppressOverlayAnimation && _shouldShowOverlay) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() => _suppressOverlayAnimation = false);
              });
            }

            final animateOverlayIn =
                _shouldShowOverlay && !_suppressOverlayAnimation;
            final animateOverlayOut = _animateOverlayDismiss;
            final animateOverlay = animateOverlayIn || animateOverlayOut;

            return Stack(
              children: [
                MapLibreMap(
                  initialCameraPosition: _initial,
                  myLocationEnabled: true,
                  myLocationRenderMode: MyLocationRenderMode.compass,
                  myLocationTrackingMode: MyLocationTrackingMode.none,

                  styleString:
                      _styleJson ??
                      'https://tiles.openfreemap.org/styles/bright',
                  onMapCreated: (c) {
                    _mapController = c;
                    _controllerCompleter.complete(c);
                    c.onSymbolTapped.add(_onSymbolTapped);
                  },
                  onStyleLoadedCallback: () async {
                    await _addCustomIcon();
                    if (mounted) setState(() => _styleLoaded = true);
                  },
                ),
                if (_styleLoaded)
                  Positioned(
                    right: 16,
                    bottom: 90,
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
                  bottom: _sheetTopFromBottom + _overlaySpacing,
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
                    child: _shouldShowOverlay
                        ? CafeOverlayCard(
                            key: ValueKey(_selectedCafe!.id),
                            cafe: _selectedCafe!,
                            onClose: _dismissOverlay,
                          )
                        : const SizedBox.shrink(),
                  ),
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
                        if (state is MapLoadedState &&
                            state.locationDenied &&
                            !state.locationBannerDismissed)
                          LocationDeniedBanner(
                            visible: true,
                            onDismiss: () => context.read<MapBloc>().add(
                              MapDismissLocationBannerEvent(),
                            ),
                          ),
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

  Future<void> _plotCafeMarkers(List<CafeSummary> cafes) async {
    final controller = await _controllerCompleter.future;
    await controller.clearSymbols();
    _selectedSymbol = null;
    if (mounted) {
      setState(() {
        _selectedCafe = null;
        _overlayDismissed = false;
      });
    }

    for (final cafe in cafes) {
      if (cafe.lat == null || cafe.lng == null) continue;
      await controller.addSymbol(
        SymbolOptions(
          geometry: LatLng(cafe.lat!, cafe.lng!),
          iconImage: 'map_pin',
          iconSize: 0.17,
        ),
        {'id': cafe.id},
      );
    }
  }

  void _onSymbolTapped(Symbol symbol) {
    if (_selectedSymbol != null && _selectedSymbol!.id != symbol.id) {
      _mapController?.updateSymbol(
        _selectedSymbol!,
        const SymbolOptions(iconSize: 0.17),
      );
    }
    _mapController?.updateSymbol(symbol, const SymbolOptions(iconSize: 0.23));
    _selectedSymbol = symbol;
    final cafeId = symbol.data?['id'];
    if (cafeId == null) return;

    CafeSummary? selectedCafe;
    for (final cafe in _cafes) {
      if (cafe.id == cafeId) {
        selectedCafe = cafe;
        break;
      }
    }

    if (selectedCafe == null) return;

    final wasVisible = _shouldShowOverlay;

    setState(() {
      _selectedCafe = selectedCafe;
      _overlayDismissed = false;
      _suppressOverlayAnimation = wasVisible;
    });
  }

  void _onSheetMetricsChanged(BottomSheetMetrics metrics) {
    final extent = metrics.extent;
    final minExtent = metrics.minExtent;
    final topFromBottom = metrics.topFromBottom;
    final changed =
        _sheetExtent != extent ||
        _sheetMinExtent != minExtent ||
        _sheetTopFromBottom != topFromBottom;

    if (!changed) return;

    setState(() {
      _sheetExtent = extent;
      _sheetMinExtent = minExtent;
      _sheetTopFromBottom = topFromBottom;
    });
  }

  bool get _isSheetExpanded => _sheetExtent > _sheetMinExtent + 0.01;

  bool get _shouldShowOverlay {
    return _selectedCafe != null &&
        !_overlayDismissed &&
        !_isSheetExpanded &&
        _sheetTopFromBottom > 0;
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
      _animateOverlayDismiss = true;
    });
    Future.delayed(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      if (_animateOverlayDismiss) {
        setState(() => _animateOverlayDismiss = false);
      }
    });
  }

  Future<void> _addCustomIcon() async {
    final ByteData bytes = await rootBundle.load('assets/images/MapPin.png');
    final Uint8List imageData = bytes.buffer.asUint8List();
    await _mapController!.addImage('map_pin', imageData);
  }

  // --- UPDATED METHOD ---
  Future<void> _defaultView() async {
    final c = await _controllerCompleter.future;
    await c.updateMyLocationTrackingMode(MyLocationTrackingMode.tracking);
  }
}
