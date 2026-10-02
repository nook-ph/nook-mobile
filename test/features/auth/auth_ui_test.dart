import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/features/auth/presentation/widgets/auth_ui.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(24), child: child),
  ),
);

double _opacityAbove(WidgetTester tester, Finder finder) {
  return tester
      .widget<Opacity>(
        find.ancestor(of: finder, matching: find.byType(Opacity)),
      )
      .opacity;
}

void main() {
  group('isValidAuthEmail', () {
    test('accepts a normal address and rejects partial ones', () {
      expect(isValidAuthEmail('maria.cruz@gmail.com'), isTrue);
      expect(isValidAuthEmail('maria.cruz@gmail'), isFalse);
      expect(isValidAuthEmail('maria.cruz@'), isFalse);
      expect(isValidAuthEmail('maria @gmail.com'), isFalse);
    });
  });

  group('passwordHelper', () {
    test('shows muted while empty, even unfocused (C1)', () {
      final helper = passwordHelper(value: '', focused: false, minLength: 8);
      expect(helper?.text, 'At least 8 characters');
      expect(helper?.color, AuthColors.muted);
    });

    test('turns green once the rule is met while typing (C3)', () {
      final helper = passwordHelper(
        value: 'latte-at-nine',
        focused: true,
        minLength: 8,
      );
      expect(helper?.color, AuthColors.success);
    });

    test('stays muted while too short', () {
      final helper = passwordHelper(value: 'abc', focused: true, minLength: 6);
      expect(helper?.text, 'At least 6 characters');
      expect(helper?.color, AuthColors.muted);
    });

    test('hides once filled and the field is left (C4, D8)', () {
      expect(
        passwordHelper(value: 'latte-at-nine', focused: false, minLength: 8),
        isNull,
      );
    });
  });

  group('AuthPrimaryButton', () {
    testWidgets('is the same pill at 40% when it cannot be used', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const AuthPrimaryButton(label: 'Continue', onPressed: null)),
      );
      expect(_opacityAbove(tester, find.text('Continue')), 0.4);
      final box = tester.getSize(
        find.ancestor(
          of: find.text('Continue'),
          matching: find.byType(Container),
        ),
      );
      expect(box.height, 52);
    });

    testWidgets('fires when enabled', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(AuthPrimaryButton(label: 'Continue', onPressed: () => taps++)),
      );
      expect(_opacityAbove(tester, find.text('Continue')), 1);
      await tester.tap(find.text('Continue'));
      expect(taps, 1);
    });

    testWidgets('loading shows the spinner and loading label, full opacity', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          AuthPrimaryButton(
            label: 'Log in',
            loading: true,
            loadingLabel: 'Logging in…',
            onPressed: () => taps++,
          ),
        ),
      );
      expect(find.text('Logging in…'), findsOneWidget);
      expect(find.text('Log in'), findsNothing);
      expect(find.byType(AuthSpinner), findsOneWidget);
      expect(_opacityAbove(tester, find.text('Logging in…')), 1);
      await tester.tap(find.text('Logging in…'));
      expect(taps, 0);
    });
  });

  group('AuthOutlineButton', () {
    testWidgets('swaps its icon for the spinner while loading', (tester) async {
      await tester.pumpWidget(
        _host(
          const AuthOutlineButton(
            label: 'Continue with Apple',
            icon: Icon(LucideIcons.apple),
            loading: true,
            onPressed: null,
          ),
        ),
      );
      expect(find.byIcon(LucideIcons.apple), findsNothing);
      expect(find.byType(AuthSpinner), findsOneWidget);
      expect(find.text('Continue with Apple'), findsOneWidget);
    });
  });

  group('AuthTextField', () {
    testWidgets('label above, helper under, red stroke and message on error', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          AuthTextField(
            controller: controller,
            label: 'Password',
            hintText: 'Password',
            helperText: 'At least 8 characters',
          ),
        ),
      );
      expect(find.text('At least 8 characters'), findsOneWidget);
      expect(find.byType(AuthErrorLine), findsNothing);

      await tester.pumpWidget(
        _host(
          AuthTextField(
            controller: controller,
            label: 'Password',
            hintText: 'Password',
            helperText: 'At least 8 characters',
            errorText: 'Password must contain at least 8 characters',
          ),
        ),
      );
      // The error replaces the helper.
      expect(find.text('At least 8 characters'), findsNothing);
      expect(
        find.text('Password must contain at least 8 characters'),
        findsOneWidget,
      );
      expect(find.byIcon(LucideIcons.circleAlert), findsOneWidget);

      final decoration = tester
          .widget<TextField>(find.byType(TextField))
          .decoration!;
      final border = decoration.enabledBorder! as OutlineInputBorder;
      expect(border.borderSide.color, AuthColors.danger);
      expect(border.borderSide.width, 1.5);
      expect(border.borderRadius, BorderRadius.circular(12));
    });

    testWidgets('accent colour strokes the field (username available)', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'maria_cruz');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(
          AuthTextField(
            controller: controller,
            prefixText: '@',
            accentColor: AuthColors.success,
          ),
        ),
      );
      final border =
          tester
                  .widget<TextField>(find.byType(TextField))
                  .decoration!
                  .enabledBorder!
              as OutlineInputBorder;
      expect(border.borderSide.color, AuthColors.success);
      expect(find.text('@'), findsOneWidget);
    });
  });

  group('AuthStatusPill', () {
    testWidgets('three states use the design colours', (tester) async {
      await tester.pumpWidget(
        _host(
          const Column(
            children: [
              AuthStatusPill.checking(),
              AuthStatusPill.available(label: '@maria_cruz is available!'),
              AuthStatusPill.unavailable(label: '@maria is already taken.'),
            ],
          ),
        ),
      );
      expect(find.text('Checking availability…'), findsOneWidget);
      expect(find.byType(AuthSpinner), findsOneWidget);

      Color background(String label) {
        final container = tester.widget<Container>(
          find
              .ancestor(of: find.text(label), matching: find.byType(Container))
              .first,
        );
        return (container.decoration! as BoxDecoration).color!;
      }

      expect(background('Checking availability…'), AuthColors.tint);
      expect(background('@maria_cruz is available!'), AuthColors.successTint);
      expect(background('@maria is already taken.'), AuthColors.dangerTint);
      expect(find.byIcon(LucideIcons.circleCheck), findsOneWidget);
      expect(find.byIcon(LucideIcons.circleAlert), findsOneWidget);
    });
  });

  group('AuthCheckbox', () {
    testWidgets('toggles and shows the check only when ticked', (tester) async {
      var value = false;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => _host(
            AuthCheckbox(
              value: value,
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      );
      expect(find.byIcon(LucideIcons.check), findsNothing);
      await tester.tap(find.byType(AuthCheckbox));
      await tester.pump();
      expect(value, isTrue);
      expect(find.byIcon(LucideIcons.check), findsOneWidget);
    });
  });

  group('AuthToast', () {
    testWidgets('errors carry the alert, success the check', (tester) async {
      await tester.pumpWidget(
        _host(
          const Column(
            children: [
              AuthToast(message: 'Connection failed. Check your internet.'),
              AuthToast(
                message: 'Password updated successfully',
                success: true,
              ),
            ],
          ),
        ),
      );
      expect(find.byIcon(LucideIcons.circleAlert), findsOneWidget);
      expect(find.byIcon(LucideIcons.circleCheck), findsOneWidget);
    });
  });

  group('AuthPage', () {
    testWidgets('shows the back arrow only when there is somewhere to go', (
      tester,
    ) async {
      var backs = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: AuthPage(onBack: () => backs++, children: const [Text('Body')]),
        ),
      );
      await tester.tap(find.byIcon(LucideIcons.arrowLeft));
      expect(backs, 1);

      await tester.pumpWidget(
        const MaterialApp(home: AuthPage(children: [Text('Body')])),
      );
      expect(find.byIcon(LucideIcons.arrowLeft), findsNothing);
    });
  });
}
