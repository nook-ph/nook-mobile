import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../data/onboarding_data.dart';

part 'onboarding_event.dart';
part 'onboarding_state.dart';

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  OnboardingBloc() : super(const OnboardingState()) {

    on<PageChanged>((event, emit) {
      final isLast = event.index == OnboardingData.items.length - 1;
      emit(state.copyWith(
        pageIndex: event.index,
        isLastPage: isLast,
      ));
    });
  }
}