import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Hardcoded filter labels (shared by [MapFilterBottomSheet] and sub-sheets).
const List<String> kMapFilterBestForLabels = [
  'Date Spot',
  'Solo Work / Study',
  'Group Hangout',
  'Book Cafe',
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
  'Open 24 Hours',
  'Pet Friendly',
];

const List<String> kMapFilterPaymentLabels = ['Cash', 'E-wallet', 'Card'];

/// Uppercase section labels for full filter sheet only (not sub-sheets).
const String kMapFilterSectionSortBy = 'SORT BY';
const String kMapFilterSectionBestFor = 'BEST FOR';
const String kMapFilterSectionAmenities = 'AMENITIES';
const String kMapFilterSectionPaymentAccepted = 'PAYMENT ACCEPTED';

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
    'top_rated' => 'Top rated',
    'trending' => 'Trending',
    'newest' => 'Newest',
    _ => 'Nearby',
  };
}

List<({String id, String label, IconData icon})> mapFilterSortOptions() => [
  (id: 'nearby', label: 'Nearby', icon: PhosphorIcons.mapPin()),
  (id: 'top_rated', label: 'Top rated', icon: PhosphorIcons.star()),
  (id: 'trending', label: 'Trending', icon: PhosphorIcons.trendUp()),
  (id: 'newest', label: 'Newest', icon: PhosphorIcons.sparkle()),
];
