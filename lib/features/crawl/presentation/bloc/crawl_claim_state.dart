import 'package:equatable/equatable.dart';
import 'package:nook/core/errors/failure.dart';
import 'package:nook/features/crawl/domain/entities/stamp_claim_result.dart';

sealed class CrawlClaimState extends Equatable {
  const CrawlClaimState();

  @override
  List<Object?> get props => [];
}

class CrawlClaimInitial extends CrawlClaimState {
  const CrawlClaimInitial();
}

class AcquiringGps extends CrawlClaimState {
  final String crawlId;
  final String stopId;
  final String crawlTitle;
  final String cafeName;

  const AcquiringGps({
    required this.crawlId,
    required this.stopId,
    required this.crawlTitle,
    required this.cafeName,
  });

  @override
  List<Object?> get props => [crawlId, stopId, crawlTitle, cafeName];
}

class ClaimSubmitting extends CrawlClaimState {
  final String crawlId;
  final String stopId;
  final String crawlTitle;
  final String cafeName;
  final double lat;
  final double lng;

  const ClaimSubmitting({
    required this.crawlId,
    required this.stopId,
    required this.crawlTitle,
    required this.cafeName,
    required this.lat,
    required this.lng,
  });

  @override
  List<Object?> get props => [crawlId, stopId, crawlTitle, cafeName, lat, lng];
}

class ClaimSuccess extends CrawlClaimState {
  final StampClaimResult result;
  final String crawlTitle;
  final String cafeName;

  const ClaimSuccess(this.result, this.crawlTitle, this.cafeName);

  @override
  List<Object?> get props => [result, crawlTitle, cafeName];
}

class ClaimSuccessWithTierCompletion extends CrawlClaimState {
  final StampClaimResult result;
  final TierCompletionResult tier;
  final String crawlTitle;
  final String cafeName;

  const ClaimSuccessWithTierCompletion(
    this.result,
    this.tier,
    this.crawlTitle,
    this.cafeName,
  );

  @override
  List<Object?> get props => [result, tier, crawlTitle, cafeName];
}

class GpsDenied extends CrawlClaimState {
  const GpsDenied();
}

class GpsTimeout extends CrawlClaimState {
  const GpsTimeout();
}

class LocationTooFar extends CrawlClaimState {
  final int distanceMeters;

  const LocationTooFar(this.distanceMeters);

  @override
  List<Object?> get props => [distanceMeters];
}

class AlreadyClaimed extends CrawlClaimState {
  final DateTime claimedAt;

  const AlreadyClaimed(this.claimedAt);

  @override
  List<Object?> get props => [claimedAt];
}

class CrawlExpired extends CrawlClaimState {
  const CrawlExpired();
}

class StopInactive extends CrawlClaimState {
  const StopInactive();
}

class NotRegistered extends CrawlClaimState {
  const NotRegistered();
}

class ClaimNetworkError extends CrawlClaimState {
  final Failure failure;

  const ClaimNetworkError(this.failure);

  @override
  List<Object?> get props => [failure];
}
