import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/gallery/domain/entities/gallery_photo.dart';
import 'package:nook/features/gallery/presentation/cubit/gallery_cubit.dart';

import 'gallery_fakes.dart';

void main() {
  late FakeGalleryRepository repo;
  late GalleryCubit cubit;

  setUp(() {
    repo = FakeGalleryRepository([
      galleryPhoto('old', takenAt: DateTime(2025, 1, 1)),
      galleryPhoto('new', takenAt: DateTime(2026, 9, 1), cafeId: 'cafe-2'),
      galleryPhoto('pinned-2', takenAt: DateTime(2024, 1, 1), pin: 2),
      galleryPhoto('pinned-1', takenAt: DateTime(2023, 1, 1), pin: 1),
      galleryPhoto('hidden', takenAt: DateTime(2026, 1, 1), hidden: true),
    ]);
    cubit = GalleryCubit(repository: repo);
  });

  tearDown(() => cubit.close());

  List<String> ids() => [for (final p in cubit.state.photos) p.id];

  test('loads pinned photos first by slot, then newest first', () async {
    await cubit.load();
    expect(cubit.state.status, GalleryStatus.loaded);
    expect(ids(), ['pinned-1', 'pinned-2', 'new', 'hidden', 'old']);
  });

  test('counts cups and cafes visitors can see, and the hidden ones', () async {
    await cubit.load();
    expect(cubit.state.cupCount, 4);
    expect(cubit.state.cafeCount, 2);
    expect(cubit.state.hiddenCount, 1);
    expect(cubit.state.pinnedCount, 2);
  });

  test(
    'a failed first load fails; a failed refresh keeps the photos',
    () async {
      repo.readFailure = Exception('offline');
      await cubit.load();
      expect(cubit.state.status, GalleryStatus.failed);

      repo.readFailure = null;
      await cubit.load();
      repo.readFailure = Exception('offline');
      await cubit.load(refresh: true);
      expect(cubit.state.status, GalleryStatus.loaded);
      expect(cubit.state.photos, hasLength(5));
    },
  );

  group('pinning', () {
    test('pins to the first free slot', () async {
      await cubit.load();
      final photo = cubit.state.photos.firstWhere((p) => p.id == 'old');
      expect(await cubit.togglePin(photo), PinOutcome.pinned);
      expect(repo.calls, ['pin old 3']);
      expect(ids().take(3), ['pinned-1', 'pinned-2', 'old']);
    });

    test('a fourth pin is refused without a write', () async {
      repo.photos.add(galleryPhoto('pinned-3', pin: 3));
      await cubit.load();
      final photo = cubit.state.photos.firstWhere((p) => p.id == 'old');
      expect(await cubit.togglePin(photo), PinOutcome.full);
      expect(repo.calls, isEmpty);
    });

    test('unpinning frees the slot and puts it back by date', () async {
      await cubit.load();
      final photo = cubit.state.photos.firstWhere((p) => p.id == 'pinned-1');
      expect(await cubit.togglePin(photo), PinOutcome.unpinned);
      expect(repo.calls, ['pin pinned-1 null']);
      expect(ids().first, 'pinned-2');
      expect(ids().last, 'pinned-1');
    });

    test('a failed pin goes back', () async {
      await cubit.load();
      repo.writeFailure = Exception('offline');
      final photo = cubit.state.photos.firstWhere((p) => p.id == 'old');
      expect(await cubit.togglePin(photo), PinOutcome.failed);
      expect(
        cubit.state.photos.firstWhere((p) => p.id == 'old').isPinned,
        isFalse,
      );
    });
  });

  test('hiding a pinned photo unpins it', () async {
    await cubit.load();
    final photo = cubit.state.photos.firstWhere((p) => p.id == 'pinned-1');
    expect(await cubit.setHidden(photo, hidden: true), isTrue);
    final after = cubit.state.photos.firstWhere((p) => p.id == 'pinned-1');
    expect(after.isHidden, isTrue);
    expect(after.isPinned, isFalse);
    expect(cubit.state.cupCount, 3);
  });

  test('delete removes the photo; a failed one comes back', () async {
    await cubit.load();
    final photo = cubit.state.photos.firstWhere((p) => p.id == 'old');
    expect(await cubit.delete(photo), isTrue);
    expect(ids(), isNot(contains('old')));

    repo.writeFailure = Exception('offline');
    final other = cubit.state.photos.firstWhere((p) => p.id == 'new');
    expect(await cubit.delete(other), isFalse);
    expect(ids(), contains('new'));
  });

  test('a review photo is never deleted from the gallery', () async {
    repo.photos.add(
      galleryPhoto('from-review', source: GalleryPhotoSource.review),
    );
    await cubit.load();
    final photo = cubit.state.photos.firstWhere((p) => p.id == 'from-review');
    expect(await cubit.delete(photo), isFalse);
    expect(repo.calls, isEmpty);
    expect(ids(), contains('from-review'));
  });

  test('added photos join the grid by date', () async {
    await cubit.load();
    await cubit.addPhotos(
      cafeId: 'cafe-9',
      photos: [pickedPhoto('a', takenAt: DateTime(2026, 10, 1))],
      source: GalleryPhotoSource.gallery,
      drinkName: 'Cortado',
    );
    expect(repo.added.single.drink, 'Cortado');
    // Newest, so first after the pins.
    expect(ids()[2], 'new-5');
  });

  // A photo Nook's moderation took off the profile is the owner's only: it
  // is not a cup visitors see, and pinning it would only use up a slot.
  group('a moderated photo', () {
    setUp(() {
      repo.photos.add(
        galleryPhoto('modded', takenAt: DateTime(2026, 9, 9), moderated: true),
      );
    });

    test('is not counted as a cup', () async {
      await cubit.load();
      expect(ids(), contains('modded'));
      // Same as without it: old, new, pinned-2, pinned-1.
      expect(cubit.state.cupCount, 4);
      expect(cubit.state.cafeCount, 2);
    });

    test('is never pinned', () async {
      await cubit.load();
      final photo = cubit.state.photos.firstWhere((p) => p.id == 'modded');
      expect(await cubit.togglePin(photo), PinOutcome.failed);
      expect(repo.calls, isEmpty);
    });
  });

  // The ranking reveal can add a photo before the Profile tab ever loaded
  // the gallery. The grid must then hold the whole gallery, not just the
  // new photo.
  test('a photo added before the gallery loaded brings the rest', () async {
    expect(cubit.state.status, GalleryStatus.initial);
    await cubit.addPhotos(
      cafeId: 'cafe-9',
      photos: [pickedPhoto('a', takenAt: DateTime(2026, 10, 1))],
      source: GalleryPhotoSource.rank,
    );
    await pumpEventQueue();
    expect(cubit.state.status, GalleryStatus.loaded);
    expect(ids(), ['pinned-1', 'pinned-2', 'new-5', 'new', 'hidden', 'old']);
    expect(cubit.state.cupCount, 5);
  });

  test('a photo added while the gallery loads is not lost', () async {
    final gate = Completer<void>();
    repo.readGate = gate.future;
    // The read starts (and snapshots) before the photo is saved ...
    final loading = cubit.load();
    await cubit.addPhotos(
      cafeId: 'cafe-9',
      photos: [pickedPhoto('a', takenAt: DateTime(2026, 10, 1))],
      source: GalleryPhotoSource.rank,
    );
    // ... and returns after it.
    repo.readGate = null;
    gate.complete();
    await loading;
    await pumpEventQueue();
    expect(cubit.state.status, GalleryStatus.loaded);
    expect(ids(), contains('new-5'));
    expect(ids(), hasLength(6));
  });

  test('drink and note are trimmed, and blank clears them', () async {
    await cubit.load();
    final photo = cubit.state.photos.firstWhere((p) => p.id == 'old');
    await cubit.setDetails(
      photo,
      drinkName: '  Flat white ',
      caption: ' Silky, not too hot. ',
    );
    expect(repo.calls.last, 'details old Flat white Silky, not too hot.');
    expect(
      cubit.state.photos.firstWhere((p) => p.id == 'old').caption,
      'Silky, not too hot.',
    );
    await cubit.setDetails(photo, drinkName: '   ', caption: '');
    expect(repo.calls.last, 'details old null null');
    final cleared = cubit.state.photos.firstWhere((p) => p.id == 'old');
    expect(cleared.drinkName, isNull);
    expect(cleared.caption, isNull);
  });

  test('a note added with photos reaches the repository', () async {
    await cubit.load();
    await cubit.addPhotos(
      cafeId: 'cafe-9',
      photos: [pickedPhoto('a')],
      source: GalleryPhotoSource.gallery,
      caption: 'Best cortado in Lahug',
    );
    expect(repo.added.single.caption, 'Best cortado in Lahug');
  });
}
