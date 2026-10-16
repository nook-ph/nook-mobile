import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nook/core/analytics/saver_survey_events.dart';
import 'package:nook/core/presentation/widgets/cafe_card_image.dart';
import 'package:nook/core/presentation/widgets/cafe_distance_label.dart';
import 'package:nook/core/presentation/widgets/confirm_sheet.dart';
import 'package:nook/core/widgets/error/state_styles.dart';
import 'package:nook/features/cafe_details/presentation/utils/cafe_open_status.dart';
import 'package:nook/features/guest_saves/domain/cafe_snapshot.dart';
import 'package:nook/features/saver_survey/domain/saver_survey_follow_up.dart';
import 'package:nook/features/saver_survey/domain/saver_survey_reasons.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';

/// Opens the survey. Resolves to null on Skip, a swipe down, a tap on the
/// scrim or Back (before or after Send: the host knows which from
/// [SaverSurveySheet.onSend]), or to the follow-up action that closed it.
Future<SaverSurveyResult?> showSaverSurveySheet(
  BuildContext context, {
  required SaverSurveySheet sheet,
}) {
  return showModalBottomSheet<SaverSurveyResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x66000000),
    // TalkBack reads the scrim by this name ("Scrim" by default).
    barrierLabel: 'Close',
    builder: (_) => sheet,
  );
}

/// What was picked on Send.
class SaverSurveyAnswer {
  const SaverSurveyAnswer({required this.reasons});

  /// Reason ids, in list order.
  final List<String> reasons;

  /// The `saver_survey_answered` properties: reason ids only.
  Map<String, Object> analytics() => {'reasons': reasons};
}

/// How the follow-up card was closed: [action] is one of
/// [SaverSurveyActions] (never `close`, which pops with null).
class SaverSurveyResult {
  const SaverSurveyResult(this.followUp, this.action);

  final SaverSurveyFollowUp followUp;
  final String action;
}

/// Two faces in one sheet. First the question: grabber, the title, one line
/// naming the cafe, the answers as rows with a trailing checkbox (up to
/// [SaverSurveyCopy.maxPicks]; another tap replaces the oldest pick), then
/// Skip and Send under a hairline. After Send, the same sheet swaps to one
/// follow-up card when [onSend] returns one: "Thanks, that helps." with a
/// close button, a line, the cafe as a photo row, and one action.
class SaverSurveySheet extends StatefulWidget {
  const SaverSurveySheet({
    super.key,
    required this.cafeName,
    required this.days,
    required this.onSend,
    this.onUseLocation,
    this.now,
  });

  /// The cafe the question names; null says "a cafe".
  final String? cafeName;

  /// Days since it was saved.
  final int days;

  /// Logs the answer, then picks the follow-up. Null: the sheet closes (the
  /// host shows the thanks toast).
  final Future<SaverSurveyFollowUp?> Function(SaverSurveyAnswer answer) onSend;

  /// "Use my location" on the location card: asks, then returns the nearest
  /// card, or null to close.
  final Future<SaverSurveyFollowUp?> Function()? onUseLocation;

  /// For the open state; defaults to now.
  final DateTime Function()? now;

  @override
  State<SaverSurveySheet> createState() => _SaverSurveySheetState();
}

class _SaverSurveySheetState extends State<SaverSurveySheet> {
  /// Picked ids, oldest first.
  final _picked = <String>[];
  bool _busy = false;
  SaverSurveyFollowUp? _followUp;

  void _toggle(SaverSurveyReason reason) {
    setState(() {
      if (_picked.remove(reason.id)) return;
      if (_picked.length >= SaverSurveyCopy.maxPicks) _picked.removeAt(0);
      _picked.add(reason.id);
    });
  }

