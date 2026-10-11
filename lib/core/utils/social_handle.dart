/// First path segments that are a kind of content, not an account.
const _nonProfileSegments = {'p', 'reel', 'reels', 'tv', 'stories', 'explore'};

/// The account name in a social link or handle, without the @:
/// `https://www.instagram.com/lorenzo.s.cafe/?hl=en` → `lorenzo.s.cafe`.
/// Null for a link to a post or reel, which names no profile.
String? socialHandle(String rawValue) {
  final trimmed = rawValue.trim();
  if (trimmed.isEmpty) return null;

  var value = trimmed;
  if (!value.contains('://') && value.startsWith('www.')) {
    value = 'https://$value';
  }

  final parsed = Uri.tryParse(value);
  String? handle;
  if (parsed != null &&
      (parsed.hasScheme || parsed.host.isNotEmpty) &&
      parsed.pathSegments.isNotEmpty) {
    // The profile is the first segment: ".../cafe/reels/" is still "cafe".
    handle = parsed.pathSegments.firstWhere(
      (segment) => segment.trim().isNotEmpty,
      orElse: () => '',
    );
    // A link to a post or a reel names no profile; the link itself opens.
    if (_nonProfileSegments.contains(handle.toLowerCase())) return null;
    if (handle.isEmpty && parsed.queryParameters.isNotEmpty) {
      handle = parsed.queryParameters['id'];
    }
  } else if (trimmed.contains('/')) {
    handle = trimmed.split('/').last;
  } else {
    handle = trimmed;
  }

  final normalized = handle?.replaceFirst('@', '').trim();
  if (normalized == null || normalized.isEmpty) return null;
  return normalized;
}
