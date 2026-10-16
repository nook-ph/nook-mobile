import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/analytics/saves_events.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/cafe/domain/use_cases/get_cafe_statuses_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/set_cafe_status_usecase.dart';
import 'package:nook/core/cafe/presentation/cafe_status_cubit.dart';
import 'package:nook/features/guest_saves/data/guest_saves_store.dart';
import 'package:nook/features/guest_saves/domain/cafe_snapshot.dart';
import 'package:nook/features/guest_saves/presentation/cubit/guest_saves_cubit.dart';
import 'package:nook/features/guest_saves/presentation/widgets/directions_save_nudge.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/analytics/recording_analytics.dart';

class _NoRepository implements ICafeRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

const _cafe = CafeSnapshot(id: 'c1', name: 'Kape Uno');

/// Stands in for the cafe page: owns the nudge like `_CafeDetailsPageState`.
class _Host extends StatefulWidget {
  const _Host();

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late final DirectionsSaveNudge _nudge;

  @override
  void initState() {
    super.initState();
    _nudge = DirectionsSaveNudge(
      cafeId: _cafe.id,
      host: this,
      cafe: () => _cafe,
      toastOffset: () => 0,
      isSignedIn: () => false,
    );
  }

  @override
  void dispose() {
    _nudge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox());
}

void main() {
  late RecordingAnalytics analytics;
  late GuestSavesCubit saves;
  late CafeStatusCubit statuses;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    analytics = RecordingAnalytics.install(addTearDown);
    DirectionsSaveNudge.resetForTest();
    saves = GuestSavesCubit(store: GuestSavesStore());
    final repository = _NoRepository();
    statuses = CafeStatusCubit(
      getCafeStatusesUseCase: GetCafeStatusesUseCase(repository),
      setCafeStatusUseCase: SetCafeStatusUseCase(repository),
    );
  });

  tearDown(() async {
    await saves.close();
    await statuses.close();
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider.value(value: saves),
        BlocProvider.value(value: statuses),
      ],
      child: const MaterialApp(home: _Host()),
    ),
  );

  /// The toast overlay goes in after a frame and fades in.
  Future<void> showToast(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> settleToasts(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
  }

  testWidgets('a guest back from directions to an unsaved cafe is asked '
      'once, and Save keeps it on the phone', (tester) async {
    await pump(tester);

    DirectionsLaunches.notify(_cafe.id);
    await tester.pump(DirectionsSaveNudge.fallbackDelay);
    await showToast(tester);

    expect(find.text(DirectionsSaveNudge.message), findsOneWidget);
    expect(analytics.propertiesOf(SavesEvents.directionsSaveNudgeShown), {
      'cafe_id': _cafe.id,
    });

    await tester.tap(find.text(DirectionsSaveNudge.actionLabel));
    // Let the on-phone write finish and its toast replace the nudge.
    await showToast(tester);

    expect(analytics.names, contains(SavesEvents.directionsSaveNudgeTapped));
    expect(saves.state.statusFor(_cafe.id), CafeStatus.wantToTry);
    await settleToasts(tester);

    // Asked once per cafe per session.
    analytics.events.clear();
    DirectionsLaunches.notify(_cafe.id);
    await tester.pump(DirectionsSaveNudge.fallbackDelay);
    expect(
      analytics.names,
      isNot(contains(SavesEvents.directionsSaveNudgeShown)),
    );
    await settleToasts(tester);
  });

  testWidgets('maps already in front when the launch is reported: no nudge '
      'in the background, it waits for the return', (tester) async {
    await pump(tester);
    final binding = tester.binding;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

    DirectionsLaunches.notify(_cafe.id);
    await tester.pump(DirectionsSaveNudge.fallbackDelay);
    await tester.pump(const Duration(seconds: 1));
    expect(
      analytics.names,
      isNot(contains(SavesEvents.directionsSaveNudgeShown)),
    );

    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(DirectionsSaveNudge.settleDelay);
    await showToast(tester);
    expect(find.text(DirectionsSaveNudge.message), findsOneWidget);
    await settleToasts(tester);
  });

  testWidgets('a cafe that already has a status is not nudged', (tester) async {
    statuses.showLocal({_cafe.id: CafeStatus.been});
    await pump(tester);

    DirectionsLaunches.notify(_cafe.id);
    await tester.pump(DirectionsSaveNudge.fallbackDelay);
    await showToast(tester);

    expect(find.text(DirectionsSaveNudge.message), findsNothing);
    expect(
      analytics.names,
      isNot(contains(SavesEvents.directionsSaveNudgeShown)),
    );
    await settleToasts(tester);
  });

  testWidgets('directions to another cafe do nothing here', (tester) async {
    await pump(tester);

    DirectionsLaunches.notify('other');
    await tester.pump(DirectionsSaveNudge.fallbackDelay);

    expect(analytics.events, isEmpty);
  });
}
