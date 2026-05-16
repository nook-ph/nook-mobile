import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/app_event.dart';
import 'package:nook/core/app_state.dart';

import 'package:shared_preferences/shared_preferences.dart';

class AppBloc extends Bloc<AppEvent, AppState> {
  AppBloc() : super(AppInitial()) {
    on<AppStarted>(_onAppStarted);
    on<OnboardingCompleted>(_onOnboardingCompleted);
  }

  Future<void> _onAppStarted(AppStarted event, Emitter<AppState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
    debugPrint('AppBloc: AppStarted hasSeenOnboarding=$hasSeenOnboarding');

    if (hasSeenOnboarding) {
      debugPrint('AppBloc: emit ShowHome');
      emit(ShowHome());
    } else {
      debugPrint('AppBloc: emit ShowOnboarding');
      emit(ShowOnboarding());
    }
  }

  Future<void> _onOnboardingCompleted(
    OnboardingCompleted event,
    Emitter<AppState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);

    debugPrint('AppBloc: emit ShowHome (onboarding completed)');
    emit(ShowHome());
  }
}
