class CrawlStop {
  final String id;
  final String crawlId;
  final String cafeId;
  final String cafeName;
  final String cafeAddress;
  final double cafeLat;
  final double cafeLng;
  final int stopOrder;
  final String tier;
  final bool isActive;
  final String? label;
  final bool isClaimed;
  final DateTime? claimedAt;

  const CrawlStop({
    required this.id,
    required this.crawlId,
    required this.cafeId,
    required this.cafeName,
    required this.cafeAddress,
    required this.cafeLat,
    required this.cafeLng,
    required this.stopOrder,
    required this.tier,
    this.isActive = true,
    this.label,
    this.isClaimed = false,
    this.claimedAt,
  });
}
