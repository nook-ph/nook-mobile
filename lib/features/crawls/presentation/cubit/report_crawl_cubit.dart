import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/features/crawls/domain/use_cases/report_crawl_usecase.dart';

class ReportCrawlState extends Equatable {
  final String? reason;
  final bool submitting;
  final bool sent;
  final Object? error;

  const ReportCrawlState({
    this.reason,
    this.submitting = false,
    this.sent = false,
    this.error,
  });

  bool get canSubmit => reason != null && !submitting;

  @override
  List<Object?> get props => [reason, submitting, sent, error];
}

class ReportCrawlCubit extends Cubit<ReportCrawlState> {
  ReportCrawlCubit({required this.reportCrawlUseCase})
    : super(const ReportCrawlState());

  final ReportCrawlUseCase reportCrawlUseCase;

  /// Sent as the report's reason; each fits the server's 50-character cap.
  static const reasons = [
    'Offensive or hateful title',
    'Spam or advertising',
    'Unsafe or misleading route',
    'Something else',
  ];

  /// Crawls reported since the app started. The report RPC returns nothing
  /// and silently ignores a repeat, so the server never says "already
  /// reported"; this is the only way the UI can. It does not survive a
  /// restart, after which a repeat is accepted and dropped server-side.
  static final Set<String> _reportedThisSession = {};

  static bool alreadyReported(String crawlId) =>
      _reportedThisSession.contains(crawlId);

  @visibleForTesting
  static void resetSession() => _reportedThisSession.clear();

  void choose(String reason) => emit(ReportCrawlState(reason: reason));

  Future<void> submit(String crawlId, {String? details}) async {
    final reason = state.reason;
    if (reason == null || state.submitting) return;
    emit(ReportCrawlState(reason: reason, submitting: true));
    try {
      await reportCrawlUseCase(
        crawlId: crawlId,
        reason: reason,
        details: details,
      );
      _reportedThisSession.add(crawlId);
      emit(ReportCrawlState(reason: reason, sent: true));
    } catch (e, st) {
      debugPrint('[ReportCrawl] submit failed: $e\n$st');
      emit(ReportCrawlState(reason: reason, error: e));
    }
  }
}
