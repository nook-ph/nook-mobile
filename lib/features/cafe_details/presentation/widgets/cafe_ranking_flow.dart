import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/analytics/analytics_service.dart';
import 'package:nook/core/cafe/domain/entities/cafe_details.dart';
import 'package:nook/core/cafe/domain/entities/cafe_ranking.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/cafe/presentation/cafe_ranking_cubit.dart';
import 'package:nook/core/presentation/widgets/cafe_card_image.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/gallery/data/gallery_photo_picker.dart';
import 'package:nook/features/gallery/domain/entities/gallery_photo.dart';
import 'package:nook/features/gallery/domain/entities/picked_cafe.dart';
import 'package:nook/features/gallery/domain/i_cafe_picker_source.dart';
import 'package:nook/features/gallery/presentation/cubit/gallery_cubit.dart';
import 'package:nook/features/gallery/presentation/gallery_flows.dart';
import 'package:nook/features/gallery/presentation/widgets/gallery_image.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';
import 'package:nook/features/lists/presentation/widgets/lists_ui.dart';
import 'package:nook/injection_container.dart';

/// How the ranking sheet ended, so the caller knows which toast (if any) to
/// show. A null result from the sheet means it was dismissed — treated as
/// [skipped], because the Been mark is already saved either way.
enum RankingFlowOutcome {
  /// User chose "Skip for now" or dismissed the sheet — no ranking written.
  skipped,

  /// Ranked and revealed; the score screen was the feedback, no toast needed.
  completed,

  /// Ranked, and the user asked to add a note — the caller opens the note
  /// sheet with its own (still-mounted) context; opening it from inside this
  /// sheet would use a context that was popped a frame earlier.
  completedAddNote,

  /// Ranked, and the user tapped through to their ranked list. Same
  /// popped-context reason as [completedAddNote]: the caller navigates.
  completedViewList,

  /// The write failed. The Been mark is safe; only the score was lost.
  failed,
}

/// The post-Been flow (spec: docs/RANKING_DESIGN.md §3.1; Figma "Rank —
/// bucket" to "Rank — reveal"): one sheet in four steps — answer, compare,
/// saving, score. Every step is skippable and the Been mark is already
/// persisted before this opens — ranking is the dessert, not the bill.
///
/// [cafeLocation] is the line under the cafe's name on its comparison card.
Future<RankingFlowOutcome?> showCafeRankingFlow(
  BuildContext context, {
  required CafeRankingCubit cubit,
  required String cafeId,
  required String cafeName,
  String? cafeImageUrl,
  String? cafeLocation,
  GalleryFlowDeps? gallery,
}) {
  return ListsSheet.show<RankingFlowOutcome>(
    context,
    builder: (_) => CafeRankingFlow(
      cubit: cubit,
      cafeId: cafeId,
      cafeName: cafeName,
      cafeImageUrl: cafeImageUrl,
      cafeLocation: cafeLocation,
      gallery: gallery ?? _appGallery(),
    ),
  );
}

/// The app's gallery, when it is set up (it is not in most widget tests).
GalleryFlowDeps? _appGallery() {
  if (!sl.isRegistered<GalleryCubit>() ||
      !sl.isRegistered<GalleryPhotoPicker>() ||
      !sl.isRegistered<ICafePickerSource>()) {
    return null;
  }
  return GalleryFlowDeps(
    cubit: sl<GalleryCubit>(),
    picker: sl<GalleryPhotoPicker>(),
    cafes: sl<ICafePickerSource>(),
  );
}

/// The toast for [RankingFlowOutcome.failed].
void showRankingFailedToast(BuildContext context, {double bottomOffset = 0}) {
  showPrimaryToast(
    context,
    "Couldn't save your ranking — your Been is safe.",
    bottomOffset: bottomOffset,
  );
}

/// "Lahug, Cebu City" for a cafe's comparison card.
String cafeRankingLocation(CafeDetails details) {
  return [
    details.neighborhood,
    details.city,
  ].map((part) => part.trim()).where((part) => part.isNotEmpty).join(', ');
}

