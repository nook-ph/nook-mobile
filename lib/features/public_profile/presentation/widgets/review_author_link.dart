import 'package:flutter/material.dart';
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
        onTap: () =>
            PublicProfilePage.open(context, userId: userId, nameHint: name),
        borderRadius: BorderRadius.circular(8),
        child: child,
      ),
    );
  }
}
