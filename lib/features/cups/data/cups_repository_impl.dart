import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nook/core/cafe/domain/entities/report_reason.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/upload/domain/entities/uploaded_file.dart';
import 'package:nook/features/cups/data/cups_backend.dart';
import 'package:nook/features/cups/data/cups_json.dart';
import 'package:nook/features/cups/data/legacy_cups.dart';
import 'package:nook/features/cups/domain/entities/cup.dart';
import 'package:nook/features/cups/domain/i_cups_repository.dart';
import 'package:nook/features/gallery/data/gallery_repository_impl.dart';
import 'package:nook/features/gallery/domain/entities/gallery_photo.dart';
import 'package:nook/features/gallery/domain/i_community_photos_repository.dart';
import 'package:nook/features/gallery/domain/i_gallery_repository.dart';
import 'package:nook/features/public_profile/domain/i_public_profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// [ICupsRepository] on Supabase. Calls the Cups RPCs (nook-supabase
/// `feat/cups`) and, where the server doesn't have them yet, answers from
/// the reviews and gallery reads and writes the app used before
/// ([CupsBackend] decides once per run).
///
/// Photos upload the same way on both: the gallery presign
/// (`uploadType: gallery_photo`), so the files are reused if a cup RPC
/// turns out to be missing.
class CupsRepositoryImpl implements ICupsRepository {
  CupsRepositoryImpl({
    required SupabaseClient client,
    required CupsBackend backend,
    required GalleryFileUploader upload,
    required ICafeRepository cafes,
    required ICommunityPhotosRepository legacyPhotos,
    required IGalleryRepository gallery,
    required IPublicProfileRepository profiles,
  }) : _client = client,
       _backend = backend,
       _upload = upload,
       _cafes = cafes,
       _legacyPhotos = legacyPhotos,
       _gallery = gallery,
       _profiles = profiles;

  final SupabaseClient _client;
  final CupsBackend _backend;
  final GalleryFileUploader _upload;
  final ICafeRepository _cafes;
  final ICommunityPhotosRepository _legacyPhotos;
  final IGalleryRepository _gallery;
  final IPublicProfileRepository _profiles;

  /// How many of a cafe's photos the legacy path reads to build cups.
  static const _legacyPhotoLimit = 100;

  String? get _me => _client.auth.currentUser?.id;

  @override
  CupsMode get mode => _backend.mode;

  @override
  Future<CupsMode> resolveMode() async {
    if (_backend.mode != CupsMode.unknown) return _backend.mode;
    try {
      await _backend.run<void>(
        cups: () async {
          await _client.rpc(
            'get_cafe_cup_stats',
            params: {'p_cafe_ids': <String>[]},
          );
        },
        legacy: () async {},
      );
    } catch (e) {
      // Offline or the like: still unknown; the next call settles it.
      debugPrint('[Cups] mode not settled: $e');
    }
    return _backend.mode;
  }

  // ── Reads ──────────────────────────────────────────────────────────────

  @override
  Future<CafeCups> getCafeCups(
    String cafeId, {
    CupSort sort = CupSort.recommended,
    int? ratingFilter,
    CupItemKind? kind,
    int limit = 10,
    int offset = 0,
  }) => _guard(
    'Could not load the cups.',
    () => _backend.run(
      cups: () => _cupsCafeCups(
        cafeId,
        sort: sort,
        ratingFilter: ratingFilter,
        kind: kind,
        limit: limit,
        offset: offset,
      ),
      legacy: () => _legacyCafeCups(
        cafeId,
        sort: sort,
        ratingFilter: ratingFilter,
        kind: kind,
        limit: limit,
        offset: offset,
      ),
    ),
  );

  /// How many of a cafe's cups the kind counts and the kind filter read.
  /// Past this the counts are a floor; no cafe is near it (prod: 12 cups).
  static const kindScanLimit = 100;

  /// Cups per kind, by cafe: recounted on every unfiltered first page and
  /// dropped on any write, kept for the filtered pages in between.
  final _kindCounts = <String, Map<CupItemKind, int>>{};

