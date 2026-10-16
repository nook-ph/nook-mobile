import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/presentation/bottom_nav.dart';
import 'package:nook/core/presentation/pages/main_screen.dart';
import 'package:nook/features/home_widget/presentation/widget_links.dart';

import '../../analytics/recording_analytics.dart';

final _shellKey = GlobalKey();

Widget _app() {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => MainShell(
          key: _shellKey,
          isAuthenticated: () => false,
          pagesBuilder: (_) => const [
            Center(child: Text('home page')),
            Center(child: Text('map page')),
            Center(child: Text('saved page')),
            Center(child: Text('profile page')),
          ],
        ),
      ),
      GoRoute(
        path: '/cafe/:id',
        builder: (_, state) =>
            Scaffold(body: Text('cafe ${state.pathParameters['id']}')),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

int _currentTab(WidgetTester tester) => tester
    .widget<BottomNav>(find.byType(BottomNav, skipOffstage: false))
    .currentIndex;

/// A page pushed over the shell with Navigator, as Settings is.
void _pushSettings() {
  Navigator.of(_shellKey.currentContext!).push(
    MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('settings page')),
    ),
  );
}

/// The opener acts after the next frame; on a phone the tap's route or the
/// resume brings one.
Future<void> _frame(WidgetTester tester) async {
  tester.binding.scheduleFrame();
  await tester.pumpAndSettle();
}

void main() {
  setUp(WidgetLinks.reset);
  tearDown(WidgetLinks.reset);

  testWidgets('the header tap closes pages pushed over the shell', (
    tester,
  ) async {
    RecordingAnalytics.install(addTearDown);
    await tester.pumpWidget(_app());
    _pushSettings();
    await tester.pumpAndSettle();
    expect(find.text('settings page'), findsOneWidget);

    WidgetLinks.acceptFromPlatform(Uri.parse('nook://saved?via=widget'));
    await _frame(tester);

    expect(find.text('settings page'), findsNothing);
    expect(_currentTab(tester), MainShell.savedTab);
    expect(find.text('saved page'), findsOneWidget);
  });

  testWidgets('a cafe tap opens one cafe page over Home, not over Settings', (
    tester,
  ) async {
    RecordingAnalytics.install(addTearDown);
    await tester.pumpWidget(_app());
    _pushSettings();
    await tester.pumpAndSettle();

    WidgetLinks.acceptFromPlatform(Uri.parse('nook://cafe/abc?via=widget'));
    await _frame(tester);
    expect(find.text('cafe abc'), findsOneWidget);

    // The same tap opened again (its re-queue after the router's `/`):
    // still one cafe page.
    WidgetLinks.pending.value = WidgetLink.parse(
      Uri.parse('nook://cafe/abc?via=widget'),
    );
    await _frame(tester);
    expect(find.text('cafe abc'), findsOneWidget);

    // Back lands on Home, not on Settings or a second copy.
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.text('cafe abc'), findsNothing);
    expect(find.text('settings page'), findsNothing);
    expect(_currentTab(tester), 0);
  });

  testWidgets('a page refusing Back while it saves is not torn down, and '
      'the cafe waits until it closes itself', (tester) async {
    RecordingAnalytics.install(addTearDown);
    await tester.pumpWidget(_app());
    final busy = ValueNotifier(true);
    final busyContext = _pushBusyPage(busy);
    _pushSettings();
    await tester.pumpAndSettle();

    WidgetLinks.acceptFromPlatform(Uri.parse('nook://cafe/abc?via=widget'));
    await _frame(tester);

    // Settings above it closes; the busy page stays on top, nothing over it
    // that its own pop would close instead of itself.
    expect(find.text('settings page'), findsNothing);
    expect(find.text('saving page'), findsOneWidget);
    expect(find.text('cafe abc'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('cafe abc'), findsNothing);

    // The save ends: the page lets go and closes itself.
    busy.value = false;
    await tester.pump();
    Navigator.of(busyContext()).pop();
    await tester.pumpAndSettle();
    expect(find.text('saving page'), findsNothing);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('cafe abc'), findsOneWidget);
    expect(_currentTab(tester), 0);
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.text('home page'), findsOneWidget);
  });

  testWidgets('a header tap over a busy page opens Saved once it closes', (
    tester,
  ) async {
    RecordingAnalytics.install(addTearDown);
    await tester.pumpWidget(_app());
    final busy = ValueNotifier(true);
    final busyContext = _pushBusyPage(busy);
    await tester.pumpAndSettle();

    WidgetLinks.acceptFromPlatform(Uri.parse('nook://saved?via=widget'));
    await _frame(tester);
    expect(find.text('saving page'), findsOneWidget);
    expect(_currentTab(tester), 0, reason: 'no tab switch hidden under it');

    // The save ends in the same step that closes the page.
    busy.value = false;
    Navigator.of(busyContext()).pop();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('saving page'), findsNothing);
    expect(_currentTab(tester), MainShell.savedTab);
  });

  testWidgets('a busy page that lets go but stays open keeps its draft', (
    tester,
  ) async {
    RecordingAnalytics.install(addTearDown);
    await tester.pumpWidget(_app());
    final busy = ValueNotifier(true);
    _pushBusyPage(busy);
    await tester.pumpAndSettle();

    WidgetLinks.acceptFromPlatform(Uri.parse('nook://cafe/abc?via=widget'));
    await _frame(tester);

    // The save failed: Back works again, the page stays with its error.
    busy.value = false;
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('saving page'), findsOneWidget);
    expect(find.text('cafe abc'), findsNothing);
  });

  testWidgets('a tap waiting on a busy page is dropped after a minute', (
    tester,
  ) async {
    RecordingAnalytics.install(addTearDown);
    await tester.pumpWidget(_app());
    final busy = ValueNotifier(true);
    _pushBusyPage(busy);
    await tester.pumpAndSettle();

    WidgetLinks.acceptFromPlatform(Uri.parse('nook://cafe/abc?via=widget'));
    await _frame(tester);
    await tester.pump(const Duration(minutes: 1, seconds: 1));

    busy.value = false;
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('saving page'), findsOneWidget);
    expect(find.text('cafe abc'), findsNothing);
  });
}

/// A page that holds Back while [busy], as Edit profile does while saving.
/// Returns its context, for the pop it makes when the save ends.
BuildContext Function() _pushBusyPage(ValueNotifier<bool> busy) {
  late BuildContext pageContext;
  Navigator.of(_shellKey.currentContext!).push(
    MaterialPageRoute<void>(
      builder: (_) => ValueListenableBuilder<bool>(
        valueListenable: busy,
        builder: (context, value, _) {
          pageContext = context;
          return PopScope(
            canPop: !value,
            child: const Scaffold(body: Text('saving page')),
          );
        },
      ),
    ),
  );
  return () => pageContext;
}
