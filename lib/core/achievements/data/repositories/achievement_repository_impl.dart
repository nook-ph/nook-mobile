import 'package:dartz/dartz.dart';
import 'package:nook/core/achievements/data/sources/achievement_remote_data_source.dart';
import 'package:nook/core/achievements/domain/entities/user_achievement.dart';
import 'package:nook/core/achievements/domain/repositories/i_achievement_repository.dart';
import 'package:nook/core/errors/failure.dart';

class AchievementRepositoryImpl implements IAchievementRepository {
  final IAchievementRemoteDataSource remoteDataSource;

  AchievementRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, List<UserAchievement>>> getUserAchievements(
    String userId,
  ) async {
    try {
      final models = await remoteDataSource.getUserAchievements(userId);
      return Right(models);
    } catch (e, st) {
      return Left(_mapToFailure(e, st));
    }
  }

  Failure _mapToFailure(Object e, StackTrace st) {
    if (e is Failure) return e;
    return Failure(e.toString());
  }
}
