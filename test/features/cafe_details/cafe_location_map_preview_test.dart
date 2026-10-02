import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_location_map_preview.dart';

void main() {
  testWidgets('far below the fold, the native map is not created', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 3000),
                CafeLocationMapPreview(lat: 10.3167, lng: 123.8907),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(CafeLocationMapPreview), findsOneWidget);
    expect(find.byType(MapLibreMap), findsNothing);
    // The grey block keeps the preview's place in the layout.
    expect(tester.getSize(find.byType(CafeLocationMapPreview)).height, 180);
  });
}
