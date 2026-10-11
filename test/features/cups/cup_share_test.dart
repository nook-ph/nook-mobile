import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/services/share_service.dart';
import 'package:nook/features/cafe_details/presentation/widgets/review_actions_sheet.dart';
import 'package:nook/features/cups/data/cups_json.dart';
import 'package:nook/features/cups/domain/entities/cup.dart';
import 'package:nook/features/cups/presentation/share/cup_share_sheet.dart';
import 'package:nook/features/cups/presentation/share/cup_story_overlay.dart';
import 'package:nook/features/cups/presentation/widgets/cup_composer_sheet.dart';

CupCard _cup({
  String? cupId = 'cup-1',
  bool isMine = true,
  String? moderation,
  int? rating,
  String? note,
  List<CupItem> items = const [],
}) => CupCard(
  id: cupId ?? 'u:day',
  cupId: cupId,
  userId: 'u1',
  username: 'sai',
  visitedAt: DateTime(2026, 10, 11),
  isMine: isMine,
  moderationStatus: moderation,
  rating: rating,
  note: note,
  items: items,
);

const _latte = CupItem(
  id: 'i1',
  kind: CupItemKind.coffee,
  name: 'Spanish latte',
);
const _bread = CupItem(id: 'i2', kind: CupItemKind.food, name: 'Banana bread');

void main() {
  group('share rules', () {
    test('only your own visible cup with an id can be shared', () {
      expect(_cup().canShare, isTrue);
      expect(_cup(moderation: 'visible').canShare, isTrue);
      expect(_cup(moderation: 'hidden').canShare, isFalse);
      expect(_cup(isMine: false).canShare, isFalse);
      expect(_cup(cupId: null).canShare, isFalse);
    });

    test('moderation_status is read from the cup json', () {
      final card = CupsJson.card({
        'id': 'c1',
        'user_id': 'u1',
        'visited_at': '2026-10-11',
        'moderation_status': 'hidden',
      });
      expect(card.moderationStatus, 'hidden');
      expect(CupsJson.card({'id': 'c1'}).moderationStatus, isNull);
    });

    test('the posted toast offers Share for a new visible cup only', () {
      CupComposerOutcome out(CupComposerAction a, CupCard? cup) =>
          CupComposerOutcome(a, result: CupPostResult(cup: cup));
      expect(shareableCup(out(CupComposerAction.posted, _cup())), isNotNull);
      expect(shareableCup(out(CupComposerAction.posted, null)), isNull);
      expect(
        shareableCup(out(CupComposerAction.posted, _cup(moderation: 'hidden'))),
        isNull,
      );
      expect(shareableCup(out(CupComposerAction.updated, _cup())), isNull);
    });

    test('Share cup leads the own-cup menu only when it can share', () {
      Iterable<ReviewOption> options(ReviewOptionsSheet s) =>
          s.options.map((o) => o.option);
      expect(
        options(ReviewOptionsSheet.forOwnCup(canShare: true)).first,
        ReviewOption.share,
      );
      expect(
        options(ReviewOptionsSheet.forOwnCup()),
        isNot(contains(ReviewOption.share)),
      );
    });
  });

  test('cupLink carries the ref', () {
    expect(
      ShareService.cupLink('abc', ref: 'cup_story'),
      'https://www.nookph.app/cups/abc?ref=cup_story',
    );
  });

  test('item line: first named item, its kind, and the rest', () {
    expect(cupItemLine(_cup()), isNull);
    expect(cupItemLine(_cup(items: [_latte])), 'Spanish latte · Coffee');
    expect(
      cupItemLine(_cup(items: [_latte, _bread])),
      'Spanish latte · Coffee +1 more',
    );
    expect(
      cupItemLine(
        _cup(
          items: [const CupItem(id: 'x', name: 'Mocha')],
        ),
      ),
      'Mocha',
    );
  });

  test('a long note is cut at a word', () {
    expect(clipNote('Short  and\nsweet'), 'Short and sweet');
    final long = List.filled(60, 'latte').join(' ');
    final clipped = clipNote(long);
    expect(clipped.length, lessThanOrEqualTo(181));
    expect(clipped, endsWith('latte…'));
  });

  group('CupStoryOverlay', () {
    Future<void> pump(WidgetTester t, CupCard cup, {bool onPhoto = false}) =>
        t.pumpWidget(
          MaterialApp(
            home: Center(
              child: CupStoryOverlay(
                cup: cup,
                cafeName: 'Volte Specialty Café',
                cafeArea: 'Lahug, Cebu City',
                onPhoto: onPhoto,
              ),
            ),
          ),
        );

    testWidgets('over a photo: what you had, the cafe, stars, no note', (
      t,
    ) async {
      await pump(
        t,
        _cup(note: 'Quiet upstairs', rating: 3, items: [_latte, _bread]),
        onPhoto: true,
      );
      expect(find.text('Spanish latte · Coffee +1 more'), findsOneWidget);
      expect(find.text('Volte Specialty Café'), findsOneWidget);
      expect(find.textContaining('Quiet upstairs'), findsNothing);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
    });

    testWidgets('note layout quotes the note over the items and cafe', (
      t,
    ) async {
      await pump(t, _cup(note: 'Quiet upstairs', rating: 4, items: [_latte]));
      expect(find.text('“Quiet upstairs”'), findsOneWidget);
      expect(find.text('Spanish latte'), findsOneWidget);
      expect(find.text('Volte Specialty Café'), findsOneWidget);
      expect(find.text('www.nookph.app'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
    });

    testWidgets('stars only: no headline, no empty quote', (t) async {
      await pump(t, _cup(rating: 5));
      expect(find.textContaining('“'), findsNothing);
      expect(find.text('Volte Specialty Café'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(5));
    });

    testWidgets('unrated: no stars', (t) async {
      await pump(t, _cup(note: 'Good'));
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(find.byIcon(Icons.star_outline_rounded), findsNothing);
    });

    testWidgets('ignores the device text size', (t) async {
      await t.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: MaterialApp(
            home: CupStoryOverlay(
              cup: _cup(note: 'Hi'),
              cafeName: 'Kamp',
              onPhoto: false,
            ),
          ),
        ),
      );
      final ctx = t.element(find.text('Kamp'));
      expect(MediaQuery.textScalerOf(ctx), TextScaler.noScaling);
    });
  });

  testWidgets('sheet: Share, the overlay alone, the link and the handle', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CupShareSheet(
            cup: _cup(note: 'Good', rating: 4),
            cafeId: 'cafe-1',
            cafeName: 'Kamp',
            entry: 'cup_menu',
            instagramRaw: 'https://www.instagram.com/kamp.cafe/?hl=en',
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Share the overlay only (transparent)'), findsOneWidget);
    expect(find.text('Choose photo'), findsOneWidget);
    expect(find.text('Link to your cup'), findsOneWidget);
    expect(find.text('Tag the café: @kamp.cafe'), findsOneWidget);
  });
}
