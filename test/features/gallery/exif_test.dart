import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/gallery/data/gallery_photo_picker.dart';

void main() {
  test('reads the EXIF date format', () {
    expect(
      parseExifDate('2026:03:14 09:41:07'),
      DateTime(2026, 3, 14, 9, 41, 7),
    );
  });

  test('ignores missing, zeroed, malformed and future dates', () {
    expect(parseExifDate(null), isNull);
    expect(parseExifDate('0000:00:00 00:00:00'), isNull);
    expect(parseExifDate('March 14'), isNull);
    final nextYear = DateTime.now().year + 1;
    expect(parseExifDate('$nextYear:01:01 10:00:00'), isNull);
  });
}
