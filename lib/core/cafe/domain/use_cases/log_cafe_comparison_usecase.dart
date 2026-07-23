import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';

class LogCafeComparisonUseCase {
  final ICafeRepository repository;

  const LogCafeComparisonUseCase(this.repository);

  /// Best-effort: never throws, never blocks the ranking flow.
  Future<void> call({
    required String winnerCafeId,
    required String loserCafeId,
  }) {
    return repository.logCafeComparison(
      winnerCafeId: winnerCafeId,
      loserCafeId: loserCafeId,
    );
  }
}
