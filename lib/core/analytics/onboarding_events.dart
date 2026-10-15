// PostHog events for first launch: the onboarding slides, the "What are you
// looking for?" step and the three cafes suggested after it. Sent through
// `logAppEvent`. Named object_verb in the past tense, like the rest of the
// app's events. No free text in properties.

/// Onboarding events.
abstract final class OnboardingEvents {
  /// A step came on screen. Properties: `index` (0-based; the three slides
  /// are 0-2 and the purpose step is [purposeStepIndex]).
  static const slideViewed = 'onboarding_slide_viewed';

  /// Skip was tapped. On a slide it jumps to the purpose step; on the
  /// purpose step it goes to Home. Properties: `index` (the step it was
  /// tapped on).
  static const skipped = 'onboarding_skipped';

  /// Onboarding ended after a purpose was picked (not skipped). Properties:
  /// `purpose`, `exit` (`show_all`: "Show me everything"; `cafe`: a
  /// suggested cafe was opened; `no_suggestions`: the suggestions failed,
  /// timed out or came back empty and Home was shown instead).
  static const completed = 'onboarding_completed';

  /// A purpose was tapped on the purpose step. Properties: `purpose`
  /// (`work`, `date`, `specialty`, `exploring`).
  static const purposeSelected = 'onboarding_purpose_selected';

  /// One of the suggested cafes after the purpose step. Properties:
  /// `purpose`, `position` (0-based), `cafe_id`.
  static const firstSuggestionTapped = 'first_suggestion_tapped';

  /// The `index` the purpose step reports, after the three slides.
  static const purposeStepIndex = 3;
}
