import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/utils/content_filter.dart';

void main() {
  group('ContentFilter.containsObjectionable', () {
    test('allows clean content', () {
      expect(
        ContentFilter.containsObjectionable('Great coffee and cozy vibes'),
        isFalse,
      );
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
        isFalse,
      );
    });

    test('abbreviations do not make the whole review look spelled out', () {
      for (final clean in [
        'Open until 2 a.m. and the spicy tuna melt is great',
        'Closes at 9 p.m. on weekdays, grape soda is a must',
        'Seats A B C by the window are the quiet ones',
        'W i f i is fast and the staff are kind',
        'I got the no. 1 combo, a s a p, then left',
      ]) {
        expect(
          ContentFilter.containsObjectionable(clean),
          isFalse,
          reason: clean,
        );
      }
    });

    test('"CP" (cellphone) is ordinary Philippine English', () {
      expect(
        ContentFilter.containsObjectionable(
          'No CP signal inside but wifi is ok',
        ),
        isFalse,
      );
      expect(ContentFilter.containsObjectionable('childporn'), isTrue);
    });

    test('still catches a term spelled out inside ordinary prose', () {
      for (final bad in [
        'the barista is a f a g g o t honestly',
        'nice place. r-e-t-a-r-d staff though',
        'you f_a_g',
        'f 4 g g 0 t',
        'such a r e t a r d e d menu',
        'c.u.n.t',
      ]) {
        expect(ContentFilter.containsObjectionable(bad), isTrue, reason: bad);
      }
    });

    test('still catches plain and leetspeak terms next to punctuation', () {
      expect(ContentFilter.containsObjectionable('what a slut.'), isTrue);
      expect(ContentFilter.containsObjectionable('r3tard, really'), isTrue);
    });
  });
}
