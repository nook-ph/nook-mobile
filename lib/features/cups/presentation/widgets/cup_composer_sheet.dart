import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/analytics/profile_events.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/cafe/presentation/cafe_ranking_cubit.dart';
import 'package:nook/core/cafe/presentation/cafe_status_cubit.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/core/utils/error_info.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_note_sheet.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_ranking_flow.dart';
import 'package:nook/features/cafe_details/presentation/widgets/review_actions_sheet.dart';
import 'package:nook/features/cafe_details/presentation/widgets/review_sheet_shell.dart';
import 'package:nook/features/cups/domain/entities/cup.dart';
import 'package:nook/features/cups/domain/i_cups_repository.dart';
import 'package:nook/features/cups/presentation/cup_draft.dart';
import 'package:nook/features/cups/presentation/share/cup_share_sheet.dart';
import 'package:nook/features/cups/presentation/widgets/cup_card_view.dart';
import 'package:nook/features/gallery/data/gallery_photo_picker.dart';
import 'package:nook/features/gallery/domain/entities/gallery_photo.dart';
import 'package:nook/features/gallery/domain/entities/picked_cafe.dart';
import 'package:nook/features/gallery/presentation/widgets/gallery_image.dart';
import 'package:nook/features/lists/presentation/utils/open_been_list.dart';
import 'package:nook/features/lists/presentation/widgets/lists_ui.dart';
import 'package:nook/injection_container.dart';

/// What the composer did when it closed.
enum CupComposerAction { posted, updated, deleted }

class CupComposerOutcome {
  const CupComposerOutcome(this.action, {this.result});

  final CupComposerAction action;
  final CupPostResult? result;

  bool get markedBeen => result?.markedBeen ?? false;

  /// The toast: "Cup posted", "Cup updated" or "Cup deleted", with
  /// "Marked as Been" when posting did that.
  String get message => switch (action) {
    CupComposerAction.posted =>
      markedBeen ? 'Cup posted · Marked as Been' : 'Cup posted',
    CupComposerAction.updated => 'Cup updated',
    CupComposerAction.deleted => 'Cup deleted',
  };
}

/// Opens "Add your cup" for [cafe]: a new cup for this visit, with photos
/// and what you had (coffee, another drink, food, the space), an optional
/// note, optional stars and the day (docs/references/cups). [editing]
/// opens one of your cups instead, as "Edit your cup", with Delete.
///
/// [photos] and [note] start a new cup with them (the rank reveal's photo,
/// the private Been note). [menu] lets "What is it?" suggest the cafe's
/// menu items. The caller handles guests. Shows the outcome's toast and
/// returns it; null when closed without saving.
Future<CupComposerOutcome?> openCupComposer(
  BuildContext context, {
  required PickedCafe cafe,
  required String source,
  CupCard? editing,
  List<PickedGalleryPhoto> photos = const [],
  String? note,
  List<CupMenuOption> menu = const [],
  List<CupCard>? myCups,
  ICupsRepository? repository,
  GalleryPhotoPicker? picker,
  double toastOffset = 0,
}) async {
  dismissToasts();
  final outcome = await ReviewSheetShell.show<CupComposerOutcome>(
    context,
    // A drag would close it past the discard check and mid-upload.
    enableDrag: false,
    builder: (_) => CupComposerSheet(
      cafe: cafe,
      source: source,
      editing: editing,
      initialPhotos: photos,
      initialNote: note,
      menu: menu,
      myCups: myCups,
      repository: repository,
      picker: picker,
    ),
  );
  if (outcome != null && context.mounted) {
    final ranking = context.read<CafeRankingCubit?>();
    final been =
        context.read<CafeStatusCubit?>()?.state.statusFor(cafe.id) ==
        CafeStatus.been;
    final rankIt =
        ranking != null &&
        offersRankIt(
          outcome,
          been: been,
          ranked:
              ranking.state.rankingFor(cafe.id) != null ||
              ranking.state.isPending(cafe.id),
        );
    final shareCup = shareableCup(outcome);
    void rank() => _rankAfterCup(
      context,
      cafe: cafe,
      ranking: ranking!,
      toastOffset: toastOffset,
    );
    void share() {
      if (!context.mounted) return;
      showCupShareSheet(
        context,
        cup: shareCup!,
        cafeId: cafe.id,
        cafeName: cafe.name,
        cafeArea: cafe.area,
        entry: CupShareEntry.postedToast,
      );
    }

    if (shareCup != null && rankIt) {
      // Both actions only fit a 320pt screen with the short message.
      showPrimaryToastWithAction(
        context,
        'Cup posted',
        actionLabel: 'Share',
        onAction: share,
        secondaryActionLabel: 'Rank it',
        onSecondaryAction: rank,
        duration: const Duration(seconds: 6),
        bottomOffset: toastOffset,
      );
    } else if (shareCup != null) {
      showPrimaryToastWithAction(
        context,
        outcome.message,
        actionLabel: 'Share',
        onAction: share,
        bottomOffset: toastOffset,
      );
    } else if (rankIt) {
      showPrimaryToastWithAction(
        context,
        outcome.message,
        actionLabel: rankItLabel,
        onAction: rank,
        bottomOffset: toastOffset,
      );
    } else {
      showPrimaryToast(context, outcome.message, bottomOffset: toastOffset);
    }
  }
  return outcome;
}

/// The cup a posted toast offers to Share: a new, visible cup the server
/// sent back (a legacy backend may not). Edits and deletes never do.
CupCard? shareableCup(CupComposerOutcome outcome) {
  final cup = outcome.result?.cup;
  if (outcome.action != CupComposerAction.posted || cup?.cupId == null) {
    return null;
  }
  final status = cup!.moderationStatus;
  return status == null || status == 'visible' ? cup : null;
}

