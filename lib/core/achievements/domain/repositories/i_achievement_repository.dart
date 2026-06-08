import 'package:dartz/dartz.dart';
import 'package:nook/core/achievements/domain/entities/user_achievement.dart';
import 'package:nook/core/errors/failure.dart';

abstract class IAchievementRepository {
  Future<Either<Failure, List<UserAchievement>>> getUserAchievements(
    String userId,
  );
}
