import 'dart:async';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';
import 'package:nook/features/map/presentation/widgets/bottom_modal_sheet.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final _controllerCompleter = Completer<MapLibreMapController>();
  bool _styleLoaded = false;

  static const _initial = CameraPosition(
    target: LatLng(10.3167, 123.8907),
    zoom: 12,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MapLibreMap(
            initialCameraPosition: _initial,
            styleString:
                'https://tiles.openfreemap.org/styles/bright', // TODO change with custom maputnik map
            onMapCreated: (c) => _controllerCompleter.complete(c),
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
          if (_styleLoaded) BottomModalSheet(),
        ],
      ),
    );
  }

  Future<void> _defaultView() async {
    final c = await _controllerCompleter.future;
    await c.animateCamera(CameraUpdate.newCameraPosition(_initial));
  }
}