  Future<void> _send() async {
    if (_picked.isEmpty || _busy) return;
    setState(() => _busy = true);
    final answer = SaverSurveyAnswer(
      reasons: [
        for (final r in SaverSurveyCopy.reasons)
          if (_picked.contains(r.id)) r.id,
      ],
    );
    final followUp = await widget.onSend(answer);
    if (!mounted) return;
    if (followUp == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _followUp = followUp;
    });
  }

  Future<void> _useLocation() async {
    final ask = widget.onUseLocation;
    if (ask == null || _busy) return;
    setState(() => _busy = true);
    final next = await ask();
    if (!mounted) return;
    if (next == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _followUp = next;
    });
  }

  void _act(SaverSurveyFollowUp followUp, String action) {
    if (action == SaverSurveyActions.useLocation) {
      _useLocation();
      return;
    }
    Navigator.of(context).pop(SaverSurveyResult(followUp, action));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = math.max(20.0, MediaQuery.viewPaddingOf(context).bottom);
    final followUp = _followUp;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: StateStyles.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: AnimatedSwitcher(
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 200),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeOut,
        layoutBuilder: (current, previous) => current ?? const SizedBox(),
        child: followUp == null
            ? _Question(
                key: const ValueKey('question'),
                message: SaverSurveyCopy.message(
                  cafeName: widget.cafeName,
                  days: widget.days,
                ),
                cafeName: widget.cafeName,
                picked: _picked,
                busy: _busy,
                bottom: bottom,
                onToggle: _toggle,
                onSkip: () => Navigator.of(context).pop(),
                onSend: _send,
              )
            : _FollowUpCard(
                key: ValueKey(followUp.kind),
                followUp: followUp,
                busy: _busy,
                bottom: bottom,
                now: widget.now?.call() ?? DateTime.now(),
                onAction: (action) => _act(followUp, action),
                onClose: () => Navigator.of(context).pop(),
              ),
      ),
    );
  }
}

