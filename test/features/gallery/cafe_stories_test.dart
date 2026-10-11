import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/gallery/domain/entities/cafe_story.dart';
import 'package:nook/features/gallery/presentation/stories/story_position.dart';
import 'package:nook/features/gallery/presentation/stories/story_seen_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'community_photos_fakes.dart';

void main() {
  group('groupCafeStories', () {
    test('one story per person, newest person first, photos oldest first', () {
      final stories = groupCafeStories([
        communityPhoto('p4', username: 'sai', takenAt: DateTime(2026, 3, 4)),
        communityPhoto('p3', username: 'lia', takenAt: DateTime(2026, 3, 3)),
        communityPhoto('p2', username: 'sai', takenAt: DateTime(2026, 3, 2)),
        communityPhoto('p1', username: 'ben', takenAt: DateTime(2026, 3, 1)),
      ]);

      expect(
        [for (final s in stories) s.credit.username],
        ['sai', 'lia', 'ben'],
      );
      expect([for (final p in stories.first.photos) p.id], ['p2', 'p4']);
      expect(stories.first.latest.id, 'p4');
    });

    test('same date: keeps the server order (newest id first)', () {
      final stories = groupCafeStories([
        communityPhoto('p3', username: 'sai'),
        communityPhoto('p2', username: 'lia'),
        communityPhoto('p1', username: 'sai'),
      ]);

      expect(stories.first.credit.username, 'sai');
      // Oldest first: p1 came after p3 in the newest-first list.
      expect([for (final p in stories.first.photos) p.id], ['p1', 'p3']);
    });

    test('nothing in, nothing out', () {
      expect(groupCafeStories(const []), isEmpty);
    });
  });

  group('CafeStory seen', () {
    final story = groupCafeStories([
      communityPhoto('p3', takenAt: DateTime(2026, 3, 3)),
      communityPhoto('p2', takenAt: DateTime(2026, 3, 2)),
      communityPhoto('p1', takenAt: DateTime(2026, 3, 1)),
    ]).single;

    test('starts at the first unseen photo', () {
      expect(story.startIndexFor({}), 0);
      expect(story.startIndexFor({'p1'}), 1);
      expect(story.startIndexFor({'p1', 'p2'}), 2);
    });

    test('all seen: seen, and a rewatch starts at the beginning', () {
      final all = {'p1', 'p2', 'p3'};
      expect(story.isSeenIn(all), isTrue);
      expect(story.isSeenIn({'p1', 'p2'}), isFalse);
      expect(story.startIndexFor(all), 0);
    });
  });

  group('storyAgeLabel', () {
    final now = DateTime(2026, 10, 11, 12);

    test('short ages, then the month', () {
      expect(storyAgeLabel(now, now), 'now');
      expect(
        storyAgeLabel(now.subtract(const Duration(minutes: 12)), now),
        '12m',
      );
      expect(storyAgeLabel(now.subtract(const Duration(hours: 5)), now), '5h');
      expect(storyAgeLabel(now.subtract(const Duration(days: 3)), now), '3d');
      expect(storyAgeLabel(now.subtract(const Duration(days: 15)), now), '2w');
      expect(storyAgeLabel(DateTime(2026, 7, 19), now), 'Jul 2026');
    });

    test('a date in the future (clock skew) reads now', () {
      expect(storyAgeLabel(now.add(const Duration(hours: 1)), now), 'now');
    });
  });

  group('StoryPosition', () {
    final stories = groupCafeStories([
      communityPhoto('a2', username: 'sai', takenAt: DateTime(2026, 3, 4)),
      communityPhoto('a1', username: 'sai', takenAt: DateTime(2026, 3, 3)),
      communityPhoto('b1', username: 'lia', takenAt: DateTime(2026, 3, 2)),
    ]);

    test('next walks a person, then the next person, then done', () {
      var at = StoryPosition.startOf(stories, 0, {});
      expect(at, const StoryPosition(0, 0));
      at = at.next(stories, {});
      expect(at, const StoryPosition(0, 1));
      at = at.next(stories, {});
      expect(at, const StoryPosition(1, 0));
      at = at.next(stories, {});
      expect(at.done, isTrue);
    });

    test('previous walks back across people and stops at the start', () {
      expect(
        const StoryPosition(1, 0).previous(stories),
        const StoryPosition(0, 1),
      );
      expect(
        const StoryPosition(0, 1).previous(stories),
        const StoryPosition(0, 0),
      );
      expect(
        const StoryPosition(0, 0).previous(stories),
        const StoryPosition(0, 0),
      );
    });

    test('the next person starts at their first unseen photo', () {
      final two = groupCafeStories([
        communityPhoto('a1', username: 'sai', takenAt: DateTime(2026, 3, 9)),
        communityPhoto('b2', username: 'lia', takenAt: DateTime(2026, 3, 2)),
        communityPhoto('b1', username: 'lia', takenAt: DateTime(2026, 3, 1)),
      ]);
      expect(
        const StoryPosition(0, 0).next(two, {'b1'}),
        const StoryPosition(1, 1),
      );
    });
  });

  group('StorySeenCubit', () {
    test('loads what was saved and saves what is marked', () async {
      final store = MemoryStorySeenStore({'p1'});
      final cubit = StorySeenCubit(store: store);
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state, {'p1'});

      await cubit.markSeen('p2');
      expect(cubit.state, {'p1', 'p2'});
      expect(store.saved, {'p1', 'p2'});
    });

    test('marking twice writes once', () async {
      final store = MemoryStorySeenStore();
      final cubit = StorySeenCubit(store: store);
      addTearDown(cubit.close);
      final states = <Set<String>>[];
      final sub = cubit.stream.listen(states.add);
      addTearDown(sub.cancel);

      await cubit.markSeen('p1');
      await cubit.markSeen('p1');
      await Future<void>.delayed(Duration.zero);
      expect(states, hasLength(1));
    });

    test('a mark made before the load finishes survives it', () async {
      final store = MemoryStorySeenStore({'old'});
      final cubit = StorySeenCubit(store: store);
      addTearDown(cubit.close);

      final loading = cubit.load();
      await cubit.markSeen('new');
      await loading;
      expect(cubit.state, containsAll(['old', 'new']));
    });
  });

  group('PrefsStorySeenStore', () {
    test('keeps only the newest ids past the cap', () async {
      SharedPreferences.setMockInitialValues({});
      const store = PrefsStorySeenStore(cap: 2);
      await store.save({'a', 'b', 'c'});
      expect(await store.load(), {'b', 'c'});
    });
  });
}
