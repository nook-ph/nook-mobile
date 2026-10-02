import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/preferences/review_draft_store.dart';
import 'package:nook/core/utils/compressed_image_target.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ReviewDraftStore', () {
    late ReviewDraftStore store;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      store = ReviewDraftStore();
    });

    test('a draft is only visible to the account that wrote it', () async {
      await store.save(
        'cafe-1',
        text: 'Quiet upstairs',
        rating: 4,
        userId: 'a',
      );

      expect(await store.load('cafe-1', userId: 'b'), isNull);

      final own = await store.load('cafe-1', userId: 'a');
      expect(own!.text, 'Quiet upstairs');
      expect(own.rating, 4);
    });

    test('two accounts keep separate drafts for the same cafe', () async {
      await store.save('cafe-1', text: 'From A', rating: 5, userId: 'a');
      await store.save('cafe-1', text: 'From B', rating: 2, userId: 'b');

      expect((await store.load('cafe-1', userId: 'a'))!.text, 'From A');
      expect((await store.load('cafe-1', userId: 'b'))!.text, 'From B');
    });

    test('clearing one account\'s draft leaves the other\'s', () async {
      await store.save('cafe-1', text: 'From A', rating: 5, userId: 'a');
      await store.save('cafe-1', text: 'From B', rating: 2, userId: 'b');

      await store.clear('cafe-1', userId: 'a');

      expect(await store.load('cafe-1', userId: 'a'), isNull);
      expect(await store.load('cafe-1', userId: 'b'), isNotNull);
    });

    test('without a user id it still keys by cafe', () async {
      await store.save('cafe-1', text: 'Old style', rating: 3);

      expect((await store.load('cafe-1'))!.text, 'Old style');
      expect(await store.load('cafe-1', userId: 'a'), isNull);
    });
  });

  group('compressedImageTarget', () {
    test('a PNG stays a PNG', () {
      expect(compressedImageTarget('/tmp/pick/shot.png'), (
        path: '/tmp/pick/shot_compressed.png',
        isPng: true,
      ));
    });

    test('everything else is written, and named, as JPEG', () {
      for (final name in ['a.jpg', 'a.jpeg', 'a.heic', 'a.webp', 'a.HEIC']) {
        expect(compressedImageTarget('/tmp/pick/$name'), (
          path: '/tmp/pick/a_compressed.jpg',
          isPng: false,
        ), reason: name);
      }
    });

    test('an upper-case extension never yields the source path', () {
      final target = compressedImageTarget('/tmp/pick/IMG_0001.JPG');
      expect(target.path, '/tmp/pick/IMG_0001_compressed.jpg');
      expect(target.path, isNot('/tmp/pick/IMG_0001.JPG'));
      expect(compressedImageTarget('/tmp/pick/IMG.PNG').isPng, isTrue);
    });

    test('only the final extension is replaced', () {
      expect(
        compressedImageTarget('/data/user.jpg.cache/photo.jpg').path,
        '/data/user.jpg.cache/photo_compressed.jpg',
      );
      expect(
        compressedImageTarget('/data/v1.2/photo').path,
        '/data/v1.2/photo_compressed.jpg',
      );
    });
  });
}
