/// The cities and areas the city waitlist recognises, so a typed answer can
/// be sent as a known name and anything else as `other`. The typed text
/// itself never leaves the phone: it could be a name, a number or an
/// address.
abstract final class WaitlistCities {
  /// Canonical name, then other ways people write it. Matching ignores
  /// case, accents, punctuation, extra spaces and a "City" / "City of"
  /// around the name, so "davao city", "Davao" and "DAVAO" all match.
  static const _names = <String, List<String>>{
    // Metro Manila
    'Metro Manila': ['NCR', 'National Capital Region', 'MM'],
    'Manila': [],
    'Quezon City': ['QC'],
    'Makati': [],
    'Taguig': ['BGC', 'Bonifacio Global City'],
    'Pasig': ['Ortigas'],
    'Mandaluyong': [],
    'San Juan': [],
    'Pasay': [],
    'Parañaque': [],
    'Las Piñas': [],
    'Muntinlupa': ['Alabang'],
    'Marikina': [],
    'Caloocan': [],
    'Valenzuela': [],
    'Malabon': [],
    'Navotas': [],
    // Luzon
    'Baguio': [],
    'Antipolo': [],
    'Angeles': ['Clark'],
    'San Fernando': [],
    'Olongapo': ['Subic'],
    'Tagaytay': [],
    'Batangas': [],
    'Lipa': [],
    'Calamba': [],
    'Santa Rosa': ['Sta Rosa'],
    'Bacoor': [],
    'Dasmariñas': ['Dasma'],
    'Imus': [],
    'Lucena': [],
    'Naga': [],
    'Legazpi': ['Legaspi'],
    'Dagupan': [],
    'Vigan': [],
    'Laoag': [],
    'Tuguegarao': [],
    'Cabanatuan': [],
    'Malolos': [],
    'Puerto Princesa': ['Palawan'],
    'El Nido': [],
    'Boracay': [],
    // Visayas
    'Cebu': [],
    'Mandaue': [],
    'Lapu-Lapu': ['Lapulapu', 'Mactan'],
    'Talisay': [],
    'Iloilo': [],
    'Bacolod': [],
    'Dumaguete': [],
    'Tagbilaran': ['Bohol', 'Panglao'],
    'Tacloban': [],
    'Ormoc': [],
    'Roxas': [],
    // Mindanao
    'Davao': [],
    'Cagayan de Oro': ['CDO'],
    'Zamboanga': [],
    'General Santos': ['GenSan', 'Gen San'],
    'Iligan': [],
    'Butuan': [],
    'Cotabato': [],
    'Surigao': [],
    'Siargao': ['General Luna'],
    'Dipolog': [],
    'Koronadal': [],
    'Tagum': [],
    'Valencia': [],
    'Malaybalay': [],
  };

  /// Each name and alias as written, normalised. A typed answer is looked
  /// up as it is, then without a "City" around it: so "Davao City" finds
  /// Davao, while "Quezon" (the province) does not find Quezon City.
  static final Map<String, String> _byKey = {
    for (final entry in _names.entries)
      for (final written in [entry.key, ...entry.value])
        _normalise(written): entry.key,
  };

  /// The canonical name [typed] refers to, or null when it is not a city or
  /// area on the list. A province or country after a comma, or a trailing
  /// "Philippines" / "PH", does not stop a match: "Davao City,
  /// Philippines" and "Iloilo City, Iloilo" match.
  static String? match(String typed) {
    final whole = _lookup(typed);
    if (whole != null) return whole;
    final comma = typed.indexOf(',');
    if (comma <= 0) return null;
    return _lookup(typed.substring(0, comma));
  }

  static String? _lookup(String typed) {
    final k = _withoutCountry(_normalise(typed));
    if (k.isEmpty) return null;
    return _byKey[k] ?? _byKey[_stripCity(k)];
  }

  static const _countrySuffixes = [' philippines', ' ph'];

  static String _withoutCountry(String k) {
    for (final suffix in _countrySuffixes) {
      if (k.endsWith(suffix)) return k.substring(0, k.length - suffix.length);
    }
    return k;
  }

  static final _nonAlphanumeric = RegExp(r'[^a-z0-9]+');

  static const _accents = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', //
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', //
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', //
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', //
    'ñ': 'n', 'ç': 'c',
  };

  /// Lower case, accents dropped, anything but letters and digits as
  /// spaces, single-spaced.
  static String _normalise(String text) {
    final buffer = StringBuffer();
    for (final rune in text.toLowerCase().runes) {
      // A combining mark (an "n" typed with a separate tilde) goes with
      // the letter before it.
      if (rune >= 0x0300 && rune <= 0x036F) continue;
      final char = String.fromCharCode(rune);
      buffer.write(_accents[char] ?? char);
    }
    return buffer
        .toString()
        // Anything but a letter or digit (punctuation, quotes, emoji)
        // separates words.
        .replaceAll(_nonAlphanumeric, ' ')
        .trim();
  }

  static String _stripCity(String key) {
    var k = key.trim();
    if (k.startsWith('city of ')) k = k.substring('city of '.length);
    if (k.endsWith(' city')) k = k.substring(0, k.length - ' city'.length);
    return k.trim();
  }
}
