import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/features/auth/presentation/pages/email_confirmation_pending_page.dart';
import 'package:nook/features/auth/presentation/widgets/auth_code_boxes.dart';

import '../auth_test_host.dart';
import '../fake_auth_bloc.dart';

/// A pushed state reaches the page a microtask later, then rebuilds it.
Future<void> _settleState(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

void main() {
  late FakeAuthBloc bloc;

  setUp(() {
    bloc = FakeAuthBloc(
      const AuthAwaitingEmailConfirmation(email: 'maria.cruz@gmail.com'),
    );
  });
  tearDown(() => bloc.close());

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      authTestHost(page: const EmailConfirmationPendingScreen(), bloc: bloc),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('code, verify, resend link and the way back (F2)', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(find.text('Enter your code'), findsOneWidget);
    expect(
      find.textContaining('maria.cruz@gmail.com', findRichText: true),
      findsOneWidget,
    );
    expect(tester.getSize(find.byType(AuthCodeBoxes)).height, 56);
    expect(find.text("Didn't get a code? Resend"), findsOneWidget);
    expect(find.text('Wrong email? Go back'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '482913');
    await tester.pump();
    await tester.tap(find.text('Verify & continue'));
    await tester.pump();
    expect((bloc.events.single as AuthVerifyOtpEvent).token, '482913');
  });

  testWidgets('a wrong code sits under the boxes (F5)', (tester) async {
    await pumpPage(tester);
    bloc.push(
      const AuthAwaitingEmailConfirmation(
        email: 'maria.cruz@gmail.com',
        isVerifying: true,
      ),
    );
    await _settleState(tester);
    expect(find.text('Verifying…'), findsOneWidget);

    bloc.push(
      const AuthAwaitingEmailConfirmation(
        email: 'maria.cruz@gmail.com',
        error: 'That code is incorrect or has expired.',
      ),
    );
    await _settleState(tester);
    expect(find.text('That code is incorrect or has expired.'), findsOne);
  });

  testWidgets('a sent code starts the 60s countdown as plain text (C6)', (
    tester,
  ) async {
    await pumpPage(tester);
    bloc.push(
      const AuthAwaitingEmailConfirmation(
        email: 'maria.cruz@gmail.com',
        resendCount: 1,
      ),
    );
    await _settleState(tester);
    expect(find.text('Resend code in 60s'), findsOneWidget);
    expect(find.text("Didn't get a code? Resend"), findsNothing);

    await tester.pump(const Duration(seconds: 61));
    expect(find.text("Didn't get a code? Resend"), findsOneWidget);
  });
}
