import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/features/lists/bloc/lists_bloc.dart';

/// Stands in for [AuthBloc] in widget tests: records every event and lets
/// the test push the states the real bloc would emit.
class FakeAuthBloc extends Bloc<AuthEvent, AuthState> implements AuthBloc {
  FakeAuthBloc([AuthState? initial]) : super(initial ?? AuthInitial()) {
    on<AuthEvent>((event, _) => events.add(event));
  }

  final List<AuthEvent> events = [];

  void push(AuthState state) => emit(state);

  @override
  ListsBloc get listsBloc => throw UnimplementedError();
}
