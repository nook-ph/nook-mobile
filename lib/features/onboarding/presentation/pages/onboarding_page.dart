import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/analytics/onboarding_events.dart';
import 'package:nook/core/analytics/screen_tracking.dart';
import 'package:nook/core/app_bloc.dart';
import 'package:nook/core/app_event.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/preferences/home_location_prompt_store.dart';
import 'package:nook/core/preferences/onboarding_purpose_store.dart';
import 'package:nook/features/auth/presentation/widgets/auth_ui.dart';
import 'package:nook/features/onboarding/bloc/purpose_suggestions_cubit.dart';
import 'package:nook/features/onboarding/domain/get_purpose_suggestions_usecase.dart';
import 'package:nook/features/onboarding/presentation/widgets/purpose_step.dart';
import 'package:nook/features/onboarding/presentation/widgets/purpose_suggestions_step.dart';
import 'package:nook/injection_container.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../bloc/onboarding_bloc.dart';
import '../../data/onboarding_data.dart';
import '../widgets/onboarding_image.dart';

/// First launch (Figma A1–A3): illustration, page dots, left-aligned copy,
/// Skip on the slides and Next/Continue pinned to the bottom. Then one
/// question ("What are you looking for?") and three cafes that answer it, so
/// a new user reaches a cafe page in a few taps.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    this.onFinish,
    this.loadSuggestions,
    this.purposeStore,
    this.onOpenCafe,
  });

  /// Called when onboarding is over (skipped from the purpose step, "Show me
  /// everything", a suggestion opened, or no suggestions to show). Defaults
  /// to telling [AppBloc] onboarding is done.
  final VoidCallback? onFinish;

  /// Fetches the cafes for a purpose. Defaults to the registered
  /// [GetPurposeSuggestionsUseCase]; with neither, picking a purpose goes
  /// straight to Home.
  final PurposeSuggestionsLoader? loadSuggestions;

  /// Where the picked purpose is kept. Defaults to the registered one.
  final OnboardingPurposeStore? purposeStore;

  /// Opens a suggested cafe. Defaults to pushing `/cafe/:id`.
  final ValueChanged<String>? onOpenCafe;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

