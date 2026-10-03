import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/search/presentation/widgets/search_tag_match.dart';

void main() {
  test('everyday words map to the filter they mean', () {
    expect(searchTagsFor('wifi').first, 'Free WiFi');
    expect(searchTagsFor('WiFi ').first, 'Free WiFi');
    expect(searchTagsFor('study').first, 'Solo Work / Study');
    expect(searchTagsFor('outlets').first, 'Power Outlets');
    expect(searchTagsFor('aircon').first, 'Air Conditioned');
    expect(searchTagsFor('barkada').first, 'Group Hangout');
  });

  test('a start of a word matches from three letters', () {
    expect(searchTagsFor('stu'), contains('Solo Work / Study'));
    expect(searchTagsFor('wi'), isEmpty, reason: 'too short to guess');
  });

  test('cafe names do not turn into filters', () {
    expect(searchTagsFor('Three Two Brew'), isEmpty);
    expect(searchTagsFor('Misfits'), isEmpty);
  });

  test('never more than asked for', () {
    expect(searchTagsFor('co', max: 1).length, lessThanOrEqualTo(1));
  });
}
