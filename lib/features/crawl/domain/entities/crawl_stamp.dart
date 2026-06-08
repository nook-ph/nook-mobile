class CrawlStamp {
  final String id;
  final String stopId;
  final String cafeId;
  final String cafeName;
  final int stopOrder;
  final String tier;
  final DateTime claimedAt;
  final String claimMethod;
  final bool isVerified;

  const CrawlStamp({
    required this.id,
    required this.stopId,
    required this.cafeId,
    required this.cafeName,
    this.stopOrder = 0,
    required this.tier,
    required this.claimedAt,
    required this.claimMethod,
    this.isVerified = false,
  });
}
