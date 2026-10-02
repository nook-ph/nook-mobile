import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/app_bloc.dart';
import 'package:nook/core/app_event.dart';
import 'package:nook/features/auth/presentation/widgets/auth_ui.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../bloc/onboarding_bloc.dart';
import '../../data/onboarding_data.dart';
import '../widgets/onboarding_image.dart';

/// First launch (Figma A1–A3): illustration, page dots, left-aligned copy,
/// Skip on the first two slides and Next/Continue pinned to the bottom.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, this.onFinish});

  /// Called by Skip and by Continue on the last slide. Defaults to telling
  /// [AppBloc] onboarding is done.
  final VoidCallback? onFinish;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _finish(BuildContext context) {
    final onFinish = widget.onFinish;
    if (onFinish != null) {
      onFinish();
    } else {
      context.read<AppBloc>().add(OnboardingCompleted());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => OnboardingBloc(),
      child: Scaffold(
        backgroundColor: AuthColors.surface,
        body: BlocBuilder<OnboardingBloc, OnboardingState>(
          builder: (context, state) {
            final currentData = OnboardingData.items[state.pageIndex];

            return SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 48,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Align(
                        alignment: Alignment.centerRight,
                        // Gone on the last slide, where Continue does the
                        // same thing.
                        child: state.isLastPage
                            ? null
                            : AuthTextLink(
                                label: 'Skip',
                                color: AuthColors.muted,
                                onTap: () => _finish(context),
                              ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: authGutter,
                      ),
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
                                  context.read<OnboardingBloc>().add(
                                    PageChanged(index),
                                  );
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
                                Text(
                                  currentData.title,
                                  style: AuthText.display,
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  currentData.description,
                                  style: AuthText.body,
                                ),
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
                          _finish(context);
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeIn,
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