/// The score band each answer lands in (docs/RANKING_DESIGN.md).
String rankBucketRange(RankBucket bucket) => switch (bucket) {
  RankBucket.liked => 'Scores 7.0 – 10.0',
  RankBucket.fine => 'Scores 4.0 – 6.9',
  RankBucket.disliked => 'Scores 1.0 – 3.9',
};

enum _Phase { bucket, compare, saving, reveal }

/// The sheet body. Public so it can be pumped in tests; open it with
/// [showCafeRankingFlow].
class CafeRankingFlow extends StatefulWidget {
  const CafeRankingFlow({
    super.key,
    required this.cubit,
    required this.cafeId,
    required this.cafeName,
    this.cafeImageUrl,
    this.cafeLocation,
    this.gallery,
  });

  final CafeRankingCubit cubit;
  final String cafeId;
  final String cafeName;
  final String? cafeImageUrl;
  final String? cafeLocation;

  /// Offers "Add a photo of what you had" on the reveal. Null hides it.
  final GalleryFlowDeps? gallery;

  @override
  State<CafeRankingFlow> createState() => _CafeRankingFlowState();
}

class _CafeRankingFlowState extends State<CafeRankingFlow> {
  _Phase _phase = _Phase.bucket;
  RankingFlowOutcome? _outcome;
  CafeRanking? _result;
  int? _overallRank;
  int _rankedCount = 0;

  /// The opponent on screen, once its name is known. "Too close" places the
  /// cafe beside it, and the reveal says so.
  String? _opponentName;
  String? _tooCloseTo;

  /// The ranking this cafe already has, captured when the sheet opens. Its
  /// presence turns step 1 into the re-rank variant: without it the sheet
  /// asked "How was it?" identically whether you were ranking for the first
  /// time or moving an existing entry, and never said which.
  late final CafeRanking? _existing = widget.cubit.state.rankingFor(
    widget.cafeId,
  );
  late final String? _existingRankLabel = _buildExistingRankLabel();

  String? _buildExistingRankLabel() {
    final existing = _existing;
    if (existing == null) return null;
    final overall = widget.cubit.state.overallRankOf(widget.cafeId);
    if (overall == null) return existing.displayScore;
    return '${existing.displayScore} · #$overall of '
        '${widget.cubit.state.rankedCount}';
  }

  void _onBack() {
    final session = widget.cubit.state.session;
    if (session == null) return;
    if (session.canUndo) {
      widget.cubit.undoComparison();
      setState(() => _opponentName = null);
    } else {
      // Back off the first comparison returns to the feeling question, so a
      // wrong bucket isn't a dead end.
      widget.cubit.cancelSession();
      setState(() => _phase = _Phase.bucket);
    }
  }

  @override
  void dispose() {
    // Swipe-down / barrier dismissal skips _finish, so an open session would
    // otherwise linger on the app-wide cubit and leak into the next flow.
    if (_outcome == null) widget.cubit.cancelSession();
    super.dispose();
  }

  /// True while the rankings are being read for a bucket tap.
  bool _loadingRankings = false;

  /// The photo added from the reveal, shown in place of the prompt.
  PickedGalleryPhoto? _addedPhoto;

  Future<void> _addPhoto() async {
    final gallery = widget.gallery;
    if (gallery == null) return;
    _track('rank_photo_tapped');
    final location = widget.cafeLocation?.trim() ?? '';
    final photo = await addRankPhoto(
      context,
      gallery,
      cafe: PickedCafe(
        id: widget.cafeId,
        name: widget.cafeName,
        area: location.isEmpty ? null : location,
        imageUrl: widget.cafeImageUrl,
      ),
    );
    if (!mounted || photo == null) return;
    _track('rank_photo_added');
    setState(() => _addedPhoto = photo);
  }

  void _finish(RankingFlowOutcome outcome) {
    _outcome = outcome;
    Navigator.pop(context, outcome);
  }

  /// The ✕. Before a score exists it is a skip; on the reveal the ranking is
  /// already saved, so it is the same as Done.
  void _close() {
    _finish(
      _phase == _Phase.reveal
          ? RankingFlowOutcome.completed
          : RankingFlowOutcome.skipped,
    );
  }

  void _track(String event, [Map<String, dynamic>? extra]) {
    unawaited(
      sl<AnalyticsService>().track(
        widget.cafeId,
        event,
        metadata: {AnalyticsMetadataKeys.screen: 'cafe_details', ...?extra},
      ),
    );
  }

