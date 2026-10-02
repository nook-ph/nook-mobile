/// Client-side objectionable-content filter.
///
/// Backs the "automated filtering technology" the EULA (§3) promises and the
/// App Store UGC guideline requires. Applied to every user-authored text
/// surface before it is submitted: review text, usernames, and bios.
///
/// This is a first line of defence only — the authoritative moderation pipeline
/// (report queue + superadmin `mod_*` RPCs) still governs published content.
/// Keep [_blockedTerms] conservative to avoid false positives (e.g. the
/// Scunthorpe problem); server-side moderation catches what slips through.
class ContentFilter {
  const ContentFilter._();

  /// Curated list of slurs / hate terms / explicit sexual terms. Lowercase,
  /// matched on word boundaries after normalisation. Extend as needed — this is
  /// intentionally kept in one place for easy updates.
  static const List<String> _blockedTerms = [
    'nigger',
    'nigga',
    'faggot',
    'fag',
    'retard',
    'retarded',
    'chink',
    'spic',
    'kike',
    'coon',
    'cunt',
    'whore',
    'slut',
    'rape',
    'rapist',
    'pedophile',
    'pedo',
    'molest',
    'bestiality',
    'childporn',
  ];

  /// Common leetspeak / obfuscation substitutions folded before matching.
  static const Map<String, String> _leetMap = {
    '0': 'o',
    '1': 'i',
    '3': 'e',
    '4': 'a',
    '5': 's',
    '7': 't',
    '@': 'a',
    '\$': 's',
    '!': 'i',
  };

  /// Normalises text for matching: lowercase, fold leetspeak, and strip
  /// characters commonly used to break up words (spaces, dots, dashes,
  /// underscores) so "n i g g e r" / "n.i.g.g.e.r" are still caught.
  static String _normalize(String input) {
    final lower = input.toLowerCase();
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(_leetMap[char] ?? char);
    }
    return buffer.toString();
  }

  /// Runs of three or more single characters split by separators
  /// ("f a g g o t", "r.e.t.a.r.d"): the signature of deliberate evasion.
  static final RegExp _spelledOutRun = RegExp(
    r'(?<![a-z0-9])[a-z0-9](?:[\s._\-]+[a-z0-9](?![a-z0-9])){2,}',
  );

  static final RegExp _separators = RegExp(r'[\s._\-]+');

  /// True if [text] contains any blocked term. Uses whole-word matching on the
  /// normalised text (which also defeats leetspeak), plus a de-spaced pass over
  /// each spelled-out run. Only the run itself is collapsed, so ordinary prose
  /// around an abbreviation ("2 a.m. and the spicy tuna") is never joined up
  /// into a false positive.
  static bool containsObjectionable(String text) {
    if (text.trim().isEmpty) return false;
    final normalized = _normalize(text);
    final collapsedRuns = _spelledOutRun
        .allMatches(normalized)
        .map((match) => match.group(0)!.replaceAll(_separators, ''))
        .toList(growable: false);

    for (final term in _blockedTerms) {
      // Whole-word match in the normalised text (word boundaries prevent
      // "grape" from matching "rape").
      if (RegExp('\\b$term\\b').hasMatch(normalized)) return true;
      // Only for deliberately spaced-out text, catch "f a g g o t" style.
      if (collapsedRuns.any((run) => run.contains(term))) return true;
    }
    return false;
  }

  /// Standard user-facing rejection message.
  static const String rejectionMessage =
      'This contains language that violates our community guidelines. '
      'Please revise it and try again.';
}
