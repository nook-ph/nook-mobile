import 'package:flutter/material.dart';
import 'package:nook/features/crawls/domain/entities/crawl.dart';
import 'package:nook/features/crawls/domain/entities/crawl_run.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_widgets.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';

enum CrawlOverlayLayout {
  stacked('Stacked'),
  strip('Strip'),
  route('Route'),
  stamp('Stamp');

  const CrawlOverlayLayout(this.label);
  final String label;
}

/// The share artwork: the stop count, the cafes' names, the route line and
/// the wordmark, with no card behind them, laid straight over the user's
/// photo (the Strava model).
///
/// Always built at 360×640 logical and captured at 3× = 1080×1920, the
/// Instagram Story size. Content stays clear of the top and bottom ~96pt,
/// where Instagram draws its own UI.
class CrawlShareOverlay extends StatelessWidget {
  const CrawlShareOverlay({
    super.key,
    required this.layout,
    required this.run,
    this.stampStop,
  });

  final CrawlOverlayLayout layout;
  final CrawlRun run;

  /// The stop being shared, for [CrawlOverlayLayout.stamp].
  final CrawlStop? stampStop;

  static const size = Size(360, 640);

  /// A soft shadow baked into the artwork so it stays readable on a bright
  /// photo — there is no scrim.
  static const _shadow = [
    Shadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 1)),
  ];

  static const _white = Colors.white;

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: size,
      child: DefaultTextStyle(
        style: const TextStyle(
          fontFamily: 'Poppins',
          color: _white,
          shadows: _shadow,
          decoration: TextDecoration.none,
        ),
        child: switch (layout) {
          CrawlOverlayLayout.stacked => _stacked(),
          CrawlOverlayLayout.strip => _strip(),
          CrawlOverlayLayout.route => _route(),
          CrawlOverlayLayout.stamp => _stamp(),
        },
      ),
    );
  }

  /// "3/5" — how many of the crawl's stops the user has stamped.
  (String, String) get _stopsStat =>
      ('Stops', '${run.myStampCount}/${run.crawl.stops.length}');

  /// The crawl's cafes in order, one per line. [numbered] prefixes each with
  /// its stop number, matching the nodes of the numbered route.
  Widget _cafeNames({
    required CrossAxisAlignment align,
    double fontSize = 14,
    bool numbered = false,
  }) {
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final stop in run.crawl.stops)
          Text(
            numbered ? '${stop.order}  ${stop.name}' : stop.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: align == CrossAxisAlignment.center
                ? TextAlign.center
                : TextAlign.start,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
      ],
    );
  }

  Widget _stat(
    (String, String) stat,
    double valueSize,
    CrossAxisAlignment align,
  ) {
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          stat.$1,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.4,
            height: 1.3,
            color: Color(0xE6FFFFFF),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          stat.$2,
          style: TextStyle(
            fontSize: valueSize,
            fontWeight: FontWeight.w600,
            height: 1.05,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  Widget _wordmark(double height) => Image.asset(
    'assets/logos/logoT.png',
    height: height,
    color: _white,
    semanticLabel: 'nook',
  );

  Widget _trace(Size size, {bool numbered = false}) => CustomPaint(
    size: size,
    painter: CrawlRoutePainter(
      stops: run.crawl.stops,
      lineColor: _white,
      nodeColor: _white,
      numberColor: numbered ? ListsTokens.brand : null,
      strokeWidth: numbered ? 3.5 : 3,
      nodeRadius: numbered ? 10 : 4.5,
    ),
  );

  Widget _stacked() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stat(_stopsStat, 32, CrossAxisAlignment.center),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: _cafeNames(align: CrossAxisAlignment.center),
          ),
          const SizedBox(height: 18),
          _trace(const Size(176, 104)),
          const SizedBox(height: 18),
          _wordmark(20),
        ],
      ),
    );
  }

  Widget _strip() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 96),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _wordmark(16),
          const SizedBox(height: 12),
          Text(
            run.crawl.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          _cafeNames(align: CrossAxisAlignment.start, numbered: true),
          const SizedBox(height: 12),
          _stat(_stopsStat, 22, CrossAxisAlignment.start),
        ],
      ),
    );
  }

  Widget _route() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _trace(const Size(282, 166), numbered: true),
            const SizedBox(height: 22),
            Text(
              run.crawl.title,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${_stopsStat.$2} stops',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            _cafeNames(
              align: CrossAxisAlignment.start,
              fontSize: 13,
              numbered: true,
            ),
            const SizedBox(height: 22),
            _wordmark(18),
          ],
        ),
      ),
    );
  }

  Widget _stamp() {
    final stop = stampStop ?? run.crawl.stops.first;
    final total = run.crawl.stops.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 96),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STOP ${stop.order} OF $total',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            stop.name,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.6,
              height: 1.13,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 1; i <= total; i++) ...[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= run.myStampCount ? _white : null,
                    border: Border.all(color: _white, width: 1.5),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _wordmark(16),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  run.crawl.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
