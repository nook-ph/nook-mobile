import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../bloc/onboarding_bloc.dart';
import '../../data/onboarding_data.dart';
import '../widgets/onboarding_image.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

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

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => OnboardingBloc(),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: BlocBuilder<OnboardingBloc, OnboardingState>(
          builder: (context, state) {
            final currentData = OnboardingData.items[state.pageIndex];

            return SafeArea(
              child: Column(
                children: [
                  // top section
                  Expanded(
                    flex: 3,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: OnboardingData.items.length,
                      onPageChanged: (index) {
                        context.read<OnboardingBloc>().add(PageChanged(index));
                      },
                      itemBuilder: (context, index) {
                        return OnboardingImageWidget(
                          model: OnboardingData.items[index],
                        );
                      },
                    ),
                  ),

                  //bot
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 22,
                      ),
                      child: Column(
                        children: [
                          const Spacer(),

                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Column(
                              key: ValueKey<int>(state.pageIndex),
                              children: [
                                // title
                                Text(
                                  currentData.title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF344E41),
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                // subtitle
                                Text(
                                  currentData.description,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF0A0F0D),
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 30),

                          SmoothPageIndicator(
                            controller: _pageController,
                            count: OnboardingData.items.length,
                            effect: const ExpandingDotsEffect(
                              activeDotColor: Color(0xFF344E41),
                              dotColor: Color(0xFFE0E0E0),
                              dotHeight: 8,
                              dotWidth: 8,
                              expansionFactor: 4,
                              spacing: 8,
                            ),
                          ),

                          const SizedBox(height: 20),

                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton(
                              onPressed: () {
                                if (state.isLastPage) {
                                  print("Go home");
                                } else {
                                  _pageController.nextPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeIn,
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF344E41),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                state.isLastPage ? "Get Started" : "Next",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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