  /// `get_cafe_cups` without its kind filter. The server's kind filter and
  /// its per-kind numbers count legacy photos as coffee and count photos,
  /// not cups; both are worked out here from the cards instead, so a chip's
  /// number is the number of cups it shows (UX review 4.2, 2.2).
  Future<CafeCups> _rpcCafeCups(
    String cafeId, {
    required CupSort sort,
    int? ratingFilter,
    required int limit,
    int offset = 0,
  }) async {
    final raw = await _client.rpc(
      'get_cafe_cups',
      params: {
        'p_cafe_id': cafeId,
        'p_sort': sort.wire,
        'p_rating_filter': ratingFilter,
        'p_kind_filter': null,
        'p_limit': limit.clamp(1, kindScanLimit),
        'p_offset': offset,
        // The stories tray reads its photos on its own.
        'p_photo_limit': 0,
      },
    );
    return CupsJson.cafeCups(raw, cafeId: cafeId);
  }

  Future<Map<CupItemKind, int>> _countKinds(String cafeId) async {
    final all = await _rpcCafeCups(
      cafeId,
      sort: CupSort.recent,
      limit: kindScanLimit,
    );
    return _kindCounts[cafeId] = CupStats.cupKindCounts(all.cards);
  }

  Future<CafeCups> _cupsCafeCups(
    String cafeId, {
    required CupSort sort,
    int? ratingFilter,
    CupItemKind? kind,
    required int limit,
    required int offset,
  }) async {
    if (kind == null) {
      final page = await _rpcCafeCups(
        cafeId,
        sort: sort,
        ratingFilter: ratingFilter,
        limit: limit,
        offset: offset,
      );
      final fresh = offset == 0 && ratingFilter == null;
      final Map<CupItemKind, int> counts;
      if (fresh && !page.hasMore) {
        // The page is every cup: count from it, no second read.
        counts = _kindCounts[cafeId] = CupStats.cupKindCounts(page.cards);
      } else {
        counts =
            (fresh ? null : _kindCounts[cafeId]) ?? await _countKinds(cafeId);
      }
      return CafeCups(
        cafeId: page.cafeId,
        stats: page.stats.copyWith(kindCounts: counts),
        cards: page.cards,
        total: page.total,
        hasMore: page.hasMore,
        myCups: page.myCups,
      );
    }
    // A kind: filtered here from the cafe's cups, in the asked order.
    final all = await _rpcCafeCups(
      cafeId,
      sort: sort,
      ratingFilter: ratingFilter,
      limit: kindScanLimit,
    );
    final matching = [
      for (final c in all.cards)
        if (LegacyCups.hasKind(c, kind)) c,
    ];
    final page = matching.skip(offset).take(limit).toList();
    final counts = ratingFilter == null
        ? (_kindCounts[cafeId] = CupStats.cupKindCounts(all.cards))
        : (_kindCounts[cafeId] ?? await _countKinds(cafeId));
    return CafeCups(
      cafeId: all.cafeId,
      stats: all.stats.copyWith(kindCounts: counts),
      cards: page,
      total: matching.length,
      hasMore: offset + page.length < matching.length,
      myCups: all.myCups,
    );
  }

  Future<CafeCups> _legacyCafeCups(
    String cafeId, {
    required CupSort sort,
    int? ratingFilter,
    CupItemKind? kind,
    required int limit,
    required int offset,
  }) async {
    final all = await _legacyCardsAt(cafeId);
    final matching = LegacyCups.sort([
      for (final c in all)
        if ((ratingFilter == null || c.rating == ratingFilter) &&
            (kind == null || LegacyCups.hasKind(c, kind)))
          c,
    ], sort);
    final page = matching.skip(offset).take(limit).toList();
    return CafeCups(
      cafeId: cafeId,
      stats: CupStats.fromCards(all),
      cards: page,
      total: matching.length,
      hasMore: offset + page.length < matching.length,
      myCups: LegacyCups.mine(all),
    );
  }

  Future<List<CupCard>> _legacyCardsAt(String cafeId) async {
    final reviewsRead = _cafes.getCafeReviewsById(cafeId);
    final photos = await _legacyPhotos.getCafePhotos(
      cafeId,
      limit: _legacyPhotoLimit,
    );
    return LegacyCups.cafeCards(
      reviews: await reviewsRead,
      photos: photos.photos,
      cafeId: cafeId,
      me: _me,
    );
  }

  @override
  Future<ProfileCups?> getProfileCups({String? userId, String? username}) =>
      _guard(
        'Could not load the cups.',
        () => _backend.run(
          cups: () async {
            final raw = await _client.rpc(
              'get_profile_cups',
              params: {
                'p_user_id': ?userId,
                if (userId == null) 'p_username': ?username,
              },
            );
            return CupsJson.profileCups(raw);
          },
          legacy: () => _legacyProfileCups(userId: userId, username: username),
        ),
      );