/// The posted toast's action (REVIEWS_GALLERY_MERGE, "Posting marks the
/// cafe Been"; COFFEE_VOICE keeps the Your visit wording).
const rankItLabel = 'Rank it · ~20 sec';

/// Whether the posted toast offers "Rank it": a new cup at a cafe that is
/// Been now (posting just marked it, or it already was) and not ranked
/// yet. Edits and deletes never do.
bool offersRankIt(
  CupComposerOutcome outcome, {
  required bool ranked,
  required bool been,
}) =>
    outcome.action == CupComposerAction.posted &&
    !ranked &&
    (outcome.markedBeen || been);

/// "Rank it" from the posted toast: the ranking flow for [cafe], with its
/// reveal's follow-ups, as Your visit opens it. The toast can outlive the
/// page, so nothing happens once [context] is gone.
Future<void> _rankAfterCup(
  BuildContext context, {
  required PickedCafe cafe,
  required CafeRankingCubit ranking,
  double toastOffset = 0,
}) async {
  if (!context.mounted) return;
  logAppEvent(CupEvents.rankItTapped, properties: {'cafe_id': cafe.id});
  dismissToasts();
  final outcome = await showCafeRankingFlow(
    context,
    cubit: ranking,
    cafeId: cafe.id,
    cafeName: cafe.name,
    cafeImageUrl: cafe.imageUrl,
    cafeLocation: cafe.area,
  );
  if (!context.mounted) return;
  switch (outcome) {
    case RankingFlowOutcome.completedAddNote:
      await showCafeNoteSheet(
        context,
        cafeId: cafe.id,
        cafeName: cafe.name,
        bottomOffset: toastOffset,
      );
    case RankingFlowOutcome.completedViewList:
      await openBeenList(context);
    case RankingFlowOutcome.failed:
      showRankingFailedToast(context, bottomOffset: toastOffset);
    case RankingFlowOutcome.completed || RankingFlowOutcome.skipped || null:
      break;
  }
}

/// One item in the composer: one the cup already has, a new photo, or a
/// new name without a photo.
class _Item {
  _Item.existing(CupItem item)
    : existing = item,
      picked = null,
      kind = item.kind,
      name = item.label ?? '',
      menuItemId = item.menuItemId;

  // New items start with no kind: the person picks one (UX review 2.2).
  _Item.photo(PickedGalleryPhoto photo)
    : existing = null,
      picked = photo,
      name = '';

  _Item.text() : existing = null, picked = null, name = '';

  final CupItem? existing;
  final PickedGalleryPhoto? picked;

  /// Null until picked; on a saved legacy photo, never said.
  CupItemKind? kind;
  String name;
  String? menuItemId;
  bool uploaded = false;

  /// Identity for keys; stable while the sheet is open.
  late final Object key = existing?.id ?? picked?.file.path ?? Object();

  bool get isNew => existing == null;
  bool get hasPhoto => picked != null || (existing?.hasPhoto ?? false);
  String? get imageUrl => picked?.file.path ?? existing?.imageUrl;

  /// New items are edited in place; saved ones can only be removed (and
  /// legacy review photos not even that).
  bool get editable => isNew;
  bool get removable => existing == null || !existing!.isFromReview;

  /// A new item that would post without a kind.
  bool get needsKind =>
      isNew && kind == null && (hasPhoto || name.trim().isNotEmpty);

  /// "Coffee", or what it is without a kind: "Photo" or "Item".
  String get kindLabel => kind?.label ?? (hasPhoto ? 'Photo' : 'Item');

  CupItemDraft toDraft() => CupItemDraft(
    file: picked?.file,
    takenAt: picked?.takenAt,
    kind: kind,
    name: name.trim().isEmpty ? null : name.trim(),
    menuItemId: menuItemId,
  );
}

class CupComposerSheet extends StatefulWidget {
  const CupComposerSheet({
    super.key,
    required this.cafe,
    required this.source,
    this.editing,
    this.initialPhotos = const [],
    this.initialNote,
    this.menu = const [],
    this.myCups,
    this.repository,
    this.picker,
    this.now,
  });

  final PickedCafe cafe;

  /// One of [CupSource], for analytics.
  final String source;

  /// One of your cups, to edit. Null for a new cup.
  final CupCard? editing;
  final List<PickedGalleryPhoto> initialPhotos;
  final String? initialNote;
  final List<CupMenuOption> menu;

  /// Your earlier cups at this cafe, newest first, when the caller has
  /// them; null asks the server (`my_cups`). A new cup shows the last one.
  final List<CupCard>? myCups;

  /// For tests; the app uses the registered ones.
  final ICupsRepository? repository;
  final GalleryPhotoPicker? picker;
  final DateTime Function()? now;

  @override
  State<CupComposerSheet> createState() => _CupComposerSheetState();
}

class _CupComposerSheetState extends State<CupComposerSheet> {
  late final ICupsRepository _repository =
      widget.repository ?? sl<ICupsRepository>();

  final _note = TextEditingController();
  final _name = TextEditingController();
  final _nameFocus = FocusNode();
  final _items = <_Item>[];
  final _removed = <String>[];

  int? _rating;
  late DateTime _visitedAt;
  int _selected = 0;

  bool _posting = false;
  bool _deleting = false;
  String? _error;
  bool _tried = false;

  /// The last post or save went out and failed (not a form nudge).
  bool _failed = false;

  /// What the form held when it opened, to tell whether closing loses work.
  late final Object _opened;

