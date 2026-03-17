import 'dart:async';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';

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
          if (_styleLoaded) BottomSheet(),
        ],
      ),
    );
  }

  Future<void> _defaultView() async {
    final c = await _controllerCompleter.future;
    await c.animateCamera(CameraUpdate.newCameraPosition(_initial));
  }
}

class BottomSheet extends StatefulWidget {
  const BottomSheet({super.key});

  @override
  State<BottomSheet> createState() => _BottomSheetState();
}

class _BottomSheetState extends State<BottomSheet> {
  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.06,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: [0.06, 0.5, 0.85],
      snapAnimationDuration: Duration(milliseconds: 80),
      builder: (BuildContext context, ScrollController scrollController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: <Widget>[
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: 25,
                  itemBuilder: (BuildContext context, int index) {
                    return ListTile(
                      title: Text(
                        'Item $index',
                        style: TextStyle(color: colorScheme.surface),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