/// The grabber every face of the sheet starts with.
class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: StateStyles.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({
    super.key,
    required this.message,
    required this.cafeName,
    required this.picked,
    required this.busy,
    required this.bottom,
    required this.onToggle,
    required this.onSkip,
    required this.onSend,
  });

  final String message;
  final String? cafeName;
  final List<String> picked;
  final bool busy;
  final double bottom;
  final ValueChanged<SaverSurveyReason> onToggle;
  final VoidCallback onSkip;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final canSend = picked.isNotEmpty && !busy;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Grabber(),
        // The title stays put; only the line and the answers scroll.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Semantics(
            header: true,
            child: Text(
              SaverSurveyCopy.title,
              style: StateStyles.text(20, FontWeight.w600, StateStyles.ink),
            ),
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Message(text: message, bold: cafeName),
                const SizedBox(height: 12),
                for (final reason in SaverSurveyCopy.reasons)
                  _ReasonRow(
                    label: reason.label,
                    picked: picked.contains(reason.id),
                    onTap: () => onToggle(reason),
                  ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1, color: StateStyles.border),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, bottom),
          child: Row(
            children: [
              Expanded(
                child: SheetButton(
                  label: SaverSurveyCopy.skipLabel,
                  color: StateStyles.ink,
                  fill: StateStyles.surface,
                  bordered: true,
                  onTap: onSkip,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SheetButton(
                  label: SaverSurveyCopy.sendLabel,
                  color: canSend ? StateStyles.surface : StateStyles.muted,
                  fill: canSend ? StateStyles.brand : StateStyles.tint,
                  onTap: canSend ? onSend : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The line under the title, with the cafe's name in SemiBold. Set in ink:
/// the shared muted token is 3.65:1 on the sheet, under 4.5:1 for 14sp.
class _Message extends StatelessWidget {
  const _Message({required this.text, this.bold});

  final String text;
  final String? bold;

  @override
  Widget build(BuildContext context) {
    final base = StateStyles.text(14, FontWeight.w400, StateStyles.ink);
    final name = bold?.trim();
    final at = (name == null || name.isEmpty) ? -1 : text.indexOf(name);
    if (at < 0) return Text(text, style: base);
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: text.substring(0, at)),
          TextSpan(
            text: name,
            style: base.copyWith(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: text.substring(at + name!.length)),
        ],
      ),
    );
  }
}

/// One answer: the label, then a checkbox at the trailing edge. The whole
/// row is the target (at least 48 high). Always tappable: with two picked,
/// a third replaces the oldest.
class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.label,
    required this.picked,
    required this.onTap,
  });

  final String label;
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        checked: picked,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      label,
                      style: StateStyles.text(
                        16,
                        picked ? FontWeight.w500 : FontWeight.w400,
                        StateStyles.ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ExcludeSemantics(
                  child: Checkbox(
                    value: picked,
                    onChanged: (_) => onTap(),
                    activeColor: StateStyles.brand,
                    checkColor: StateStyles.surface,
                    side: const BorderSide(
                      color: StateStyles.muted,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
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

/// The follow-up face: "Thanks, that helps." and a close button on one
/// line, one sentence for the kind, the cafe as a photo row (name, then the
/// fact that answers the reason), and one full-width action under a
/// hairline.
class _FollowUpCard extends StatelessWidget {
  const _FollowUpCard({
    super.key,
    required this.followUp,
    required this.busy,
    required this.bottom,
    required this.now,
    required this.onAction,
    required this.onClose,
  });

  final SaverSurveyFollowUp followUp;
  final bool busy;
  final double bottom;
  final DateTime now;
  final ValueChanged<String> onAction;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final cafe = followUp.cafe;
    final (line, actionLabel, action) = switch (followUp.kind) {
      SaverSurveyFollowUpKind.openState => (
        "Here's where it stands today.",
        'See cafe',
        SaverSurveyActions.seeCafe,
      ),
      SaverSurveyFollowUpKind.nearest => (
        'The closest of your saves:',
        'See cafe',
        SaverSurveyActions.seeCafe,
      ),
      SaverSurveyFollowUpKind.locationAsk => (
        'Turn on location to see which of your saves is closest. It is '
            'never shared with cafes.',
        'Use my location',
        SaverSurveyActions.useLocation,
      ),
      SaverSurveyFollowUpKind.share => (
        'Send it to them and pick a day.',
        'Share',
        SaverSurveyActions.share,
      ),
      SaverSurveyFollowUpKind.later => (
        "It'll stay in Your places.",
        'Done',
        SaverSurveyActions.done,
      ),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Grabber(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    SaverSurveyCopy.thanks,
                    style: StateStyles.text(
                      20,
                      FontWeight.w600,
                      StateStyles.ink,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: onClose,
                tooltip: 'Close',
                icon: const Icon(Icons.close, size: 24),
                color: StateStyles.ink,
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  line,
                  style: StateStyles.text(14, FontWeight.w400, StateStyles.ink),
                ),
                if (cafe != null) ...[
                  const SizedBox(height: 12),
                  _CafeRow(
                    cafe: cafe,
                    fact: _fact(cafe),
                    status: _status(cafe),
                  ),
                ],
              ],
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1, color: StateStyles.border),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, bottom),
          child: SheetButton(
            label: actionLabel,
            color: busy ? StateStyles.muted : StateStyles.surface,
            fill: busy ? StateStyles.tint : StateStyles.brand,
            onTap: busy ? null : () => onAction(action),
          ),
        ),
      ],
    );
  }

  CafeOpenStatus? _status(CafeSnapshot cafe) {
    final hours = cafe.operatingHours;
    if (hours == null) return null;
    final status = CafeOpenStatus.resolve(hours, now);
    return status.hasAnyHours ? status : null;
  }

  /// The second line: the open state ("Open until 9 PM", "Closed · opens
  /// 8 AM tomorrow", "No hours listed yet"), led by the distance on the
  /// nearest card.
  String _fact(CafeSnapshot cafe) {
    final status = _status(cafe);
    final hours = status?.barText ?? 'No hours listed yet';
    final meters = followUp.distanceMeters;
    final distance = meters == null ? null : formatDistanceMeters(meters);
    if (distance == null) return hours;
    return '$distance away · $hours';
  }
}

/// A 56 photo, then the cafe's name and one line of fact with a status dot.
class _CafeRow extends StatelessWidget {
  const _CafeRow({required this.cafe, required this.fact, this.status});

  final CafeSnapshot cafe;
  final String fact;
  final CafeOpenStatus? status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final s = status;
    final dot = s == null
        ? null
        : s.isSoon
        ? colors.warning
        : s.isOpen
        ? colors.success
        : StateStyles.muted;
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CafeCardImage(
              imageUrl: cafe.coverImage,
              placeholderSeed: cafe.name,
              showSampleLabel: false,
              width: 56,
              height: 56,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cafe.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: StateStyles.text(16, FontWeight.w600, StateStyles.ink),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (dot != null) ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: dot,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        fact,
                        style: StateStyles.text(
                          14,
                          FontWeight.w400,
                          StateStyles.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
