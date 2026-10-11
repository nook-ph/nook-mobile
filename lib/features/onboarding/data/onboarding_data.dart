class OnboardingModel {
  final String title;
  final String description;
  final String imagePath;

  const OnboardingModel({
    required this.title,
    required this.description,
    required this.imagePath,
  });
}

class OnboardingData {
  static const List<OnboardingModel> items = [
    OnboardingModel(
      title: "Find your kind\nof cafe",
      description:
          "Pour-over bars, iced-latte spots, quiet corners to work — all on one map.",
      imagePath: "assets/images/relaxing.png",
    ),
    OnboardingModel(
      title: "Know before\nyou go",
      description:
          "Wi-Fi, outlets, hours and menus, kept current by the community.",
      imagePath: "assets/images/looking.png",
    ),
    OnboardingModel(
      title: "Keep your\ncoffee story",
      description:
          "Mark where you've been, rank your favorites, save the ones to try next.",
      imagePath: "assets/images/friends.png",
    ),
  ];
}
