import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/utils/error_info.dart';
import 'package:nook/core/widgets/error/full_page_error_widget.dart';

void main() {
  Future<void> pumpError(
    WidgetTester tester,
    ErrorInfo error, {
    VoidCallback? onRetry,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FullPageErrorWidget(error: error, onRetry: onRetry),
        ),
      ),
    );
  }

  Container pill(WidgetTester tester, String label) {
    return tester.widget<Container>(
      find.ancestor(of: find.text(label), matching: find.byType(Container)),
    );
  }

  const signedOut = ErrorInfo(
    type: ErrorType.sessionExpired,
    title: "You've been signed out",
    subtitle: 'Sign in to continue',
  );
  const offline = ErrorInfo(
    type: ErrorType.offline,
    title: "You're offline",
    subtitle: 'Check your connection and try again',
  );

  testWidgets('signed out offers a filled Sign in pill', (tester) async {
    await pumpError(tester, signedOut, onRetry: () {});
    expect(find.text("You've been signed out"), findsOneWidget);
    expect(find.byIcon(LucideIcons.lock), findsOneWidget);
    expect(
      (pill(tester, 'Sign in').decoration! as BoxDecoration).color,
      const Color(0xFF344E41),
    );
  });

  testWidgets('offline offers an outlined Try again pill', (tester) async {
    await pumpError(tester, offline, onRetry: () {});
    expect(find.byIcon(LucideIcons.wifiOff), findsOneWidget);
    final decoration = pill(tester, 'Try again').decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFFFEFEFE));
    expect(decoration.border, isNotNull);
  });

  testWidgets('uses the system frame sizes', (tester) async {
    await pumpError(tester, offline, onRetry: () {});

    final icon = tester.widget<Icon>(find.byIcon(LucideIcons.wifiOff));
    expect(icon.size, 22);
    expect(
      tester.getSize(
        find.ancestor(
          of: find.byIcon(LucideIcons.wifiOff),
          matching: find.byType(Container),
        ),
      ),
      const Size(48, 48),
    );

    final title = tester.widget<Text>(find.text("You're offline"));
    expect(title.style!.fontSize, 16);
    expect(title.style!.fontWeight, FontWeight.w600);

    // The pill hugs its label: 44 high and narrower than the page.
    final pillSize = tester.getSize(
      find.ancestor(
        of: find.text('Try again'),
        matching: find.byType(Container),
      ),
    );
    expect(pillSize.height, 44);
    expect(pillSize.width, lessThan(200));
  });

  testWidgets('tapping the pill retries', (tester) async {
    var retries = 0;
    await pumpError(tester, offline, onRetry: () => retries++);
    await tester.tap(find.text('Try again'));
    expect(retries, 1);
  });

  testWidgets('no action without onRetry', (tester) async {
    await pumpError(tester, offline);
    expect(find.text('Try again'), findsNothing);
  });
}
