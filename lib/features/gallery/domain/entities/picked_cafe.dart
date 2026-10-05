import 'package:equatable/equatable.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';

/// The cafe a batch of photos is being added to: just what the sheets show.
class PickedCafe extends Equatable {
  const PickedCafe({
    required this.id,
    required this.name,
    this.area,
    this.imageUrl,
  });

  factory PickedCafe.fromSummary(CafeSummary cafe) => PickedCafe(
    id: cafe.id,
    name: cafe.name,
    area: cafe.locationLabel.isEmpty ? null : cafe.locationLabel,
    imageUrl: cafe.coverImage,
  );

  final String id;
  final String name;

  /// "Lahug, Cebu City".
  final String? area;
  final String? imageUrl;

  @override
  List<Object?> get props => [id, name, area, imageUrl];
}
