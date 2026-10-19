import 'package:flutter/material.dart';
import 'package:nook/features/cups/domain/entities/cup.dart';

/// The share artwork for your cup, laid straight over its photo like the
/// crawl recap ([CrawlShareOverlay]): what you had, the cafe, area, stars
/// and the wordmark, with no card behind them. A cup without a photo gets
/// its note, centered, on brand green instead.
///
/// Built at 360 × 640 logical and captured at 3× = 1080 × 1920, the
/// Instagram Story size. Text stays clear of the top 84 and bottom 113,
/// where Instagram draws its own UI.
class CupStoryOverlay extends StatelessWidget {
  const CupStoryOverlay({
    super.key,
    required this.cup,
    required this.cafeName,
    this.cafeArea,
    required this.onPhoto,
  });

  static const size = Size(360, 640);
  static const safeTop = 84.0;
  static const safeBottom = 113.0;

  /// Brand green, the ground of a cup without a photo.
  static const noteGround = Color(0xFF344E41);

  final CupCard cup;
  final String cafeName;
  final String? cafeArea;

  /// Over a photo: the bottom strip. Otherwise the centered note.
  final bool onPhoto;

  /// Baked in so the words stay readable on a bright photo: no scrim.
  static const _shadow = [
    Shadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 1)),
  ];

  @override
  Widget build(BuildContext context) {
    // An image of a fixed size: the device's text size does not apply.
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox.fromSize(
        size: size,
        child: DefaultTextStyle(
          style: const TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white,
            shadows: _shadow,
            decoration: TextDecoration.none,
            height: 1.3,
          ),
          child: onPhoto ? _strip() : _note(),
        ),
      ),
    );
  }

  String? get _area {
    final a = cafeArea?.trim() ?? '';
    return a.isEmpty ? null : a;
  }

  /// Bottom-left, like the crawl's Strip.
  Widget _strip() {
    final item = cupItemLine(cup);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, safeTop, 24, safeBottom),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _wordmark(16),
          const SizedBox(height: 12),
          if (item != null) ...[
            Text(
              item,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 2),
          ],
          _cafeName(TextAlign.start),
          if (_area != null) _areaText(TextAlign.start),
          if (cup.rating != null) ...[
            const SizedBox(height: 8),
            _Stars(rating: cup.rating!, size: 18),
          ],
          const SizedBox(height: 10),
          const _Url(),
        ],
      ),
    );
  }

  /// Centered, like the crawl's Stacked: stars over the note (Fable).
  Widget _note() {
    final note = cup.hasNote ? clipNote(cup.note!) : null;
    final items = [for (final i in cup.items) ?i.label];
    // No note: what you had is the headline; with neither, the stars are.
    final headline = note ?? (items.isEmpty ? null : items.take(3).join(' · '));
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, safeTop, 32, safeBottom),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (cup.rating != null) ...[
            _Stars(rating: cup.rating!, size: headline == null ? 34 : 22),
            const SizedBox(height: 18),
          ],
          if (headline != null) ...[
            Text(
              note == null ? headline : '“$headline”',
              maxLines: 7,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: note == null ? 24 : 21,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
          ],
          if (note != null && items.isNotEmpty) ...[
            Text(
              items.take(3).join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: _sage),
            ),
            const SizedBox(height: 6),
          ],
          _cafeName(TextAlign.center),
          if (_area != null) _areaText(TextAlign.center),
          const SizedBox(height: 22),
          _wordmark(20),
          const SizedBox(height: 6),
          const _Url(),
        ],
      ),
    );
  }

  Widget _cafeName(TextAlign align) => Text(
    cafeName,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    textAlign: align,
    style: const TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.4,
      height: 1.2,
    ),
  );

  Widget _areaText(TextAlign align) => Text(
    _area!,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    textAlign: align,
    style: const TextStyle(fontSize: 13, color: _white90),
  );

  Widget _wordmark(double height) => Image.asset(
    'assets/logos/logoT.png',
    height: height,
    color: Colors.white,
    semanticLabel: 'nook',
  );
}

/// "Spanish latte · Coffee +2 more": the first named item with its kind.
/// Null when nothing in the cup has a name.
String? cupItemLine(CupCard cup) {
  final named = [
    for (final i in cup.items)
      if (i.label != null) i,
  ];
  if (named.isEmpty) return null;
  final first = named.first;
  final kind = first.kind == null ? '' : ' · ${first.kind!.label}';
  final more = named.length > 1 ? ' +${named.length - 1} more' : '';
  return '${first.label}$kind$more';
}

/// About seven lines of the card's note, cut at a word.
String clipNote(String note, {int max = 180}) {
  final text = note.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.length <= max) return text;
  final cut = text.substring(0, max);
  final space = cut.lastIndexOf(' ');
  return '${(space > max ~/ 2 ? cut.substring(0, space) : cut).trimRight()}…';
}

const _sage = Color(0xFFDAD7CD);
const _white90 = Color(0xE6FFFFFF);

class _Url extends StatelessWidget {
  const _Url();

  @override
  Widget build(BuildContext context) => const Text(
    'www.nookph.app',
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: _white90,
    ),
  );
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating, required this.size});

  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: i <= rating ? Colors.white : const Color(0x99FFFFFF),
            shadows: CupStoryOverlay._shadow,
          ),
      ],
    );
  }
}
