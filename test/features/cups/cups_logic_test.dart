import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/domain/entities/cafe_details.dart';
import 'package:nook/core/utils/content_filter.dart';
import 'package:nook/features/cups/data/cups_json.dart';
import 'package:nook/features/cups/data/legacy_cups.dart';
import 'package:nook/features/cups/domain/entities/cup.dart';
import 'package:nook/features/cups/presentation/cup_draft.dart';
import 'package:nook/features/cups/presentation/cup_menu.dart';
import 'package:nook/features/cups/presentation/widgets/cafe_cups_section.dart';
import 'package:nook/features/gallery/domain/entities/cafe_story.dart';
import 'package:nook/features/gallery/domain/entities/community_photo.dart';
import 'package:nook/features/gallery/domain/entities/gallery_photo.dart';

import '../gallery/community_photos_fakes.dart';
import '../gallery/gallery_fakes.dart';

Review _review(String id, String user, {int rating = 5, DateTime? at}) =>
    Review(
      id: id,
      cafeId: 'cafe-1',
      userId: user,
      rating: rating,
      content: 'Note $id',
      createdAt: at ?? DateTime(2026, 10, 1),
      updatedAt: at ?? DateTime(2026, 10, 1),
      name: user,
    );

void main() {
  group('CupsJson', () {
    test('a cup without stars has a null rating, never zero', () {
      final cup = CupsJson.card({
        'id': 'c1',
        'source': 'photos',
        'is_virtual': true,
        'user_id': 'u1',
        'username': 'sai',
        'rating': null,
        'visited_at': '2026-10-02',
        'items': [
          {
            'id': 'p1',
            'kind': null,
            'item_name': null,
            'photo': {'id': 'p1', 'image_url': 'https://cdn/p1.jpg'},
          },
        ],
      });
      expect(cup.rating, isNull);
      expect(cup.cupId, 'c1');
      expect(cup.isVirtual, isTrue);
      expect(cup.source, 'photos');
      expect(cup.items.single.kind, isNull);
      expect(cup.items.single.hasPhoto, isTrue);
      expect(CupsJson.rating(0), isNull);
      expect(CupsJson.rating(6), isNull);
      expect(CupsJson.rating('4'), 4);
    });

    test('a text item has no photo, and a menu name stands in', () {
      final item = CupsJson.item({
        'id': 'i1',
        'kind': 'food',
        'item_name': null,
        'menu_item_id': 'm1',
        'menu_item_name': 'Ensaymada',
        'photo': null,
      });
      expect(item.hasPhoto, isFalse);
      expect(item.label, 'Ensaymada');
      expect(item.menuItemId, 'm1');
    });

    test('stats: per-kind photo counts and the fair rating', () {
      final stats = CupsJson.stats({
        'cup_count': 5,
        'people_count': 3,
        'photo_count': 7,
        'coffee_photo_count': 4,
        'drink_photo_count': 0,
        'food_photo_count': 3,
        'space_photo_count': 0,
        'rated_people_count': 2,
        'rating': 4.5,
      });
      expect(stats.cupCount, 5);
      expect(stats.kindCounts, {CupItemKind.coffee: 4, CupItemKind.food: 3});
      expect(stats.hasRatings, isTrue);
      expect(stats.rating, 4.5);
      expect(CupsJson.stats({'rated_people_count': 0}).hasRatings, isFalse);
    });

    test('profile cups come grouped by cafe with their visits', () {
      final cups = CupsJson.profileCups({
        'user_id': 'u1',
        'highlights_public': true,
        'is_self': false,
        'cafes': [
          {
            'cafe_id': 'k',
            'cafe_name': 'Kamp',
            'visit_count': 4,
            'cups': [
              {'id': 'a', 'visited_at': '2026-09-01', 'rating': 4},
              {'id': 'b', 'visited_at': '2026-10-01', 'note': 'Again.'},
            ],
          },
        ],
      })!;
      final cafe = cups.cafes.single;
      expect(cafe.visitCount, 4);
      // Newest visit first.
      expect(cafe.cups.first.id, 'b');
      expect(cafe.rating, 4);
      expect(cafe.cups.first.userId, 'u1');
      expect(CupsJson.profileCups(null), isNull);
    });

    test('the visit date is sent as a day', () {
      expect(CupsJson.visitDate(DateTime(2026, 3, 4, 23, 30)), '2026-03-04');
    });
  });

  group('LegacyCups', () {
    test('each review is one visit; loose photos make one visit per person '
        'and day; review photos join their review', () {
      final cards = LegacyCups.cafeCards(
        cafeId: 'cafe-1',
        reviews: [_review('r1', 'user-lia')],
        photos: [
          CommunityPhoto(
            photo: galleryPhoto(
              'rp',
              source: GalleryPhotoSource.review,
            ).copyWith(),
            credit: const PhotoCredit(userId: 'user-lia', username: 'lia'),
          ),
          communityPhoto('a', username: 'sai', takenAt: DateTime(2026, 3, 1)),
          communityPhoto('b', username: 'sai', takenAt: DateTime(2026, 3, 1)),
          communityPhoto('c', username: 'sai', takenAt: DateTime(2026, 3, 8)),
        ],
      );
      // galleryPhoto's review photos point at 'review-1', not 'r1': loose.
      final sai = cards.where((c) => c.userId == 'user-sai').toList();
      expect(sai, hasLength(2));
      expect(sai.map((c) => c.photos.length).toSet(), {1, 2});
      expect(sai.every((c) => c.visitsByAuthor == 2), isTrue);
      expect(sai.every((c) => c.rating == null), isTrue);
      final lia = cards.firstWhere((c) => c.reviewId == 'r1');
      expect(lia.rating, 5);
      expect(lia.source, 'review');
    });

    test('the cafe rating counts each person once: their latest rated '
        'visit', () {
      final stats = CupStats.fromCards([
        CupCard(
          id: '1',
          userId: 'mae',
          username: 'mae',
          rating: 1,
          visitedAt: DateTime(2026, 1, 1),
        ),
        CupCard(
          id: '2',
          userId: 'mae',
          username: 'mae',
          rating: 5,
          visitedAt: DateTime(2026, 6, 1),
        ),
        CupCard(
          id: '3',
          userId: 'jun',
          username: 'jun',
          rating: 4,
          visitedAt: DateTime(2026, 2, 1),
        ),
        CupCard(
          id: '4',
          userId: 'sai',
          username: 'sai',
          visitedAt: DateTime(2026, 2, 1),
        ),
      ]);
      expect(stats.cupCount, 4);
      expect(stats.peopleCount, 3);
      expect(stats.ratedCount, 2);
      expect(stats.rating, 4.5);
    });

    test('the profile grid groups a person’s cups by cafe, newest first', () {
      final cafes = LegacyCups.profileCafes(
        userId: 'me',
        username: 'me',
        reviews: [
          WrittenReview(
            id: 'r1',
            cafeId: 'cafe-1',
            cafeName: 'Kamp',
            rating: 4,
            content: 'Good.',
            createdAt: DateTime(2026, 2, 1),
            updatedAt: DateTime(2026, 2, 1),
          ),
        ],
        photos: [
          galleryPhoto('a', takenAt: DateTime(2026, 5, 1)),
          galleryPhoto('h', takenAt: DateTime(2026, 6, 1), hidden: true),
          galleryPhoto('x', cafeId: 'cafe-2', takenAt: DateTime(2026, 1, 1)),
        ],
      );
      expect(cafes.map((c) => c.cafeId), ['cafe-1', 'cafe-2']);
      final kamp = cafes.first;
      expect(kamp.visitCount, 2);
      expect(kamp.cups.first.photos.single.id, 'a');
      expect(kamp.rating, 4);
      // Hidden photos stay off the grid.
      expect(kamp.photos.map((p) => p.id), ['a']);
    });
  });

  group('checkCupDraft', () {
    test('a photo, a named item or a note is enough; stars alone are not', () {
      expect(
        checkCupDraft(photoCount: 0, note: '  ', rating: 5),
        CupDraftIssue.empty,
      );
      expect(checkCupDraft(photoCount: 1, note: '', rating: null), isNull);
      expect(
        checkCupDraft(photoCount: 0, namedItemCount: 1, note: '', rating: null),
        isNull,
      );
      expect(checkCupDraft(photoCount: 0, note: 'Nice', rating: null), isNull);
    });

    test('limits', () {
      expect(
        checkCupDraft(photoCount: 8, namedItemCount: 3, note: '', rating: null),
        CupDraftIssue.tooManyItems,
      );
      expect(
        checkCupDraft(photoCount: 1, note: 'a' * 1001, rating: null),
        CupDraftIssue.noteTooLong,
      );
    });

    test('the legacy backend needs stars with a note', () {
      expect(
        checkCupDraft(photoCount: 1, note: 'Nice', rating: null, legacy: true),
        CupDraftIssue.needsRating,
      );
      expect(
        checkCupDraft(photoCount: 1, note: '', rating: null, legacy: true),
        isNull,
      );
      expect(
        checkCupDraft(photoCount: 0, note: 'Nice', rating: 4, legacy: true),
        isNull,
      );
    });

    test('the guidelines check covers the note and item names', () {
      expect(
        checkCupDraft(
          photoCount: 1,
          note: '',
          rating: null,
          itemNames: ['whore'],
        ),
        CupDraftIssue.objectionable,
      );
      expect(
        cupDraftMessage(CupDraftIssue.objectionable),
        ContentFilter.rejectionMessage,
      );
    });

    test('server codes read as words', () {
      expect(cupErrorMessage('cup_empty'), isNotNull);
      expect(cupErrorMessage('too_many_photos'), contains('10'));
      expect(cupErrorMessage('something_else'), isNull);
    });
  });

  test('menu kinds come from the name first, then the category', () {
    expect(guessCupKind('Coffee', 'Matcha latte'), CupItemKind.drink);
    expect(guessCupKind('Coffee & Tea', 'Spanish latte'), CupItemKind.coffee);
    expect(guessCupKind('Pastries', 'Ensaymada'), CupItemKind.food);
    expect(guessCupKind(null, 'Banana bread'), CupItemKind.food);
    expect(guessCupKind(null, 'House special'), isNull);
  });

  test('stats words leave out ratings nobody gave', () {
    expect(cupStatsParts(const CupStats(cupCount: 1)), ['1 cup']);
    expect(
      cupStatsParts(
        const CupStats(cupCount: 3, photoCount: 5, ratedCount: 2, rating: 4.5),
      ),
      ['2 ratings', '3 cups', '5 photos'],
    );
  });

  test('a ring says visits, then photos, never cups for one visit', () {
    final one = DateTime(2026, 10, 2, 10);
    CafeStory story(List<DateTime> days) => CafeStory(
      credit: const PhotoCredit(userId: 'u', username: 'u'),
      photos: [
        for (var i = 0; i < days.length; i++)
          communityPhoto('p$i', username: 'u', takenAt: days[i]),
      ],
    );
    expect(storySubLabel(story([one]), '2d'), '2d');
    expect(
      storySubLabel(story([one, one.add(const Duration(minutes: 5))]), 'x'),
      '2 photos',
    );
    expect(
      storySubLabel(story([one, one.add(const Duration(days: 3))]), 'x'),
      '2 visits',
    );
  });
}
