import 'package:nook/features/auth/domain/repository/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GetCurrentSessionUseCase {
  final AuthRepository _repository;

  GetCurrentSessionUseCase(this._repository);

  Session? call() {
    return _repository.getCurrentSession();
  }
}
