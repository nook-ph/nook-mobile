import 'package:get_it/get_it.dart';
import 'package:nook/core/cafe/data/cafe_remote_data_source.dart';
import 'package:nook/core/cafe/data/cafe_repository_impl.dart';
import 'package:nook/core/cafe/data/cafe_store.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/cafe/domain/usecases/add_favorite_cafe_usecase.dart';
import 'package:nook/core/cafe/domain/usecases/get_cafe_details_usecase.dart';
import 'package:nook/core/cafe/domain/usecases/get_favorite_cafes_usecase.dart';
import 'package:nook/core/cafe/domain/usecases/get_cafe_summaries_usecase.dart';
import 'package:nook/core/cafe/domain/usecases/remove_favorite_cafe_usecase.dart';
import 'package:nook/features/cafe_details/bloc/cafe_details_bloc.dart';
import 'package:nook/features/favorites/bloc/favorites_bloc.dart';
import 'package:nook/features/home_page/bloc/home_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // 1) External dependencies
  sl.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);

  // 2) Data sources
  sl.registerLazySingleton<CafeStore>(() => CafeStore());
  sl.registerLazySingleton<CafeRemoteDataSource>(
    () => CafeRemoteDataSource(sl<SupabaseClient>()),
  );

  // 3) Repositories
  sl.registerLazySingleton<ICafeRepository>(
    () => CafeRepositoryImpl(sl<CafeRemoteDataSource>(), sl<CafeStore>()),
  );

  // 4) Use cases
  sl.registerLazySingleton<GetCafeSummariesUseCase>(
    () => GetCafeSummariesUseCase(sl<ICafeRepository>()),
  );
  sl.registerLazySingleton<GetCafeDetailsUseCase>(
    () => GetCafeDetailsUseCase(sl<ICafeRepository>()),
  );
  sl.registerLazySingleton<GetFavoriteCafesUseCase>(
    () => GetFavoriteCafesUseCase(sl<ICafeRepository>()),
  );
  sl.registerLazySingleton<AddFavoriteCafeUseCase>(
    () => AddFavoriteCafeUseCase(sl<ICafeRepository>()),
  );
  sl.registerLazySingleton<RemoveFavoriteCafeUseCase>(
    () => RemoveFavoriteCafeUseCase(sl<ICafeRepository>()),
  );

  // 5) Blocs
  sl.registerFactory<HomeBloc>(
    () => HomeBloc(getCafeSummariesUseCase: sl<GetCafeSummariesUseCase>()),
  );
  sl.registerFactory<CafeDetailsBloc>(
    () => CafeDetailsBloc(getCafeDetailsUseCase: sl<GetCafeDetailsUseCase>()),
  );
  sl.registerLazySingleton<FavoritesBloc>(
    () => FavoritesBloc(
      getFavoriteCafesUseCase: sl<GetFavoriteCafesUseCase>(),
      addFavoriteCafeUseCase: sl<AddFavoriteCafeUseCase>(),
      removeFavoriteCafeUseCase: sl<RemoveFavoriteCafeUseCase>(),
    ),
  );

  // Future features registration area:
  // favorites
  // map
  // profile
  // search
}
