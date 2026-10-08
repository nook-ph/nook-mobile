import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/analytics/profile_events.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/public_profile/presentation/pages/public_profile_page.dart';

/// Makes a review's author (avatar and name) open their public profile.
/// Left as plain content for the viewer's own review, and when the author
/// is unknown.
class ReviewAuthorLink extends StatelessWidget {
  const ReviewAuthorLink({
    super.key,
    required this.userId,
    required this.name,
    required this.child,
    this.isOwn = false,
  });

  final String userId;
  final String name;
  final Widget child;
  final bool isOwn;

  @override
  Widget build(BuildContext context) {
    if (isOwn || userId.isEmpty) return child;
    return Semantics(
      button: true,
      label: 'Open $name’s profile',
      child: AdaptiveTap(
        onTap: () => PublicProfilePage.open(
          context,
          userId: userId,
          nameHint: name,
          source: ProfileViewSource.review,
        ),
        borderRadius: BorderRadius.circular(8),
        child: child,
      ),
    );
  }
}

/// A review author's name, with a small chevron when it opens their profile
/// so the name reads as a way in, not a label (launch-review/profile-ux.md,
/// J2 step 1).
class ReviewAuthorName extends StatelessWidget {
  const ReviewAuthorName({
    super.key,
    required this.name,
    required this.style,
    required this.linked,
  });

  final String name;
  final TextStyle? style;

  /// Whether the name opens a profile (another person, known id).
  final bool linked;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
    if (!linked) return text;
    final size = (style?.fontSize ?? 14) + 2;
    return Row(
      children: [
        Flexible(child: text),
        const SizedBox(width: 2),
        Icon(
          LucideIcons.chevronRight,
          size: MediaQuery.textScalerOf(context).scale(size),
          color: const Color(0xFF767574),
        ),
      ],
    );
  }
}
