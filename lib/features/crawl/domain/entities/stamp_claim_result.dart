import 'package:nook/features/crawl/domain/entities/crawl_stamp.dart';

class StampClaimResult {
  final CrawlStamp stamp;
  final int totalStamps;
  final TierCompletionResult? tierCompletion;

  const StampClaimResult({
    required this.stamp,
    this.totalStamps = 0,
    this.tierCompletion,
  });
}

class TierCompletionResult {
  final String tierId;
  final String tierSlug;
  final String tierName;
  final String? completionCopy;
  final String achievementId;
  final String? badgeImageUrl;
  final DateTime earnedAt;

  const TierCompletionResult({
    required this.tierId,
    required this.tierSlug,
    required this.tierName,
    this.completionCopy,
    required this.achievementId,
    this.badgeImageUrl,
    required this.earnedAt,
  });
}
