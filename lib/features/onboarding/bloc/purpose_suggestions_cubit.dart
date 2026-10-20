import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/preferences/onboarding_purpose_store.dart';

/// Fetches the cafes suggested for a purpose.
typedef PurposeSuggestionsLoader =
    Future<List<CafeSummary>> Function(OnboardingPurpose purpose);

enum PurposeSuggestionsStatus { idle, loading, loaded, failed }

class PurposeSuggestionsState extends Equatable {
  const PurposeSuggestionsState({
    this.status = PurposeSuggestionsStatus.idle,
    this.purpose,
    this.cafes = const [],
  });

  final PurposeSuggestionsStatus status;
  final OnboardingPurpose? purpose;
  final List<CafeSummary> cafes;

  @override
  List<Object?> get props => [status, purpose, cafes];
}

/// The suggestions step. A fetch that fails, comes back empty or takes
/// longer than [timeout] ends in [PurposeSuggestionsStatus.failed], and the
/// page goes on to Home: a new user is never left on a spinner.
class PurposeSuggestionsCubit extends Cubit<PurposeSuggestionsState> {
  PurposeSuggestionsCubit(
    this._load, {
    this.timeout = const Duration(seconds: 6),
  }) : super(const PurposeSuggestionsState());

  final PurposeSuggestionsLoader _load;
  final Duration timeout;

  Future<void> load(OnboardingPurpose purpose) async {
    emit(
      PurposeSuggestionsState(
        status: PurposeSuggestionsStatus.loading,
        purpose: purpose,
      ),
    );
    List<CafeSummary> cafes;
    try {
      cafes = await _load(purpose).timeout(timeout);
    } catch (_) {
      cafes = const [];
    }
    if (isClosed) return;
    emit(
      PurposeSuggestionsState(
        status: cafes.isEmpty
            ? PurposeSuggestionsStatus.failed
            : PurposeSuggestionsStatus.loaded,
        purpose: purpose,
        cafes: cafes,
      ),
    );
  }
}
