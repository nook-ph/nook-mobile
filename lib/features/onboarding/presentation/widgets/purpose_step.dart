import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/preferences/onboarding_purpose_store.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/auth/presentation/widgets/auth_ui.dart';

/// Label, one line of context and icon for each purpose.
typedef PurposeCopy = ({String label, String hint, IconData icon});

PurposeCopy purposeCopy(OnboardingPurpose purpose) => switch (purpose) {
  OnboardingPurpose.work => (
    label: 'Work or study',
    hint: 'Wi-Fi, outlets, room for a laptop',
    icon: LucideIcons.laptop,
  ),
  OnboardingPurpose.date => (
    label: 'Date or hangout',
    hint: 'Somewhere good to sit and talk',
    icon: LucideIcons.users,
  ),
  OnboardingPurpose.specialty => (
    label: 'Specialty coffee',
    hint: 'Pour-overs, good beans, a proper flat white',
    icon: LucideIcons.coffee,
  ),
  OnboardingPurpose.exploring => (
    label: 'Just exploring',
    hint: 'Show me what\'s good',
    icon: LucideIcons.compass,
  ),
};

/// The last onboarding step: one question, four answers, one tap each.
/// Skip lives in the page's top row.
class PurposeStep extends StatelessWidget {
  const PurposeStep({super.key, required this.onSelected});

  final ValueChanged<OnboardingPurpose> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(authGutter, 8, authGutter, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('What are you\nlooking for?', style: AuthText.display),
          const SizedBox(height: 14),
          const Text(
            'Pick one and we\'ll start you with a few cafes that fit.',
            style: AuthText.body,
          ),
          const SizedBox(height: 24),
          for (final purpose in OnboardingPurpose.values) ...[
            if (purpose != OnboardingPurpose.values.first)
              const SizedBox(height: 12),
            _PurposeOption(
              copy: purposeCopy(purpose),
              onTap: () => onSelected(purpose),
            ),
          ],
        ],
      ),
    );
  }
}

class _PurposeOption extends StatelessWidget {
  const _PurposeOption({required this.copy, required this.onTap});

  final PurposeCopy copy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${copy.label}. ${copy.hint}',
      excludeSemantics: true,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AuthColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AuthColors.tint,
                  shape: BoxShape.circle,
                ),
                child: Icon(copy.icon, size: 20, color: AuthColors.brand),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(copy.label, style: AuthText.bodyStrong),
                    Text(copy.hint, style: AuthText.small),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: AuthColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
