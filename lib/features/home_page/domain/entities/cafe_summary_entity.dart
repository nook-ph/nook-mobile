class CafeSummaryEntity {
  final String id;
  final String name;
  final String address;
  final double rating;
  final String? featuredImageUrl; 
  final String? systemBadge;      
  final List<String> tags;        

  CafeSummaryEntity({
    required this.id,
    required this.name,
    required this.address,
    required this.rating,
    this.featuredImageUrl,
    this.systemBadge,
    this.tags = const [],
  });
}