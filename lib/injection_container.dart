import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_it/get_it.dart';
import 'package:nook/core/preferences/last_saved_list_store.dart';
import 'package:nook/core/preferences/location_prompt_store.dart';
import 'package:nook/core/preferences/review_draft_store.dart';
import 'package:nook/core/preferences/terms_acceptance_store.dart';
import 'package:nook/core/analytics/analytics_service.dart';
import 'package:nook/core/block/block_cubit.dart';
import 'package:nook/core/block/data/block_remote_data_source.dart';
import 'package:nook/core/block/data/block_repository_impl.dart';
import 'package:nook/core/block/domain/repositories/i_block_repository.dart';
import 'package:nook/core/block/domain/use_cases/block_user_usecase.dart';
import 'package:nook/core/block/domain/use_cases/get_blocked_user_ids_usecase.dart';
import 'package:nook/core/block/domain/use_cases/get_blocked_users_usecase.dart';
import 'package:nook/core/block/domain/use_cases/unblock_user_usecase.dart';
import 'package:nook/core/cafe/data/cafe_remote_data_source.dart';
import 'package:nook/core/cafe/data/cafe_repository_impl.dart';
import 'package:nook/core/cafe/data/cafe_store.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/cafe/domain/use_cases/add_cafe_to_list_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/add_review_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/create_list_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/delete_review_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/report_review_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/get_cafe_details_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/get_cafe_list_memberships_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/get_cafe_reviews_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/get_reviews_written_by_user_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/get_cafes_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/get_user_lists_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/remove_cafe_from_list_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/resolve_quick_save_list_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/set_cafe_status_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/get_cafe_statuses_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/set_cafe_note_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/get_cafe_note_usecase.dart';
import 'package:nook/core/cafe/presentation/cafe_status_cubit.dart';
import 'package:nook/core/services/share_service.dart';
import 'package:nook/core/filters/cubit/filter_cubit.dart';
import 'package:nook/core/upload/data/upload_remove_data_source.dart';
import 'package:nook/core/upload/data/upload_repository_impl.dart';
import 'package:nook/core/upload/domain/use_cases/upload_use_case.dart';
import 'package:nook/features/home_page/domain/use_cases/get_cafe_summaries_usecase.dart';
import 'package:nook/features/profile/bloc/avatar_upload_bloc.dart';
import 'package:nook/features/profile/data/profile_remote_data_source.dart';
import 'package:nook/features/profile/data/profile_repository_impl.dart';
import 'package:nook/features/profile/domain/i_profile_repository.dart';
import 'package:nook/features/profile/use_cases/update_profile_usecase.dart';
import 'package:nook/features/search/bloc/search_bloc.dart';
import 'package:nook/features/search/domain/use_cases/search_cafes_usecase.dart';
import 'package:nook/core/upload/domain/repositories/i_review_image_upload_repository.dart';
import 'package:nook/features/cafe_details/bloc/cafe_details_bloc.dart';
import 'package:nook/features/cafe_details/bloc/review_submit_bloc.dart';
import 'package:nook/features/cafe_details/bloc/reviews_bloc.dart';
import 'package:nook/features/home_page/bloc/home_bloc.dart';
import 'package:nook/features/lists/bloc/lists_bloc.dart';
import 'package:nook/features/lists/presentation/cubit/save_to_list_cubit.dart';
import 'package:nook/features/map/bloc/map_bloc.dart';
import 'package:nook/features/map/data/datasources/cafe_tags_remote_data_source.dart';
import 'package:nook/features/map/data/repositories/cafe_tags_repository_impl.dart';
import 'package:nook/features/map/domain/use_cases/get_cafe_cards_usecase.dart';
import 'package:nook/features/map/domain/use_cases/get_cafes_for_viewport_usecase.dart';
import 'package:nook/features/map/domain/use_cases/get_filter_tags_usecase.dart';
import 'package:nook/features/map/domain/repositories/i_cafe_tags_repository.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // 1) External dependencies
  sl.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);
  sl.registerLazySingleton<AnalyticsService>(() => AnalyticsService());

  sl.registerLazySingleton<LastSavedListStore>(() => LastSavedListStore());
  sl.registerLazySingleton<LocationPromptStore>(() => LocationPromptStore());
  sl.registerLazySingleton<ReviewDraftStore>(() => ReviewDraftStore());
  sl.registerLazySingleton<TermsAcceptanceStore>(() => TermsAcceptanceStore());

  sl.registerLazySingleton<http.Client>(() => http.Client());

  sl.registerLazySingleton<ShareService>(
    () => ShareService(httpClient: sl<http.Client>()),
  );

  // 2) Data sources
  sl.registerLazySingleton<CafeStore>(() => CafeStore());
  sl.registerLazySingleton<CafeRemoteDataSource>(
    () => CafeRemoteDataSource(sl<SupabaseClient>()),
  );

  sl.registerLazySingleton<ProfileRemoteDataSource>(
    () => ProfileRemoteDataSource(supabaseClient: sl<SupabaseClient>()),
  );

  sl.registerLazySingleton<UploadRemoteDataSource>(
    () => UploadRemoteDataSource(
      httpClient: sl<http.Client>(),
      presignUrl: dotenv.env['UPLOAD_PRESIGN_URL'] ?? '',
      authTokenGetter: () =>
          Supabase.instance.client.auth.currentSession?.accessToken,
      authTokenRefresher: () async {
        final refreshed = await Supabase.instance.client.auth.refreshSession();
        return refreshed.session?.accessToken;
      },
    ),
  );

  sl.registerLazySingleton<CafeTagsRemoteDataSource>(
    () => CafeTagsRemoteDataSourceImpl(sl<SupabaseClient>()),
  );

  sl.registerLazySingleton<BlockRemoteDataSource>(
    () => BlockRemoteDataSource(sl<SupabaseClient>()),
  );

  // 3) Repositories
  sl.registerLazySingleton<ICafeRepository>(
    () => CafeRepositoryImpl(sl<CafeRemoteDataSource>(), sl<CafeStore>()),
  );

  sl.registerLazySingleton<IProfileRepository>(
    () => ProfileRepositoryImpl(sl<ProfileRemoteDataSource>()),
  );

  sl.registerLazySingleton<IUploadRepository>(
    () => UploadRepositoryImpl(sl<UploadRemoteDataSource>()),
  );

  sl.registerLazySingleton<ICafeTagsRepository>(
    () => CafeTagsRepositoryImpl(sl<CafeTagsRemoteDataSource>()),
  );

  sl.registerLazySingleton<IBlockRepository>(
    () => BlockRepositoryImpl(sl<BlockRemoteDataSource>()),
  );

  // 4) Use cases
  sl.registerLazySingleton<GetCafeCardUseCase>(
    () => GetCafeCardUseCase(sl<ICafeRepository>()),
  );
  sl.registerLazySingleton<GetCafesForViewportUseCase>(
    () => GetCafesForViewportUseCase(sl<ICafeRepository>()),
  );
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
  sl.registerLazySingleton<GetReviewsWrittenByUserUseCase>(
    () => GetReviewsWrittenByUserUseCase(sl<ICafeRepository>()),
  );
  sl.registerLazySingleton<AddReviewUseCase>(
    () => AddReviewUseCase(sl<ICafeRepository>()),
  );
  sl.registerLazySingleton<DeleteReviewUseCase>(
    () => DeleteReviewUseCase(sl<ICafeRepository>()),
  );
  sl.registerLazySingleton<ReportReviewUseCase>(
    () => ReportReviewUseCase(sl<ICafeRepository>()),
  );

  // Blocking use cases
  sl.registerLazySingleton<BlockUserUseCase>(
    () => BlockUserUseCase(sl<IBlockRepository>()),
  );
  sl.registerLazySingleton<UnblockUserUseCase>(
    () => UnblockUserUseCase(sl<IBlockRepository>()),
  );
  sl.registerLazySingleton<GetBlockedUserIdsUseCase>(
    () => GetBlockedUserIdsUseCase(sl<IBlockRepository>()),
  );
  sl.registerLazySingleton<GetBlockedUsersUseCase>(
    () => GetBlockedUsersUseCase(sl<IBlockRepository>()),
  );

  sl.registerLazySingleton<UploadReviewImagesUseCase>(
    () => UploadReviewImagesUseCase(sl<IUploadRepository>()),
  );
  sl.registerLazySingleton<UploadAvatarUseCase>(
    () => UploadAvatarUseCase(sl<IUploadRepository>()),
  );

  //list usecases

  sl.registerLazySingleton<GetUserListsUseCase>(
    () => GetUserListsUseCase(sl<ICafeRepository>()),
  );
  sl.registerLazySingleton<AddCafeToListUseCase>(
    () => AddCafeToListUseCase(sl<ICafeRepository>()),
  );
  sl.registerLazySingleton<RemoveCafeFromListUseCase>(
    () => RemoveCafeFromListUseCase(sl<ICafeRepository>()),
  );
  sl.registerLazySingleton<CreateListUseCase>(
    () => CreateListUseCase(sl<ICafeRepository>()),
  );
  sl.registerLazySingleton<GetCafeListMembershipsUseCase>(
    () => GetCafeListMembershipsUseCase(sl<ICafeRepository>()),
  );
  sl.registerLazySingleton<ResolveQuickSaveListUseCase>(
    () => ResolveQuickSaveListUseCase(
      repository: sl<ICafeRepository>(),
      lastSavedListStore: sl<LastSavedListStore>(),
      createListUseCase: sl<CreateListUseCase>(),
    ),
  );
  sl.registerLazySingleton<SetCafeStatusUseCase>(
    () => SetCafeStatusUseCase(sl<ICafeRepository>()),
  );
  sl.registerLazySingleton<GetCafeStatusesUseCase>(
    () => GetCafeStatusesUseCase(sl<ICafeRepository>()),
  );
  sl.registerLazySingleton<SetCafeNoteUseCase>(
    () => SetCafeNoteUseCase(sl<ICafeRepository>()),
  );
  sl.registerLazySingleton<GetCafeNoteUseCase>(
    () => GetCafeNoteUseCase(sl<ICafeRepository>()),
  );

  sl.registerLazySingleton<UpdateProfileUseCase>(
    () => UpdateProfileUseCase(sl<IProfileRepository>()),
  );

  // 5) Blocs
  sl.registerFactory<MapBloc>(
    () => MapBloc(
      getCafeCardUseCase: sl<GetCafeCardUseCase>(),
      getFilterTagsUseCase: sl<GetFilterTagsUseCase>(),
      getCafesForViewportUseCase: sl<GetCafesForViewportUseCase>(),
    ),
  );

  sl.registerFactory<AvatarUploadBloc>(
    () => AvatarUploadBloc(
      uploadAvatarUseCase: sl<UploadAvatarUseCase>(),
      updateProfileAvatarUseCase: sl<UpdateProfileUseCase>(),
    ),
  );
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
  sl.registerLazySingleton<ListsBloc>(
    () => ListsBloc(
      getUserListsUseCase: sl<GetUserListsUseCase>(),
      addCafeToListUseCase: sl<AddCafeToListUseCase>(),
      removeCafeFromListUseCase: sl<RemoveCafeFromListUseCase>(),
      createListUseCase: sl<CreateListUseCase>(),
      repository: sl<ICafeRepository>(),
      analytics: sl<AnalyticsService>(),
    ),
  );
  // App-wide Been / Want to Try status cache (singleton like ListsBloc, so a
  // status set on details is instantly visible on any surface).
  sl.registerLazySingleton<CafeStatusCubit>(
    () => CafeStatusCubit(
      getCafeStatusesUseCase: sl<GetCafeStatusesUseCase>(),
      setCafeStatusUseCase: sl<SetCafeStatusUseCase>(),
    ),
  );
  sl.registerFactory<SaveToListCubit>(
    () => SaveToListCubit(
      getUserListsUseCase: sl<GetUserListsUseCase>(),
      getCafeListMembershipsUseCase: sl<GetCafeListMembershipsUseCase>(),
      addCafeToListUseCase: sl<AddCafeToListUseCase>(),
      removeCafeFromListUseCase: sl<RemoveCafeFromListUseCase>(),
      createListUseCase: sl<CreateListUseCase>(),
      lastSavedListStore: sl<LastSavedListStore>(),
      currentUserId: () => sl<SupabaseClient>().auth.currentUser?.id,
    ),
  );

  sl.registerLazySingleton<GetFilterTagsUseCase>(
    () => GetFilterTagsUseCase(sl<ICafeTagsRepository>()),
  );

  // Search
  sl.registerLazySingleton<SearchCafesUseCase>(
    () => SearchCafesUseCase(sl<ICafeRepository>()),
  );

  sl.registerLazySingleton<FilterCubit>(() => FilterCubit());

  // App-wide blocked-users cache (drives instant feed filtering)
  sl.registerLazySingleton<BlockCubit>(
    () => BlockCubit(
      blockUser: sl<BlockUserUseCase>(),
      unblockUser: sl<UnblockUserUseCase>(),
      getBlockedIds: sl<GetBlockedUserIdsUseCase>(),
    ),
  );

  sl.registerFactory<SearchBloc>(
    () => SearchBloc(
      searchCafesUseCase: sl<SearchCafesUseCase>(),
      supabase: sl<SupabaseClient>(),
    ),
  );

  // Future features registration area:
  // map
  // profile
  // search
}
