import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/crawls/presentation/pages/crawl_complete_page.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_sign_in_sheet.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_ui.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_widgets.dart';
import 'package:nook/features/crawls/presentation/widgets/invite_crew_sheet.dart';
import 'package:nook/features/crawls/presentation/widgets/run_options_sheet.dart';
import 'package:nook/utils/theme/theme.dart';

import 'crawl_fixtures.dart';

/// Layout smoke tests on a 360pt phone at a larger text size. A RenderFlex
/// overflow fails the test.
void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double height = 720,
  }) async {
    tester.view.physicalSize = Size(360, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: TAppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(360, height),
            textScaler: const TextScaler.linear(1.3),
          ),
          child: child,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('crawl complete fits, with the Figma seal sizes', (tester) async {
    await pump(
      tester,
      CrawlCompletePage(run: run(stops: 6, stamped: 6, withCrew: true)),
      height: 1400,
    );

    expect(tester.takeException(), isNull);
    final seals = tester.widgetList<CrawlSeal>(find.byType(CrawlSeal)).toList();
    expect(seals.first.size, 120);
    expect(seals.skip(1).map((s) => s.size).toSet(), {44});
    expect(find.text('6 cafes added to Been'), findsOneWidget);
  });

  testWidgets('sheets and the leave dialog fit', (tester) async {
    await pump(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              RunOptionsSheet(run: run(stops: 5, stamped: 2, withCrew: true)),
              InviteCrewSheet(run: run(stops: 5, stamped: 2, withCrew: true)),
              const CrawlSignInSheet(
                title: 'Sign in to start this crawl',
                message:
                    'Stamps are saved to your account, so a run needs one.',
              ),
              const LeaveRunDialog(stampCount: 2),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Leave run'), findsWidgets);
    expect(find.text('Stay'), findsOneWidget);
  });

  testWidgets('route rows, the state view and the pills fit', (tester) async {
    await pump(
      tester,
      Scaffold(
        body: Column(
          children: [
            const CrawlSegmentedProgress(done: 2, total: 5),
            CrawlRouteRow(
              lineBelow: true,
              marker: const CrawlSeal(size: 28),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Text('The Coffee Bean and Tea Leaf Reserve'),
                  ),
                  CrawlPillButton(label: 'Stamp', onTap: () {}, tapHeight: 36),
                ],
              ),
            ),
            const CrawlRouteRow(
              marker: CrawlNumberBadge(number: 2, size: 28, outlined: true),
              child: Text('Brindle'),
            ),
            Expanded(
              child: CrawlStateView(
                icon: CrawlStateView.goneIcon,
                title: 'This run is no longer available',
                subtitle: 'The crawl may have been removed.',
                primaryLabel: 'Back to Lists',
                onPrimary: () {},
              ),
            ),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    // The segmented bar is 6 tall, one segment per stop.
    expect(tester.getSize(find.byType(CrawlSegmentedProgress)).height, 6);
  });
}
