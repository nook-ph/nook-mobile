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
    'Cebu': ['Cebu City'],
    'Mandaue': [],
    'Lapu-Lapu': ['Lapu Lapu', 'Mactan'],
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

  static final Map<String, String> _byKey = {
    for (final entry in _names.entries) ...{
      key(entry.key): entry.key,
      for (final alias in entry.value) key(alias): entry.key,
    },
  };

  /// The canonical name [typed] refers to, or null when it is not a city or
  /// area on the list.
  static String? match(String typed) {
    final k = key(typed);
    if (k.isEmpty) return null;
    return _byKey[k];
  }

  static const _accents = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', //
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', //
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', //
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', //
    'ñ': 'n', 'ç': 'c',
  };

  /// Lower case, accents dropped, anything but letters and digits as
  /// spaces, single-spaced, and a leading "city of" or trailing "city"
  /// taken off.
  static String key(String text) {
    final buffer = StringBuffer();
    for (final rune in text.toLowerCase().runes) {
      // A combining mark (an "n" typed with a separate tilde) goes with
      // the letter before it.
      if (rune >= 0x0300 && rune <= 0x036F) continue;
      final char = String.fromCharCode(rune);
      buffer.write(_accents[char] ?? char);
    }
    var k = buffer
        .toString()
        // Anything but a letter or digit (punctuation, quotes, emoji)
        // separates words.
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
    if (k.startsWith('city of ')) k = k.substring('city of '.length);
    if (k.endsWith(' city')) k = k.substring(0, k.length - ' city'.length);
    return k.trim();
  }
}