  Future<ProfileCups?> _legacyProfileCups({
    String? userId,
    String? username,
  }) async {
    final me = _me;
    if (me != null && userId == me) {
      final photosRead = _gallery.getMyPhotos();
      final reviews = await _cafes.getReviewsWrittenByUser(me);
      return ProfileCups(
        userId: me,
        isSelf: true,
        cafes: LegacyCups.profileCafes(
          userId: me,
          username: username ?? '',
          isMine: true,
          reviews: reviews,
          photos: await photosRead,
        ),
      );
    }
    final profile = await _profiles.getProfile(
      userId: userId,
      username: userId == null ? username : null,
    );
    if (profile == null) return null;
    return ProfileCups(
      userId: profile.userId,
      isSelf: profile.isSelf,
      highlightsPublic: profile.highlightsPublic,
      cafes: LegacyCups.profileCafes(
        userId: profile.userId,
        username: profile.username,
        avatarUrl: profile.avatarUrl,
        isMine: profile.isSelf,
        reviews: profile.reviews,
        photos: profile.highlightsPublic || profile.isSelf
            ? profile.photos
            : const [],
      ),
    );
  }

  // ── Writes ─────────────────────────────────────────────────────────────

  @override
  Future<CupPostResult> postCup({
    required String cafeId,
    int? rating,
    String? note,
    DateTime? visitedAt,
    required List<CupItemDraft> items,
    void Function(int index)? onPhotoUploaded,
  }) async {
    _kindCounts.clear();
    final cleanNote = _clean(note, maxCupNote);
    final cleanItems = _cleanItems(items);
    // Read alongside the uploads, so a post whose answer never came back
    // can be told apart from one that never landed.
    final before = _backend.mode == CupsMode.legacy ? null : _myCupIds(cafeId);
    final uploads = await _uploadItems(cleanItems, cafeId, onPhotoUploaded);
    final payload = _payload(cleanItems, uploads);
    // Set once a row points at the uploaded files: from then on they stay.
    var filesInUse = false;
    try {
      return await _backend.run(
        cups: () async {
          final raw = await _client.rpc(
            'post_cup',
            params: {
              'p_cafe_id': cafeId,
              'p_rating': rating,
              'p_note': cleanNote,
              'p_items': payload,
              'p_visited_at': visitedAt == null
                  ? null
                  : CupsJson.visitDate(visitedAt),
            },
          );
          return CupsJson.postResult(raw, itemsAdded: payload.length);
        },
        legacy: () async {
          final me = _requireMe();
          if (rating == null && cleanNote != null) {
            throw _needsRating;
          }
          if (rating != null) {
            final own = (await _cafes.getCafeReviewsById(
              cafeId,
            )).where((r) => r.userId == me).firstOrNull;
            if (own != null) {
              // 1.1.x keeps one review per cafe.
              throw const CupsException(
                'For now you can rate a cafe once. Edit your earlier cup to '
                'change it; photos can still go on a new one.',
                code: 'legacy_one_review',
              );
            }
          }
          if (rating == null && uploads.isEmpty) {
            throw const CupsException(
              'Add a photo to post your cup.',
              code: 'cup_empty',
            );
          }
          await _legacyInsertPhotos(me, cafeId, cleanItems, uploads);
          filesInUse = true;
          if (rating != null) {
            await _cafes.addCafeReview(
              cafeId: cafeId,
              userId: me,
              rating: rating,
              content: cleanNote ?? '',
            );
          }
          return CupPostResult(itemsAdded: uploads.length);
        },
      );
    } catch (e) {
      // No answer is not a no: the cup may be in. Then it is the result,
      // its files stay, and "Try again" can't post it twice.
      if (_unanswered(e) && before != null) {
        final landed = await _landedCup(
          cafeId,
          before: await before,
          rating: rating,
          note: cleanNote,
        );
        if (landed != null) {
          return CupPostResult(cup: landed, itemsAdded: payload.length);
        }
      }
      // Unless a row points at the files, "Try again" uploads them again.
      if (!filesInUse) {
        _deleteFiles([for (final f in uploads.values) f.objectKey]);
      }
      throw _wrap(e, 'Could not post your cup.');
    }
  }

