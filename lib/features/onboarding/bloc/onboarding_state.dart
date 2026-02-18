part of 'onboarding_bloc.dart';

class OnboardingState extends Equatable {
    final int pageIndex;
    final bool isLastPage;

    const OnboardingState({
        this.pageIndex = 0,
        this.isLastPage = false
    });

    OnboardingState copyWith({
        int? pageIndex,
        bool? isLastPage
    }) {
        return OnboardingState(
            pageIndex: pageIndex ?? this.pageIndex,
            isLastPage: isLastPage ?? this.isLastPage
        );
    }

    @override
    List<Object> get props => [pageIndex, isLastPage];
}