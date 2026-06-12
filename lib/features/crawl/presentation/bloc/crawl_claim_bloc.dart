import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/errors/failure.dart';
import 'package:nook/features/crawl/domain/failures/crawl_failures.dart';
import 'package:nook/features/crawl/domain/use_cases/claim_stamp_usecase.dart';
import 'package:nook/features/crawl/presentation/bloc/crawl_claim_event.dart';
import 'package:nook/features/crawl/presentation/bloc/crawl_claim_state.dart';

class CrawlClaimBloc extends Bloc<CrawlClaimEvent, CrawlClaimState> {
  final ClaimStampUseCase _claimStampUseCase;

  CrawlClaimBloc({
    required ClaimStampUseCase claimStampUseCase,
  })  : _claimStampUseCase = claimStampUseCase,
        super(const CrawlClaimInitial()) {
    on<ClaimInitialized>(_onClaimInitialized);
    on<ClaimRetryRequested>(_onClaimRetryRequested);
    on<ClaimResetRequested>((_, emit) => emit(const CrawlClaimInitial()));
  }

  Future<void> _onClaimInitialized(
    ClaimInitialized event,
    Emitter<CrawlClaimState> emit,
  ) async {
    // GPS checking is temporarily disabled for testing.
    // To re-enable:
    //   1. Add `final GpsService _gpsService` field and constructor param
    //   2. Import 'package:nook/core/services/gps_service.dart'
    //   3. Replace the line below with the original GPS acquisition:
    //      final gps = await _gpsService.getCurrentPosition();
    //      switch (gps) { GpsResult(denied) → GpsDenied, etc. }
    await _submitClaim(emit, event, 0.0, 0.0);
  }

  Future<void> _submitClaim(
    Emitter<CrawlClaimState> emit,
    ClaimInitialized event,
    double lat,
    double lng,
  ) async {
    emit(
      ClaimSubmitting(
        crawlId: event.crawlId,
        stopId: event.stopId,
        crawlTitle: event.crawlTitle,
        cafeName: event.cafeName,
        lat: lat,
        lng: lng,
      ),
    );

    final result = await _claimStampUseCase.call(
      crawlId: event.crawlId,
      stopId: event.stopId,
      lat: lat,
      lng: lng,
    );

    switch (result) {
      case Right(value: final stampResult)
          when stampResult.tierCompletion != null:
        emit(
          ClaimSuccessWithTierCompletion(
            stampResult,
            stampResult.tierCompletion!,
            event.crawlTitle,
            event.cafeName,
          ),
        );
      case Right(value: final stampResult):
        emit(ClaimSuccess(stampResult, event.crawlTitle, event.cafeName));
      case Left(value: final LocationTooFarFailure f):
        emit(LocationTooFar(f.distanceMeters));
      case Left(value: final AlreadyClaimedFailure f):
        emit(AlreadyClaimed(f.claimedAt));
      case Left(value: CrawlEndedFailure()):
        emit(const CrawlExpired());
      case Left(value: StopInactiveFailure()):
        emit(const StopInactive());
      case Left(value: final Failure failure):
        emit(ClaimNetworkError(failure));
    }
  }

  Future<void> _onClaimRetryRequested(
    ClaimRetryRequested event,
    Emitter<CrawlClaimState> emit,
  ) async {
    final s = state;
    switch (s) {
      case ClaimNetworkError():
        emit(const CrawlClaimInitial());
      case _:
        emit(const CrawlClaimInitial());
    }
  }
}
