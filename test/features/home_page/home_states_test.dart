import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/domain/entities/cafe_query.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
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

  @override
  Future<List<CafeSummary>> getCafes(CafeQuery query) async {
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
