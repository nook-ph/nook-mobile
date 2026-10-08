import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/block/block_cubit.dart';
import 'package:nook/core/cafe/domain/entities/report_reason.dart';
import 'package:nook/core/cafe/domain/use_cases/report_review_usecase.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_guest_sign_in_sheet.dart';
import 'package:nook/features/cafe_details/presentation/widgets/review_sheet_shell.dart';
import 'package:nook/injection_container.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// What the ⋯ sheet on a review can return.
enum ReviewOption { report, block, delete }

String? _currentUserId() => Supabase.instance.client.auth.currentUser?.id;

String _displayName(String? authorName) {
  final name = authorName?.trim() ?? '';
  return name.isEmpty ? 'this user' : name;
}

/// Opens the ⋯ sheet for another user's review: report or block. A guest
/// can open it too; either choice then asks them to sign in.
///
/// [toastBottomOffset] lifts the result toast above a pinned bottom bar.
/// [currentUserId] says who is signed in (null for a guest); it defaults to
/// the Supabase session.
Future<void> showReviewActionsSheet(
  BuildContext context, {
  required String reviewId,
  required String cafeId,
  required String authorId,
  String? authorName,
  double toastBottomOffset = 0,
  ValueGetter<String?>? currentUserId,
}) async {
  final choice = await ReviewSheetShell.show<ReviewOption>(
    context,
    builder: (_) => ReviewOptionsSheet.forOther(authorName: authorName),
  );
  if (choice == null || !context.mounted) return;

  final reporterId = (currentUserId ?? _currentUserId)();
  if (reporterId == null) {
    await CafeGuestSignInSheet.show(
      context,
      action: CafeGuestAction.reportReview,
    );
    return;
  }

  if (choice == ReviewOption.report) {
    final sent = await ReviewSheetShell.show<bool>(
      context,
      builder: (_) => ReviewReportSheet(
        onSubmit: (reason, details) => sl<ReportReviewUseCase>().call(
          reviewId: reviewId,
          cafeId: cafeId,
          reporterId: reporterId,
          reasonCode: reason.code,
          description: details,
        ),
      ),
    );
    if (sent == true && context.mounted) {
      showPrimaryToast(
        context,
        ReviewReportSheet.sentMessage,
        bottomOffset: toastBottomOffset,
      );
    }
    return;
  }

  if (choice == ReviewOption.block) {
    await _confirmAndBlock(
      context,
      reviewId: reviewId,
      cafeId: cafeId,
      authorId: authorId,
      authorName: authorName,
      reporterId: reporterId,
      toastBottomOffset: toastBottomOffset,
    );
  }
}

/// Opens the ⋯ sheet for the signed-in user's own review, then the delete
/// confirmation. True when the user confirmed the delete; the caller does
/// the deleting.
Future<bool> showOwnReviewSheet(
  BuildContext context, {
  String? cafeName,
}) async {
  final choice = await ReviewSheetShell.show<ReviewOption>(
    context,
    builder: (_) => ReviewOptionsSheet.forOwn(cafeName: cafeName),
  );
  if (choice != ReviewOption.delete || !context.mounted) return false;

  final confirmed = await ReviewSheetShell.show<bool>(
    context,
    builder: (_) => ReviewConfirmSheet.deleteReview(cafeName: cafeName),
  );
  return confirmed == true;
}

