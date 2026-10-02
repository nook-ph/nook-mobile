import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/cafe/domain/entities/cafe_details.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:nook/features/profile/presentation/profile_logic.dart';
import 'package:nook/features/profile/presentation/widgets/profile_sheet.dart';
import 'package:nook/features/profile/presentation/widgets/profile_tokens.dart';

/// Opens the ⋯ sheet for one of the user's own reviews, then the delete
/// confirmation, then deletes it through [ProfileCubit] and reports the
/// outcome in a toast.
Future<void> showProfileReviewOptions(
  BuildContext context,
  WrittenReview review,
) async {
  final cubit = context.read<ProfileCubit>();

  final delete = await ProfileSheet.show<bool>(
    context,
    builder: (_) => ProfileReviewOptionsSheet(cafeName: review.cafeName),
  );
  if (delete != true || !context.mounted) return;

  final confirmed = await showProfileConfirmSheet(
    context,
    title: 'Delete this review?',
    message: 'This cannot be undone.',
    confirmLabel: 'Delete',
    destructive: true,
  );
  if (!confirmed) return;

  try {
    await cubit.deleteReview(review.id);
    if (!context.mounted) return;
    showPrimaryToast(context, 'Review deleted');
  } catch (_) {
    if (!context.mounted) return;
    showPrimaryToast(context, 'Could not delete the review. Please try again.');
  }
}

/// The ⋯ sheet for the user's own review: one row, Delete. Pops true when
/// it is tapped.
class ProfileReviewOptionsSheet extends StatelessWidget {
  const ProfileReviewOptionsSheet({super.key, required this.cafeName});

  final String cafeName;

  @override
  Widget build(BuildContext context) {
    final cafe = cafeName.trim();
    return ProfileSheet(
      title: cafe.isEmpty ? 'Your review' : 'Your review of $cafe',
      children: [
        ProfileSheetOption(
          icon: LucideIcons.trash2,
          title: 'Delete review',
          detail: 'Removes it from the cafe page and your profile',
          destructive: true,
          onTap: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}

/// The "Sort by" sheet of the Your reviews page. Pops with the order that
/// was tapped.
class ProfileReviewSortSheet extends StatelessWidget {
  const ProfileReviewSortSheet({super.key, required this.selected});

  final ProfileReviewSort selected;

  @override
  Widget build(BuildContext context) {
    return ProfileSheet(
      title: 'Sort by',
      children: [
        for (final sort in ProfileReviewSort.values)
          Semantics(
            inMutuallyExclusiveGroup: true,
            checked: sort == selected,
            child: AdaptiveTap(
              onTap: () => Navigator.of(context).pop(sort),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        sort.label,
                        style: ProfileTokens.text(
                          14,
                          weight: sort == selected
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (sort == selected)
                      const Icon(
                        LucideIcons.check,
                        size: 18,
                        color: ProfileTokens.brand,
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
