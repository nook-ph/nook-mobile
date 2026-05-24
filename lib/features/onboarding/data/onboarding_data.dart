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
      title: "Find your\nPerfect Brew",
      description:
          "Discover local hidden gems, rate your favorites, and never settle for bad coffee again",
      imagePath: "assets/images/relaxing.png",
    ),
    OnboardingModel(
      title: "Explore Local\nCafes",
      description:
          "Find the best spots for studying, meetings, or just a quick coffee with our interactive map",
      imagePath: "assets/images/looking.png",
    ),
    OnboardingModel(
      title: "Join the Coffee\nCommunity",
      description:
          "Rate your favorites, save spots for later, and help others find the best study nooks",
      imagePath: "assets/images/friends.png",
    ),
  ];
}