  Future<void> _onBucketChosen(RankBucket bucket) async {
    if (_phase != _Phase.bucket || _loadingRankings) return;
    _track('rank_bucket_chosen', {'bucket': bucket.wire});

    // Without the user's rankings there are no opponents, and the cafe would
    // be saved at #1 with no comparisons. Read them first; give up if the
    // read fails again rather than write a rank nobody chose.
    if (!widget.cubit.state.loaded) {
      _loadingRankings = true;
      await widget.cubit.load();
      if (!mounted) return;
      _loadingRankings = false;
      if (!widget.cubit.state.loaded) {
        _finish(RankingFlowOutcome.failed);
        return;
      }
    }

    final session = widget.cubit.startSession(widget.cafeId, bucket);
    if (session.isComplete) {
      // Nothing to compare against — first cafe in this bucket.
      _commit();
    } else {
      setState(() => _phase = _Phase.compare);
    }
  }

  void _onComparisonPicked({required bool preferredTarget}) {
    // The outgoing step stays tappable while it fades: a second tap must not
    // answer again or start a second save.
    if (_phase != _Phase.compare) return;
    final session = widget.cubit.state.session;
    if (session == null) return;
    _track('rank_comparison_answered', {
      'comparison_index': session.comparisonsAsked + 1,
      'preferred_new': preferredTarget,
    });
    widget.cubit.answerComparison(preferredTarget: preferredTarget);
    if (widget.cubit.state.session?.isComplete ?? true) {
      _commit();
    } else {
      setState(() => _opponentName = null);
    }
  }

  void _onTooClose() {
    if (_phase != _Phase.compare) return;
    final session = widget.cubit.state.session;
    _track('rank_skipped', {
      'comparisons_answered': session?.comparisonsAsked ?? 0,
    });
    // A skip keeps the current estimate, which is the top of what is left of
    // the range, not necessarily beside the cafe on screen. Only say "next
    // to" when that is where it lands.
    final opponentPosition = session?.currentOpponentPosition;
    final placed = session?.resolvedPosition;
    final beside =
        opponentPosition != null &&
        placed != null &&
        (placed == opponentPosition || placed == opponentPosition + 1);
    _tooCloseTo = beside ? _opponentName : null;
    widget.cubit.skipComparisons();
    _commit();
  }

