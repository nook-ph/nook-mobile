import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nook/core/analytics/saver_survey_events.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/widgets/error/state_styles.dart';
import 'package:nook/features/saver_survey/domain/saver_survey_reasons.dart';

/// Opens the survey. Resolves to the answer on Send; null on Skip, a swipe
/// down, a tap on the scrim or Back.
Future<SaverSurveyAnswer?> showSaverSurveySheet(BuildContext context) {
  return showModalBottomSheet<SaverSurveyAnswer>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x66000000),
    builder: (_) => const SaverSurveySheet(),
  );
}

/// What was picked on Send.
class SaverSurveyAnswer {
  const SaverSurveyAnswer({required this.reasons, this.otherText = ''});

  /// Reason ids, in list order.
  final List<String> reasons;

  /// The "Something else" text, trimmed. Stays on the phone.
  final String otherText;

  /// The `saver_survey_answered` properties. The text itself is never sent
  /// (the app's analytics carry no free text), only whether there was any
  /// and a length bucket.
  Map<String, Object> analytics() => {
    'reasons': reasons,
    'other_text_present': otherText.isNotEmpty,
    'other_text_length': saverSurveyLengthBucket(otherText.length),
  };
}

/// Grabber, the question and one line, the answers as rows with a trailing
/// checkbox (up to [SaverSurveyCopy.maxPicks]; the rest dim once full),
/// a short field under "Something else" when it is picked, then Skip and
/// Send side by side under a hairline. Send waits for a pick.
class SaverSurveySheet extends StatefulWidget {
  const SaverSurveySheet({super.key});

  @override
  State<SaverSurveySheet> createState() => _SaverSurveySheetState();
}

class _SaverSurveySheetState extends State<SaverSurveySheet> {
  final _picked = <String>{};
  final _other = TextEditingController();
  final _otherFocus = FocusNode();

  bool get _full => _picked.length >= SaverSurveyCopy.maxPicks;
  bool get _otherPicked => _picked.contains(SaverSurveyCopy.other.id);

  @override
  void dispose() {
    _other.dispose();
    _otherFocus.dispose();
    super.dispose();
  }

  void _toggle(SaverSurveyReason reason) {
    setState(() {
      if (!_picked.remove(reason.id)) {
        if (_full) return;
        _picked.add(reason.id);
      }
    });
    if (reason.id == SaverSurveyCopy.other.id && _otherPicked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _otherFocus.requestFocus();
      });
    }
  }

  void _send() {
    if (_picked.isEmpty) return;
    Navigator.of(context).pop(
      SaverSurveyAnswer(
        reasons: [
          for (final r in SaverSurveyCopy.reasons)
            if (_picked.contains(r.id)) r.id,
        ],
        otherText: _otherPicked ? _other.text.trim() : '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final bottom = keyboard > 0
        ? 12.0
        : math.max(20.0, media.viewPadding.bottom);
    final canSend = _picked.isNotEmpty;

    return Padding(
      // Rides up with the keyboard; the field stays above it.
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: StateStyles.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: StateStyles.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        SaverSurveyCopy.title,
                        style: StateStyles.text(
                          20,
                          FontWeight.w600,
                          StateStyles.ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      SaverSurveyCopy.message,
                      style: StateStyles.text(
                        14,
                        FontWeight.w400,
                        StateStyles.muted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final reason in SaverSurveyCopy.reasons)
                      _ReasonRow(
                        label: reason.label,
                        picked: _picked.contains(reason.id),
                        enabled: _picked.contains(reason.id) || !_full,
                        onTap: () => _toggle(reason),
                      ),
                    if (_otherPicked) ...[
                      const SizedBox(height: 4),
                      TextField(
                        controller: _other,
                        focusNode: _otherFocus,
                        maxLength: SaverSurveyCopy.maxOtherLength,
                        minLines: 1,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.done,
                        style: StateStyles.text(
                          16,
                          FontWeight.w400,
                          StateStyles.ink,
                        ),
                        decoration: InputDecoration(
                          hintText: SaverSurveyCopy.otherHint,
                          hintStyle: StateStyles.text(
                            16,
                            FontWeight.w400,
                            StateStyles.muted,
                          ),
                          counterStyle: StateStyles.text(
                            12,
                            FontWeight.w400,
                            StateStyles.muted,
                          ),
                          filled: true,
                          fillColor: StateStyles.tint,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
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
                    child: _SheetButton(
                      label: SaverSurveyCopy.skipLabel,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SheetButton(
                      label: SaverSurveyCopy.sendLabel,
                      filled: true,
                      onTap: canSend ? _send : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One answer: the label, then a checkbox at the trailing edge. The whole
/// row is the target (at least 48 high). Dimmed and inert while two others
/// are picked.
class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.label,
    required this.picked,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool picked;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        checked: picked,
        enabled: enabled,
        child: InkWell(
          onTap: enabled ? onTap : null,
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
                        enabled ? StateStyles.ink : StateStyles.muted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ExcludeSemantics(
                  child: Checkbox(
                    value: picked,
                    onChanged: enabled ? (_) => onTap() : null,
                    activeColor: StateStyles.brand,
                    checkColor: StateStyles.surface,
                    side: BorderSide(
                      color: enabled ? StateStyles.muted : StateStyles.border,
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

/// 48 high pill with a Medium 14 label. Filled is the brand action; a null
/// [onTap] greys it out. Unfilled is a quiet bordered pill.
class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fill = !filled
        ? StateStyles.surface
        : enabled
        ? StateStyles.brand
        : StateStyles.tint;
    final color = !filled
        ? StateStyles.ink
        : enabled
        ? StateStyles.surface
        : StateStyles.muted;
    return Semantics(
      button: true,
      enabled: enabled,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(100),
            border: filled ? null : Border.all(color: StateStyles.border),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: StateStyles.text(14, FontWeight.w500, color),
          ),
        ),
      ),
    );
  }
}
