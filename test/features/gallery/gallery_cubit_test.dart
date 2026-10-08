import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/gallery/domain/entities/gallery_photo.dart';
import 'package:nook/features/gallery/domain/entities/picked_cafe.dart';
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

  test('a new cafe moves a photo; a review photo stays put', () async {
    await cubit.load();
    final photo = cubit.state.photos.firstWhere((p) => p.id == 'old');
    const lorenzo = PickedCafe(
      id: 'lorenzo',
      name: "Lorenzo's Cafe",
      area: 'Lahug, Cebu City',
    );
    expect(await cubit.setDetails(photo, cafe: lorenzo), isTrue);
    expect(repo.calls.last, 'details old null null cafe lorenzo');
    final moved = cubit.state.photos.firstWhere((p) => p.id == 'old');
    expect(moved.cafeId, 'lorenzo');
    expect(moved.cafeName, "Lorenzo's Cafe");
    expect(moved.cafeArea, 'Lahug, Cebu City');

    final review = galleryPhoto('rv', source: GalleryPhotoSource.review);
    await cubit.setDetails(review, cafe: lorenzo);
    expect(repo.calls.last, 'details rv null null');
  });

  group('upload', () {
    test('each photo waits in uploads until its row lands', () async {
      final gated = _GatedRepository();
      final c = GalleryCubit(repository: gated);
      addTearDown(c.close);
      await c.load();

      final done = c.upload(
        cafeId: 'cafe-9',
        photos: [pickedPhoto('a'), pickedPhoto('b')],
        source: GalleryPhotoSource.gallery,
        drinkName: 'Cortado',
      );
      expect(c.state.uploads, hasLength(2));
      expect(c.state.uploads.every((u) => !u.failed), isTrue);
      expect(c.state.photos, isEmpty);

      gated.gate.complete();
      final result = await done;
      expect(result, (added: 2, failed: 0));
      expect(c.state.uploads, isEmpty);
      expect(c.state.photos, hasLength(2));
      // One call per photo, so one failure never sinks the batch.
      expect(gated.added.map((a) => a.count), [1, 1]);
      expect(gated.added.every((a) => a.drink == 'Cortado'), isTrue);
    });

    test('a failed photo stays, and Retry adds it exactly once', () async {
      await cubit.load();
      repo.writeFailure = Exception('offline');
      final result = await cubit.upload(
        cafeId: 'cafe-9',
        photos: [pickedPhoto('a')],
        source: GalleryPhotoSource.gallery,
      );
      expect(result, (added: 0, failed: 1));
      final failed = cubit.state.uploads.single;
      expect(failed.failed, isTrue);

      repo.writeFailure = null;
      // Two quick taps on Retry: the second finds it already going.
      final first = cubit.retryUpload(failed.id);
      final second = cubit.retryUpload(failed.id);
      expect(await first, isTrue);
      expect(await second, isFalse);
      expect(repo.added, hasLength(1));
      expect(cubit.state.uploads, isEmpty);
      expect(ids(), contains('new-5'));
    });

    test('a failed photo can be removed instead', () async {
      await cubit.load();
      repo.writeFailure = Exception('offline');
      await cubit.upload(
        cafeId: 'cafe-9',
        photos: [pickedPhoto('a')],
        source: GalleryPhotoSource.gallery,
      );
      cubit.discardUpload(cubit.state.uploads.single.id);
      expect(cubit.state.uploads, isEmpty);
    });

    test('a reload keeps photos still uploading', () async {
      final gated = _GatedRepository();
      final c = GalleryCubit(repository: gated);
      addTearDown(c.close);
      await c.load();
      final done = c.upload(
        cafeId: 'cafe-9',
        photos: [pickedPhoto('a')],
        source: GalleryPhotoSource.gallery,
      );
      await c.load(refresh: true);
      expect(c.state.uploads, hasLength(1));
      gated.gate.complete();
      await done;
    });

    test('signing out drops uploads; a late row does not come back', () async {
      final gated = _GatedRepository();
      final c = GalleryCubit(repository: gated);
      addTearDown(c.close);
      await c.load();
      final done = c.upload(
        cafeId: 'cafe-9',
        photos: [pickedPhoto('a')],
        source: GalleryPhotoSource.gallery,
      );
      c.clear();
      gated.gate.complete();
      await done;
      expect(c.state.photos, isEmpty);
      expect(c.state.uploads, isEmpty);
    });
  });
}

/// Holds every add until [gate] completes.
class _GatedRepository extends FakeGalleryRepository {
  final gate = Completer<void>();

  @override
  Future<List<GalleryPhoto>> addPhotos({
    required String cafeId,
    required List<PickedGalleryPhoto> photos,
    required GalleryPhotoSource source,
    String? drinkName,
    String? caption,
  }) async {
    await gate.future;
    return super.addPhotos(
      cafeId: cafeId,
      photos: photos,
      source: source,
      drinkName: drinkName,
      caption: caption,
    );
  }
}
