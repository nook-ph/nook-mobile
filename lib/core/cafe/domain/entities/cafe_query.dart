class CafeQuery {
  final String? query;
  final String? userId;
  final String? sort;
  final List<String> tags;
  final double? lat;
  final double? lng;
  final int page;
  final int limit;

  const CafeQuery({
    this.query,
    this.userId,
    this.sort,
    this.tags = const [],
    this.lat,
    this.lng,
    this.page = 0,
    this.limit = 15,
  });

  int get offset => page * limit;

  Map<String, dynamic> toRpcParams() {
    return {
      'p_query': query,
      'p_user_id': userId,
      'p_sort': sort,
      'p_tag_names': tags.isEmpty ? null : tags,
      'p_lat': lat,
      'p_lng': lng,
      'p_limit': limit,
      'p_offset': offset,
    };
  }
}
