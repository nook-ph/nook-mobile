import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/utils/content_filter.dart';

void main() {
  group('ContentFilter.containsObjectionable', () {
    test('allows clean content', () {
      expect(ContentFilter.containsObjectionable('Great coffee and cozy vibes'),
          isFalse);
      expect(ContentFilter.containsObjectionable(''), isFalse);
      expect(ContentFilter.containsObjectionable('   '), isFalse);
    });

    test('flags a slur regardless of case', () {
      expect(ContentFilter.containsObjectionable('You RETARD'), isTrue);
      expect(ContentFilter.containsObjectionable('faggot'), isTrue);
    });

    test('flags leetspeak obfuscation', () {
      expect(ContentFilter.containsObjectionable('f4ggot'), isTrue);
    });

    test('flags spaced/punctuated evasion', () {
      expect(ContentFilter.containsObjectionable('f a g g o t'), isTrue);
      expect(ContentFilter.containsObjectionable('r.e.t.a.r.d'), isTrue);
    });

    test('does not false-positive on clean substrings (Scunthorpe safety)', () {
      // "class" contains no blocked term; "grape" must not match "rape" as a
      // whole word.
      expect(ContentFilter.containsObjectionable('first class latte'), isFalse);
      expect(
          ContentFilter.containsObjectionable('grape juice on the menu'),
          isFalse);
    });
  });
}
