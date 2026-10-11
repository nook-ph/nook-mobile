import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/presentation/widgets/default_system_ui.dart';

void main() {
  testWidgets('status bar icons go back to dark after a viewer closes', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        builder: (context, child) => DefaultSystemUi(child: child!),
        // A page with no AppBar, like Home or Profile.
        home: const Scaffold(body: Center(child: Text('home'))),
      ),
    );
    await tester.pumpAndSettle();
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);

    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Scaffold(backgroundColor: Colors.black),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      SystemChrome.latestStyle?.statusBarIconBrightness,
      Brightness.light,
    );

    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);
  });
}
