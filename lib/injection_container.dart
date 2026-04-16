import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_it/get_it.dart';
import 'package:nook/core/cafe/data/cafe_remote_data_source.dart';
import 'package:nook/core/cafe/data/cafe_repository_impl.dart';
import 'package:nook/core/cafe/data/cafe_store.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/cafe/domain/usecases/add_review_usecase.dart';
import 'package:nook/core/cafe/domain/usecases/add_favorite_cafe_usecase.dart';
import 'package:nook/core/cafe/domain/usecases/get_cafe_details_usecase.dart';
import 'package:nook/core/cafe/domain/usecases/get_cafe_reviews_usecase.dart';
import 'package:nook/core/cafe/domain/usecases/get_favorite_cafes_usecase.dart';
import 'package:nook/core/cafe/domain/usecases/get_cafes_usecase.dart';
import 'package:nook/core/cafe/domain/usecases/get_cafe_summaries_usecase.dart';
import 'package:nook/core/cafe/domain/usecases/remove_favorite_cafe_usecase.dart';
import 'package:nook/core/upload/data/review_image_upload_remote_data_source.dart';
import 'package:nook/core/upload/data/review_image_upload_repository_impl.dart';
import 'package:nook/core/upload/domain/repositories/i_review_image_upload_repository.dart';
import 'package:nook/core/upload/domain/usecases/upload_review_images_usecase.dart';
import 'package:nook/features/cafe_details/bloc/cafe_details_bloc.dart';
import 'package:nook/features/cafe_details/bloc/review_submit_bloc.dart';
import 'package:nook/features/cafe_details/bloc/reviews_bloc.dart';
import 'package:nook/features/favorites/bloc/favorites_bloc.dart';
import 'package:nook/features/home_page/bloc/home_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // 1) External dependencies
  sl.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);
  sl.registerLazySingleton<http.Client>(() => http.Client());

  // 2) Data sources
  sl.registerLazySingleton<CafeStore>(() => CafeStore());
  sl.registerLazySingleton<CafeRemoteDataSource>(
    () => CafeRemoteDataSource(sl<SupabaseClient>()),
  );
  sl.registerLazySingleton<ReviewImageUploadRemoteDataSource>(
    () => ReviewImageUploadRemoteDataSource(
      httpClient: sl<http.Client>(),
      apiBaseUrl: dotenv.env['UPLOAD_API_BASE_URL'] ?? '',
      presignPath:
          dotenv.env['UPLOAD_REVIEW_IMAGES_PRESIGN_PATH'] ??
          '/uploads/review-images/presign',
      authTokenGetter: () =>
          Supabase.instance.client.auth.currentSession?.accessToken,
      authTokenRefresher: () async {
        final refreshed = await Supabase.instance.client.auth.refreshSession();
        return refreshed.session?.accessToken;
      },
    ),
  );

  // 3) Repositories
  sl.registerLazySingleton<ICafeRepository>(
    () => CafeRepositoryImpl(sl<CafeRemoteDataSource>(), sl<CafeStore>()),
  );
  sl.registerLazySingleton<IReviewImageUploadRepository>(
    () => ReviewImageUploadRepositoryImpl(
      sl<ReviewImageUploadRemoteDataSource>(),
    ),
  );

  // 4) Use cases
  sl.registerLazySingleton<GetHomeFeedUseCase>(
    () => GetHomeFeedUseCase(sl<ICafeRepository>()),
  );
  sl.registerLazySingleton<GetCafesUseCase>(
    () => GetCafesUseCase(sl<ICafeRepository>()),
  );
  sl.registerLazySingleton<GetCafeDetailsUseCase>(
    () => GetCafeDetailsUseCase(sl<ICafeRepository>()),
  );
  sl.registerLazySingleton<GetCafeReviewsUseCase>(
    () => GetCafeReviewsUseCase(sl<ICafeRepository>()),
  );
  sl.registerLazySingleton<AddReviewUseCase>(
    () => AddReviewUseCase(sl<ICafeRepository>()),
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
  sl.registerLazySingleton<UploadReviewImagesUseCase>(
    () => UploadReviewImagesUseCase(sl<IReviewImageUploadRepository>()),
  );

  // 5) Blocs
  sl.registerFactory<HomeBloc>(
    () => HomeBloc(getHomeFeedUseCase: sl<GetHomeFeedUseCase>()),
  );
  sl.registerFactory<CafeDetailsBloc>(
    () => CafeDetailsBloc(getCafeDetailsUseCase: sl<GetCafeDetailsUseCase>()),
  );
  sl.registerFactory<ReviewsBloc>(
    () => ReviewsBloc(getCafeReviewsUseCase: sl<GetCafeReviewsUseCase>()),
  );
  sl.registerFactory<ReviewSubmitBloc>(
    () => ReviewSubmitBloc(
      addReviewUseCase: sl<AddReviewUseCase>(),
      uploadReviewImagesUseCase: sl<UploadReviewImagesUseCase>(),
    ),
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