  Future<void> _commit() async {
    if (_phase == _Phase.saving || _phase == _Phase.reveal) return;
    setState(() => _phase = _Phase.saving);
    final ranking = await widget.cubit.commitSession();
    if (!mounted) return;

    if (ranking == null) {
      _finish(RankingFlowOutcome.failed);
      return;
    }

    _track('rank_completed', {
      'bucket': ranking.bucket.wire,
      'score': ranking.score,
      'position': ranking.position,
    });
    // The score reveal is this feature's "stamp" moment.
    unawaited(HapticFeedback.mediumImpact());
    setState(() {
      _result = ranking;
      _overallRank = widget.cubit.state.overallRankOf(widget.cafeId);
      _rankedCount = widget.cubit.state.rankedCount;
      _phase = _Phase.reveal;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.cubit.state.session;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      // Each step is a different height: keep them pinned to the bottom edge
      // while one fades into the next.
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.bottomCenter,
        children: [...previous, ?current],
      ),
      child: switch (_phase) {
        _Phase.bucket => ListsSheet(
          key: const ValueKey('bucket'),
          title: 'How was ${widget.cafeName}?',
          gap: 10,
          onClose: _close,
          children: _bucketStep(),
        ),
        _Phase.compare => ListsSheet(
          key: ValueKey('compare-${session?.comparisonsAsked}'),
          title: 'Which did you like more?',
          gap: 14,
          onBack: _onBack,
          onClose: _close,
          children: [
            _CompareStep(
              cafeName: widget.cafeName,
              cafeImageUrl: widget.cafeImageUrl,
              cafeLocation: widget.cafeLocation,
              opponentId: session?.currentOpponent,
              step: session?.currentComparison ?? 1,
              total: session?.plannedComparisons ?? 1,
              revisitedPick: session?.revisitedPick,
              onOpponentNamed: (name) => _opponentName = name,
              onPicked: _onComparisonPicked,
              onTooClose: _onTooClose,
            ),
          ],
        ),
        _Phase.saving => ListsSheet(
          key: const ValueKey('saving'),
          gap: 12,
          onClose: _close,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox.square(
                    dimension: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: ListsTokens.brand,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Saving your rank…',
                    style: listsText(14, color: ListsTokens.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        _Phase.reveal => ListsSheet(
          key: const ValueKey('reveal'),
          gap: 12,
          onClose: _close,
          children: [
            _RevealStep(
              cafeName: widget.cafeName,
              cafeImageUrl: widget.cafeImageUrl,
              ranking: _result!,
              overallRank: _overallRank,
              rankedCount: _rankedCount,
              tooCloseTo: _tooCloseTo,
              photo: widget.gallery == null
                  ? null
                  : RankPhotoPrompt(added: _addedPhoto, onTap: _addPhoto),
              onDone: () => _finish(RankingFlowOutcome.completed),
              onAddNote: () => _finish(RankingFlowOutcome.completedAddNote),
              onViewList: () => _finish(RankingFlowOutcome.completedViewList),
            ),
          ],
        ),
      },
    );
  }

  // ── Step 1: bucket ───────────────────────────────────────────────────────

  List<Widget> _bucketStep() {
    final existing = _existing;
    final rankLabel = _existingRankLabel;
    final isRerank = existing != null;

    return [
      // Re-ranking used to be indistinguishable from ranking fresh: same
      // question, no sign the cafe already had a score, and a "Skip" that
      // looked like it might discard one.
      if (isRerank && rankLabel != null)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ListsTokens.tint,
            borderRadius: BorderRadius.circular(ListsTokens.radius),
          ),
          child: Text(
            'Ranked $rankLabel — answer again to move it. '
            'Skipping keeps this rank.',
            style: listsText(12),
          ),
        ),
      for (final bucket in RankBucket.values)
        _BucketOption(
          label: switch (bucket) {
            RankBucket.liked => 'Liked it',
            RankBucket.fine => 'It was fine',
            RankBucket.disliked => 'Not for me',
          },
          range: rankBucketRange(bucket),
          isCurrent: existing?.bucket == bucket,
          onTap: () => _onBucketChosen(bucket),
        ),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListsTextButton(
              label: isRerank ? 'Keep current rank' : 'Skip for now',
              onTap: () => _finish(RankingFlowOutcome.skipped),
            ),
            // The mark is already saved. Saying so removes the main reason to
            // hesitate on a screen that is otherwise entirely optional.
            if (!isRerank)
              Text(
                'Already saved to Been — this just ranks it.',
                textAlign: TextAlign.center,
                style: listsText(12, color: ListsTokens.muted),
              ),
          ],
        ),
      ),
    ];
  }
}

/// One answer: a full-width card with the score range under its label.
class _BucketOption extends StatelessWidget {
  const _BucketOption({
    required this.label,
    required this.range,
    required this.onTap,
    this.isCurrent = false,
  });

  final String label;
  final String range;
  final VoidCallback onTap;

