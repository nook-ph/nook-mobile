import 'package:nook/core/services/gps_service.dart';
import 'package:nook/features/crawl/domain/use_cases/claim_stamp_usecase.dart';
import 'package:nook/features/crawl/domain/use_cases/get_active_crawls_usecase.dart';
import 'package:nook/features/crawl/domain/use_cases/get_crawl_detail_usecase.dart';
import 'package:nook/features/crawl/domain/use_cases/register_for_crawl_usecase.dart';
import 'package:nook/features/crawl/presentation/bloc/crawl_claim_bloc.dart';
import 'package:nook/features/crawl/presentation/cubit/active_crawls_cubit.dart';
import 'package:nook/features/crawl/presentation/cubit/crawl_detail_cubit.dart';
import 'package:nook/injection_container.dart';

void registerCrawlPresentation() {
  // Services
  sl.registerLazySingleton<GpsService>(() => GpsServiceImpl());

  // Cubits
  sl.registerFactory<ActiveCrawlsCubit>(
    () => ActiveCrawlsCubit(
      getActiveCrawlsUseCase: sl<GetActiveCrawlsUseCase>(),
      supabase: sl(),
    ),
  );

  sl.registerFactory<CrawlDetailCubit>(
    () => CrawlDetailCubit(
      getCrawlDetailUseCase: sl<GetCrawlDetailUseCase>(),
      registerForCrawlUseCase: sl<RegisterForCrawlUseCase>(),
    ),
  );

  // Blocs
  sl.registerFactory<CrawlClaimBloc>(
    () => CrawlClaimBloc(
      claimStampUseCase: sl<ClaimStampUseCase>(),
      gpsService: sl<GpsService>(),
    ),
  );
}
