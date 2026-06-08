import 'package:dartz/dartz.dart';
import 'package:nook/core/achievements/domain/entities/user_achievement.dart';
import 'package:nook/core/achievements/domain/repositories/i_achievement_repository.dart';
import 'package:nook/core/errors/failure.dart';

class GetUserAchievementsUseCase {
  final IAchievementRepository repository;

  GetUserAchievementsUseCase(this.repository);

  Future<Either<Failure, List<UserAchievement>>> call(String userId) {
    return repository.getUserAchievements(userId);
  }
}
