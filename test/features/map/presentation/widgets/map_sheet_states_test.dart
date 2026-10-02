import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/utils/error_info.dart';
import 'package:nook/features/map/presentation/widgets/map_sheet_states.dart';
import 'package:nook/features/map/presentation/widgets/map_tokens.dart';

void main() {
  test('each failure kind has its own icon', () {
    expect(mapErrorIcon(ErrorType.offline), LucideIcons.wifiOff);
    expect(mapErrorIcon(ErrorType.sessionExpired), LucideIcons.lock);
    expect(mapErrorIcon(ErrorType.serverError), LucideIcons.triangleAlert);
  });

  Future<void> pump(WidgetTester tester, Widget child) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));

  testWidgets('no cafes offers Clear filters only when filtered', (t) async {
    var cleared = false;
    await pump(
      t,
      MapSheetStateView.noCafes(onClearFilters: () => cleared = true),
    );
    expect(find.text('No cafes in this area'), findsOneWidget);
    await t.tap(find.text('Clear filters'));
    expect(cleared, isTrue);

    await pump(t, MapSheetStateView.noCafes());
    expect(find.text('Clear filters'), findsNothing);
  });

  testWidgets('no cafes uses the ink map icon; errors keep the brand one', (
    t,
  ) async {
    await pump(t, MapSheetStateView.noCafes());
    expect(t.widget<Icon>(find.byIcon(LucideIcons.map)).color, MapTokens.ink);

    await pump(
      t,
      MapSheetStateView.error(
        error: const SocketException('no network'),
        onRetry: () {},
        onSignIn: () {},
      ),
    );
    expect(
      t.widget<Icon>(find.byIcon(LucideIcons.wifiOff)).color,
      MapTokens.brand,
    );
  });

  testWidgets('offline error offers Try again', (t) async {
    var retried = false;
    await pump(
      t,
      MapSheetStateView.error(
        error: const SocketException('no network'),
        onRetry: () => retried = true,
        onSignIn: () {},
      ),
    );
    expect(find.text("You're offline"), findsOneWidget);
    await t.tap(find.text('Try again'));
    expect(retried, isTrue);
  });

  testWidgets('skeleton renders without overflow', (t) async {
    await pump(t, const MapSheetSkeleton());
    expect(t.takeException(), isNull);
  });
}
