import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/home_page/bloc/home_bloc.dart';
import 'package:nook/features/home_page/bloc/home_event.dart';
import 'package:nook/features/home_page/bloc/home_states.dart';
import 'package:nook/features/home_page/presentation/pages/home_page.dart';

class _StubHomeBloc extends Bloc<HomeEvent, HomeState> implements HomeBloc {
  _StubHomeBloc(super.initialState) {
    on<HomeEvent>((event, _) => events.add(event));
  }

  final events = <HomeEvent>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<_StubHomeBloc> pump(WidgetTester tester, HomeState state) async {
    final bloc = _StubHomeBloc(state);
    addTearDown(bloc.close);
    await tester.pumpWidget(
      BlocProvider<HomeBloc>.value(
        value: bloc,
        child: const RetryOnResume(child: SizedBox()),
      ),
    );
    return bloc;
  }

  void resume(WidgetTester tester) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }

  testWidgets('back in the app on an error, Home loads again (UX S9)', (
    tester,
  ) async {
    final bloc = await pump(
      tester,
      HomeError(const SocketException('offline')),
    );
    resume(tester);
    await tester.pump();
    expect(bloc.events.whereType<LoadHomeDataEvent>(), hasLength(1));
  });

  testWidgets('a loaded Home is left alone on resume', (tester) async {
    final bloc = await pump(tester, HomeLoadingState());
    resume(tester);
    await tester.pump();
    expect(bloc.events, isEmpty);
  });
}