  /// Your cups here before this one, newest visit first.
  List<CupCard> _earlier = const [];

  CupCard? get _editing => widget.editing;
  bool get _busy => _posting || _deleting;
  bool get _legacy => _repository.mode == CupsMode.legacy;
  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    final cup = _editing;
    if (cup != null) {
      _items.addAll(cup.items.map(_Item.existing));
      _rating = cup.rating;
      _note.text = cup.note?.trim() ?? '';
      _visitedAt = cup.visitedAt;
    } else {
      _items.addAll(widget.initialPhotos.map(_Item.photo));
      _note.text = widget.initialNote?.trim() ?? '';
      _visitedAt = _dayFromPhotos(widget.initialPhotos) ?? _now;
      _loadEarlier();
    }
    _syncNameField();
    _opened = _snapshot;
    _note.addListener(_refresh);
    logAppEvent(
      CupEvents.composerOpened,
      properties: {
        'cafe_id': widget.cafe.id,
        'source': widget.source,
        'editing': cup != null,
        'backend': _repository.mode.name,
      },
    );
    // Settles legacy vs cups, which decides what the form can offer.
    if (_repository.mode == CupsMode.unknown) {
      _repository.resolveMode().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  /// A repeat visit: what you posted here last, so the form can say so
  /// (UX review 2.4). Garnish: a failed read just leaves it out.
  Future<void> _loadEarlier() async {
    var cups = widget.myCups;
    if (cups == null) {
      try {
        cups = (await _repository.getCafeCups(widget.cafe.id, limit: 1)).myCups;
      } catch (_) {
        return;
      }
    }
    if (!mounted || cups.isEmpty) return;
    final sorted = [...cups]
      ..sort((a, b) => b.visitedAt.compareTo(a.visitedAt));
    setState(() => _earlier = sorted);
  }

  /// Your latest earlier visit with stars: the one counting in the cafe's
  /// average now (each person counts once, their latest rated visit).
  CupCard? get _earlierRated =>
      _earlier.where((c) => c.rating != null).firstOrNull;

  @override
  void dispose() {
    _note.dispose();
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Object get _snapshot =>
      (_items.length, _removed.length, _note.text.trim(), _rating, _visitedAt);

  /// Closing now would lose something: a new item, a removal, or a changed
  /// note, stars or day. Kinds and names only live on new items.
  bool get _dirty => _snapshot != _opened;

  Future<void> _confirmDiscard() async {
    if (_busy) return;
    final discard = await ReviewSheetShell.show<bool>(
      context,
      builder: (_) => ReviewConfirmSheet.discardCup(editing: _editing != null),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  /// A photo taken in the last month dates the visit; older ones are
  /// probably from the camera roll, and today is the better guess.
  DateTime? _dayFromPhotos(List<PickedGalleryPhoto> photos) {
    final dates = [
      for (final p in photos)
        if (p.takenAt != null) p.takenAt!,
    ];
    if (dates.isEmpty) return null;
    final earliest = dates.reduce((a, b) => a.isBefore(b) ? a : b);
    final age = _now.difference(earliest);
    return age.isNegative || age.inDays > 30 ? null : earliest;
  }

  void _syncNameField() {
    if (_items.isEmpty) {
      _name.text = '';
      return;
    }
    _selected = _selected.clamp(0, _items.length - 1);
    _name.text = _items[_selected].name;
  }

  void _select(int index) {
    if (index == _selected) return;
    setState(() {
      _selected = index;
      _name.text = _items[index].name;
    });
  }

  void _remove(int index) {
    final item = _items[index];
    if (!item.removable || _busy) return;
    setState(() {
      _items.removeAt(index);
      final id = item.existing?.id;
      if (id != null) _removed.add(id);
      if (_selected >= index && _selected > 0) _selected--;
      _syncNameField();
    });
  }

  int get _room => maxCupItems - _items.length;

  Future<void> _addPhotos() async {
    if (_busy || _room <= 0) return;
    final source = await ListsSheet.show<_PhotoSource>(
      context,
      builder: (sheetContext) => ListsSheet(
        title: 'Add photos',
        gap: 4,
        children: [
          ListsSheetAction(
            title: 'Take a photo',
            onTap: () => Navigator.pop(sheetContext, _PhotoSource.camera),
          ),
          ListsSheetAction(
            title: 'Choose from library',
            onTap: () => Navigator.pop(sheetContext, _PhotoSource.library),
          ),
        ],
      ),
    );
    if (source == null || !mounted) return;
    final picker = widget.picker ?? sl<GalleryPhotoPicker>();
    List<PickedGalleryPhoto> picked;
    try {
      if (source == _PhotoSource.camera) {
        final shot = await picker.takePhoto();
        picked = shot == null ? const [] : [shot];
      } else {
        picked = await picker.pickMany();
      }
    } catch (_) {
      if (mounted) {
        showPrimaryToast(
          context,
          "Couldn't open your photos. Check Nook's photo access in Settings.",
        );
      }
      return;
    }
    if (picked.isEmpty || !mounted) return;
    final room = _room;
    setState(() {
      final first = _items.length;
      final hadPhotos = _items.any((i) => i.picked != null);
      _items.addAll(picked.take(room).map(_Item.photo));
      _selected = first;
      _syncNameField();
      if (_editing == null && !hadPhotos) {
        _visitedAt = _dayFromPhotos(picked) ?? _visitedAt;
      }
    });
    if (picked.length > room && mounted) {
      showPrimaryToast(context, 'A cup holds up to $maxCupItems items.');
    }
  }

  void _addTextItem() {
    if (_busy || _room <= 0) return;
    setState(() {
      _items.add(_Item.text());
      _selected = _items.length - 1;
      _syncNameField();
    });
    _nameFocus.requestFocus();
  }

  Future<void> _pickDate() async {
    final now = _now;
    final picked = await showDatePicker(
      context: context,
      initialDate: _visitedAt.isAfter(now) ? now : _visitedAt,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      helpText: 'When did you visit?',
    );
    if (picked != null && mounted) setState(() => _visitedAt = picked);
  }

  List<_Item> get _named => [
    for (final i in _items)
      if (!i.hasPhoto && i.name.trim().isNotEmpty) i,
  ];

  CupDraftIssue? get _issue => checkCupDraft(
    photoCount: _items.where((i) => i.hasPhoto).length,
    namedItemCount: _named.length,
    note: _note.text,
    rating: _rating,
    itemNames: [for (final i in _items) i.name],
    untypedCount: _items.where((i) => i.needsKind).length,
    legacy: _legacy,
  );

  Future<void> _save() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    final issue = _issue;
    if (issue != null) {
      setState(() {
        _tried = true;
        _failed = false;
        _error = cupDraftMessage(issue);
        // Bring up the first item still missing its kind, chips and all.
        if (issue == CupDraftIssue.needsKind) {
          final first = _items.indexWhere((i) => i.needsKind);
          if (first >= 0) {
            _selected = first;
            _name.text = _items[first].name;
          }
        }
      });
      return;
    }
    setState(() {
      _posting = true;
      _failed = false;
      _error = null;
      for (final i in _items) {
        i.uploaded = false;
      }
    });
    final fresh = [
      for (final i in _items)
        if (i.isNew && (i.hasPhoto || i.name.trim().isNotEmpty)) i,
    ];
    final note = _note.text.trim();
    final cup = _editing;
    try {
      final CupPostResult result;
      if (cup == null) {
        result = await _repository.postCup(
          cafeId: widget.cafe.id,
          rating: _rating,
          note: note.isEmpty ? null : note,
          visitedAt: _visitedAt,
          items: [for (final i in fresh) i.toDraft()],
          onPhotoUploaded: (i) {
            if (mounted) setState(() => fresh[i].uploaded = true);
          },
        );
      } else {
        result = await _repository.updateCup(
          cup,
          rating: _rating,
          note: note.isEmpty ? null : note,
          visitedAt: _visitedAt,
          addItems: [for (final i in fresh) i.toDraft()],
          removeItemIds: _removed,
          onPhotoUploaded: (i) {
            if (mounted) setState(() => fresh[i].uploaded = true);
          },
        );
      }
      logAppEvent(
        CupEvents.posted,
        properties: {
          'cafe_id': widget.cafe.id,
          'source': widget.source,
          'has_photo': _items.any((i) => i.hasPhoto),
          'has_note': note.isNotEmpty,
          'has_rating': _rating != null,
          'photo_count': fresh.where((i) => i.hasPhoto).length,
          'item_count': fresh.length,
          'kinds': {for (final i in fresh) ?i.kind?.wire}.join(','),
          'created': cup == null,
          'marked_been': result.markedBeen,
          'backend': _repository.mode.name,
        },
      );
      if (!mounted) return;
      unawaited(HapticFeedback.lightImpact());
      Navigator.of(context).pop(
        CupComposerOutcome(
          cup == null ? CupComposerAction.posted : CupComposerAction.updated,
          result: result,
        ),
      );
    } on CupsException catch (e) {
      if (!mounted) return;
      setState(() {
        _posting = false;
        _tried = true;
        _failed = true;
        _error = cupErrorMessage(e.code) ?? _failureMessage(e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _posting = false;
        _tried = true;
        _failed = true;
        _error = _offline;
      });
    }
  }

  static const _offline =
      "Couldn't reach Nook. Your cup is still here: try again when "
      "you're back online.";

  /// A lost connection says the draft is safe; a lost session says how to
  /// get back. Anything else keeps the repository's words.
  String _failureMessage(CupsException e) {
    final cause = e.cause;
    if (cause == null) return e.message;
    return switch (AppErrorCopy.fromException(cause).type) {
      ErrorType.offline => _offline,
      ErrorType.sessionExpired =>
        "You've been signed out. Sign in again, then post your cup.",
      _ => e.message,
    };
  }

  Future<void> _delete() async {
    final cup = _editing;
    if (_busy || cup == null) return;
    final confirmed = await ReviewSheetShell.show<bool>(
      context,
      builder: (_) => ReviewConfirmSheet.deleteCup(cafeName: widget.cafe.name),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await _repository.deleteCup(cup);
      logAppEvent(
        CupEvents.deleted,
        properties: {
          'cafe_id': widget.cafe.id,
          'backend': _repository.mode.name,
        },
      );
      if (!mounted) return;
      Navigator.of(
        context,
      ).pop(const CupComposerOutcome(CupComposerAction.deleted));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = "Couldn't delete your cup. Please try again.";
      });
    }
  }

  /// Under the stars on a repeat visit: what they do to your rating for
  /// this cafe. Only your latest rated visit counts in its average, so new
  /// stars replace [earlier]'s, and none leave it standing. A visit dated
  /// before [earlier] changes nothing, and says nothing.
  String? _ratingNote(CupCard? earlier) {
    if (earlier == null) return null;
    final day = DateTime(_visitedAt.year, _visitedAt.month, _visitedAt.day);
    final then = earlier.visitedAt;
    if (day.isBefore(DateTime(then.year, then.month, then.day))) return null;
    final when = cupShortDay(then, _now);
    return _rating == null
        ? 'Your $when rating (${earlier.rating}★) still counts for this cafe.'
        : 'Your rating for this cafe now. Replaces your $when rating '
              '(${earlier.rating}★).';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy && !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: ReviewSheetShell(
        title: _editing == null ? 'Add your cup' : 'Edit your cup',
        onClose: () => Navigator.of(context).maybePop(),
        child: _form(context),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final issue = _issue;
    final error = _error;
    final selected = _items.isEmpty ? null : _items[_selected];
    final needsStars =
        _legacy && _note.text.trim().isNotEmpty && _rating == null;
    // 1.1.x has nowhere to keep a name without a photo, or a kind.
    final canName = !_legacy;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CafeLine(cafe: widget.cafe),
        if (_editing == null && _earlier.isNotEmpty) ...[
          const SizedBox(height: 10),
          _LastCupLine(cups: _earlier, now: _now),
        ],
        const SizedBox(height: 12),
        const Divider(height: 1, thickness: 1, color: ReviewTokens.border),
        const SizedBox(height: 16),
        _SectionLabel(
          'What you had',
          trailing: _items.isEmpty ? null : '${_items.length} of $maxCupItems',
        ),
        const SizedBox(height: 10),
        _ItemRow(
          items: _items,
          selected: _selected,
          posting: _posting,
          showMissingKind: _tried,
          canAdd: _room > 0 && !_busy,
          onSelect: _select,
          onRemove: _busy ? null : _remove,
          onAdd: _addPhotos,
        ),
        if (selected != null) ...[
          const SizedBox(height: 12),
          if (canName)
            _KindChips(
              value: selected.kind,
              onChanged: selected.editable && !_busy
                  ? (kind) => setState(() {
                      selected.kind = kind;
                      // Picking the last missing kind answers the nudge.
                      if (_error == cupDraftMessage(CupDraftIssue.needsKind) &&
                          !_items.any((i) => i.needsKind)) {
                        _error = null;
                      }
                    })
                  : null,
            ),
          if (canName) const SizedBox(height: 10),
          _NameField(
            controller: _name,
            focusNode: _nameFocus,
            enabled: selected.editable && !_busy,
            menu: widget.menu,
            label: selected.editable
                ? (selected.hasPhoto
                      ? 'What is it? (optional)'
                      : 'What did you have?')
                : 'Saved items can be removed, not renamed',
            hint: switch (selected.kind) {
              null || CupItemKind.coffee => 'Iced Spanish latte',
              CupItemKind.drink => 'Matcha latte',
              CupItemKind.food => 'Banana bread',
              CupItemKind.space => 'The window seats upstairs',
            },
            onChanged: (value) => setState(() {
              selected.name = value;
              selected.menuItemId = null;
            }),
            onPicked: (option) => setState(() {
              selected.name = option.name;
              selected.menuItemId = option.id;
              if (option.kind != null) selected.kind = option.kind!;
            }),
          ),
        ],
        if (canName && _room > 0)
          Align(
            alignment: Alignment.centerLeft,
            child: _TextAction(
              icon: LucideIcons.plus,
              label: _items.isEmpty
                  ? 'Add what you had without a photo'
                  : 'Add something without a photo',
              onTap: _busy ? null : _addTextItem,
            ),
          )
        else
          const SizedBox(height: 12),
        _Field(
          controller: _note,
          enabled: !_busy,
          maxLength: maxCupNote,
          minLines: 3,
          maxLines: 6,
          label: 'Note (optional)',
          hint: 'What did you order? How was it?',
        ),
        const SizedBox(height: 8),
        _StarsRow(
          rating: _rating,
          required: needsStars,
          onChanged: _busy ? null : (stars) => setState(() => _rating = stars),
        ),
        if (_editing == null) ...[
          if (_ratingNote(_earlierRated) case final note?)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                note,
                style: context.textTheme.bodySmall?.copyWith(
                  color: ReviewTokens.muted,
                  fontSize: 13,
                ),
              ),
            ),
        ],
        _DateRow(date: _visitedAt, now: _now, onTap: _busy ? null : _pickDate),
        if (error != null) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              error,
              style: context.textTheme.bodySmall?.copyWith(
                color: ReviewTokens.danger,
                fontSize: 13,
              ),
            ),
          ),
        ] else if (issue == CupDraftIssue.empty) ...[
          const SizedBox(height: 8),
          Text(
            'A photo or a note is enough. Stars are up to you.',
            style: context.textTheme.bodySmall?.copyWith(
              color: ReviewTokens.muted,
              fontSize: 13,
            ),
          ),
        ],
        const SizedBox(height: 16),
        ReviewPrimaryButton(
          label: error != null && _failed
              ? 'Try again'
              : _editing == null
              ? 'Post cup'
              : 'Save changes',
          busy: _posting,
          busyLabel: _items.any((i) => i.isNew && i.picked != null)
              ? 'Uploading…'
              : 'Saving…',
          onTap: issue == CupDraftIssue.empty || _deleting ? null : _save,
        ),
        if (_editing != null) ...[
          const SizedBox(height: 4),
          Semantics(
            button: true,
            child: AdaptiveTap(
              onTap: _busy ? null : _delete,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: 48,
                alignment: Alignment.center,
                child: _deleting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: ReviewTokens.danger,
                        ),
                      )
                    : Text(
                        'Delete cup',
                        style: context.textTheme.bodyMediumMed.copyWith(
                          color: ReviewTokens.danger,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

enum _PhotoSource { camera, library }

/// The cafe and who reads it, under the title (Maps' "Posting publicly").
class _CafeLine extends StatelessWidget {
  const _CafeLine({required this.cafe});

  final PickedCafe cafe;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ListsThumb(imageUrl: cafe.imageUrl, size: 40, radius: 8),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                cafe.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodyMediumMed.copyWith(
                  color: ReviewTokens.ink,
                  fontSize: 14,
                ),
              ),
              Text(
                'Posting publicly · on the cafe and your profile',
                maxLines: 2,
                style: context.textTheme.bodySmall?.copyWith(
                  color: ReviewTokens.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Your last cup here · Jul 19 · ★★★★☆" on a repeat visit, so you know
/// you've been and what you gave (Apple Books shows your earlier entry).
class _LastCupLine extends StatelessWidget {
  const _LastCupLine({required this.cups, required this.now});

  /// Newest visit first; not empty.
  final List<CupCard> cups;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final last = cups.first;
    final when = cupShortDay(last.visitedAt, now);
    final rating = last.rating;
    final lead = cups.length > 1
        ? 'Your last of ${cups.length} cups here'
        : 'Your last cup here';
    final style = context.textTheme.bodySmall?.copyWith(
      color: ReviewTokens.muted,
      fontSize: 13,
    );
    return Semantics(
      label: [
        lead,
        when,
        if (rating != null) rating == 1 ? '1 star' : '$rating stars',
      ].join(', '),
      excludeSemantics: true,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 2,
        children: [
          const Icon(
            LucideIcons.history,
            size: 14,
            color: ReviewTokens.mutedIcon,
          ),
          Text('$lead · $when', style: style),
          if (rating != null) ...[
            Text('·', style: style),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var star = 1; star <= 5; star++)
                  Icon(
                    star <= rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 14,
                    color: star <= rating
                        ? ReviewTokens.star
                        : const Color(0xFFB0B0B0),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// "Jul 19", with the year when it isn't this one ("Jul 19, 2025").
String cupShortDay(DateTime date, DateTime now) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final day = '${months[date.month - 1]} ${date.day}';
  return date.year == now.year ? day : '$day, ${date.year}';
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: context.textTheme.bodyMediumMed.copyWith(
            color: ReviewTokens.ink,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Text(
            trailing!,
            style: context.textTheme.bodySmall?.copyWith(
              color: ReviewTokens.muted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }
}

/// The items in one row that scrolls sideways, then the add tile. The
/// selected one is ringed; its kind and name are edited below. While
/// posting each new photo carries a bar along its bottom edge until its
/// upload is done (Monday's composer).
class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.items,
    required this.selected,
    required this.posting,
    required this.canAdd,
    required this.onSelect,
    required this.onRemove,
    required this.onAdd,
    this.showMissingKind = false,
  });

  final List<_Item> items;
  final int selected;
  final bool posting;

  /// Post was tried: an item still without a kind says so in red.
  final bool showMissingKind;
  final bool canAdd;
  final ValueChanged<int> onSelect;
  final ValueChanged<int>? onRemove;
  final VoidCallback onAdd;

  static const size = 84.0;

  /// Room above and right of each photo for its remove target, so the
  /// 44pt target can reach past the photo's corner without covering its
  /// middle (where a tap selects).
  static const hang = 6.0;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    return SizedBox(
      height: size + hang + 22 * scale,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: items.length + (canAdd || items.isEmpty ? 1 : 0),
        // 10 between photos, counting each tile's hang.
        separatorBuilder: (_, _) => const SizedBox(width: 10 - hang),
        itemBuilder: (context, i) {
          if (i == items.length) {
            return Padding(
              padding: const EdgeInsets.only(top: hang),
              child: _AddTile(
                onTap: canAdd ? onAdd : null,
                first: items.isEmpty,
              ),
            );
          }
          final item = items[i];
          final remove = onRemove;
          return _ItemTile(
            key: ValueKey(item.key),
            item: item,
            index: i,
            count: items.length,
            selected: i == selected,
            uploading: posting && item.picked != null && !item.uploaded,
            missingKind: showMissingKind && item.needsKind,
            onTap: () => onSelect(i),
            onRemove: remove == null || !item.removable
                ? null
                : () => remove(i),
          );
        },
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    super.key,
    required this.item,
    required this.index,
    required this.count,
    required this.selected,
    required this.uploading,
    required this.onTap,
    this.onRemove,
    this.missingKind = false,
  });

  final _Item item;
  final int index;
  final int count;
  final bool selected;
  final bool uploading;
  final bool missingKind;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    const size = _ItemRow.size;
    final name = item.name.trim();
    final remove = onRemove;
    final url = item.imageUrl;
    const hang = _ItemRow.hang;
    return SizedBox(
      width: size + hang,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox.square(
            dimension: size + hang,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  bottom: 0,
                  width: size,
                  height: size,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Semantics(
                        button: true,
                        selected: selected,
                        label:
                            '${item.kindLabel} ${index + 1} of $count'
                            '${name.isEmpty ? '' : ', $name'}'
                            '${item.needsKind ? ', pick a kind' : ''}',
                        excludeSemantics: true,
                        child: AdaptiveTap(
                          onTap: onTap,
                          borderRadius: BorderRadius.circular(10),
                          child: DecoratedBox(
                            position: DecorationPosition.foreground,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? ReviewTokens.brand
                                    : (url == null
                                          ? ReviewTokens.border
                                          : Colors.transparent),
                                width: selected ? 2.5 : 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: url == null
                                  ? ColoredBox(
                                      color: ReviewTokens.tint.withValues(
                                        alpha: 0.5,
                                      ),
                                      child: Center(
                                        child: Icon(
                                          _kindIcon(item.kind),
                                          size: 26,
                                          color: ReviewTokens.brand,
                                        ),
                                      ),
                                    )
                                  : GalleryImage(
                                      url: url,
                                      cacheWidth: (size * 3).round(),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      if (uploading)
                        Positioned(
                          left: 6,
                          right: 6,
                          bottom: 6,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: const LinearProgressIndicator(
                              minHeight: 3,
                              color: Colors.white,
                              backgroundColor: Color(0x66FFFFFF),
                              semanticsLabel: 'Uploading photo',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // The badge sits inside the photo's corner; its 44pt target
                // takes the corner and the hang, not the photo's middle.
                if (remove != null)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Semantics(
                      button: true,
                      label: 'Remove item ${index + 1}',
                      excludeSemantics: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: remove,
                        child: SizedBox.square(
                          dimension: 44,
                          child: Align(
                            alignment: Alignment.topRight,
                            child: Padding(
                              padding: const EdgeInsets.only(
                                top: hang + 5,
                                right: hang + 5,
                              ),
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: const Color(0xE60A0F0D),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white),
                                ),
                                child: const Icon(
                                  LucideIcons.x,
                                  size: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: size,
            child: Text(
              item.needsKind
                  ? 'Pick a kind'
                  : name.isEmpty
                  ? (item.editable ? 'Add name' : item.kindLabel)
                  : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: missingKind
                    ? ReviewTokens.danger
                    : name.isEmpty || item.needsKind
                    ? ReviewTokens.muted
                    : ReviewTokens.ink,
                fontWeight: name.isEmpty || item.needsKind
                    ? FontWeight.w400
                    : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A text item with no kind yet shows a pencil, not a guess.
IconData _kindIcon(CupItemKind? kind) =>
    kind == null ? LucideIcons.pencilLine : cupKindIcon(kind);

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap, required this.first});

  final VoidCallback? onTap;

  /// Nothing added yet: the tile says what it is for.
  final bool first;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Add photos',
      excludeSemantics: true,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: first ? 176 : _ItemRow.size,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          height: _ItemRow.size,
          decoration: BoxDecoration(
            color: ReviewTokens.tint.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ReviewTokens.border),
          ),
          child: first
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      LucideIcons.camera,
                      size: 20,
                      color: ReviewTokens.brand,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Add photos',
                        maxLines: 2,
                        style: context.textTheme.bodyMediumMed.copyWith(
                          color: ReviewTokens.brand,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                )
              : Icon(
                  LucideIcons.plus,
                  size: 22,
                  color: enabled ? ReviewTokens.brand : ReviewTokens.mutedIcon,
                ),
        ),
      ),
    );
  }
}

/// Coffee · Drink · Food · Space for the selected item.
class _KindChips extends StatelessWidget {
  const _KindChips({required this.value, required this.onChanged});

  /// Null: none picked yet, so no chip is lit.
  final CupItemKind? value;
  final ValueChanged<CupItemKind>? onChanged;

  @override
  Widget build(BuildContext context) {
    final change = onChanged;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final kind in CupItemKind.values)
          Semantics(
            button: true,
            selected: kind == value,
            enabled: change != null,
            label: kind.label,
            excludeSemantics: true,
            child: AdaptiveTap(
              onTap: change == null ? null : () => change(kind),
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: kind == value ? ReviewTokens.brand : null,
                    border: Border.all(
                      color: kind == value
                          ? ReviewTokens.brand
                          : ReviewTokens.border,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _kindIcon(kind),
                        size: 14,
                        color: kind == value
                            ? Colors.white
                            : (change == null
                                  ? ReviewTokens.mutedIcon
                                  : ReviewTokens.ink),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        kind.label,
                        style: context.textTheme.bodySmall?.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: kind == value
                              ? Colors.white
                              : (change == null
                                    ? ReviewTokens.muted
                                    : ReviewTokens.ink),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// "What is it?", suggesting the cafe's menu items as you type.
class _NameField extends StatelessWidget {
  const _NameField({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.menu,
    required this.label,
    required this.hint,
    required this.onChanged,
    required this.onPicked,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final List<CupMenuOption> menu;
  final String label;
  final String hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<CupMenuOption> onPicked;

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<CupMenuOption>(
      textEditingController: controller,
      focusNode: focusNode,
      displayStringForOption: (o) => o.name,
      optionsBuilder: (value) => menuMatches(menu, value.text),
      onSelected: onPicked,
      fieldViewBuilder: (context, controller, focusNode, onSubmit) => _Field(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        maxLength: maxCupItemName,
        label: label,
        hint: hint,
        onChanged: onChanged,
        counter: false,
        suffix: menu.isEmpty
            ? null
            : const Icon(
                LucideIcons.bookOpen,
                size: 18,
                color: ReviewTokens.muted,
              ),
      ),
      optionsViewBuilder: (context, onSelect, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 3,
          color: ReviewTokens.surface,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220, maxWidth: 360),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 6),
              shrinkWrap: true,
              children: [
                for (final option in options)
                  InkWell(
                    onTap: () => onSelect(option),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        option.name,
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: ReviewTokens.ink,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Menu items whose name has [query] in it, best first: starts-with
/// before contains, then shorter. Up to 6; none for an empty query.
List<CupMenuOption> menuMatches(List<CupMenuOption> menu, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty || menu.isEmpty) return const [];
  final hits = [
    for (final o in menu)
      if (o.name.toLowerCase().contains(q) && o.name.toLowerCase() != q) o,
  ];
  hits.sort((a, b) {
    final aStart = a.name.toLowerCase().startsWith(q) ? 0 : 1;
    final bStart = b.name.toLowerCase().startsWith(q) ? 0 : 1;
    if (aStart != bStart) return aStart - bStart;
    return a.name.length.compareTo(b.name.length);
  });
  return hits.take(6).toList();
}

/// A labelled field ("(optional)" in the label, as Oku's).
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.enabled,
    required this.maxLength,
    required this.label,
    required this.hint,
    this.focusNode,
    this.minLines = 1,
    this.maxLines = 1,
    this.onChanged,
    this.counter = true,
    this.suffix,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool enabled;
  final int maxLength;
  final String label;
  final String hint;
  final int minLines;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  /// Shows "n/max" once it gets close to the limit.
  final bool counter;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      onChanged: onChanged,
      textCapitalization: TextCapitalization.sentences,
      cursorColor: ReviewTokens.brand,
      style: context.textTheme.bodyMedium?.copyWith(
        color: ReviewTokens.ink,
        fontSize: 16,
        height: 1.4,
      ),
      buildCounter:
          (context, {required currentLength, required isFocused, maxLength}) {
            final limit = maxLength ?? 0;
            if (!counter || currentLength < limit - 100) return null;
            return Text(
              '$currentLength/$limit',
              style: context.textTheme.bodySmall?.copyWith(
                color: currentLength >= limit
                    ? ReviewTokens.danger
                    : ReviewTokens.muted,
              ),
            );
          },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: context.textTheme.bodyMedium?.copyWith(
          color: ReviewTokens.muted,
          fontSize: 14,
        ),
        floatingLabelStyle: context.textTheme.bodyMedium?.copyWith(
          color: ReviewTokens.ink,
          fontSize: 14,
        ),
        alignLabelWithHint: true,
        hintText: hint,
        hintStyle: context.textTheme.bodyMedium?.copyWith(
          color: ReviewTokens.muted,
          fontSize: 16,
        ),
        counterText: counter ? null : '',
        suffixIcon: suffix,
        filled: true,
        fillColor: ReviewTokens.surface,
        contentPadding: const EdgeInsets.all(14),
        enabledBorder: border(ReviewTokens.border, 1),
        disabledBorder: border(ReviewTokens.border, 1),
        focusedBorder: border(ReviewTokens.ink, 1.5),
      ),
    );
  }
}

/// "Rate this cafe (optional)" and five stars; tapping the lit star again
/// clears it, as does Clear.
class _StarsRow extends StatelessWidget {
  const _StarsRow({
    required this.rating,
    required this.onChanged,
    this.required = false,
  });

  final int? rating;
  final ValueChanged<int?>? onChanged;

  /// The legacy backend needs stars with a note: say so instead of
  /// "(optional)".
  final bool required;

  static const _words = ['Terrible', 'Bad', 'Okay', 'Great', 'Excellent'];

  @override
  Widget build(BuildContext context) {
    final change = onChanged;
    final value = rating;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Rate this cafe',
              style: context.textTheme.bodyMediumMed.copyWith(
                color: ReviewTokens.ink,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                required ? 'needed with a note for now' : '(optional)',
                style: context.textTheme.bodySmall?.copyWith(
                  color: required ? ReviewTokens.danger : ReviewTokens.muted,
                ),
              ),
            ),
            if (value != null && change != null)
              AdaptiveTap(
                onTap: () => change(null),
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 44,
                    minWidth: 44,
                  ),
                  child: Center(
                    child: Text(
                      'Clear',
                      style: context.textTheme.bodyMediumMed.copyWith(
                        color: ReviewTokens.brand,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        Row(
          children: [
            for (var star = 1; star <= 5; star++)
              AdaptiveTap(
                onTap: change == null
                    ? null
                    : () => change(star == value ? null : star),
                borderRadius: BorderRadius.circular(22),
                child: Semantics(
                  button: true,
                  selected: value != null && star <= value,
                  label: star == 1 ? '1 star' : '$star stars',
                  excludeSemantics: true,
                  child: SizedBox(
                    width: 40,
                    height: 44,
                    child: Icon(
                      value != null && star <= value
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 30,
                      color: value != null && star <= value
                          ? ReviewTokens.star
                          : const Color(0xFFB0B0B0),
                    ),
                  ),
                ),
              ),
            if (value != null) ...[
              const SizedBox(width: 6),
              Text(
                _words[value - 1],
                style: context.textTheme.bodyMediumMed.copyWith(
                  color: ReviewTokens.brand,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// "Visited · Today ›": which visit this cup is.
class _DateRow extends StatelessWidget {
  const _DateRow({required this.date, required this.now, this.onTap});

  final DateTime date;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = visitDayLabel(date, now);
    return Semantics(
      button: true,
      label: 'Visited $label. Change',
      excludeSemantics: true,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: [
              Text(
                'Visited',
                style: context.textTheme.bodyMediumMed.copyWith(
                  color: ReviewTokens.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                label,
                style: context.textTheme.bodyMediumMed.copyWith(
                  color: ReviewTokens.brand,
                  fontSize: 14,
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: ReviewTokens.brand,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Today", "Yesterday", or "Mon, Oct 6" (with the year when not this one).
String visitDayLabel(DateTime date, DateTime now) {
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(date.year, date.month, date.day)).inDays;
  if (days <= 0) return 'Today';
  if (days == 1) return 'Yesterday';
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final day =
      '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  return date.year == now.year ? day : '$day, ${date.year}';
}

class _TextAction extends StatelessWidget {
  const _TextAction({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: ReviewTokens.brand),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: context.textTheme.bodyMediumMed.copyWith(
                    color: ReviewTokens.brand,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
