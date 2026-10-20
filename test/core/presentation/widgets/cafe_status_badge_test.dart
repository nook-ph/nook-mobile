import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/cafe/domain/use_cases/get_cafe_statuses_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/set_cafe_status_usecase.dart';
import 'package:nook/core/cafe/presentation/cafe_status_cubit.dart';
import 'package:nook/core/presentation/widgets/cafe_status_badge.dart';

class _NoRepository implements ICafeRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// Two badges in a row whose order the test controls, unkeyed, the way a
/// rail that puts the newest save first reuses its elements.
class _Row extends StatelessWidget {
  const _Row(this.ids);

  final List<String> ids;

  @override
  Widget build(BuildContext context) =>
      Row(children: [for (final id in ids) CafeStatusBadge(cafeId: id)]);
}

void main() {
  late CafeStatusCubit statuses;

  setUp(() {
    final repository = _NoRepository();
    statuses = CafeStatusCubit(
      getCafeStatusesUseCase: GetCafeStatusesUseCase(repository),
      setCafeStatusUseCase: SetCafeStatusUseCase(repository),
    );
  });

  tearDown(() => statuses.close());

  Widget app(List<String> ids) => MaterialApp(
    home: BlocProvider.value(
      value: statuses,
      child: Scaffold(body: _Row(ids)),
    ),
  );

  testWidgets('a reused badge shows the status of its new cafe (review #1)', (
    tester,
  ) async {
    // Brew Szn saved; Flavour not yet.
    statuses.showLocal({'brew': CafeStatus.wantToTry});
    await tester.pumpWidget(app(['brew']));
    expect(find.text('Want to try'), findsOneWidget);

    // Flavour is saved and moves to the front: slot 0 now belongs to it.
    statuses.showLocal({
      'brew': CafeStatus.wantToTry,
      'flavour': CafeStatus.wantToTry,
    });
    await tester.pumpWidget(app(['flavour', 'brew']));
    await tester.pump();

    expect(find.text('Want to try'), findsNWidgets(2));
  });

  testWidgets('a reused badge clears when its new cafe has no status', (
    tester,
  ) async {
    statuses.showLocal({'brew': CafeStatus.been});
    await tester.pumpWidget(app(['brew']));
    expect(find.text('Been'), findsOneWidget);

    await tester.pumpWidget(app(['other']));
    await tester.pump();
    expect(find.text('Been'), findsNothing);
  });
}
