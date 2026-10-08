import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/analytics/analytics_service.dart';
import 'package:nook/core/utils/content_filter.dart';
import 'package:nook/features/crawls/domain/entities/crawl.dart';
import 'package:nook/features/crawls/domain/entities/crawl_exception.dart';
import 'package:nook/features/crawls/domain/use_cases/create_crawl_usecase.dart';

enum CrawlBuilderStatus { editing, submitting, created, failed }

/// Why a title cannot be used. Shown on the field, not as a toast.
enum CrawlTitleProblem { length, rejected }

class CrawlBuilderState extends Equatable {
  /// Cafe ids in stop order.
  final List<String> selectedIds;
  final CrawlBuilderStatus status;
  final Crawl? created;
  final Object? error;

  const CrawlBuilderState({
    this.selectedIds = const [],
    this.status = CrawlBuilderStatus.editing,
    this.created,
    this.error,
  });

  bool get isFull => selectedIds.length >= CreateCrawlUseCase.maxStops;

  bool get hasEnoughStops => selectedIds.length >= CreateCrawlUseCase.minStops;

  /// The server refused the title itself, so the message belongs on the
  /// field. Every other failure is about the crawl as a whole.
  bool get titleRefused {
    final e = error;
    return status == CrawlBuilderStatus.failed &&
        e is CrawlInvalid &&
        e.code.startsWith('crawl_title');
  }

  /// 1-based stop number for [cafeId], or null when it is not picked.
  int? orderOf(String cafeId) {
    final index = selectedIds.indexOf(cafeId);
    return index < 0 ? null : index + 1;
  }

  CrawlBuilderState copyWith({
    List<String>? selectedIds,
    CrawlBuilderStatus? status,
    Crawl? created,
    Object? error,
  }) {
    return CrawlBuilderState(
      selectedIds: selectedIds ?? this.selectedIds,
      status: status ?? this.status,
      created: created ?? this.created,
      error: error,
    );
  }

  @override
  List<Object?> get props => [selectedIds, status, created, error];
}

/// Picking and ordering 3–6 stops from a list, then creating the crawl.
class CrawlBuilderCubit extends Cubit<CrawlBuilderState> {
  CrawlBuilderCubit({
    required this.createCrawlUseCase,
    required this.analytics,
    List<String> initialCafeIds = const [],
  }) : super(
         CrawlBuilderState(
           // Start with the list's first few cafes picked: most lists become
           // a crawl as they are, and unpicking is one tap.
           selectedIds: initialCafeIds
               .take(CreateCrawlUseCase.maxStops)
               .toList(),
         ),
       );

  final CreateCrawlUseCase createCrawlUseCase;
  final AnalyticsService analytics;

  /// Checks a title before it is sent. Null means it can be submitted.
  static CrawlTitleProblem? checkTitle(String title) {
    final trimmed = title.trim();
    if (trimmed.length < CreateCrawlUseCase.minTitleLength ||
        trimmed.length > CreateCrawlUseCase.maxTitleLength) {
      return CrawlTitleProblem.length;
    }
    if (ContentFilter.containsObjectionable(trimmed)) {
      return CrawlTitleProblem.rejected;
    }
    return null;
  }

  /// Clears a failed attempt once the user edits something, keeping the
  /// stops they picked.
  void dismissFailure() {
    if (state.status != CrawlBuilderStatus.failed) return;
    emit(state.copyWith(status: CrawlBuilderStatus.editing));
  }

  /// Adds [cafeId] as the next stop, or removes it. Returns false when the
  /// crawl is already full and nothing changed.
  bool toggle(String cafeId) {
    if (_locked) return false;
    final ids = List<String>.from(state.selectedIds);
    if (ids.contains(cafeId)) {
      ids.remove(cafeId);
    } else {
      if (state.isFull) return false;
      ids.add(cafeId);
    }
    emit(state.copyWith(selectedIds: ids, status: CrawlBuilderStatus.editing));
    return true;
  }

  /// Moves the stop at [index] one place up ([delta] -1) or down (+1): the
  /// way to reorder without dragging (WCAG 2.2, 2.5.7).
  void move(int index, int delta) {
    if (_locked) return;
    final ids = List<String>.from(state.selectedIds);
    final target = index + delta;
    if (index < 0 ||
        index >= ids.length ||
        target < 0 ||
        target >= ids.length) {
      return;
    }
    ids.insert(target, ids.removeAt(index));
    emit(state.copyWith(selectedIds: ids, status: CrawlBuilderStatus.editing));
  }

  /// Replaces the order with [ids] (the same stops), e.g. the shortest route.
  void setOrder(List<String> ids) {
    if (_locked) return;
    if (ids.length != state.selectedIds.length ||
        !ids.every(state.selectedIds.contains)) {
      return;
    }
    emit(state.copyWith(selectedIds: ids, status: CrawlBuilderStatus.editing));
  }

  /// `ReorderableListView` semantics: [newIndex] is the slot before removal.
  void reorder(int oldIndex, int newIndex) {
    // A drag during Create would put the state back to editing, re-enable
    // the button and let a second, identical crawl be created.
    if (_locked) return;
    final ids = List<String>.from(state.selectedIds);
    if (oldIndex < 0 || oldIndex >= ids.length) return;
    var target = newIndex > oldIndex ? newIndex - 1 : newIndex;
    target = target.clamp(0, ids.length - 1);
    ids.insert(target, ids.removeAt(oldIndex));
    emit(state.copyWith(selectedIds: ids, status: CrawlBuilderStatus.editing));
  }

  /// The stops are fixed while the crawl is being created, and once it is.
  bool get _locked =>
      state.status == CrawlBuilderStatus.submitting ||
      state.status == CrawlBuilderStatus.created;

  Future<void> submit({required String title, String? sourceListId}) async {
    if (_locked) return;
    emit(state.copyWith(status: CrawlBuilderStatus.submitting));
    try {
      final crawl = await createCrawlUseCase(
        title: title,
        cafeIds: state.selectedIds,
        sourceListId: sourceListId,
      );
      analytics.logEvent(
        'crawl_created',
        properties: {
          'stop_count': crawl.stops.length,
          'source': sourceListId == null ? 'scratch' : 'list',
        },
      );
      if (isClosed) return;
      emit(state.copyWith(status: CrawlBuilderStatus.created, created: crawl));
    } catch (e, st) {
      debugPrint('[CrawlBuilder] submit failed: $e\n$st');
      if (isClosed) return;
      emit(state.copyWith(status: CrawlBuilderStatus.failed, error: e));
    }
  }
}