  /// Ids of your cups at [cafeId]; null when the read fails.
  Future<Set<String>?> _myCupIds(String cafeId) async {
    try {
      final page = await _rpcCafeCups(cafeId, sort: CupSort.recent, limit: 1);
      return {for (final c in page.myCups) c.id};
    } catch (_) {
      return null;
    }
  }

  /// Your cup at [cafeId] that is not in [before] and has this post's
  /// stars and note: the post went in after all. Null if none, or if the
  /// cups can't be read either.
  Future<CupCard?> _landedCup(
    String cafeId, {
    required Set<String>? before,
    required int? rating,
    required String? note,
  }) async {
    if (before == null) return null;
    final List<CupCard> mine;
    try {
      mine = (await _rpcCafeCups(
        cafeId,
        sort: CupSort.recent,
        limit: 1,
      )).myCups;
    } catch (_) {
      return null;
    }
    return mine
        .where(
          (c) =>
              !before.contains(c.id) &&
              c.rating == rating &&
              (c.note?.trim() ?? '') == (note ?? ''),
        )
        .firstOrNull;
  }

  /// The request got no answer from the server (offline, timed out), as
  /// opposed to the server saying no.
  static bool _unanswered(Object e) =>
      e is! PostgrestException && e is! CupsException && e is! AuthException;

  @override
  Future<CupPostResult> updateCup(
    CupCard cup, {
    int? rating,
    String? note,
    DateTime? visitedAt,
    List<CupItemDraft> addItems = const [],
    List<String> removeItemIds = const [],
    void Function(int index)? onPhotoUploaded,
  }) async {
    _kindCounts.clear();
    final cafeId = cup.cafeId ?? '';
    final cleanNote = _clean(note, maxCupNote);
    final cleanItems = _cleanItems(addItems);
    final uploads = await _uploadItems(cleanItems, cafeId, onPhotoUploaded);
    final payload = _payload(cleanItems, uploads);
    final cupId = cup.cupId;
    // Set once a row points at the uploaded files: from then on they stay.
    var filesInUse = false;
    try {
      if (cupId != null) {
        // A real cup: the cup RPCs exist, or it couldn't have an id.
        // A legacy visit's id is virtual: the first call copies it into
        // cups under a new id and the virtual one stops resolving, so every
        // later call uses the id the server hands back. Items go in before
        // the stars and note, so a cup whose only photo is new isn't empty
        // when update_cup checks.
        var id = cupId;
        Object? raw;
        if (payload.isNotEmpty) {
          raw = await _client.rpc(
            'add_cup_items',
            params: {'p_cup_id': id, 'p_items': payload},
          );
          filesInUse = true;
          id = _returnedCupId(raw) ?? id;
        }
        raw = await _client.rpc(
          'update_cup',
          params: {
            'p_cup_id': id,
            'p_rating': rating,
            'p_note': cleanNote,
            'p_visited_at': visitedAt == null
                ? null
                : CupsJson.visitDate(visitedAt),
          },
        );
        id = _returnedCupId(raw) ?? id;
        for (final itemId in removeItemIds) {
          raw = await _client.rpc(
            'remove_cup_item',
            params: {'p_cup_id': id, 'p_item_id': itemId},
          );
          final keys = raw is Map && raw['object_keys'] is List
              ? [for (final k in raw['object_keys'] as List) k?.toString()]
              : const <String?>[];
          _deleteFiles(keys);
        }
        return CupsJson.postResult(raw, itemsAdded: payload.length);
      }

      // A legacy review or photo group.
      final me = _requireMe();
      if (rating == null && cleanNote != null) throw _needsRating;
      await _legacyInsertPhotos(me, cafeId, cleanItems, uploads);
      filesInUse = true;
      final reviewId = cup.reviewId;
      if (reviewId != null) {
        if (rating != null) {
          await _client
              .from('reviews')
              .update({'rating': rating, 'content': cleanNote ?? ''})
              .eq('id', reviewId)
              .eq('user_id', me);
        } else {
          // Stars and note both cleared: the review goes, photos stay.
          await _cafes.deleteReview(reviewId);
        }
      } else if (rating != null) {
        final own = (await _cafes.getCafeReviewsById(
          cafeId,
        )).where((r) => r.userId == me).firstOrNull;
        if (own != null) {
          throw const CupsException(
            'For now you can rate a cafe once. Edit your earlier cup to '
            'change it.',
            code: 'legacy_one_review',
          );
        }
        await _cafes.addCafeReview(
          cafeId: cafeId,
          userId: me,
          rating: rating,
          content: cleanNote ?? '',
        );
      }
      await _removePhotos(removeItemIds);
      return CupPostResult(itemsAdded: uploads.length);
    } catch (e) {
      if (!filesInUse) {
        _deleteFiles([for (final f in uploads.values) f.objectKey]);
      }
      throw _wrap(e, 'Could not save your cup.');
    }
  }

