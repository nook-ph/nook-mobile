import 'cafe_details.dart';

class CafeBundle {
  final CafeDetails details;
  final List<MenuItem>? menu;
  final List<Review>? reviews;

  const CafeBundle({required this.details, this.menu, this.reviews});

  CafeBundle copyWith({
    CafeDetails? details,
    List<MenuItem>? menu,
    List<Review>? reviews,
  }) {
    return CafeBundle(
      details: details ?? this.details,
      menu: menu ?? this.menu,
      reviews: reviews ?? this.reviews,
    );
  }
}
