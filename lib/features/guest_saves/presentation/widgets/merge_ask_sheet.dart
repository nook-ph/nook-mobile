import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';
import 'package:nook/features/profile/presentation/widgets/profile_tokens.dart';
import 'package:nook/features/profile/presentation/widgets/profile_ui.dart';

/// How the merge ask ended.
enum MergeAskAnswer {
  /// "Add them".
  add,

  /// "Not now".
  notNow,

  /// Swiped down, the scrim, or Back: kept on the phone, as "Not now".
  dismissed;

  /// The `answer` property of `guest_saves_merge_answered`.
  String get wire => switch (this) {
    add => 'add',
    notNow => 'not_now',
    dismissed => 'dismissed',
  };
}

/// Asked right after a sign-in when this phone holds saves another account
/// left (a merge into it failed): add them to the account just signed in,
/// or keep them on the phone. Never moved without asking, since on a shared
/// phone they may be someone else's.
///
/// Laid out like the notification pre-prompt and the guest sign-in sheet
/// (grabber, icon in a tinted circle, centred title and reason, the two
/// choices stacked under it); see `docs/references/guest-saves/README.md`.
class MergeAskSheet extends StatelessWidget {
  const MergeAskSheet({super.key, required this.count, this.names = const []});

  /// Saves the other account left; at least 1.
  final int count;

  /// Their cafe names, newest first, so the person can tell whether they
  /// are theirs.
  final List<String> names;

  static const addLabel = 'Add them';
  static const addOneLabel = 'Add it';

  /// "Add it" for one save, "Add them" for more, as the reason says.
  static String addLabelFor(int count) => count == 1 ? addOneLabel : addLabel;
  static const notNowLabel = 'Not now';

  /// "Add 3 saved cafes?". Cafes, as the toast after it says ("Moved 3
  /// cafes to your account").
  static String titleFor(int count) =>
      count == 1 ? 'Add 1 saved cafe?' : 'Add $count saved cafes?';

  /// "Flavour Coffee, Kiosk and 1 more were saved on this phone before.
  /// Add them to your account?": at most two names, then a count. Without
  /// names, "These were saved…".
  static String reasonFor(int count, [List<String> names = const []]) {
    final shown = [
      for (final n in names)
        if (n.trim().isNotEmpty) n.trim(),
    ].take(2).toList();
    final it = count == 1 ? 'it' : 'them';
    final tail = 'saved on this phone before. Add $it to your account?';
    if (shown.isEmpty) {
      return count == 1 ? 'This was $tail' : 'These were $tail';
    }
    final rest = count - shown.length;
    final String who;
    if (rest > 0) {
      who = '${shown.join(', ')} and $rest more';
    } else {
      who = shown.join(' and ');
    }
    return '$who ${count == 1 ? 'was' : 'were'} $tail';
  }

  /// Shows the sheet and says how it ended.
  static Future<MergeAskAnswer> show(
    BuildContext context, {
    required int count,
    List<String> names = const [],
  }) async {
    final answer = await showModalBottomSheet<MergeAskAnswer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ProfileTokens.surface,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => MergeAskSheet(count: count, names: names),
    );
    return answer ?? MergeAskAnswer.dismissed;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    const gap = SizedBox(height: 8);

    // Scrolls when it outgrows the screen at the largest text sizes.
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, math.max(34.0, bottomInset)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: ProfileTokens.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Center(
              child: Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: ProfileTokens.tint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.smartphone,
                  size: 24,
                  color: ProfileTokens.brand,
                ),
              ),
            ),
            gap,
            Semantics(
              header: true,
              child: Text(
                titleFor(count),
                textAlign: TextAlign.center,
                style: ProfileTokens.text(20, weight: FontWeight.w600),
              ),
            ),
            gap,
            Text(
              reasonFor(count, names),
              textAlign: TextAlign.center,
              style: ProfileTokens.text(14, color: ListsTokens.muted),
            ),
            const SizedBox(height: 28),
            ProfilePillButton(
              label: addLabelFor(count),
              onTap: () => Navigator.of(context).pop(MergeAskAnswer.add),
            ),
            gap,
            Semantics(
              button: true,
              child: AdaptiveTap(
                onTap: () => Navigator.of(context).pop(MergeAskAnswer.notNow),
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  alignment: Alignment.center,
                  child: Text(
                    notNowLabel,
                    style: ProfileTokens.text(14, weight: FontWeight.w500),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