  /// The `cup.id` an add/update/remove RPC answers with.
  static String? _returnedCupId(Object? raw) {
    if (raw is! Map) return null;
    final cup = raw['cup'];
    if (cup is! Map) return null;
    final id = cup['id'];
    return id is String && id.isNotEmpty ? id : null;
  }

  @override
  Future<void> deleteCup(CupCard cup) =>
      _guard('Could not delete your cup.', () async {
        _kindCounts.clear();
        final cupId = cup.cupId;
        if (cupId != null) {
          final raw = await _client.rpc(
            'delete_cup',
            params: {'p_cup_id': cupId},
          );
          final keys = raw is Map && raw['object_keys'] is List
              ? [for (final k in raw['object_keys'] as List) k?.toString()]
              : const <String?>[];
          _deleteFiles(keys);
          return;
        }
        final reviewId = cup.reviewId;
        // The review's own photos go with it (its trigger); the rest of the
        // group are gallery photos.
        if (reviewId != null) await _cafes.deleteReview(reviewId);
        await _removePhotos([
          for (final i in cup.items)
            if (!i.isFromReview) i.id,
        ]);
      });

  @override
  Future<CupCard> toggleHelpful(CupCard card) =>
      _guard("Couldn't update. Please try again.", () async {
        final cupId = card.cupId;
        if (cupId != null) {
          final raw = await _client.rpc(
            'toggle_cup_helpful',
            params: {'p_cup_id': cupId},
          );
          final json = raw is Map ? raw : const {};
          return card.copyWith(
            hasVoted: json['voted'] == true,
            helpfulCount: (json['helpful_count'] as num?)?.toInt(),
          );
        }
        final reviewId = card.reviewId;
        final me = _me;
        if (reviewId == null || me == null) {
          throw const CupsException('Nothing to vote on.');
        }
        await _cafes.toggleHelpfulVote(reviewId, me, card.hasVoted);
        return card.copyWith(
          hasVoted: !card.hasVoted,
          helpfulCount: (card.helpfulCount + (card.hasVoted ? -1 : 1)).clamp(
            0,
            1 << 31,
          ),
        );
      });

  @override
  Future<void> reportCup(
    CupCard card, {
    required String cafeId,
    required ReportReason reason,
    String? details,
  }) => _guard('Could not send the report.', () async {
    final text = details?.trim();
    final description = text == null || text.isEmpty ? null : text;
    final cupId = card.cupId;
    if (cupId != null) {
      try {
        await _client.rpc(
          'report_cup',
          params: {
            'p_cup_id': cupId,
            'p_reason_code': reason.code,
            'p_description': description,
          },
        );
      } on PostgrestException catch (e) {
        // Reporting twice is not an error to the reporter.
        if (e.message != 'already_reported') rethrow;
      }
      return;
    }
    final reviewId = card.reviewId;
    final me = _me;
    if (reviewId != null && me != null) {
      await _cafes.reportReview(
        reviewId: reviewId,
        cafeId: cafeId,
        reporterId: me,
        reasonCode: reason.code,
        description: description,
      );
      return;
    }
    // Photos only: each photo goes to the photo queue.
    for (final photo in card.photos) {
      if (photo.id.startsWith('review:')) continue;
      await _profiles.reportPhoto(
        photo.id,
        photoReasonFor(reason),
        details: description,
      );
    }
  });

  // ── Helpers ────────────────────────────────────────────────────────────

  static const _needsRating = CupsException(
    'Add a star rating to post your note.',
    code: 'legacy_needs_rating',
  );

  String _requireMe() {
    final me = _me;
    if (me == null) {
      throw const CupsException(
        'Sign in to add your cup.',
        code: 'not_authenticated',
      );
    }
    return me;
  }

