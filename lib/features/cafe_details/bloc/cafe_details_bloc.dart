import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/features/cafe_details/bloc/cafe_details_event.dart';
import 'package:nook/features/cafe_details/bloc/cafe_details_states.dart';
import 'package:nook/features/cafe_details/domain/use_cases/get_cafe_details_usecase.dart';


class CafeDetailsBloc extends Bloc<CafeDetailsEvent, CafeDetailsState> {

  final GetCafeDetailsUseCase getCafeDetailsUseCase;

  CafeDetailsBloc({required this.getCafeDetailsUseCase})
      : super(const CafeDetailsInitial()) {
    on<LoadCafeDetailsRequested>(_onLoadCafeDetailsRequested);
  }

  Future<void> _onLoadCafeDetailsRequested(
    LoadCafeDetailsRequested event,
    Emitter<CafeDetailsState> emit,
  ) async {
    emit(const CafeDetailsLoading());

    try {
      final result = await getCafeDetailsUseCase.call(
        GetCafeDetailsParams(
          cafeId: event.cafeId,
          menuHighlightsLimit: event.menuHighlightsLimit,
          latestReviewsLimit: event.latestReviewsLimit,
          allMenuLimit: 50,
          allReviewsLimit: 50,
        ),
      );

      emit(CafeDetailsLoaded(result));
    } catch (e) {
      debugPrint('[CafeDetailsBloc] Fetch Error: $e');
      emit(CafeDetailsError(e.toString()));
    }
  }
}