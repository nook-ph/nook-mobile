import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/features/home_page/bloc/home_event.dart';
import 'package:nook/features/home_page/bloc/home_states.dart';
import 'package:nook/features/home_page/domain/use_cases/get_home_cafes_usecase.dart';
import 'package:flutter/foundation.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final GetHomeCafesUseCase getHomeCafesUseCase;

  HomeBloc({required this.getHomeCafesUseCase}) : super(HomeInitialState()) {
    on<LoadHomeDataEvent>(_onLoadHomeData);
  }

  Future<void> _onLoadHomeData(
    LoadHomeDataEvent event,
    Emitter<HomeState> emit,
  ) async {
    emit(HomeLoadingState());

    try {
      debugPrint('[HomeBloc] Fetching home cafes...');
      final result = await getHomeCafesUseCase.call();

      debugPrint(
        '[HomeBloc] Fetch success featured=${result.featured.length} recommended=${result.recommended.length}',
      );

      emit(
        HomeLoadedState(
          featuredCafes: result.featured,
          recommendedCafes: result.recommended,
        ),
      );
    } catch (e) {
      debugPrint('[HomeBloc] Fetch error: $e');
      emit(HomeError(e.toString()));
    }
  }
}
