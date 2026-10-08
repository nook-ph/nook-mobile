import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/features/profile/presentation/pages/settings_page.dart';
import 'package:nook/features/profile/presentation/widgets/profile_tokens.dart';
import 'package:nook/features/profile/presentation/widgets/profile_ui.dart';

import '../auth/fake_auth_bloc.dart';
import 'profile_test_support.dart';

void main() {
  Future<FakeAuthBloc> pump(
    WidgetTester tester, {
    String provider = 'email',
    SettingsLocationStatus location = SettingsLocationStatus.on,
  }) async {
    // Tall enough that every group, Privacy included, is on screen.
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = FakeAuthBloc();
    await tester.pumpWidget(
      profileHost(
        auth: auth,
        page: SettingsPage(
          currentUser: () => userWith(provider),
          readLocationStatus: () async => location,
        ),
      ),
    );
    await tester.pump();
    return auth;
  }

  ProfilePillButton button(WidgetTester tester, String label) {
    return tester.widget<ProfilePillButton>(
      find.widgetWithText(ProfilePillButton, label),
    );
  }

  testWidgets('rows sit in groups, with links out marked as such', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Settings'), findsOneWidget);
    for (final group in ['Permissions', 'Account', 'Legal']) {
      expect(find.text(group), findsOneWidget);
    }
    for (final row in [
      'Location',
      'Change email',
      'Change password',
      'Blocked users',
      'Terms of Use (EULA)',
      'Privacy Policy',
      'Log out',
      'Delete account',
    ]) {
      expect(find.text(row), findsOneWidget);
    }
    // The two legal rows leave the app.
    expect(find.byIcon(LucideIcons.externalLink), findsNWidgets(2));
    expect(find.text('Signed in with Google'), findsNothing);

    final delete = tester.widget<Text>(find.text('Delete account'));
    expect(delete.style?.color, ProfileTokens.danger);
  });

  testWidgets('location shows its status; Denied is red', (tester) async {
    await pump(tester, location: SettingsLocationStatus.denied);

    final denied = tester.widget<Text>(find.text('Denied'));
    expect(denied.style?.color, ProfileTokens.danger);
  });

  testWidgets('location off and not set are muted', (tester) async {
    await pump(tester, location: SettingsLocationStatus.off);
    expect(
      tester.widget<Text>(find.text('Off')).style?.color,
      ProfileTokens.muted,
    );

    await pump(tester, location: SettingsLocationStatus.unknown);
    await tester.pump();
    expect(find.text('Not set'), findsOneWidget);
  });

  testWidgets('a Google account has no email or password to change', (
    tester,
  ) async {
    await pump(tester, provider: 'google');

    expect(find.text('Signed in with Google'), findsOneWidget);
    expect(find.text('Change email'), findsNothing);
    expect(find.text('Change password'), findsNothing);
    expect(find.text('Blocked users'), findsOneWidget);
  });

  testWidgets('Log out asks in a sheet and signs out on confirm', (
    tester,
  ) async {
    final auth = await pump(tester);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Log out?'), findsOneWidget);
    expect(find.text('Are you sure you want to log out?'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);

    await tester.tap(find.widgetWithText(ProfilePillButton, 'Log out'));
    await tester.pumpAndSettle();
    expect(auth.events.whereType<AuthSignOutEvent>(), hasLength(1));
  });

  testWidgets('cancelling the log out sheet does nothing', (tester) async {
    final auth = await pump(tester);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(auth.events, isEmpty);
    expect(find.text('Log out?'), findsNothing);
  });

  group('Delete account', () {
    Future<void> open(WidgetTester tester) async {
      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
    }

    testWidgets('email account: the password unlocks the red button', (
      tester,
    ) async {
      final auth = await pump(tester);
      await open(tester);

      expect(find.text('Delete account?'), findsOneWidget);
      expect(find.text('Enter your password to confirm:'), findsOneWidget);
      expect(button(tester, 'Delete account').onTap, isNull);

      await tester.enterText(find.byType(TextField), 'hunter2');
      await tester.pump();
      expect(button(tester, 'Delete account').onTap, isNotNull);

      await tester.tap(
        find.widgetWithText(ProfilePillButton, 'Delete account'),
      );
      await tester.pump();

      final sent = auth.events.whereType<AuthDeleteAccountEvent>().single;
      expect(sent.password, 'hunter2');
      // Deleting: the button says so and Cancel is out of reach.
      expect(find.text('Deleting…'), findsOneWidget);
      expect(button(tester, 'Cancel').onTap, isNull);

      // Let the sheet go, so its spinner does not outlive the test.
      auth.push(const AuthAccountDeleted());
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });

    testWidgets('Google account: only DELETE in capitals unlocks it', (
      tester,
    ) async {
      final auth = await pump(tester, provider: 'google');
      await open(tester);

      expect(find.text('Type DELETE in capitals to confirm:'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'DELET');
      await tester.pump();
      expect(button(tester, 'Delete account').onTap, isNull);

      // Typed in lower case, the field upper-cases it.
      await tester.enterText(find.byType(TextField), 'delete');
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'DELETE',
      );
      expect(button(tester, 'Delete account').onTap, isNotNull);

      await tester.tap(
        find.widgetWithText(ProfilePillButton, 'Delete account'),
      );
      await tester.pump();
      final sent = auth.events.whereType<AuthDeleteAccountEvent>().single;
      expect(sent.password, isNull);

      auth.push(const AuthAccountDeleted());
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });

    testWidgets('an error shows under the field, not in a toast', (
      tester,
    ) async {
      final auth = await pump(tester);
      await open(tester);

      await tester.enterText(find.byType(TextField), 'wrong');
      await tester.pump();
      await tester.tap(
        find.widgetWithText(ProfilePillButton, 'Delete account'),
      );
      await tester.pump();

      auth.push(AuthLoading());
      await tester.pump();
      auth.push(const AuthError('Incorrect password. Please try again.'));
      await tester.pumpAndSettle();

      // Still open, with the reason once: under the field.
      expect(find.text('Delete account?'), findsOneWidget);
      expect(
        find.text('Incorrect password. Please try again.'),
        findsOneWidget,
      );
      expect(find.byIcon(LucideIcons.circleAlert), findsOneWidget);
      expect(button(tester, 'Delete account').onTap, isNotNull);

      // Typing again clears it.
      await tester.enterText(find.byType(TextField), 'right');
      await tester.pump();
      expect(find.text('Incorrect password. Please try again.'), findsNothing);
    });

    testWidgets('Cancel closes the sheet without deleting', (tester) async {
      final auth = await pump(tester);
      await open(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Delete account?'), findsNothing);
      expect(auth.events, isEmpty);
    });
  });
}
