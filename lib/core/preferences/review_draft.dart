class ReviewDraft {
  const ReviewDraft({
    required this.text,
    required this.rating,
    required this.updatedAt,
  });

  final String text;
  final int rating;
  final DateTime updatedAt;
}
