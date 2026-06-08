import 'package:flutter/material.dart';
import 'package:nook/features/crawl/domain/entities/stamp_claim_result.dart';

class TierCompletionModal extends StatelessWidget {
  final TierCompletionResult tier;
  final VoidCallback onShare;
  final VoidCallback onContinue;

  const TierCompletionModal({
    super.key,
    required this.tier,
    required this.onShare,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox();
  }
}
