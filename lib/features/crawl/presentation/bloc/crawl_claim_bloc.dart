import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/errors/failure.dart';
import 'package:nook/core/services/gps_service.dart';
import 'package:nook/features/crawl/domain/failures/crawl_failures.dart';
import 'package:nook/features/crawl/domain/use_cases/claim_stamp_usecase.dart';
import 'package:nook/features/crawl/presentation/bloc/crawl_claim_event.dart';
import 'package:nook/features/crawl/presentation/bloc/crawl_claim_state.dart';

class CrawlClaimBloc extends Bloc<CrawlClaimEvent, CrawlClaimState> {
  final ClaimStampUseCase _claimStampUseCase;
  final GpsService _gpsService;

  CrawlClaimBloc({
    required ClaimStampUseCase claimStampUseCase,
    required GpsService gpsService,
  })  : _claimStampUseCase = claimStampUseCase,
        _gpsService = gpsService,
        super(const CrawlClaimInitial()) {
    on<ClaimInitialized>(_onClaimInitialized);
    on<ClaimRetryRequested>(_onClaimRetryRequested);
    on<ClaimResetRequested>((_, emit) => emit(const CrawlClaimInitial()));
  }

  Future<void> _onClaimInitialized(
    ClaimInitialized event,
    Emitter<CrawlClaimState> emit,
  ) async {
    emit(
      AcquiringGps(
        crawlId: event.crawlId,
        stopId: event.stopId,
        crawlTitle: event.crawlTitle,
        cafeName: event.cafeName,
      ),
    );

    final gps = await _gpsService.getCurrentPosition();
    switch (gps) {
      case GpsResult(position: final pos) when pos != null:
        await _submitClaim(emit, event, pos.latitude, pos.longitude);
      case GpsResult(denied: true):
        emit(const GpsDenied());
      case GpsResult(timeout: true):
        emit(const GpsTimeout());
      case _:
        emit(const GpsDenied());
    }
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
      case Left(value: final failure) when failure is LocationTooFarFailure:
        emit(LocationTooFar((failure as LocationTooFarFailure).distanceMeters));
      case Left(value: final failure) when failure is AlreadyClaimedFailure:
        emit(AlreadyClaimed((failure as AlreadyClaimedFailure).claimedAt));
      case Left(value: final failure) when failure is CrawlEndedFailure:
        emit(const CrawlExpired());
      case Left(value: final failure) when failure is StopInactiveFailure:
        emit(const StopInactive());
      case Left(value: final failure):
        emit(ClaimNetworkError(failure));
    }
  }

  Future<void> _onClaimRetryRequested(
    ClaimRetryRequested event,
    Emitter<CrawlClaimState> emit,
  ) async {
    final s = state;
    switch (s) {
      case AcquiringGps(
          :final crawlId,
          :final stopId,
          :final crawlTitle,
          :final cafeName,
        ):
        add(
          ClaimInitialized(
            crawlId: crawlId,
            stopId: stopId,
            crawlTitle: crawlTitle,
            cafeName: cafeName,
          ),
        );
      case LocationTooFar() ||
            AlreadyClaimed() ||
            GpsDenied() ||
            GpsTimeout() ||
            ClaimNetworkError():
        emit(const CrawlClaimInitial());
      case _:
        emit(const CrawlClaimInitial());
    }
  }
}
