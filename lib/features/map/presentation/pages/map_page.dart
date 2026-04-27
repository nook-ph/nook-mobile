import 'dart:async';
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

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final _controllerCompleter = Completer<MapLibreMapController>();
  MapLibreMapController? _mapController;
  bool _styleLoaded = false;

  static const _initial = CameraPosition(
    target: LatLng(10.3167, 123.8907),
    zoom: 12,
  );

  @override
  void dispose() {
    _mapController?.onSymbolTapped.remove(_onSymbolTapped);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<MapBloc>()
        ..add(LoadMapDataEvent())
        ..add(LoadFilterTagsEvent()),
      child: Scaffold(
        body: BlocConsumer<MapBloc, MapState>(
          listener: (context, state) {
            // Re-plot markers whenever cafes load or update
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
                      'https://tiles.openfreemap.org/styles/bright', // TODO change with custom maputnik map
                  onMapCreated: (c) {
                    _mapController = c;
                    _controllerCompleter.complete(c);
                    c.onSymbolTapped.add(_onSymbolTapped);
                  },
                  onStyleLoadedCallback: () {
                    setState(() => _styleLoaded = true);
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
                        side: BorderSide(color: Colors.white, width: 1.5),
                      ),
                      onPressed: _defaultView,
                      child: const Icon(Icons.my_location),
                    ),
                  ),
                if (_styleLoaded)
                  if (state is MapLoadingState)
                    const Center(child: CircularProgressIndicator())
                  else if (state is MapLoadedState)
                    BottomModalSheet(cafes: state.cafes, tags: state.tags)
                  else if (state is MapError)
                    Center(child: Text(state.message)),
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

    debugPrint('>>> plotting ${cafes.length} cafes');
    for (final cafe in cafes) {
      debugPrint('>>> ${cafe.name}: lat=${cafe.lat}, lng=${cafe.lng}');
      await controller.addSymbol(
        SymbolOptions(
          geometry: LatLng(cafe.lat!, cafe.lng!),
          iconImage:
              'marker-15', // built-in MapLibre icon; swap with your asset name
          iconSize: 32,
          // textField: cafe.name, // remove if you don't want labels
          // textOffset: const Offset(0, 1.5),
          // textSize: 11,
        ),
        {'id': cafe.id}, // arbitrary data attached to the symbol
      );
    }
  }

  void _onSymbolTapped(Symbol symbol) {
    // symbol.data holds the map you passed as the second arg above
    final cafeId = symbol.data?['id'];
    debugPrint('Tapped cafe id: $cafeId');
    // e.g. context.read<MapBloc>().add(SelectCafeEvent(cafeId));
  }

  Future<void> _defaultView() async {
    final c = await _controllerCompleter.future;
    await c.animateCamera(CameraUpdate.newCameraPosition(_initial));
  }
}
