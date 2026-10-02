import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/crawls/data/crawl_models.dart';
import 'package:nook/features/crawls/data/crawl_remote_data_source.dart';
import 'package:nook/features/crawls/domain/crawl_stats.dart';
import 'package:nook/features/crawls/domain/entities/crawl_exception.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'crawl_fixtures.dart';

void main() {
  group('CrawlStats', () {
    test('distance sums the straight legs between consecutive stops', () {
      // 0.001° of latitude is ~111 m; two legs of that.
      final stops = [
        stop(1, lat: 10.330, lng: 123.9),
        stop(2, lat: 10.331, lng: 123.9),
        stop(3, lat: 10.332, lng: 123.9),
      ];
      expect(CrawlStats.routeDistanceMeters(stops), closeTo(222, 2));
      expect(CrawlStats.routeDistanceMeters([stops.first]), 0);
      expect(CrawlStats.routeDistanceMeters(const []), 0);
    });

    test('elapsed is first stamp to last, and null with fewer than two', () {
      expect(CrawlStats.elapsed(run(stamped: 3)), const Duration(minutes: 80));
      expect(CrawlStats.elapsed(run(stamped: 1)), isNull);
      expect(CrawlStats.elapsed(run()), isNull);
    });

    test('formatters', () {
      expect(CrawlStats.formatDistance(492), '492 m');
      expect(CrawlStats.formatDistance(2440), '2.4 km');
      expect(CrawlStats.formatDuration(const Duration(minutes: 45)), '45 min');
      expect(CrawlStats.formatDuration(const Duration(minutes: 120)), '2h');
      expect(CrawlStats.formatDuration(const Duration(minutes: 192)), '3h 12m');
      expect(CrawlStats.formatClock(DateTime(2026, 1, 1, 15, 42)), '3:42 PM');
      expect(CrawlStats.formatClock(DateTime(2026, 1, 1, 0, 5)), '12:05 AM');
      expect(CrawlStats.formatClock(DateTime(2026, 1, 1, 12, 0)), '12:00 PM');
    });
  });

  group('CrawlRun', () {
    test('progress, next stop and completion come from my own stamps', () {
      final partial = run(stops: 3, stamped: 1);
      expect(partial.myStampCount, 1);
      expect(partial.nextStop?.stopId, 'stop-2');
      expect(partial.isComplete, isFalse);

      final done = run(stops: 3, stamped: 3);
      expect(done.isComplete, isTrue);
      expect(done.nextStop, isNull);
    });
  });

  group('CrawlModels', () {
    test('parses a run as the server builds it', () {
      final parsed = CrawlModels.run({
        'run_id': 'r1',
        'invite_code': 'ABCDEF1234',
        'planned_for': null,
        'crawl': {
          'id': 'c1',
          'title': 'Test Crawl',
          'description': null,
          'share_code': 'K7M2QX9A',
          'visibility': 'link',
          'status': 'active',
          'stop_count': 2,
          'is_creator': false,
          'creator': null,
          'runs_started': 4,
          'completions': 1,
          'stops': [
            {
              'stop_id': 's2',
              'stop_order': 2,
              'cafe_id': 'cafe-b',
              'name': 'B',
              'neighborhood': ' Lahug',
              'featured_image_url': null,
              'lat': 10.3,
              'lng': 123,
            },
            {
              'stop_id': 's1',
              'stop_order': 1,
              'cafe_id': 'cafe-a',
              'name': 'A',
              'neighborhood': null,
              'featured_image_url': 'https://x/y.jpg',
              'lat': 10.31,
              'lng': 123.9,
            },
          ],
        },
        'members': [
          {
            'user_id': 'me',
            'username': 'cris',
            'avatar_url': null,
            'joined_at': '2026-10-03T06:00:00+00:00',
            'completed_at': null,
            'is_me': true,
          },
        ],
        'stamps': [
          {
            'stop_id': 's1',
            'user_id': 'me',
            'claimed_at': '2026-10-03T06:10:00+00:00',
          },
        ],
      });

      expect(parsed.crawl.stops.map((s) => s.stopId), ['s1', 's2']);
      expect(parsed.crawl.stops.last.neighborhood, 'Lahug');
      expect(parsed.crawl.stops.last.lng, 123.0);
      expect(parsed.crawl.isLinkVisible, isTrue);
      expect(parsed.crawl.creatorUsername, isNull);
      expect(parsed.crawl.byline, 'by a former member');
      expect(parsed.crawl.runsStarted, 4);
      expect(parsed.me?.username, 'cris');
      expect(parsed.myStampedStopIds, {'s1'});
    });

    test('my crawls tolerates empty lists', () {
      final parsed = CrawlModels.myCrawls({'created': [], 'runs': []});
      expect(parsed.isEmpty, isTrue);
    });
  });

  group('CrawlRemoteDataSource.mapError', () {
    PostgrestException ex(String message, [Object? details]) =>
        PostgrestException(message: message, details: details, code: 'P0001');

    test('maps the stamp rejections with their numbers', () {
      final far = CrawlRemoteDataSource.mapError(ex('stamp_too_far', '180'));
      expect(far, isA<StampTooFar>());
      expect((far! as StampTooFar).distanceMeters, 180);

      final soon = CrawlRemoteDataSource.mapError(ex('stamp_too_soon', '412'));
      expect((soon! as StampTooSoon).waitSeconds, 412);

      final acc = CrawlRemoteDataSource.mapError(
        ex('stamp_low_accuracy', '400'),
      );
      expect((acc! as StampLowAccuracy).accuracyMeters, 400);
    });

    test('maps not-found, crew, rate limit and validation tokens', () {
      expect(
        CrawlRemoteDataSource.mapError(ex('run_not_found')),
        isA<CrawlNotFound>(),
      );
      expect(
        CrawlRemoteDataSource.mapError(ex('crawl_not_found')),
        isA<CrawlNotFound>(),
      );
      expect(CrawlRemoteDataSource.mapError(ex('crew_full')), isA<CrewFull>());
      expect(
        CrawlRemoteDataSource.mapError(ex('crawl_rate_limited')),
        isA<CrawlRateLimited>(),
      );
      final invalid = CrawlRemoteDataSource.mapError(ex('crawl_stop_count'));
      expect((invalid! as CrawlInvalid).code, 'crawl_stop_count');
    });

    test('leaves unrelated errors alone', () {
      expect(CrawlRemoteDataSource.mapError(ex('Not authenticated')), isNull);
      expect(CrawlRemoteDataSource.mapError(ex('JWT expired')), isNull);
    });
  });

  group('CrawlRoutePainter.layout', () {
    const size = Size(200, 100);

    test('keeps every stop inside the box and north at the top', () {
      final stops = crawl(stops: 5).stops;
      final points = CrawlRoutePainter.layout(stops, size, inset: 10);
      expect(points, hasLength(5));
      for (final p in points) {
        expect(p.dx, inInclusiveRange(10, 190));
        expect(p.dy, inInclusiveRange(10, 90));
      }
      // Stop 5 is the northernmost, so it is drawn highest.
      expect(points.last.dy, lessThan(points.first.dy));
    });

    test('stops on one point collapse to the centre, without NaN', () {
      final points = CrawlRoutePainter.layout([
        stop(1),
        stop(2),
        stop(3),
      ], size);
      for (final p in points) {
        expect(p, const Offset(100, 50));
      }
    });

    test('no stops, no points', () {
      expect(CrawlRoutePainter.layout(const [], size), isEmpty);
    });
  });
}
