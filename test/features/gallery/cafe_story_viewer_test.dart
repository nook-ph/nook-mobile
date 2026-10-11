import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/gallery/domain/entities/cafe_story.dart';
import 'package:nook/features/gallery/domain/entities/community_photo.dart';
import 'package:nook/features/gallery/presentation/stories/cafe_story_viewer_page.dart';
import 'package:nook/features/gallery/presentation/stories/story_seen_cubit.dart';
import 'package:nook/utils/theme/theme.dart';

import '../lists/lists_fixtures.dart' show usePhone;
import 'community_photos_fakes.dart';

void main() {
  late StorySeenCubit seen;
  late List<String> reported;
  late List<String> authors;

  // sai: a1 (Flat white), a2 (Cortado); lia: b1 (Spanish latte).
  final stories = groupCafeStories([
    communityPhoto(
      'a2',
      username: 'sai',
      drink: 'Cortado',
      takenAt: DateTime(2026, 3, 4),
    ),
    communityPhoto(
      'a1',
      username: 'sai',
      drink: 'Flat white',
      takenAt: DateTime(2026, 3, 3),
    ),
    communityPhoto(
      'b1',
      username: 'lia',
      drink: 'Spanish latte',
      takenAt: DateTime(2026, 3, 2),
    ),
  ]);

  setUp(() {
    reported = [];
    authors = [];
  });

  /// Opens the viewer from a home screen, so closing it can be seen.
  Future<void> open(
    WidgetTester tester, {
    List<CafeStory>? given,
    int initialStory = 0,
    bool autoAdvance = true,
    Set<String> seenIds = const {},
  }) async {
    usePhone(tester);
    seen = StorySeenCubit(store: MemoryStorySeenStore(seenIds));
    await seen.load();
    addTearDown(seen.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: TAppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CafeStoryViewerPage(
                      stories: given ?? stories,
                      initialStory: initialStory,
                      cafeId: 'cafe-1',
                      seen: seen,
                      autoAdvance: autoAdvance,
                      onOpenAuthor: (credit) async =>
                          authors.add(credit.username),
                      onReport: (CommunityPhoto photo) async =>
                          reported.add(photo.id),
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    // Not pumpAndSettle: it would run the story clock to the end.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // The post-frame show and the (instant) image load.
    await tester.pump();
    await tester.pump();
  }

  Future<void> tapAt(WidgetTester tester, double fraction) async {
    final box = tester.getRect(
      find.bySemanticsLabel(RegExp(r'Photo \d of \d')),
    );
    await tester.tapAt(Offset(box.left + box.width * fraction, box.center.dy));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('opens on the person, credited, and marks the photo seen', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('@sai'), findsOneWidget);
    expect(find.text('Flat white'), findsOneWidget);
    expect(find.text('Mar 2026'), findsOneWidget);
    expect(seen.state, {'a1'});
  });

  testWidgets('tap right goes on, tap left goes back, across people', (
    tester,
  ) async {
    await open(tester, autoAdvance: false);

    await tapAt(tester, 0.8);
    expect(find.text('Cortado'), findsOneWidget);
    await tapAt(tester, 0.8);
    await tester.pumpAndSettle();
    expect(find.text('Spanish latte'), findsOneWidget);
    expect(find.text('@lia'), findsOneWidget);
    await tapAt(tester, 0.1);
    await tester.pumpAndSettle();
    expect(find.text('Cortado'), findsOneWidget);
    expect(seen.state, {'a1', 'a2', 'b1'});
  });

  testWidgets('advances by itself, and holding pauses it', (tester) async {
    await open(tester);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Flat white'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2, milliseconds: 100));
    await tester.pump();
    await tester.pump();
    expect(find.text('Cortado'), findsOneWidget);

    final photo = find.bySemanticsLabel(RegExp(r'Photo \d of \d'));
    final gesture = await tester.startGesture(tester.getCenter(photo));
    await tester.pump(const Duration(milliseconds: 600)); // long press
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('Cortado'), findsOneWidget);
    await gesture.up();
    await tester.pump();
  });

  testWidgets('without auto-advance (Reduce Motion) nothing moves alone', (
    tester,
  ) async {
    await open(tester, autoAdvance: false);

    await tester.pump(const Duration(seconds: 20));
    expect(find.text('Flat white'), findsOneWidget);
  });

  testWidgets('past the last photo of the last person it closes', (
    tester,
  ) async {
    await open(tester, initialStory: 1, autoAdvance: false);

    expect(find.text('Spanish latte'), findsOneWidget);
    await tapAt(tester, 0.8);
    await tester.pumpAndSettle();
    expect(find.byType(CafeStoryViewerPage), findsNothing);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('swiping sideways changes person', (tester) async {
    await open(tester, autoAdvance: false);

    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('@lia'), findsOneWidget);
    expect(find.text('Spanish latte'), findsOneWidget);
  });

  testWidgets('swiping down closes', (tester) async {
    await open(tester, autoAdvance: false);

    await tester.fling(find.byType(PageView), const Offset(0, 400), 1500);
    await tester.pumpAndSettle();
    expect(find.byType(CafeStoryViewerPage), findsNothing);
  });

  testWidgets('the poster opens their profile; report is in "…"', (
    tester,
  ) async {
    await open(tester, autoAdvance: false);

    await tester.tap(find.bySemanticsLabel(RegExp('Open @sai’s profile')));
    await tester.pump();
    expect(authors, ['sai']);

    await tester.tap(find.bySemanticsLabel('Photo options'));
    await tester.pump();
    expect(reported, ['a1']);
  });

  testWidgets('your own story reads "You", no link and no report', (
    tester,
  ) async {
    await open(
      tester,
      given: groupCafeStories([
        communityPhoto('m1', username: 'me', isSelf: true),
      ]),
      autoAdvance: false,
    );

    expect(find.text('You'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('profile')), findsNothing);
    expect(find.bySemanticsLabel('Photo options'), findsNothing);
    await tester.tap(find.text('You'));
    await tester.pump();
    expect(authors, isEmpty);
  });

  testWidgets('starts at the first photo not yet seen', (tester) async {
    await open(tester, seenIds: {'a1'}, autoAdvance: false);

    expect(find.text('Cortado'), findsOneWidget);
  });

  testWidgets('a photo that does not load can still be passed', (tester) async {
    await open(tester, autoAdvance: false);

    // The fakes point at files that do not exist.
    await tapAt(tester, 0.8);
    expect(find.text('Cortado'), findsOneWidget);
  });

  testWidgets('large text: header and words still fit', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(
      tester,
      given: groupCafeStories([
        communityPhoto(
          'l1',
          username: 'a_very_long_username_for_a_coffee_person',
          drink: 'Iced oat-milk Spanish latte with an extra shot',
        ),
      ]),
      autoAdvance: false,
    );

    expect(tester.takeException(), isNull);
  });
}