/// Confirms, then blocks the author: auto-files a report (so the developer is
/// notified of the offending content) and updates the app-wide block cache so
/// the author's reviews vanish from the feed instantly.
Future<void> _confirmAndBlock(
  BuildContext context, {
  required String reviewId,
  required String cafeId,
  required String authorId,
  required String reporterId,
  String? authorName,
  double toastBottomOffset = 0,
}) async {
  final blockCubit = context.read<BlockCubit>();

  final confirmed = await ReviewSheetShell.show<bool>(
    context,
    builder: (_) => ReviewConfirmSheet.blockUser(authorName: authorName),
  );
  if (confirmed != true) return;

  try {
    // Notify the developer of the offending content (best-effort — a failed
    // report must not prevent the block itself).
    try {
      await sl<ReportReviewUseCase>().call(
        reviewId: reviewId,
        cafeId: cafeId,
        reporterId: reporterId,
        reasonCode: ReportReason.inappropriateContent.code,
        description: 'Auto-filed when the reporter blocked this user.',
      );
    } catch (_) {
      // Swallow — blocking is the primary, must-succeed action.
    }

    await blockCubit.block(authorId);
    if (!context.mounted) return;
    final name = authorName?.trim() ?? '';
    showPrimaryToast(
      context,
      '${name.isEmpty ? 'User' : name} blocked. Their content is now hidden.',
      bottomOffset: toastBottomOffset,
    );
  } catch (_) {
    if (!context.mounted) return;
    showPrimaryToast(
      context,
      'Could not block this user. Please try again.',
      bottomOffset: toastBottomOffset,
    );
  }
}

/// The ⋯ sheet: a title, a close button and one or two text rows. Pops with
/// the [ReviewOption] that was tapped.
class ReviewOptionsSheet extends StatelessWidget {
  const ReviewOptionsSheet._({required this.title, required this.options});

  /// Report and block, for someone else's review.
  factory ReviewOptionsSheet.forOther({String? authorName}) {
    final name = authorName?.trim() ?? '';
    return ReviewOptionsSheet._(
      title: name.isEmpty ? 'Review options' : 'Review by $name',
      options: [
        (
          option: ReviewOption.report,
          label: 'Report review',
          detail: 'Flag objectionable or abusive content',
          danger: false,
        ),
        (
          option: ReviewOption.block,
          label: 'Block ${_displayName(authorName)}',
          detail: 'Hide this user and report their content',
          danger: true,
        ),
      ],
    );
  }

  /// Delete, for the signed-in user's own review.
  factory ReviewOptionsSheet.forOwn({String? cafeName}) {
    final cafe = cafeName?.trim() ?? '';
    return ReviewOptionsSheet._(
      title: 'Your review',
      options: [
        (
          option: ReviewOption.delete,
          label: 'Delete review',
          detail:
              'Removes your rating, text and photos from '
              '${cafe.isEmpty ? 'this cafe' : cafe}',
          danger: true,
        ),
      ],
    );
  }

  final String title;
  final List<({ReviewOption option, String label, String detail, bool danger})>
  options;

