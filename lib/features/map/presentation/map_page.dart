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
      floatingActionButton: _styleLoaded
          ? FloatingActionButton(
              backgroundColor: Colors.white,
              foregroundColor: Theme.of(context).colorScheme.primary100,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.white, width: 1.5),
              ),
              onPressed: _defaultView,
              child: const Icon(
                Icons.my_location,
              ), // try either "explore" or "near_me"
            )
          : null,
      body: MapLibreMap(
        initialCameraPosition: _initial,
        styleString:
            'https://tiles.openfreemap.org/styles/bright', // TODO change with custom maputnik map
        onMapCreated: (c) => _controllerCompleter.complete(c),
        onStyleLoadedCallback: () {
          setState(() => _styleLoaded = true);
          // _showBottomSheet(); fix
        },
      ),
    );
  }

  // void _showBottomSheet() {
  //   showModalBottomSheet(
  //     context: context,
  //     isScrollControlled: true,
  //     backgroundColor: Colors.transparent,
  //     builder: (context) => DraggableScrollableSheet(
  //       initialChildSize: 0.15,
  //       minChildSize: 0.15,
  //       maxChildSize: 0.9,
  //       expand: false,
  //       builder: (context, scrollController) => Container(
  //         decoration: BoxDecoration(
  //           color: Theme.of(context).colorScheme.surface,
  //           borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
  //         ),
  //         child: ListView(
  //           controller: scrollController,
  //           children: [
  //             const SizedBox(height: 12),
  //             Center(
  //               child: Container(
  //                 width: 40,
  //                 height: 4,
  //                 decoration: BoxDecoration(
  //                   color: Theme.of(context).colorScheme.outline,
  //                   borderRadius: BorderRadius.circular(2),
  //                 ),
  //               ),
  //             ),
  //             const SizedBox(height: 16),
  //             // your content here
  //             const SizedBox(height: 24),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }

  Future<void> _defaultView() async {
    final c = await _controllerCompleter.future;
    await c.animateCamera(CameraUpdate.newCameraPosition(_initial));
  }
}