enum _Step { slides, purpose, suggestions }

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  _Step _step = _Step.slides;
  PurposeSuggestionsCubit? _suggestions;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    ScreenTracker.instance.showRoot(ScreenNames.onboarding);
    _logStep(0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _suggestions?.close();
    super.dispose();
  }

  void _logStep(int index) {
    logAppEvent(OnboardingEvents.slideViewed, properties: {'index': index});
  }

  void _finish() {
    if (_done) return;
    _done = true;
    final onFinish = widget.onFinish;
    if (onFinish != null) {
      onFinish();
    } else {
      context.read<AppBloc>().add(OnboardingCompleted());
    }
  }

  /// Ends onboarding after a purpose was picked.
  void _complete(OnboardingPurpose purpose, String exit) {
    if (_done) return;
    logAppEvent(
      OnboardingEvents.completed,
      properties: {'purpose': purpose.key, 'exit': exit},
    );
    _finish();
  }

  void _showPurpose() {
    if (_step != _Step.slides) return;
    setState(() => _step = _Step.purpose);
    _logStep(OnboardingEvents.purposeStepIndex);
  }

  void _skip(int index) {
    logAppEvent(OnboardingEvents.skipped, properties: {'index': index});
    if (_step == _Step.slides) {
      // The slides are skippable; the question is the step that gets a new
      // user to a cafe, so Skip lands on it rather than on Home.
      _showPurpose();
    } else {
      _finish();
    }
  }

  void _onPurpose(OnboardingPurpose purpose) {
    if (_step != _Step.purpose) return;
    logAppEvent(
      OnboardingEvents.purposeSelected,
      properties: {'purpose': purpose.key},
    );
    final store =
        widget.purposeStore ??
        (sl.isRegistered<OnboardingPurposeStore>()
            ? sl<OnboardingPurposeStore>()
            : null);
    if (store != null) unawaited(store.save(purpose).catchError((_) {}));

    final load =
        widget.loadSuggestions ??
        (sl.isRegistered<GetPurposeSuggestionsUseCase>()
            ? (OnboardingPurpose p) => sl<GetPurposeSuggestionsUseCase>()(p)
            : null);
    if (load == null) {
      _complete(purpose, 'no_suggestions');
      return;
    }
    final cubit = _suggestions = PurposeSuggestionsCubit(load);
    setState(() => _step = _Step.suggestions);
    cubit.load(purpose).then((_) {
      // Nothing to suggest, or not in time: Home rather than a spinner.
      if (mounted && cubit.state.status == PurposeSuggestionsStatus.failed) {
        _complete(purpose, 'no_suggestions');
      }
    });
  }

  void _openSuggestion(OnboardingPurpose purpose, CafeSummary cafe, int i) {
    if (_done) return;
    logAppEvent(
      OnboardingEvents.firstSuggestionTapped,
      properties: {'purpose': purpose.key, 'position': i, 'cafe_id': cafe.id},
    );
    // A cafe has been seen: Home may now offer "See cafes near you".
    if (sl.isRegistered<HomeLocationPromptStore>()) {
      unawaited(
        sl<HomeLocationPromptStore>().markCafeViewed().catchError((_) {}),
      );
    }
    final open = widget.onOpenCafe ?? (id) => context.push('/cafe/$id');
    open(cafe.id);
    // Home goes in under the cafe page, so back lands on the feed.
    _complete(purpose, 'cafe');
  }

  /// The 48 row above every step: Skip on the slides and the question.
  Widget _topRow(OnboardingState state) {
    final skip = switch (_step) {
      _Step.slides => () => _skip(state.pageIndex),
      _Step.purpose => () => _skip(OnboardingEvents.purposeStepIndex),
      _Step.suggestions => null,
    };
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Align(
          alignment: Alignment.centerRight,
          child: skip == null
              ? null
              : AuthTextLink(
                  label: 'Skip',
                  color: AuthColors.muted,
                  onTap: skip,
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => OnboardingBloc(),
      child: Scaffold(
        backgroundColor: AuthColors.surface,
        body: BlocBuilder<OnboardingBloc, OnboardingState>(
          builder: (context, state) {
            return SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _topRow(state),
                  ...switch (_step) {
                    _Step.slides => _slides(context, state),
                    _Step.purpose => [
                      Expanded(child: PurposeStep(onSelected: _onPurpose)),
                    ],
                    _Step.suggestions => [Expanded(child: _suggestionsStep())],
                  },
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _suggestionsStep() {
    final cubit = _suggestions!;
    return BlocBuilder<PurposeSuggestionsCubit, PurposeSuggestionsState>(
      bloc: cubit,
      builder: (context, state) {
        final purpose = state.purpose ?? OnboardingPurpose.exploring;
        return PurposeSuggestionsStep(
          purpose: purpose,
          cafes: state.cafes,
          onCafeTap: (cafe, i) => _openSuggestion(purpose, cafe, i),
          onShowAll: () => _complete(purpose, 'show_all'),
        );
      },
    );
  }

  List<Widget> _slides(BuildContext context, OnboardingState state) {
    final currentData = OnboardingData.items[state.pageIndex];
    return [
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: authGutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Takes what is left, up to the design's 340, so
              // the copy below always fits on short phones.
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 340),
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: OnboardingData.items.length,
                    onPageChanged: (index) {
                      context.read<OnboardingBloc>().add(PageChanged(index));
                      _logStep(index);
                    },
                    itemBuilder: (context, index) {
                      return OnboardingImageWidget(
                        model: OnboardingData.items[index],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SmoothPageIndicator(
                controller: _pageController,
                count: OnboardingData.items.length,
                effect: const ExpandingDotsEffect(
                  activeDotColor: AuthColors.brand,
                  dotColor: AuthColors.border,
                  dotHeight: 8,
                  dotWidth: 8,
                  radius: 4,
                  // 22 wide when active.
                  expansionFactor: 22 / 8,
                  spacing: 6,
                ),
              ),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Column(
                  key: ValueKey<int>(state.pageIndex),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(currentData.title, style: AuthText.display),
                    const SizedBox(height: 14),
                    Text(currentData.description, style: AuthText.body),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          authGutter,
          0,
          authGutter,
          authBottomGap,
        ),
        child: AuthPrimaryButton(
          label: state.isLastPage ? 'Continue' : 'Next',
          onPressed: () {
            if (state.isLastPage) {
              _showPurpose();
            } else {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeIn,
              );
            }
          },
        ),
      ),
    ];
  }
}
