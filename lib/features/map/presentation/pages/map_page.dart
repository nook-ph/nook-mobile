import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';
import 'package:nook/features/map/presentation/widgets/bottom_modal_sheet.dart';
import 'package:nook/features/map/bloc/map_bloc.dart';
import 'package:nook/features/map/bloc/map_event.dart';
import 'package:nook/features/map/bloc/map_states.dart';
import 'package:nook/injection_container.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/filters/cubit/filter_cubit.dart';
import 'package:nook/core/filters/models/cafe_filter.dart';
import 'package:nook/features/search/presentation/widgets/search_entry_button.dart';

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
              _plotCafeMarkers(state.cafes);
            }
          },
          builder: (context, state) {
            return Stack(
              children: [
                MapLibreMap(
                  initialCameraPosition: _initial,
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
                    bottom: 72,
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
                if (_styleLoaded)
                  Positioned(
                    top: SearchEntryButton.mapBottomSheetTop(context),
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: state is MapLoadingState
                        ? const BottomModalSheet(cafes: [], tags: [])
                        : state is MapLoadedState
                        ? BottomModalSheet(cafes: state.cafes, tags: state.tags)
                        : state is MapError
                        ? Center(child: Text(state.message))
                        : const SizedBox.shrink(),
                  ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
                      child: const SearchEntryButton(),
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

    for (final cafe in cafes) {
      if (cafe.lat == null || cafe.lng == null) continue;
      await controller.addSymbol(
        SymbolOptions(
          geometry: LatLng(cafe.lat!, cafe.lng!),
          iconImage: 'map_pin',
          iconSize: 1.5,
        ),
      );
    }
  }

  void _onSymbolTapped(Symbol symbol) {
    final cafeId = symbol.data?['id'];
    debugPrint('Tapped cafe id: $cafeId');
  }

  Future<void> _addCustomIcon() async {
    final ByteData bytes = await rootBundle.load('assets/images/MapPin.png');
    final Uint8List imageData = bytes.buffer.asUint8List();
    await _mapController!.addImage('map_pin', imageData);
  }

  Future<void> _defaultView() async {
    final c = await _controllerCompleter.future;
    await c.animateCamera(CameraUpdate.newCameraPosition(_initial));
  }
}
