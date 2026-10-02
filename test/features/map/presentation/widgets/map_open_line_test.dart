import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/map/presentation/widgets/map_open_line.dart';

void main() {
  final hours = <String, dynamic>{
    for (final d in [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
    ])
      d: {'open': '07:00', 'close': '22:00'},
    'sunday': {'closed': true},
  };

  // Manila is UTC+8; 2026-10-01 is a Thursday.
  DateTime manila(int day, int h, int m) =>
      DateTime.utc(2026, 10, day, h, m).subtract(const Duration(hours: 8));

  test('open shows the closing time', () {
    final line = MapOpenLine.resolve(hours, now: manila(1, 12, 0))!;
    expect(line.word, 'Open');
    expect(line.detail, 'Closes 10 PM');
  });

  test("before opening shows today's opening time", () {
    final line = MapOpenLine.resolve(hours, now: manila(1, 6, 0))!;
    expect(line.word, 'Closed');
    expect(line.detail, 'Opens 7 AM');
  });

  test('after closing on a weekday opens tomorrow', () {
    final line = MapOpenLine.resolve(hours, now: manila(1, 23, 0))!;
    expect(line.detail, 'Opens 7 AM tomorrow');
  });

  test('after closing on Saturday skips the closed Sunday', () {
    final line = MapOpenLine.resolve(hours, now: manila(3, 23, 0))!;
    expect(line.detail, 'Opens 7 AM Monday');
  });

  test('no hours gives no line', () {
    expect(MapOpenLine.resolve(null), isNull);
    expect(MapOpenLine.resolve(const {}), isNull);
  });
}
