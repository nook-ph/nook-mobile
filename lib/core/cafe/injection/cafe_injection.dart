import 'package:get_it/get_it.dart';
import 'package:nook/core/cafe/data/cafe_remote_data_source.dart';
import 'package:nook/core/cafe/data/cafe_repository_impl.dart';
import 'package:nook/core/cafe/data/cafe_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final GetIt getIt = GetIt.instance;

void setupCafeInjection() {
  getIt.registerLazySingleton<CafeStore>(() => CafeStore());

  getIt.registerLazySingleton<CafeRemoteDataSource>(
    () => CafeRemoteDataSource(Supabase.instance.client),
  );

  getIt.registerLazySingleton<CafeRepositoryImpl>(
    () => CafeRepositoryImpl(getIt<CafeRemoteDataSource>(), getIt<CafeStore>()),
  );
}
