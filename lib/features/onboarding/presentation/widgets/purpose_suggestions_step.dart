import 'package:flutter/material.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/preferences/onboarding_purpose_store.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/auth/presentation/widgets/auth_ui.dart';
import 'package:nook/features/home_page/presentation/widgets/home_cafe_card.dart';

String suggestionsTitle(OnboardingPurpose purpose) => switch (purpose) {
  OnboardingPurpose.work => 'Good for getting\nwork done',
  OnboardingPurpose.date => 'Good for a date\nor a hangout',
  OnboardingPurpose.specialty => 'For the coffee\nitself',
  OnboardingPurpose.exploring => 'A few to\nstart with',
};

/// Right after the purpose step: up to three cafes for it, Home's compact
/// cards stacked full width, and "Show me everything" pinned below.
/// [cafes] empty shows the loading line.
class PurposeSuggestionsStep extends StatelessWidget {
  const PurposeSuggestionsStep({
    super.key,
    required this.purpose,
    required this.cafes,
    required this.onCafeTap,
    required this.onShowAll,
  });

  final OnboardingPurpose purpose;
  final List<CafeSummary> cafes;
  final void Function(CafeSummary cafe, int position) onCafeTap;
  final VoidCallback onShowAll;

  static const double _photoHeight = 132;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth - authGutter * 2;
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  authGutter,
                  8,
                  authGutter,
                  24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(suggestionsTitle(purpose), style: AuthText.display),
                    const SizedBox(height: 14),
                    Text(
                      cafes.isEmpty
                          ? 'Finding cafes for you…'
                          : 'Tap one for hours, menu and what people say.',
                      style: AuthText.body,
                    ),
                    const SizedBox(height: 24),
                    if (cafes.isEmpty)
                      const Center(child: AuthSpinner())
                    else
                      for (var i = 0; i < cafes.length; i++) ...[
                        if (i > 0) const SizedBox(height: 20),
                        _SuggestionCard(
                          cafe: cafes[i],
                          width: cardWidth,
                          onTap: () => onCafeTap(cafes[i], i),
                        ),
                      ],
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            authGutter,
            0,
            authGutter,
            authBottomGap,
          ),
          child: AuthOutlineButton(
            label: 'Show me everything',
            onPressed: onShowAll,
          ),
        ),
      ],
    );
  }
}

/// Home's card with this step's tap: the card's own tap (which reports a
/// Home shelf) is switched off underneath.
class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.cafe,
    required this.width,
    required this.onTap,
  });

  final CafeSummary cafe;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: cafe.name,
      excludeSemantics: true,
      // The tap goes on this node: excluding the child's semantics drops
      // its tap action, and TalkBack or Switch Access could not choose.
      onTap: onTap,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: IgnorePointer(
          child: HomeCafeCard(
            cafe: cafe,
            width: width,
            height: PurposeSuggestionsStep._photoHeight,
          ),
        ),
      ),
    );
  }
}
