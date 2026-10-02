import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nook/core/cafe/domain/entities/cafe_query.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/location/device_location.dart';
import 'package:nook/core/utils/error_info.dart';
import 'package:nook/features/home_page/bloc/home_bloc.dart';
import 'package:nook/features/home_page/bloc/home_event.dart';
import 'package:nook/features/home_page/bloc/home_states.dart';
import 'package:nook/features/home_page/domain/use_cases/get_cafe_summaries_usecase.dart';
import 'package:nook/features/home_page/presentation/widgets/home_state_view.dart';
import 'package:nook/utils/theme/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Answers each `sort` from [results]; a sort listed in [failing] throws.
class _Repository implements ICafeRepository {
  Map<String, List<CafeSummary>> results = {};
  Map<String, Object> failing = {};

  /// Answers a turn of the event loop later, as a network call would.
  bool overNetwork = false;

  @override
  Future<List<CafeSummary>> getCafes(CafeQuery query) async {
    if (overNetwork) await Future<void>.delayed(Duration.zero);
    final error = failing[query.sort];
    if (error != null) throw error;
    return results[query.sort] ?? const [];
  }

  @override
  Future<void> warmCache(List<CafeSummary> cafes) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _cafe = CafeSummary(id: 'c1', name: 'Cafe', rating: 4.5);

Future<HomeState> _load(_Repository repository) async {
  final bloc = HomeBloc(getHomeFeedUseCase: GetHomeFeedUseCase(repository));
  addTearDown(bloc.close);
  bloc.add(LoadHomeDataEvent());
  return bloc.stream.firstWhere((s) => s is! HomeLoadingState);
}

void main() {
  // No location plugin in tests: the use case treats that as "no position",
  // so only the three always-on sections are asked for.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('empty versus failed', () {
    test(
      'every section empty and none failing is a loaded, empty feed',
      () async {
        final state = await _load(_Repository());

        expect(state, isA<HomeLoadedState>());
        final loaded = state as HomeLoadedState;
        expect(loaded.hasCafes, isFalse);
        expect(loaded.allEmpty, isTrue);
      },
    );

    test('every section failing is an error, with the first cause', () async {
      final repository = _Repository()
        ..failing = {
          'top_rated': const PostgrestException(message: 'boom', code: '500'),
          'trending': const PostgrestException(message: 'boom', code: '500'),
          'newest': const PostgrestException(message: 'boom', code: '500'),
        };

      final state = await _load(repository);

      expect(state, isA<HomeError>());
      expect((state as HomeError).error, isA<PostgrestException>());
    });

    test('one section failing leaves the others on screen', () async {
      final repository = _Repository()
        ..results = {
          'newest': [_cafe],
        }
        ..failing = {'trending': Exception('down')};

      final state = await _load(repository);

      expect(state, isA<HomeLoadedState>());
      expect((state as HomeLoadedState).newestCafes, [_cafe]);
      expect(state.trendingCafes, isEmpty);
    });

    test('two failing and one empty is still a loaded, empty feed', () async {
      final repository = _Repository()
        ..failing = {
          'trending': Exception('down'),
          'newest': Exception('down'),
        };

      final state = await _load(repository);

      expect(state, isA<HomeLoadedState>());
      expect((state as HomeLoadedState).hasCafes, isFalse);
    });
  });

  group('staged load', () {
    const near = CafeSummary(id: 'n1', name: 'Near', rating: 4);
    const LocationAccess granted = (
      servicesOff: false,
      denied: false,
      deniedForever: false,
    );
    final here = Position(
      latitude: 10.3,
      longitude: 123.9,
      timestamp: DateTime(2026),
      accuracy: 10,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

    _Repository repository() => _Repository()
      ..results = {
        'newest': [_cafe],
        'nearby': [near],
      };

    test('the sections show while the position is still pending', () async {
      final fix = Completer<Position?>();
      final bloc = HomeBloc(
        getHomeFeedUseCase: GetHomeFeedUseCase(
          repository(),
          locationAccess: () async => granted,
          firstPosition: () => fix.future,
        ),
      );
      addTearDown(bloc.close);
      final loaded = <HomeLoadedState>[];
      final sub = bloc.stream.listen((s) {
        if (s is HomeLoadedState) loaded.add(s);
      });
      addTearDown(sub.cancel);

      bloc.add(LoadHomeDataEvent());
      await pumpEventQueue();

      expect(loaded, hasLength(1));
      expect(loaded.single.newestCafes, [_cafe]);
      expect(loaded.single.nearbyCafes, isEmpty);
      expect(loaded.single.newCafeIds, {'c1'});

      fix.complete(here);
      await pumpEventQueue();

      expect(loaded, hasLength(2));
      expect(loaded.last.newestCafes, [_cafe]);
      expect(loaded.last.nearbyCafes, [near]);
      // Only the cafe the second step added is new.
      expect(loaded.last.newCafeIds, {'n1'});
    });

    test('a position that never comes leaves the sections up', () async {
      final fix = Completer<Position?>();
      final bloc = HomeBloc(
        getHomeFeedUseCase: GetHomeFeedUseCase(
          repository(),
          locationAccess: () async => granted,
          firstPosition: () => fix.future,
        ),
      );
      addTearDown(bloc.close);

      bloc.add(LoadHomeDataEvent());
      await pumpEventQueue();
      fix.complete(null);
      await pumpEventQueue();

      final state = bloc.state;
      expect(state, isA<HomeLoadedState>());
      expect((state as HomeLoadedState).newestCafes, [_cafe]);
      expect(state.nearbyCafes, isEmpty);
    });

    test('a position already known gives one emission, with nearby', () async {
      final bloc = HomeBloc(
        getHomeFeedUseCase: GetHomeFeedUseCase(
          repository()..overNetwork = true,
          locationAccess: () async => granted,
          firstPosition: () async => here,
        ),
      );
      addTearDown(bloc.close);
      final loaded = <HomeLoadedState>[];
      final sub = bloc.stream.listen((s) {
        if (s is HomeLoadedState) loaded.add(s);
      });
      addTearDown(sub.cancel);

      bloc.add(LoadHomeDataEvent());
      await pumpEventQueue();

      expect(loaded, hasLength(1));
      expect(loaded.single.nearbyCafes, [near]);
    });

    test('denied location says so on the first emission', () async {
      final bloc = HomeBloc(
        getHomeFeedUseCase: GetHomeFeedUseCase(
          repository(),
          locationAccess: () async =>
              (servicesOff: false, denied: true, deniedForever: true),
          firstPosition: () async => fail('no position without permission'),
        ),
      );
      addTearDown(bloc.close);

      bloc.add(LoadHomeDataEvent());
      final state = await bloc.stream.firstWhere((s) => s is HomeLoadedState);

      expect((state as HomeLoadedState).locationDenied, isTrue);
      expect(state.nearbyCafes, isEmpty);
    });

    test('a refresh keeps the old nearby until the new one lands', () async {
      Completer<Position?>? fix;
      final bloc = HomeBloc(
        getHomeFeedUseCase: GetHomeFeedUseCase(
          repository()..overNetwork = true,
          locationAccess: () async => granted,
          firstPosition: () => fix?.future ?? Future.value(here),
        ),
      );
      addTearDown(bloc.close);

      bloc.add(LoadHomeDataEvent());
      await pumpEventQueue();
      expect((bloc.state as HomeLoadedState).nearbyCafes, [near]);

      fix = Completer<Position?>();
      bloc.add(LoadHomeDataEvent(refresh: true));
      await pumpEventQueue();
      expect((bloc.state as HomeLoadedState).nearbyCafes, [near]);

      fix.complete(null);
      await pumpEventQueue();
      expect((bloc.state as HomeLoadedState).nearbyCafes, isEmpty);
    });
  });

  group('HomeStateView.errorCopy', () {
    test('a server fault uses the home wording', () {
      for (final error in <Object>[
        const PostgrestException(message: 'boom', code: '500'),
        Exception('anything else'),
      ]) {
        final info = HomeStateView.errorCopy(error);
        expect(info.title, "We couldn't load cafes");
        expect(info.subtitle, 'Something went wrong on our side. Try again.');
      }
    });

    test('offline and signed out keep their own copy', () {
      final offline = HomeStateView.errorCopy(const SocketException('x'));
      expect(offline.type, ErrorType.offline);
      expect(offline.title, "You're offline");

      final signedOut = HomeStateView.errorCopy(const AuthException('x'));
      expect(signedOut.type, ErrorType.sessionExpired);
      expect(signedOut.title, "You've been signed out");
    });
  });

  group('state views', () {
    Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      MaterialApp(
        theme: TAppTheme.lightTheme,
        home: Scaffold(body: child),
      ),
    );

    testWidgets('no cafes has no button', (tester) async {
      await pump(tester, const HomeStateView.noCafes());

      expect(find.text('No cafes yet'), findsOneWidget);
      expect(
        find.text('Pull to refresh. New spots appear here soon.'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('a server error offers a retry', (tester) async {
      var retried = 0;
      await pump(
        tester,
        HomeStateView.error(
          error: HomeStateView.errorCopy(
            const PostgrestException(message: 'boom', code: '500'),
          ),
          onRetry: () => retried++,
        ),
      );

      expect(find.text("We couldn't load cafes"), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(retried, 1);
    });
  });
}
