import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nook/core/preferences/home_location_prompt_store.dart';
import 'package:nook/core/preferences/location_prompt_store.dart';
import 'package:nook/features/home_page/presentation/widgets/home_location_prompt.dart';
import 'package:nook/utils/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    resetHomeLocationPromptLog();
  });

  Future<bool> offer({
    HomeLocationPromptStore? store,
    LocationPromptStore? promptStore,
    bool services = true,
    LocationPermission permission = LocationPermission.denied,
  }) => shouldOfferHomeLocation(
    store: store ?? HomeLocationPromptStore(),
    promptStore: promptStore ?? LocationPromptStore(),
    servicesEnabled: () async => services,
    checkPermission: () async => permission,
  );

  group('shouldOfferHomeLocation', () {
    test('not on the very first Home visit', () async {
      expect(await offer(), isFalse);
    });

    test('on the second launch', () async {
      await HomeLocationPromptStore().recordHomeVisit();
      expect(await offer(), isTrue);
    });

    test('on the first launch once a cafe was opened', () async {
      await HomeLocationPromptStore().markCafeViewed();
      expect(await offer(), isTrue);
    });

    test('never after it was turned down', () async {
      await HomeLocationPromptStore().recordHomeVisit();
      await HomeLocationPromptStore().markDismissed();
      expect(await offer(), isFalse);
    });

    test('never once the system prompt was shown anywhere', () async {
      await HomeLocationPromptStore().recordHomeVisit();
      await LocationPromptStore().markRequested();
      expect(await offer(), isFalse);
    });

    test('only while permission can still be asked for', () async {
      for (final p in [
        LocationPermission.whileInUse,
        LocationPermission.always,
        LocationPermission.deniedForever,
      ]) {
        SharedPreferences.setMockInitialValues({'homeVisitCount': 3});
        expect(await offer(permission: p), isFalse, reason: '$p');
      }
      SharedPreferences.setMockInitialValues({'homeVisitCount': 3});
      expect(await offer(services: false), isFalse);
    });
  });

  test('locationResultName', () {
    expect(locationResultName(LocationPermission.whileInUse), 'granted');
    expect(locationResultName(LocationPermission.always), 'granted');
    expect(locationResultName(LocationPermission.denied), 'denied');
    expect(
      locationResultName(LocationPermission.deniedForever),
      'denied_forever',
    );
  });

  group('HomeLocationPrompt', () {
    Future<void> pump(
      WidgetTester tester, {
      required VoidCallback onGranted,
      required Future<bool> Function(BuildContext) confirm,
      required Future<LocationPermission> Function() request,
    }) async {
      SharedPreferences.setMockInitialValues({'homeVisitCount': 1});
      await tester.pumpWidget(
        MaterialApp(
          theme: TAppTheme.lightTheme,
          home: Scaffold(
            body: HomeLocationPrompt(
              onGranted: onGranted,
              store: HomeLocationPromptStore(),
              promptStore: LocationPromptStore(),
              servicesEnabled: () async => true,
              checkPermission: () async => LocationPermission.denied,
              requestPermission: request,
              confirm: confirm,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('granting asks once and refreshes Home', (tester) async {
      var granted = 0;
      var requests = 0;
      await pump(
        tester,
        onGranted: () => granted++,
        confirm: (_) async => true,
        request: () async {
          requests++;
          return LocationPermission.whileInUse;
        },
      );
      expect(find.text('See cafes near you'), findsOneWidget);

      await tester.tap(find.text('See cafes near you'));
      await tester.pumpAndSettle();

      expect(requests, 1);
      expect(granted, 1);
      expect(find.text('See cafes near you'), findsNothing);
      expect(await LocationPromptStore().hasRequested(), isTrue);
    });

    testWidgets('"Not now" hides it for good without the system prompt', (
      tester,
    ) async {
      var requests = 0;
      await pump(
        tester,
        onGranted: () {},
        confirm: (_) async => false,
        request: () async {
          requests++;
          return LocationPermission.denied;
        },
      );
      await tester.tap(find.text('See cafes near you'));
      await tester.pumpAndSettle();

      expect(requests, 0);
      expect(find.text('See cafes near you'), findsNothing);
      expect(await HomeLocationPromptStore().isDismissed(), isTrue);
      expect(await LocationPromptStore().hasRequested(), isFalse);
    });

    testWidgets('the close button dismisses it', (tester) async {
      await pump(
        tester,
        onGranted: () {},
        confirm: (_) async => true,
        request: () async => LocationPermission.whileInUse,
      );
      await tester.tap(find.bySemanticsLabel('Dismiss'));
      await tester.pumpAndSettle();

      expect(find.text('See cafes near you'), findsNothing);
      expect(await HomeLocationPromptStore().isDismissed(), isTrue);
    });
  });
}
