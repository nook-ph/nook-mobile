import 'dart:async';
import 'dart:typed_data';
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
import 'package:phosphor_flutter/phosphor_flutter.dart';

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
                  onStyleLoadedCallback: () async {
                    await _addCustomIcon();
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

    for (final cafe in cafes) {
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
    // do something 
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
