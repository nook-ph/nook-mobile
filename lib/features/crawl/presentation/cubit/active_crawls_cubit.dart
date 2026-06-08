import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/features/crawl/domain/entities/crawl.dart';
import 'package:nook/features/crawl/domain/use_cases/get_active_crawls_usecase.dart';
import 'package:nook/features/crawl/presentation/cubit/active_crawls_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ActiveCrawlsCubit extends Cubit<ActiveCrawlsState> {
  final GetActiveCrawlsUseCase _getActiveCrawlsUseCase;
  final SupabaseClient _supabase;

  ActiveCrawlsCubit({
    required GetActiveCrawlsUseCase getActiveCrawlsUseCase,
    required SupabaseClient supabase,
  })  : _getActiveCrawlsUseCase = getActiveCrawlsUseCase,
        _supabase = supabase,
        super(const ActiveCrawlsLoading());

  Future<void> loadCrawls() async {
    emit(const ActiveCrawlsLoading());

    final result = await _getActiveCrawlsUseCase.call();
    switch (result) {
      case Right(value: final crawls) when crawls.isEmpty:
        emit(const ActiveCrawlsEmpty());
      case Right(value: final crawls):
        emit(ActiveCrawlsLoaded(crawls, _computeRegistered(crawls)));
      case Left(value: final failure):
        emit(ActiveCrawlsError(failure));
    }
  }

  Set<String> _computeRegistered(List<Crawl> crawls) {
    final userId = _supabase.auth.currentUser?.id;
    return const {};
  }
}
