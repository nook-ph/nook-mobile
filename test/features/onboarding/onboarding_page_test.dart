import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/analytics/onboarding_events.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/cafe/domain/use_cases/get_cafe_statuses_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/set_cafe_status_usecase.dart';
import 'package:nook/core/cafe/presentation/cafe_status_cubit.dart';
import 'package:nook/core/preferences/onboarding_purpose_store.dart';
import 'package:nook/features/onboarding/bloc/purpose_suggestions_cubit.dart';
import 'package:nook/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:nook/utils/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/analytics/recording_analytics.dart';

class _NoStatuses implements ICafeRepository {
  @override
  Future<Map<String, CafeStatus>> getCafeStatuses(List<String> ids) async =>
      const {};

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

const _cafes = [
  CafeSummary(id: 'c1', name: 'Abaca', rating: 4.6),
  CafeSummary(id: 'c2', name: 'Bo\'s', rating: 4.4),
  CafeSummary(id: 'c3', name: 'Commune', rating: 4.2),
];

void main() {
  late RecordingAnalytics analytics;
  late List<int> finishes;
  late List<String> opened;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    finishes = [];
    opened = [];
  });

  Future<void> pumpOnboarding(
    WidgetTester tester, {
    PurposeSuggestionsLoader? load,
  }) async {
    analytics = RecordingAnalytics.install(addTearDown);
    final repo = _NoStatuses();
    await tester.pumpWidget(
      BlocProvider(
        create: (_) => CafeStatusCubit(
          getCafeStatusesUseCase: GetCafeStatusesUseCase(repo),
          setCafeStatusUseCase: SetCafeStatusUseCase(repo),
        ),
        child: MaterialApp(
          theme: TAppTheme.lightTheme,
          home: OnboardingPage(
            onFinish: () => finishes.add(1),
            loadSuggestions: load ?? (_) async => _cafes,
            purposeStore: OnboardingPurposeStore(),
            onOpenCafe: opened.add,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> toPurpose(WidgetTester tester) async {
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
  }

  testWidgets('slide 1 has Skip and Next; Skip goes to the question', (
    tester,
  ) async {
    await pumpOnboarding(tester);
    expect(find.text('Find your kind\nof cafe'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(analytics.propertiesOf(OnboardingEvents.slideViewed), {'index': 0});

    await toPurpose(tester);
    expect(find.text('What are you\nlooking for?'), findsOneWidget);
    expect(finishes, isEmpty);
    expect(analytics.propertiesOf(OnboardingEvents.skipped), {'index': 0});
    expect(analytics.propertiesOf(OnboardingEvents.slideViewed), {
      'index': OnboardingEvents.purposeStepIndex,
    });
  });

  testWidgets('the last slide reads Continue and leads to the question', (
    tester,
  ) async {
    await pumpOnboarding(tester);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Know before\nyou go'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Keep your\ncoffee story'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('What are you\nlooking for?'), findsOneWidget);
    expect(
      analytics.events
          .where((e) => e.$1 == OnboardingEvents.slideViewed)
          .map((e) => e.$2!['index']),
      [0, 1, 2, 3],
    );
  });

  testWidgets('Skip on the question goes Home without a purpose', (
    tester,
  ) async {
    await pumpOnboarding(tester);
    await toPurpose(tester);
    await tester.tap(find.text('Skip'));
    expect(finishes, [1]);
    expect(analytics.propertiesOf(OnboardingEvents.skipped), {'index': 3});
    expect(analytics.names, isNot(contains(OnboardingEvents.completed)));
    expect(await OnboardingPurposeStore().read(), isNull);
  });

  testWidgets('a purpose is saved and its cafes are shown', (tester) async {
    await pumpOnboarding(tester);
    await toPurpose(tester);
    await tester.tap(find.text('Work or study'));
    await tester.pumpAndSettle();

    expect(analytics.propertiesOf(OnboardingEvents.purposeSelected), {
      'purpose': 'work',
    });
    expect(await OnboardingPurposeStore().read(), OnboardingPurpose.work);
    expect(find.text('Good for getting\nwork done'), findsOneWidget);
    expect(find.text('Abaca'), findsOneWidget);
    expect(find.text('Show me everything'), findsOneWidget);
    expect(finishes, isEmpty);
  });

  testWidgets('tapping a suggestion opens it and ends onboarding', (
    tester,
  ) async {
    await pumpOnboarding(tester);
    await toPurpose(tester);
    await tester.tap(find.text('Specialty coffee'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Bo\'s'));
    await tester.tap(find.text('Bo\'s'));
    expect(opened, ['c2']);
    expect(finishes, [1]);
    expect(analytics.propertiesOf(OnboardingEvents.firstSuggestionTapped), {
      'purpose': 'specialty',
      'position': 1,
      'cafe_id': 'c2',
    });
    expect(analytics.propertiesOf(OnboardingEvents.completed), {
      'purpose': 'specialty',
      'exit': 'cafe',
    });
  });

  testWidgets('"Show me everything" goes Home', (tester) async {
    await pumpOnboarding(tester);
    await toPurpose(tester);
    await tester.tap(find.text('Just exploring'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show me everything'));
    expect(finishes, [1]);
    expect(analytics.propertiesOf(OnboardingEvents.completed), {
      'purpose': 'exploring',
      'exit': 'show_all',
    });
  });

  testWidgets('failed suggestions go straight Home', (tester) async {
    await pumpOnboarding(tester, load: (_) async => throw Exception('x'));
    await toPurpose(tester);
    await tester.tap(find.text('Date or hangout'));
    await tester.pump();
    await tester.pump();
    expect(finishes, [1]);
    expect(analytics.propertiesOf(OnboardingEvents.completed), {
      'purpose': 'date',
      'exit': 'no_suggestions',
    });
  });

  testWidgets('while loading, "Show me everything" already works', (
    tester,
  ) async {
    final pending = Completer<List<CafeSummary>>();
    await pumpOnboarding(tester, load: (_) => pending.future);
    await toPurpose(tester);
    await tester.tap(find.text('Work or study'));
    await tester.pump();
    expect(find.text('Finding cafes for you…'), findsOneWidget);
    await tester.tap(find.text('Show me everything'));
    expect(finishes, [1]);
    pending.complete(_cafes);
    await tester.pumpAndSettle();
    expect(finishes, [1]);
  });

  for (final size in [const Size(375, 667), const Size(320, 568)]) {
    testWidgets('every step fits ${size.width}x${size.height}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpOnboarding(tester);
      expect(tester.takeException(), isNull, reason: 'slides');
      await toPurpose(tester);
      expect(tester.takeException(), isNull, reason: 'purpose');
      await tester.tap(find.text('Work or study'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'suggestions');
    });
  }
}
