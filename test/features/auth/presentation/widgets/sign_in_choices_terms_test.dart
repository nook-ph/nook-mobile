import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/constants/app_constants.dart';
import 'package:nook/core/preferences/terms_acceptance_store.dart';
import 'package:nook/features/auth/presentation/widgets/auth_ui.dart';
import 'package:nook/features/auth/presentation/widgets/sign_in_choices.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late List<SignInChoice> chosen;
  late TermsAcceptanceStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    chosen = [];
    store = TermsAcceptanceStore();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SheetSignInChoices(onChoice: chosen.add, termsStore: store),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Google with the box unticked opens the terms, not an error', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text(AuthProviderButton.googleLabel));
    await tester.pumpAndSettle();

    expect(chosen, isEmpty);
    expect(find.text('Before you continue'), findsOneWidget);
    expect(find.text(AuthProviderButton.agreeGoogleLabel), findsOneWidget);
    expect(find.textContaining('Tick the box'), findsNothing);
    expect(await store.hasAccepted(AppConstants.termsVersion), isFalse);
  });

  testWidgets('"Agree and continue" agrees and signs in, in one tap', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text(AuthProviderButton.googleLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AuthProviderButton.agreeGoogleLabel));
    await tester.pumpAndSettle();

    expect(chosen, [SignInChoice.google]);
    expect(await store.hasAccepted(AppConstants.termsVersion), isTrue);
  });

  testWidgets('a ticked box signs in with the first tap', (tester) async {
    await pump(tester);
    await tester.tap(find.byType(AuthCheckbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AuthProviderButton.googleLabel));
    await tester.pumpAndSettle();

    expect(chosen, [SignInChoice.google]);
  });

  testWidgets('email never needs the box', (tester) async {
    await pump(tester);
    await tester.tap(find.text(SheetSignInChoices.emailLabel));
    expect(chosen, [SignInChoice.email]);
  });

  testWidgets('agreed before on this phone: no box, no terms step', (
    tester,
  ) async {
    await store.markAccepted(AppConstants.termsVersion);
    await pump(tester);
    expect(find.textContaining('I agree to the'), findsNothing);
    await tester.tap(find.text(AuthProviderButton.googleLabel));
    expect(chosen, [SignInChoice.google]);
  });
}
