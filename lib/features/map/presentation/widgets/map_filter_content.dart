import 'package:flutter/material.dart';
import 'package:nook/core/utils/tag_icon_resolver.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Hardcoded filter labels (shared by [MapFilterBottomSheet] and sub-sheets).
/// Tags no cafe has (Book Cafe, Open 24 Hours) are not offered: an empty
/// filter is a dead end (docs COFFEE_VOICE.md §2.2).
const List<String> kMapFilterBestForLabels = [
  'Date Spot',
  'Solo Work / Study',
  'Group Hangout',
  'Late Night',
  'Quick Coffee',
  'Family Friendly',
  'Nature Cafe',
  'Special Occasion',
  'Specialty Coffee',
  'Student Friendly',
  'Aesthetic / IG-worthy',
  'Community Space',
];

const List<String> kMapFilterAmenityLabels = [
  'Free WiFi',
  'Power Outlets',
  'Air Conditioned',
  'Outdoor Seating',
  'Parking Available',
  'Reservations Accepted',
  'Private Rooms',
  'Wheelchair Accessible',
  'Takeaway Available',
  'Smoking Area',
  'Pet Friendly',
];

const List<String> kMapFilterPaymentLabels = ['Cash', 'E-wallet', 'Card'];

/// Every coffee label a filter can hold. The sheets only show the ones that
/// exist in the database (`CoffeeTagCatalog.available`), so the section is
/// absent until the coffee tags are.
const List<String> kMapFilterCoffeeLabels = kCoffeeTagNames;

/// Section titles of the filter sheets, in sentence case.
const String kMapFilterSectionSortBy = 'Sort by';
const String kMapFilterSectionBestFor = 'Best for';
const String kMapFilterSectionCoffee = 'Coffee';
const String kMapFilterSectionAmenities = 'Amenities';
const String kMapFilterSectionPaymentAccepted = 'Payment accepted';

Set<String> mergeTagsReplacingCategory(
  Set<String> currentTags,
  Set<String> categoryLabelPool,
  Set<String> newSelectionForCategory,
) {
  return currentTags
      .difference(categoryLabelPool)
      .union(newSelectionForCategory);
}

/// Display label for the sort quick chip (matches [mapFilterSortOptions] ids).
String mapFilterSortLabel(String sortId) {
  return switch (sortId) {
    'nearby' => 'Nearby',
    'top_rated' => 'Highest rated',
    'trending' => 'Crowd favorites',
    'newest' => 'Newest',
    _ => 'Nearby',
  };
}

List<({String id, String label, IconData icon})> mapFilterSortOptions() => [
  (id: 'nearby', label: 'Nearby', icon: PhosphorIcons.mapPin()),
  (id: 'top_rated', label: 'Highest rated', icon: PhosphorIcons.star()),
  (id: 'trending', label: 'Crowd favorites', icon: PhosphorIcons.trendUp()),
  (id: 'newest', label: 'Newest', icon: PhosphorIcons.sparkle()),
];
