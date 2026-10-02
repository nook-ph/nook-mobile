import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/features/profile/bloc/avatar_upload_state.dart';
import 'package:nook/features/profile/presentation/pages/editprofile_page.dart';
import 'package:nook/features/profile/presentation/widgets/profile_ui.dart';

import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'profile_test_support.dart';

void main() {
  /// The Save pill: usable only when it has a tap handler.
  bool saveEnabled(WidgetTester tester) {
    final save = tester.widget<ProfilePillButton>(
      find.widgetWithText(ProfilePillButton, 'Save changes'),
    );
    return save.onTap != null;
  }

  Finder field(String label) => find.descendant(
    of: find
        .ancestor(of: find.text(label), matching: find.byType(Column))
        .first,
    matching: find.byType(TextField),
  );

  Future<FakeProfileCubit> pump(
    WidgetTester tester, {
    FakeProfileCubit? cubit,
    FakeAvatarUploadBloc? avatar,
    Future<bool?> Function(String)? checkUsername,
    Future<File?> Function()? pickPhoto,
  }) async {
    final profileCubit = cubit ?? FakeProfileCubit(profile());
    await tester.pumpWidget(
      profileHost(
        cubit: profileCubit,
        avatar: avatar,
        page: EditProfilePage(
          checkUsername: checkUsername ?? (_) async => true,
          pickPhoto: pickPhoto,
        ),
      ),
    );
    await tester.pump();
    return profileCubit;
  }

  testWidgets('default: fields filled in, the rules under username, Save '
      'dimmed', (tester) async {
    await pump(tester);

    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.text('Change photo'), findsOneWidget);
    expect(find.text('Sai'), findsOneWidget);
    expect(find.text('saiimonn_'), findsOneWidget);
    expect(find.text('@'), findsOneWidget);
    expect(find.text(EditProfilePage.usernameRules), findsOneWidget);
    expect(find.text('23/150'), findsOneWidget);
    // Nothing has changed, so there is nothing to save.
    expect(saveEnabled(tester), isFalse);
  });

  testWidgets('a changed name makes Save usable and saves only what changed', (
    tester,
  ) async {
    final cubit = await pump(tester);

    await tester.enterText(field('Name'), 'Simon');
    await tester.pump();
    expect(saveEnabled(tester), isTrue);

    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(cubit.edits.single.name, 'Simon');
    // The username was not touched, so it is not sent (it has a cooldown).
    expect(cubit.edits.single.username, isNull);
    expect(find.text('Changes saved!'), findsOneWidget);
    expect(find.text('Edit profile'), findsNothing);
    await letToastExpire(tester);
  });

  testWidgets('an account with no name: the field is empty and a save does '
      'not write the placeholder', (tester) async {
    final cubit = await pump(
      tester,
      cubit: FakeProfileCubit(profile(name: 'No name')),
    );

    // "No name" is the profile's label, not text in the field.
    expect(tester.widget<TextField>(field('Name')).controller!.text, isEmpty);
    expect(saveEnabled(tester), isFalse);

    await tester.enterText(field('Bio'), 'Remote most days.');
    await tester.pump();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(cubit.edits.single.bio, 'Remote most days.');
    expect(cubit.edits.single.name, isNull);
    await letToastExpire(tester);
  });

  testWidgets('an emptied name cannot be saved', (tester) async {
    final cubit = await pump(tester);

    await tester.enterText(field('Name'), '   ');
    await tester.pump();

    expect(find.text('Name cannot be empty'), findsOneWidget);
    expect(saveEnabled(tester), isFalse);
    expect(cubit.edits, isEmpty);
  });

  testWidgets('only the fields that changed are written', (tester) async {
    final cubit = await pump(tester);

    await tester.enterText(field('Bio'), 'Cebu.');
    await tester.pump();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(cubit.edits.single.bio, 'Cebu.');
    expect(cubit.edits.single.name, isNull);
    expect(cubit.edits.single.username, isNull);
    await letToastExpire(tester);
  });

  testWidgets('a username taken at save time says so and keeps the other '
      'changes', (tester) async {
    final cubit = FakeProfileCubit(profile())
      ..usernameFailure = const PostgrestException(
        message: 'duplicate key value violates unique constraint',
        code: '23505',
      );
    await pump(tester, cubit: cubit);

    await tester.enterText(field('Name'), 'Simon');
    await tester.enterText(field('Username'), 'sai_brews');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    // The name went through on its own.
    expect(cubit.edits.single.name, 'Simon');
    expect(cubit.edits.single.username, isNull);
    // Toast and helper line both say it.
    expect(find.text('@sai_brews is already taken.'), findsNWidgets(2));
    expect(find.text('Edit profile'), findsOneWidget);
    expect(saveEnabled(tester), isFalse);
    await letToastExpire(tester);
  });

  testWidgets('changing only the case of your username skips the check', (
    tester,
  ) async {
    var checks = 0;
    final cubit = await pump(
      tester,
      checkUsername: (_) async {
        checks++;
        return false;
      },
    );

    await tester.enterText(field('Username'), 'Saiimonn_');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();

    expect(checks, 0);
    expect(find.textContaining('already taken'), findsNothing);
    expect(saveEnabled(tester), isTrue);

    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(cubit.edits.single.username, 'Saiimonn_');
    await letToastExpire(tester);
  });

  testWidgets('a photo that cannot be picked says so instead of throwing', (
    tester,
  ) async {
    await pump(tester, pickPhoto: () async => throw Exception('denied'));

    await tester.tap(find.bySemanticsLabel('Change photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from library'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not use that photo. Please try another.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await letToastExpire(tester);
  });

  testWidgets('username: checking, then available, in the one helper line', (
    tester,
  ) async {
    final answer = Completer<bool?>();
    await pump(tester, checkUsername: (_) => answer.future);

    await tester.enterText(field('Username'), 'sai_brews');
    await tester.pump();

    expect(find.text('Checking availability...'), findsOneWidget);
    expect(find.text(EditProfilePage.usernameRules), findsNothing);
    expect(saveEnabled(tester), isFalse);

    // The check is debounced.
    await tester.pump(const Duration(milliseconds: 700));
    answer.complete(true);
    await tester.pump();

    expect(find.text('@sai_brews is available!'), findsOneWidget);
    expect(find.byIcon(LucideIcons.check), findsOneWidget);
    expect(find.text('Checking availability...'), findsNothing);
    expect(saveEnabled(tester), isTrue);
  });

  testWidgets('username taken: red helper, Save stays dimmed', (tester) async {
    await pump(tester, checkUsername: (_) async => false);

    await tester.enterText(field('Username'), 'sai');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();

    expect(find.text('@sai is already taken.'), findsOneWidget);
    expect(find.byIcon(LucideIcons.circleAlert), findsOneWidget);
    expect(saveEnabled(tester), isFalse);
  });

  testWidgets('username invalid: says why without asking the server', (
    tester,
  ) async {
    var checks = 0;
    await pump(
      tester,
      checkUsername: (_) async {
        checks++;
        return true;
      },
    );

    await tester.enterText(field('Username'), 'sai brews!');
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Only letters, numbers, and underscores'), findsOneWidget);
    expect(saveEnabled(tester), isFalse);
    expect(checks, 0);
  });

  testWidgets('going back to the saved username drops the status', (
    tester,
  ) async {
    await pump(tester, checkUsername: (_) async => false);

    await tester.enterText(field('Username'), 'sai');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    await tester.enterText(field('Username'), 'saiimonn_');
    await tester.pump();

    expect(find.text(EditProfilePage.usernameRules), findsOneWidget);
    expect(find.text('@sai is already taken.'), findsNothing);
  });

  testWidgets('username locked: read-only with the days left', (tester) async {
    await pump(
      tester,
      cubit: FakeProfileCubit(
        profile(
          lastUsernameChange: DateTime.now().subtract(const Duration(days: 5)),
        ),
      ),
    );

    expect(
      find.text('You can change your username in 9 days.'),
      findsOneWidget,
    );
    expect(find.byIcon(LucideIcons.lock), findsOneWidget);
    expect(tester.widget<TextField>(field('Username')).enabled, isFalse);
    // The rest of the form still saves.
    await tester.enterText(field('Name'), 'Simon');
    await tester.pump();
    expect(saveEnabled(tester), isTrue);
  });

  testWidgets('the bio counter follows the text', (tester) async {
    await pump(tester);

    await tester.enterText(field('Bio'), 'Flat whites.');
    await tester.pump();

    expect(find.text('12/150'), findsOneWidget);
    expect(saveEnabled(tester), isTrue);
  });

  testWidgets('a failed save keeps the page open and says so', (tester) async {
    final cubit = FakeProfileCubit(profile())
      ..failure = const SocketException('offline');
    await pump(tester, cubit: cubit);

    await tester.enterText(field('Name'), 'Simon');
    await tester.pump();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not save your changes. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Edit profile'), findsOneWidget);
    expect(saveEnabled(tester), isTrue);
    await letToastExpire(tester);
  });

  testWidgets('Change photo opens the source sheet, library only', (
    tester,
  ) async {
    var picks = 0;
    await pump(
      tester,
      pickPhoto: () async {
        picks++;
        return null;
      },
    );

    await tester.tap(find.text('Change photo'));
    await tester.pumpAndSettle();

    expect(find.text('Choose from library'), findsOneWidget);
    expect(find.text('Pick a photo you already have'), findsOneWidget);
    // The camera needs a permission the app does not ask for yet.
    expect(find.text('Take a photo'), findsNothing);

    await tester.tap(find.text('Choose from library'));
    await tester.pumpAndSettle();
    expect(picks, 1);
    // Backing out of the picker changes nothing.
    expect(saveEnabled(tester), isFalse);
  });

  testWidgets('photo uploading: the label says so and Save is dimmed', (
    tester,
  ) async {
    final avatar = FakeAvatarUploadBloc();
    await pump(tester, avatar: avatar);

    avatar.push(const AvatarUploading());
    // One pump delivers the state, the next draws it. The spinner never
    // settles, so there is no pumpAndSettle here.
    await tester.pump();
    await tester.pump();

    expect(find.text('Uploading photo…'), findsOneWidget);
    expect(find.text('Change photo'), findsNothing);
    expect(find.byType(ProfileSpinner), findsOneWidget);
    expect(saveEnabled(tester), isFalse);
    expect(tester.widget<TextField>(field('Name')).enabled, isFalse);
  });

  testWidgets('upload failed: the reason is toasted and the page stays', (
    tester,
  ) async {
    final avatar = FakeAvatarUploadBloc();
    await pump(tester, avatar: avatar);

    avatar.push(
      const AvatarUploadError('Could not upload your photo. Please try again.'),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Could not upload your photo. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Edit profile'), findsOneWidget);
    await letToastExpire(tester);
  });
}
