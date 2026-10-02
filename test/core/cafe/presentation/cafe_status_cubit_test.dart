import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/cafe/domain/use_cases/get_cafe_statuses_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/set_cafe_status_usecase.dart';
import 'package:nook/core/cafe/presentation/cafe_status_cubit.dart';

class _StatusRepository implements ICafeRepository {
  Map<String, CafeStatus> server = {};
  bool failRead = false;
  bool failWrite = false;

  @override
  Future<Map<String, CafeStatus>> getCafeStatuses(List<String> cafeIds) async {
    if (failRead) throw Exception('offline');
    return {
      for (final id in cafeIds)
        if (server[id] != null) id: server[id]!,
    };
  }

  @override
  Future<CafeStatus> setCafeStatus(String cafeId, CafeStatus status) async {
    if (failWrite) throw Exception('offline');
    return server[cafeId] = status;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  late _StatusRepository repo;
  late CafeStatusCubit cubit;

  setUp(() {
    repo = _StatusRepository();
    cubit = CafeStatusCubit(
      getCafeStatusesUseCase: GetCafeStatusesUseCase(repo),
      setCafeStatusUseCase: SetCafeStatusUseCase(repo),
    );
  });

  tearDown(() => cubit.close());

  test('a failed read leaves the status unknown, not "none"', () async {
    repo.server = {'a': CafeStatus.been};
    repo.failRead = true;

    await cubit.loadFor(['a']);

    // statusFor still defaults to none; isKnown is what tells them apart.
    expect(cubit.state.statusFor('a'), CafeStatus.none);
    expect(cubit.state.isKnown('a'), isFalse);
  });

  test('a successful read makes every asked-for cafe known', () async {
    repo.server = {'a': CafeStatus.been};

    await cubit.loadFor(['a', 'b']);

    expect(cubit.state.statusFor('a'), CafeStatus.been);
    expect(cubit.state.isKnown('a'), isTrue);
    // Absent from the response is a real "none".
    expect(cubit.state.statusFor('b'), CafeStatus.none);
    expect(cubit.state.isKnown('b'), isTrue);
    expect(cubit.state.isKnown('c'), isFalse);
  });

  test(
    'a successful write makes the cafe known; a failed one does not',
    () async {
      repo.failWrite = true;
      expect(await cubit.set('a', CafeStatus.wantToTry), isFalse);
      expect(cubit.state.isKnown('a'), isFalse);
      expect(cubit.state.statusFor('a'), CafeStatus.none);

      repo.failWrite = false;
      expect(await cubit.set('a', CafeStatus.wantToTry), isTrue);
      expect(cubit.state.isKnown('a'), isTrue);
      expect(cubit.state.isPending('a'), isFalse);
    },
  );

  test('reset forgets what was known', () async {
    await cubit.loadFor(['a']);
    cubit.reset();
    expect(cubit.state.isKnown('a'), isFalse);
  });
}