  List<CupItemDraft> _cleanItems(List<CupItemDraft> items) => [
    for (final i in items)
      if (i.hasPhoto || _clean(i.name, maxCupItemName) != null)
        CupItemDraft(
          file: i.file,
          takenAt: i.takenAt,
          kind: i.kind,
          name: _clean(i.name, maxCupItemName),
          menuItemId: i.menuItemId,
        ),
  ];

  List<Map<String, Object?>> _payload(
    List<CupItemDraft> items,
    Map<int, UploadedFile> uploads,
  ) => [
    for (var i = 0; i < items.length; i++)
      CupsJson.itemPayload(
        items[i],
        objectKey: uploads[i]?.objectKey,
        imageUrl: uploads[i]?.publicUrl,
      ),
  ];

  /// Uploads every photo item side by side. Keys are indexes into [items].
  Future<Map<int, UploadedFile>> _uploadItems(
    List<CupItemDraft> items,
    String cafeId,
    void Function(int index)? onUploaded,
  ) async {
    final indexes = [
      for (var i = 0; i < items.length; i++)
        if (items[i].file != null) i,
    ];
    if (indexes.isEmpty) return const {};
    final results = await Future.wait([
      for (final i in indexes)
        _upload(file: items[i].file!, cafeId: cafeId).then<Object>((file) {
          onUploaded?.call(i);
          return (i, file);
        }, onError: (Object e, StackTrace st) => AsyncError(e, st)),
    ]);
    final failure = results.whereType<AsyncError>().firstOrNull;
    final uploaded = {
      for (final r in results.whereType<(int, UploadedFile)>()) r.$1: r.$2,
    };
    if (failure != null) {
      _deleteFiles([for (final f in uploaded.values) f.objectKey]);
      throw CupsException(
        "Couldn't upload your photos. Check your connection and try again.",
        cause: failure.error,
      );
    }
    return uploaded;
  }

  /// The legacy gallery rows for the photo items: the item name becomes
  /// the drink; the kind has nowhere to go on 1.1.x.
  Future<void> _legacyInsertPhotos(
    String me,
    String cafeId,
    List<CupItemDraft> items,
    Map<int, UploadedFile> uploads,
  ) async {
    if (uploads.isEmpty) return;
    await _client.from('user_photos').insert([
      for (final entry in uploads.entries)
        {
          'user_id': me,
          'cafe_id': cafeId,
          'image_url': entry.value.publicUrl,
          'object_key': entry.value.objectKey,
          'drink_name': items[entry.key].name,
          'taken_at': (items[entry.key].takenAt ?? DateTime.now())
              .toUtc()
              .toIso8601String(),
          'source': GalleryPhotoSource.gallery.wire,
        },
    ]);
  }

  Future<void> _removePhotos(List<String> ids) async {
    for (final id in ids) {
      if (id.startsWith('review:')) continue;
      try {
        await _gallery.deletePhoto(id);
      } catch (e) {
        // The cup is saved; a photo left behind can be removed again.
        debugPrint('[Cups] photo $id not removed: $e');
      }
    }
  }

  void _deleteFiles(List<String?> objectKeys) {
    final keys = objectKeys.whereType<String>().toSet().toList();
    if (keys.isEmpty) return;
    unawaited(
      _client.functions
          .invoke(deleteGalleryObjectFunction, body: {'objectKeys': keys})
          .then<void>(
            (_) {},
            onError: (Object e) =>
                debugPrint('[Cups] files not deleted ($keys): $e'),
          ),
    );
  }

  Future<T> _guard<T>(String message, Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      throw _wrap(e, message);
    }
  }

  static CupsException _wrap(Object e, String message) {
    if (e is CupsException) return e;
    if (e is PostgrestException) {
      return CupsException(message, code: e.message, cause: e);
    }
    return CupsException(message, cause: e);
  }

  static String? _clean(String? value, int max) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    if (trimmed.runes.length <= max) return trimmed;
    return String.fromCharCodes(trimmed.runes.take(max)).trim();
  }
}

/// The photo queue's reason for a report filed on a photo-only cup.
PhotoReportReason photoReasonFor(ReportReason reason) => switch (reason) {
  ReportReason.spam => PhotoReportReason.spam,
  ReportReason.offTopic => PhotoReportReason.notCoffee,
  ReportReason.inappropriateContent ||
  ReportReason.harassment ||
  ReportReason.hateSpeech => PhotoReportReason.offensive,
  _ => PhotoReportReason.other,
};
