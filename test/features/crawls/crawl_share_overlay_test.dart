import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_share_overlays.dart';

import 'crawl_fixtures.dart';

void main() {
  Future<void> pump(WidgetTester tester, CrawlOverlayLayout layout) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: CrawlShareOverlay(
            layout: layout,
            // The longest crawl the app allows.
            run: run(stops: 6, stamped: 6),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  for (final layout in [
    CrawlOverlayLayout.stacked,
    CrawlOverlayLayout.strip,
    CrawlOverlayLayout.route,
  ]) {
    testWidgets('${layout.label}: cafe names, no distance or time', (
      tester,
    ) async {
      await pump(tester, layout);

      // Every stop's cafe is named.
      for (var i = 1; i <= 6; i++) {
        expect(find.textContaining('Cafe $i'), findsOneWidget);
      }
      expect(find.textContaining('6/6'), findsOneWidget);
      expect(find.text('Distance'), findsNothing);
      expect(find.text('Time'), findsNothing);
      expect(find.textContaining(' km'), findsNothing);
      expect(find.textContaining(' min'), findsNothing);
      // Six names still fit the 360 x 640 story.
      expect(tester.takeException(), isNull);
    });
  }
}