  /// The bucket the cafe is ranked in today, on a re-rank.
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isCurrent,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: ListsTokens.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCurrent ? ListsTokens.brand : ListsTokens.border,
              width: isCurrent ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: listsText(14, weight: FontWeight.w500)),
                    Text(range, style: listsText(12, color: ListsTokens.muted)),
                  ],
                ),
              ),
              if (isCurrent) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: ListsTokens.tint,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    'current',
                    style: listsText(
                      12,
                      weight: FontWeight.w500,
                      color: ListsTokens.brand,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Step 2: head-to-head ───────────────────────────────────────────────────

/// Two large photo cards and one skip. The opponent id is resolved to a name
/// and photo through the repository, which is backed by the CafeStore cache —
/// after the first comparison most opponents are already local. A failed
/// fetch leaves a name-less card that is still tappable: blocking the flow on
/// a thumbnail would be backwards.
///
/// The fetch is held in State deliberately. Built inside `build()` it would
/// be recreated on every rebuild, discarding the in-flight request.
class _CompareStep extends StatefulWidget {
  const _CompareStep({
    required this.cafeName,
    required this.cafeImageUrl,
    required this.cafeLocation,
    required this.opponentId,
    required this.step,
    required this.total,
    required this.revisitedPick,
    required this.onOpponentNamed,
    required this.onPicked,
    required this.onTooClose,
  });

  final String cafeName;
  final String? cafeImageUrl;
  final String? cafeLocation;
  final String? opponentId;
  final int step;
  final int total;

  /// Set after Back: what was picked on this pair the first time. True is
  /// the cafe being ranked.
  final bool? revisitedPick;
  final ValueChanged<String> onOpponentNamed;
  final void Function({required bool preferredTarget}) onPicked;
  final VoidCallback onTooClose;

  @override
  State<_CompareStep> createState() => _CompareStepState();
}

class _CompareStepState extends State<_CompareStep> {
  CafeDetails? _opponent;

  @override
  void initState() {
    super.initState();
    _loadOpponent();
  }

  Future<void> _loadOpponent() async {
    final id = widget.opponentId;
    if (id == null) return;
    try {
      final bundle = await sl<ICafeRepository>().getCafeBundleById(
        id,
        includeMenu: false,
        includeReviews: false,
      );
      if (!mounted) return;
      setState(() => _opponent = bundle.details);
      widget.onOpponentNamed(bundle.details.name);
    } catch (_) {
      // The card stays name-less and tappable.
    }
  }

  @override
  Widget build(BuildContext context) {
    final opponent = _opponent;
    final opponentName = opponent?.name ?? 'This cafe';
    final picked = widget.revisitedPick;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The longest part of the flow. A count and a way back turn it from
        // open-ended into bounded.
        Text(
          '${widget.step} of ${widget.total}',
          textAlign: TextAlign.center,
          style: listsText(12, color: ListsTokens.muted),
        ),
        const SizedBox(height: 14),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _CompareCard(
                  name: widget.cafeName,
                  location: widget.cafeLocation,
                  imageUrl: widget.cafeImageUrl,
                  picked: picked == true,
                  onTap: () => widget.onPicked(preferredTarget: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: widget.opponentId == null
                    ? const SizedBox.shrink()
                    : _CompareCard(
                        name: opponentName,
                        location: opponent == null
                            ? null
                            : cafeRankingLocation(opponent),
                        imageUrl: opponent?.coverImage,
                        picked: picked == false,
                        onTap: () => widget.onPicked(preferredTarget: false),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ListsPillButton(
          label: 'Too close — skip',
          style: ListsPillStyle.outlined,
          onTap: widget.onTooClose,
        ),
        const SizedBox(height: 14),
        // One line of why. The comparisons are the most intrusive thing the
        // app asks for, so it says where the answers go — or, after Back,
        // which card was picked last time.
        Text(
          picked == null
              ? "Your answers order your list. Only how many cafes you've ranked shows on your profile."
              : 'You picked ${picked ? widget.cafeName : opponentName} here. '
                    'Tap either card to change it.',
          textAlign: TextAlign.center,
          style: listsText(12, color: ListsTokens.muted),
        ),
      ],
    );
  }
}

class _CompareCard extends StatelessWidget {
  const _CompareCard({
    required this.name,
    required this.location,
    required this.imageUrl,
    required this.picked,
    required this.onTap,
  });

  final String name;
  final String? location;
  final String? imageUrl;

  /// Outlined in the brand colour: the earlier answer on a revisited pair.
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    final where = location?.trim() ?? '';

    return Semantics(
      button: true,
      selected: picked,
      label: name,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          clipBehavior: Clip.antiAlias,
          // The stroke is drawn over the photo so both cards stay the same
          // size whichever is outlined.
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: picked ? ListsTokens.brand : ListsTokens.border,
              width: picked ? 2 : 1,
            ),
          ),
          decoration: BoxDecoration(
            color: ListsTokens.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // A fixed photo height keeps the two cards level even when one
              // name wraps to a second line.
              url != null && url.isNotEmpty
                  ? CafeCardImage(
                      imageUrl: url,
                      height: 170,
                      width: double.infinity,
                    )
                  : Container(
                      height: 170,
                      color: ListsTokens.tint,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.coffee_outlined,
                        color: ListsTokens.muted,
                      ),
                    ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: listsText(14, weight: FontWeight.w500),
                    ),
                    if (where.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        where,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: listsText(12, color: ListsTokens.muted),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Step 3: the payoff ─────────────────────────────────────────────────────

class _RevealStep extends StatelessWidget {
  const _RevealStep({
    required this.cafeName,
    required this.cafeImageUrl,
    required this.ranking,
    required this.overallRank,
    required this.rankedCount,
    required this.tooCloseTo,
    this.photo,
    required this.onDone,
    required this.onAddNote,
    required this.onViewList,
  });

  final String cafeName;
  final String? cafeImageUrl;
  final CafeRanking ranking;
  final int? overallRank;
  final int rankedCount;

  /// The cafe this one was placed beside by "Too close — skip".
  final String? tooCloseTo;

  /// "Add a photo of what you had", between the score and the buttons.
  final Widget? photo;
  final VoidCallback onDone;
  final VoidCallback onAddNote;
  final VoidCallback onViewList;

  String get _rankLine {
    if (rankedCount <= 1) return 'Your first ranked cafe';
    final place = '#${overallRank ?? ranking.position} of $rankedCount';
    final beside = tooCloseTo;
    return beside == null ? '$place · Been' : '$place · next to $beside';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListsThumb(imageUrl: cafeImageUrl, size: 64, radius: 16),
          const SizedBox(height: 14),
          Text(
            cafeName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: listsText(14, weight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            ranking.displayScore,
            textAlign: TextAlign.center,
            style: listsText(
              48,
              weight: FontWeight.w600,
              color: ListsTokens.brand,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _rankLine,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: listsText(14, color: ListsTokens.muted),
          ),
          if (photo != null) ...[const SizedBox(height: 18), photo!],
          SizedBox(height: photo == null ? 22 : 16),
          Row(
            children: [
              Expanded(
                // The spec's payoff CTA (§3.1 step 3). This screen is the
                // peak moment of the loop; the ranked list is the asset the
                // user just grew.
                child: ListsPillButton(
                  label: 'View my list',
                  onTap: onViewList,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                // The note is the diary content the whole feature exists to
                // collect, and this is the one moment the user is already
                // thinking about the visit.
                child: ListsPillButton(
                  label: 'Add a note',
                  style: ListsPillStyle.outlined,
                  onTap: onAddNote,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Neither CTA is the way out, so dismissal gets its own affordance.
          ListsTextButton(label: 'Done', onTap: onDone),
        ],
      ),
    );
  }
}

/// The reveal's optional photo prompt: a compact row, quieter than the two
/// buttons under it, so it reads as an offer and not a step (finding 2).
/// Once a photo is added the same row shows it with a check (Body Coach's
/// camera tile, Airbnb's added state; docs/references/coffee-gallery).
class RankPhotoPrompt extends StatelessWidget {
  const RankPhotoPrompt({super.key, required this.onTap, this.added});

  final VoidCallback onTap;
  final PickedGalleryPhoto? added;

  @override
  Widget build(BuildContext context) {
    final photo = added;
    final tile = SizedBox.square(
      dimension: 52,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: photo == null
            ? const ColoredBox(
                color: ListsTokens.tint,
                child: Icon(
                  LucideIcons.camera,
                  size: 22,
                  color: ListsTokens.brand,
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  GalleryImage(url: photo.file.path, cacheWidth: 156),
                  const ColoredBox(color: Color(0x59000000)),
                  const Center(
                    child: Icon(
                      LucideIcons.circleCheck,
                      size: 22,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
    final row = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: ListsTokens.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          tile,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  photo == null
                      ? 'Add a photo of what you had'
                      : 'Added to your gallery',
                  style: listsText(14, weight: FontWeight.w500),
                ),
                Text(
                  photo == null
                      ? 'Optional · it goes on your profile'
                      : 'Find it on your profile',
                  style: listsText(12, color: ListsTokens.muted),
                ),
              ],
            ),
          ),
          if (photo == null)
            const Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: ListsTokens.muted,
            ),
        ],
      ),
    );
    if (photo != null) return Semantics(liveRegion: true, child: row);
    return Semantics(
      button: true,
      label: 'Add a photo of what you had. Optional',
      excludeSemantics: true,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: row,
      ),
    );
  }
}
