import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/analytics/install_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('sourceFrom', () {
    test('reads src, lower-cased', () {
      expect(
        InstallSourceRecorder.sourceFrom(
          Uri.parse('https://www.nookph.app/c/abc?src=IG_Bio'),
        ),
        'ig_bio',
      );
    });

    test('no link, no src, or an unsafe value is organic', () {
      expect(InstallSourceRecorder.sourceFrom(null), 'organic');
      expect(
        InstallSourceRecorder.sourceFrom(Uri.parse('nook://cafe/1')),
        'organic',
      );
      expect(
        InstallSourceRecorder.sourceFrom(
          Uri.parse('https://x.app/?src=a%20b%3Cscript'),
        ),
        'organic',
      );
      expect(
        InstallSourceRecorder.sourceFrom(
          Uri.parse('https://x.app/?src=${'a' * 65}'),
        ),
        'organic',
      );
    });
  });

  group('recordOnFirstOpen', () {
    late List<Map<String, Object>> sent;

    InstallSourceRecorder recorder({Uri? link, bool throws = false}) =>
        InstallSourceRecorder(
          initialLink: () async {
            if (throws) throw Exception('no platform');
            return link;
          },
          setOnce: (p) async => sent.add(p),
        );

    setUp(() => sent = []);

    test('sets src from the launch link once per install', () async {
      SharedPreferences.setMockInitialValues({});
      final r = recorder(link: Uri.parse('https://www.nookph.app/?src=tiktok'));

      await r.recordOnFirstOpen();
      await r.recordOnFirstOpen();

      expect(sent, [
        {'install_source': 'tiktok'},
      ]);
    });

    test('a platform error still records organic', () async {
      SharedPreferences.setMockInitialValues({});

      await recorder(throws: true).recordOnFirstOpen();

      expect(sent, [
        {'install_source': 'organic'},
      ]);
    });

    test('an install that had already onboarded is existing', () async {
      SharedPreferences.setMockInitialValues({'hasSeenOnboarding': true});

      await recorder(
        link: Uri.parse('https://x.app/?src=ig'),
      ).recordOnFirstOpen();

      expect(sent, [
        {'install_source': 'existing'},
      ]);
    });

    test('a failed send is retried on the next open', () async {
      SharedPreferences.setMockInitialValues({});
      var fail = true;
      final r = InstallSourceRecorder(
        initialLink: () async => null,
        setOnce: (p) async {
          if (fail) throw Exception('offline');
          sent.add(p);
        },
      );

      await r.recordOnFirstOpen();
      fail = false;
      await r.recordOnFirstOpen();

      expect(sent, [
        {'install_source': 'organic'},
      ]);
    });
  });
}
