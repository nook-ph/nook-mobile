import 'dart:math';

enum CrawlStatus { draft, active, completed, cancelled }

class Crawl {
  final String id;
  final String title;
  final String? description;
  final String slug;
  final DateTime startsAt;
  final DateTime endsAt;
  final CrawlStatus status;
  final String? coverImageUrl;
  final bool isFeatured;
  final String city;
  final int totalStops;
  final String? stampTemplateUrl;

  const Crawl({
    required this.id,
    required this.title,
    this.description,
    required this.slug,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    this.coverImageUrl,
    this.isFeatured = false,
    required this.city,
    this.totalStops = 0,
    this.stampTemplateUrl,
  });

  int get daysRemaining => max(0, endsAt.difference(DateTime.now()).inDays);
}
