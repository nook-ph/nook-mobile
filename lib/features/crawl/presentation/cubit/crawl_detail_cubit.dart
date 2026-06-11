import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/features/crawl/domain/failures/crawl_failures.dart';
import 'package:nook/features/crawl/domain/use_cases/get_crawl_detail_usecase.dart';
import 'package:nook/features/crawl/domain/use_cases/register_for_crawl_usecase.dart';
import 'package:nook/features/crawl/presentation/cubit/crawl_detail_state.dart';

class CrawlDetailCubit extends Cubit<CrawlDetailState> {
  final GetCrawlDetailUseCase _getCrawlDetailUseCase;
  final RegisterForCrawlUseCase _registerForCrawlUseCase;

  CrawlDetailCubit({
    required GetCrawlDetailUseCase getCrawlDetailUseCase,
    required RegisterForCrawlUseCase registerForCrawlUseCase,
  })  : _getCrawlDetailUseCase = getCrawlDetailUseCase,
        _registerForCrawlUseCase = registerForCrawlUseCase,
        super(const CrawlDetailInitial());

  Future<void> loadDetail(String slug) async {
    emit(const CrawlDetailLoading());

    final result = await _getCrawlDetailUseCase.call(slug);
    switch (result) {
      case Right(value: final detail):
        emit(CrawlDetailLoaded(detail));
      case Left(value: final failure):
        emit(CrawlDetailError(failure));
    }
  }

  Future<void> refresh() async {
    final current = state;
    if (current case CrawlDetailLoaded(:final detail)) {
      await loadDetail(detail.crawl.slug);
    } else if (current case CrawlDetailRegisterSuccess(:final detail)) {
      await loadDetail(detail.crawl.slug);
    }
  }

  Future<void> register() async {
    final current = state;
    if (current case CrawlDetailLoaded(:final detail)) {
      final result = await _registerForCrawlUseCase.call(detail.crawl.id);
      switch (result) {
        case Right():
          emit(const CrawlDetailLoading());
          final fresh = await _getCrawlDetailUseCase.call(detail.crawl.slug);
          switch (fresh) {
            case Right(value: final d):
              emit(CrawlDetailRegisterSuccess(d));
            case Left(value: final f):
              emit(CrawlDetailError(f));
          }
        case Left(value: final failure) when failure is AlreadyRegisteredFailure:
          await loadDetail(detail.crawl.slug);
        case Left(value: final failure):
          emit(CrawlDetailError(failure));
      }
    }
  }
}
