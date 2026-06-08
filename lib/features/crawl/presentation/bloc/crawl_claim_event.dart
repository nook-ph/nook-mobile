import 'package:equatable/equatable.dart';

sealed class CrawlClaimEvent extends Equatable {
  const CrawlClaimEvent();

  @override
  List<Object?> get props => [];
}

class ClaimInitialized extends CrawlClaimEvent {
  final String crawlId;
  final String stopId;
  final String crawlTitle;
  final String cafeName;

  const ClaimInitialized({
    required this.crawlId,
    required this.stopId,
    required this.crawlTitle,
    required this.cafeName,
  });

  @override
  List<Object?> get props => [crawlId, stopId, crawlTitle, cafeName];
}

class ClaimRetryRequested extends CrawlClaimEvent {
  const ClaimRetryRequested();
}

class ClaimResetRequested extends CrawlClaimEvent {
  const ClaimResetRequested();
}
