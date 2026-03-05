import 'package:flutter_bloc/flutter_bloc.dart';

// --- EVENTS ---
abstract class NavigationEvent {}

class TabChange extends NavigationEvent {
  final int tabIndex;
  TabChange({required this.tabIndex});
}

// --- STATES ---
class NavigationState {
  final int tabIndex;
  const NavigationState({required this.tabIndex});
}

class NavigationInitial extends NavigationState {
  const NavigationInitial() : super(tabIndex: 0); 
}

// --- BLOC ---
class NavigationBloc extends Bloc<NavigationEvent, NavigationState> {
  NavigationBloc() : super(const NavigationInitial()) {
    on<TabChange>((event, emit) {
      emit(NavigationState(tabIndex: event.tabIndex));
    });
  }
}