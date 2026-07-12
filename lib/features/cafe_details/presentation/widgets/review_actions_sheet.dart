import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/block/block_cubit.dart';
import 'package:nook/core/cafe/domain/entities/report_reason.dart';
import 'package:nook/core/cafe/domain/use_cases/report_review_usecase.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/injection_container.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _kBrandGreen = Color(0xFF344E41);

/// Opens the overflow actions for another user's review: report or block.
/// Only call this for reviews the current user did NOT author.
Future<void> showReviewActionsSheet(
  BuildContext context, {
  required String reviewId,
  required String cafeId,
  required String authorId,
  String? authorName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Colors.black87),
              title: const Text('Report review'),
              subtitle: const Text('Flag objectionable or abusive content'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await _showReportReasonSheet(
                  context,
                  reviewId: reviewId,
                  cafeId: cafeId,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.redAccent),
              title: const Text(
                'Block user',
                style: TextStyle(color: Colors.redAccent),
              ),
              subtitle: Text(
                'Hide ${authorName ?? 'this user'} and report their content',
              ),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await _confirmAndBlock(
                  context,
                  reviewId: reviewId,
                  cafeId: cafeId,
                  authorId: authorId,
                  authorName: authorName,
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

String? _currentUserId() => Supabase.instance.client.auth.currentUser?.id;

/// Report reason picker + optional detail, then files the report.
Future<void> _showReportReasonSheet(
  BuildContext context, {
  required String reviewId,
  required String cafeId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ReportReasonSheet(reviewId: reviewId, cafeId: cafeId),
  );
}

class _ReportReasonSheet extends StatefulWidget {
  const _ReportReasonSheet({required this.reviewId, required this.cafeId});

  final String reviewId;
  final String cafeId;

  @override
  State<_ReportReasonSheet> createState() => _ReportReasonSheetState();
}

class _ReportReasonSheetState extends State<_ReportReasonSheet> {
  ReportReason? _selected;
  final TextEditingController _detailController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _selected;
    final reporterId = _currentUserId();
    if (reason == null || _submitting) return;
    if (reporterId == null) {
      showPrimaryToast(context, 'Please sign in to report content.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await sl<ReportReviewUseCase>().call(
        reviewId: widget.reviewId,
        cafeId: widget.cafeId,
        reporterId: reporterId,
        reasonCode: reason.code,
        description: _detailController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      showPrimaryToast(
        context,
        'Thanks for reporting. Our team reviews reports within 24 hours.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showPrimaryToast(context, 'Could not submit the report. Please retry.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Why are you reporting this review?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...ReportReason.values.map(
                  (reason) => RadioListTile<ReportReason>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    activeColor: _kBrandGreen,
                    value: reason,
                    groupValue: _selected,
                    onChanged: _submitting
                        ? null
                        : (value) => setState(() => _selected = value),
                    title: Text(reason.label),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _detailController,
                  enabled: !_submitting,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: 'Add details (optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_selected == null || _submitting)
                        ? null
                        : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kBrandGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text('Submit report'),
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

/// Confirms, then blocks the author: auto-files a report (so the developer is
/// notified of the offending content) and updates the app-wide block cache so
/// the author's reviews vanish from the feed instantly.
Future<void> _confirmAndBlock(
  BuildContext context, {
  required String reviewId,
  required String cafeId,
  required String authorId,
  String? authorName,
}) async {
  final blockCubit = context.read<BlockCubit>();
  final reporterId = _currentUserId();
  if (reporterId == null) {
    showPrimaryToast(context, 'Please sign in to block users.');
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Block ${authorName ?? 'this user'}?'),
      content: const Text(
        'You will no longer see their reviews, and their content will be '
        'reported to our team for review. You can unblock them anytime in '
        'Settings.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
          child: const Text('Block'),
        ),
      ],
    ),
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
    showPrimaryToast(
      context,
      '${authorName ?? 'User'} blocked. Their content is now hidden.',
    );
  } catch (_) {
    if (!context.mounted) return;
    showPrimaryToast(context, 'Could not block this user. Please try again.');
  }
}
