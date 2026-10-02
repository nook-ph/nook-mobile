import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/utils/content_filter.dart';
import 'package:nook/features/crawls/domain/entities/crawl.dart';
import 'package:nook/features/crawls/domain/entities/crawl_exception.dart';
import 'package:nook/features/crawls/domain/use_cases/create_crawl_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/update_crawl_title_usecase.dart';

/// Why a title was not saved, when the field can say so itself.
enum EditTitleProblem { length, rejected }

class EditCrawlTitleState extends Equatable {
  final bool saving;

  /// Set once the server has accepted the new title.
  final Crawl? saved;
  final EditTitleProblem? problem;

  /// A failure the field has no copy for (offline, session expired).
  final Object? error;

  const EditCrawlTitleState({
    this.saving = false,
    this.saved,
    this.problem,
    this.error,
  });

  @override
  List<Object?> get props => [saving, saved, problem, error];
}

class EditCrawlTitleCubit extends Cubit<EditCrawlTitleState> {
  EditCrawlTitleCubit({required this.updateCrawlTitleUseCase})
    : super(const EditCrawlTitleState());

  final UpdateCrawlTitleUseCase updateCrawlTitleUseCase;

  static bool isValidLength(String title) {
    final length = title.trim().length;
    return length >= CreateCrawlUseCase.minTitleLength &&
        length <= CreateCrawlUseCase.maxTitleLength;
  }

  /// Checks a title before it is sent, with the same rules the builder
  /// applies: 3–60 characters, then the content filter. Null means it can
  /// go to the server.
  static EditTitleProblem? check(String title) {
    final trimmed = title.trim();
    if (!isValidLength(trimmed)) return EditTitleProblem.length;
    if (ContentFilter.containsObjectionable(trimmed)) {
      return EditTitleProblem.rejected;
    }
    return null;
  }

  /// Whether Save is on: the title has changed and is 3–60 characters. A
  /// title the filter will refuse still enables Save, so the tap can say
  /// why on the field.
  static bool canSave({required String original, required String current}) {
    final trimmed = current.trim();
    return trimmed != original.trim() && isValidLength(trimmed);
  }

  /// True once the field holds the most it will take.
  static bool atLimit(String title) =>
      title.characters.length >= CreateCrawlUseCase.maxTitleLength;

  /// Typing again clears the last complaint.
  void edited() {
    if (state.problem != null || state.error != null) {
      emit(const EditCrawlTitleState());
    }
  }

  Future<void> save(String crawlId, String title) async {
    if (state.saving) return;
    final problem = check(title);
    if (problem != null) {
      emit(EditCrawlTitleState(problem: problem));
      return;
    }
    emit(const EditCrawlTitleState(saving: true));
    try {
      final crawl = await updateCrawlTitleUseCase(crawlId, title);
      emit(EditCrawlTitleState(saved: crawl));
    } on CrawlInvalid catch (e) {
      // `crawl_title_length` is the only token the update RPC raises for a
      // title today; any other rejection reads as "pick a different one".
      emit(
        EditCrawlTitleState(
          problem: e.code == 'crawl_title_length'
              ? EditTitleProblem.length
              : EditTitleProblem.rejected,
        ),
      );
    } catch (e, st) {
      debugPrint('[EditCrawlTitle] save failed: $e\n$st');
      emit(EditCrawlTitleState(error: e));
    }
  }
}