  @override
  Widget build(BuildContext context) {
    return ReviewSheetShell(
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in options) ...[
            const SizedBox(height: 4),
            AdaptiveTap(
              onTap: () => Navigator.of(context).pop(item.option),
              borderRadius: BorderRadius.circular(12),
              child: Semantics(
                button: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.bodyMediumMed.copyWith(
                          color: item.danger
                              ? ReviewTokens.danger
                              : ReviewTokens.ink,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        item.detail,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: ReviewTokens.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Are you sure" as a sheet: a question, one line of consequence, the
/// named destructive action, and Cancel. Pops true when confirmed.
class ReviewConfirmSheet extends StatelessWidget {
  const ReviewConfirmSheet({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
  });

  factory ReviewConfirmSheet.blockUser({String? authorName}) {
    return ReviewConfirmSheet(
      title: 'Block ${_displayName(authorName)}?',
      message:
          'You will no longer see their reviews, and their content will be '
          'reported. You can unblock them in Settings.',
      confirmLabel: 'Block',
    );
  }

  factory ReviewConfirmSheet.deleteReview({String? cafeName}) {
    final cafe = cafeName?.trim() ?? '';
    return ReviewConfirmSheet(
      title: 'Delete your review?',
      message:
          'Your rating, text and photos will be removed from '
          '${cafe.isEmpty ? 'this cafe' : cafe}. This cannot be undone.',
      confirmLabel: 'Delete review',
    );
  }

  final String title;
  final String message;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    return ReviewSheetShell(
      showClose: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: ReviewTokens.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium?.copyWith(
              color: ReviewTokens.muted,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          ReviewPrimaryButton(
            label: confirmLabel,
            color: ReviewTokens.danger,
            onTap: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 8),
          ReviewTextButton(
            label: 'Cancel',
            onTap: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}

/// Report reason picker with an optional one-line detail. Pops true once
/// [onSubmit] completes; stays open with a toast when it throws.
class ReviewReportSheet extends StatelessWidget {
  const ReviewReportSheet({super.key, required this.onSubmit});

  final Future<void> Function(ReportReason reason, String details) onSubmit;

  static const sentMessage =
      'Thanks for reporting. Our team reviews reports within 24 hours.';

  @override
  Widget build(BuildContext context) {
    return ReportReasonSheet<ReportReason>(
      title: 'Why are you reporting this review?',
      reasons: ReportReason.values,
      labelOf: (reason) => reason.label,
      onSubmit: onSubmit,
    );
  }
}

/// The report sheet every report in the app shares: why (one of
/// [reasons]), an optional detail, then Submit report. Nothing is sent until
/// Submit, so a stray tap on a reason never files a report. Pops true once
/// [onSubmit] completes; stays open with a toast when it throws.
class ReportReasonSheet<T> extends StatefulWidget {
  const ReportReasonSheet({
    super.key,
    required this.title,
    required this.reasons,
    required this.labelOf,
    required this.onSubmit,
    this.message,
  });

  final String title;

  /// One line under the title, such as who will know.
  final String? message;
  final List<T> reasons;
  final String Function(T reason) labelOf;
  final Future<void> Function(T reason, String details) onSubmit;

  @override
  State<ReportReasonSheet<T>> createState() => _ReportReasonSheetState<T>();
}

class _ReportReasonSheetState<T> extends State<ReportReasonSheet<T>> {
  T? _selected;
  final TextEditingController _detailController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _selected;
    if (reason == null || _submitting) return;

    setState(() => _submitting = true);
    try {
      await widget.onSubmit(reason, _detailController.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showPrimaryToast(context, 'Could not submit the report. Please retry.');
    }
  }

  static OutlineInputBorder _border(Color color, double width) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    return ReviewSheetShell(
      title: widget.title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.message case final message?) ...[
            const SizedBox(height: 2),
            Text(
              message,
              style: context.textTheme.bodySmall?.copyWith(
                color: ReviewTokens.muted,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
          ],
          const SizedBox(height: 2),
          for (final reason in widget.reasons)
            _ReasonRow(
              label: widget.labelOf(reason),
              selected: reason == _selected,
              onTap: _submitting
                  ? null
                  : () => setState(() => _selected = reason),
            ),
          const SizedBox(height: 2),
          TextField(
            controller: _detailController,
            enabled: !_submitting,
            maxLines: 1,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            cursorColor: ReviewTokens.brand,
            style: context.textTheme.bodyMedium?.copyWith(
              color: ReviewTokens.ink,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: 'Add details (optional)',
              hintStyle: context.textTheme.bodyMedium?.copyWith(
                color: ReviewTokens.muted,
                fontSize: 14,
              ),
              counterText: '',
              isDense: true,
              filled: true,
              fillColor: ReviewTokens.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              enabledBorder: _border(ReviewTokens.border, 1),
              disabledBorder: _border(ReviewTokens.border, 1),
              focusedBorder: _border(ReviewTokens.ink, 1.5),
            ),
          ),
          const SizedBox(height: 16),
          ReviewPrimaryButton(
            label: 'Submit report',
            busy: _submitting,
            onTap: _selected == null ? null : _submit,
          ),
        ],
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: label,
      excludeSemantics: true,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        // 39 tall in Figma with a 4 gap; the gap is folded into the row so
        // the whole 43 is tappable.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? ReviewTokens.brand
                        : const Color(0xFFC4C4C4),
                    width: selected ? 2 : 1.5,
                  ),
                ),
                child: selected
                    ? Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: ReviewTokens.brand,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style:
                      (selected
                              ? context.textTheme.bodyMediumMed
                              : context.textTheme.bodyMedium)
                          ?.copyWith(color: ReviewTokens.ink, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
