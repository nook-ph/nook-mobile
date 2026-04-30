import 'package:nook/core/cafe/domain/entities/cafe_list.dart';

/// Matches [ListsPage] / save-to-list sheet: default list uses server name or "Favorites".
String cafeListDisplayTitle(CafeList list) {
  if (list.isDefault) {
    final name = list.name.trim();
    return name.isEmpty ? 'Favorites' : name;
  }
  return list.name;
}
