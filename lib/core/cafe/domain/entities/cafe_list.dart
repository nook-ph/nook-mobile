// lib/features/lists/domain/entities/cafe_list.dart
class CafeList {
  final String id;
  final String name;
  final String? description;
  final String? coverImageUrl;
  final bool isDefault;
  final bool isPublic;
  final int cafeCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CafeList({
    required this.id,
    required this.name,
    this.description,
    this.coverImageUrl,
    required this.isDefault,
    required this.isPublic,
    required this.cafeCount,
    required this.createdAt,
    required this.updatedAt,
  });
}
