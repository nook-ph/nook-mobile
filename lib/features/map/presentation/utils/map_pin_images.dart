import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart' show IconData;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';

/// Rasterizes the map pin badges and registers them as style images —
/// port of the webapp's `drawPillCanvas` / `buildCoffeePinCanvas`
/// (nook-webapp `CafeMap.tsx`).
///
/// Rated cafes get a stadium "pill" (star + rating); unrated cafes get a
/// dark circular coffee badge when selected. One image is registered
/// per distinct rating and cached for the lifetime of the map style.
class MapPinImages {
  MapPinImages({required this.scale});

  /// Supersampling factor. Draw at this multiple of the logical size and
  /// compensate through the layer's icon-size (see [iconSizeFor]).
  final double scale;

  final Set<String> _registered = {};

  static const coffeeImageId = 'coffee-pin';

  /// The badge a selected unrated cafe turns into on the map: a dark circle
  /// with a coffee cup, no tail (Figma "Map — unrated pin selected").
  static const selectedCoffeeImageId = 'coffee-pin-selected';

  /// The pin marking the place being searched near (Figma "Map — searching
  /// near a chosen place").
  static const placePinImageId = 'origin-pin';

  static const _pillColor = Color(0xFF344E41);

  /// A selected pin turns near-black so it reads apart from the green ones.
  static const _selectedColor = Color(0xFF0A0F0D);
  static const _textColor = Color(0xFFFFFFFF);
  static const _iconColor = Color(0xFFFEFEFE);
  static const _strokeColor = Color(0xFFFFFFFF);
  static const _shadowColor = Color.fromRGBO(15, 35, 20, 0.35);

  // Phosphor "Coffee" (regular weight) glyph path, viewBox 0 0 256 256 —
  // same path the webapp embeds.
  static const _coffeeIconPath =
      'M80,56V24a8,8,0,0,1,16,0V56a8,8,0,0,1-16,0Zm40,8a8,8,0,0,0,8-8V24a8,8,0,0,0-16,0V56A8,8,0,0,0,120,64Zm32,0a8,8,0,0,0,8-8V24a8,8,0,0,0-16,0V56A8,8,0,0,0,152,64Zm96,56v8a40,40,0,0,1-37.51,39.91,96.59,96.59,0,0,1-27,40.09H208a8,8,0,0,1,0,16H32a8,8,0,0,1,0-16H56.54A96.3,96.3,0,0,1,24,136V88a8,8,0,0,1,8-8H208A40,40,0,0,1,248,120ZM200,96H40v40a80.27,80.27,0,0,0,45.12,72h69.76A80.27,80.27,0,0,0,200,136Zm32,24a24,24,0,0,0-16-22.62V136a95.78,95.78,0,0,1-1.2,15A24,24,0,0,0,232,128Z';

  static String pillImageId(String ratingLabel) => 'pill-$ratingLabel';

  /// Prefix of the dark, larger image a selected rated pin uses. The selected
  /// layer reads it as `concat(selectedPrefix, pillIcon)`.
  static const selectedPrefix = 'sel-';

  /// The `pillIcon` GeoJSON property value for [cafe]: the image id its pill
  /// layer should render, or '' when the cafe is unrated (dot only).
  static String pillIconFor(CafeSummary cafe) {
    if (cafe.rating <= 0) return '';
    return pillImageId(cafe.rating.toStringAsFixed(1));
  }

  /// Registers a pill image for every distinct rating in [cafes] that hasn't
  /// been registered yet, plus the coffee badge.
  Future<void> ensureImages(
    MapLibreMapController controller,
    List<CafeSummary> cafes,
  ) async {
    if (!_registered.contains(selectedCoffeeImageId)) {
      final bytes = await rasterizeSelectedCoffeePin();
      await controller.addImage(selectedCoffeeImageId, bytes);
      _registered.add(selectedCoffeeImageId);
    }

    final pending = <String, String>{};
    for (final cafe in cafes) {
      if (cafe.rating <= 0) continue;
      final ratingLabel = cafe.rating.toStringAsFixed(1);
      final id = pillImageId(ratingLabel);
      if (_registered.contains(id) || pending.containsKey(id)) continue;
      pending[id] = ratingLabel;
    }

    for (final entry in pending.entries) {
      await controller.addImage(entry.key, await rasterizePill(entry.value));
      await controller.addImage(
        '$selectedPrefix${entry.key}',
        await rasterizePill(entry.value, selected: true),
      );
      _registered.add(entry.key);
    }
  }

  /// Registers the place pin once; safe to call before every use.
  Future<void> ensurePlacePin(MapLibreMapController controller) async {
    if (_registered.contains(placePinImageId)) return;
    await controller.addImage(placePinImageId, await rasterizePlacePin());
    _registered.add(placePinImageId);
  }

  /// Registers the badge for a single cafe with the given [rating] on
  /// [controller] and returns the style-image id to reference from a symbol.
  /// A [rating] of 0 or less registers the coffee badge; otherwise a rating
  /// pill. Used by one-off previews (e.g. the cafe details location map).
  Future<String> registerSingle(
    MapLibreMapController controller,
    double rating,
  ) async {
    if (rating <= 0) {
      if (!_registered.contains(coffeeImageId)) {
        await controller.addImage(coffeeImageId, await rasterizeCoffeePin());
        _registered.add(coffeeImageId);
      }
      return coffeeImageId;
    }

    final ratingLabel = rating.toStringAsFixed(1);
    final id = pillImageId(ratingLabel);
    if (!_registered.contains(id)) {
      await controller.addImage(id, await rasterizePill(ratingLabel));
      _registered.add(id);
    }
    return id;
  }

  /// Stadium pill: star and rating in white on brand green, with a white
  /// outline. 26pt tall at rest; [selected] draws it 34pt tall in near-black.
  /// No pointer tail: the pin is drawn centred on the cafe (`icon-anchor:
  /// center`).
  @visibleForTesting
  Future<Uint8List> rasterizePill(
    String ratingLabel, {
    bool selected = false,
  }) async {
    final ratingStyle = TextStyle(
      color: _textColor,
      fontSize: (selected ? 12 : 10) * scale,
      fontWeight: FontWeight.w600,
      fontFamily: 'Poppins',
    );

    final ratingPainter = _layoutText(ratingLabel, ratingStyle);

    final starSize = (selected ? 12 : 10) * scale;
    final gap = 3 * scale;
    final paddingX = (selected ? 10 : 8) * scale;
    final pillHeight = (selected ? 34 : 26) * scale;
    final borderWidth = (selected ? 2 : 1.5) * scale;
    final shadowPad = 6 * scale;

    final contentWidth = starSize + gap + ratingPainter.width;
    final pillWidth = contentWidth + paddingX * 2;

    final canvasWidth = (pillWidth + borderWidth * 2 + shadowPad * 2).ceil();
    final canvasHeight = (pillHeight + borderWidth * 2 + shadowPad * 2).ceil();

    return _rasterize(canvasWidth, canvasHeight, (canvas) {
      final pillLeft = (canvasWidth - pillWidth) / 2;
      final pillTop = (canvasHeight - pillHeight) / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(pillLeft, pillTop, pillWidth, pillHeight),
        Radius.circular(pillHeight / 2),
      );
      _paintPill(
        canvas,
        rect,
        selected ? _selectedColor : _pillColor,
        borderWidth,
      );

      final starCx = pillLeft + paddingX + starSize / 2;
      final starCy = pillTop + pillHeight / 2;
      _drawStar(canvas, starCx, starCy, starSize / 2);

      final textX = pillLeft + paddingX + starSize + gap;
      final centerY = pillTop + pillHeight / 2 + scale * 0.5;
      ratingPainter.paint(
        canvas,
        Offset(textX, centerY - ratingPainter.height / 2),
      );
    });
  }

  void _paintPill(ui.Canvas canvas, RRect rect, Color fill, double border) {
    canvas.drawRRect(
      rect.shift(Offset(0, 2 * scale)),
      Paint()
        ..color = _shadowColor
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 3 * scale),
    );
    canvas.drawRRect(rect.inflate(border), Paint()..color = _strokeColor);
    canvas.drawRRect(rect, Paint()..color = fill);
  }

  /// Green coffee badge with a pointer tail, for one-off previews of an
  /// unrated cafe ([registerSingle]). The map tab's selected unrated pin is
  /// [rasterizeSelectedCoffeePin].
  @visibleForTesting
  Future<Uint8List> rasterizeCoffeePin() async {
    final diameter = 32 * scale;
    final tailHeight = 9 * scale;
    final tailHalfWidth = 7 * scale;
    final borderWidth = 2.5 * scale;
    final shadowPad = 6 * scale;

    final canvasWidth = (diameter + borderWidth * 2 + shadowPad * 2).ceil();
    final canvasHeight =
        (diameter + tailHeight + borderWidth * 2 + shadowPad * 2).ceil();

    return _rasterize(canvasWidth, canvasHeight, (canvas) {
      final circleLeft = (canvasWidth - diameter) / 2;
      final circleTop = shadowPad + borderWidth;

      final path = _badgePath(
        left: circleLeft,
        top: circleTop,
        width: diameter,
        height: diameter,
        centerX: canvasWidth / 2,
        tailHeight: tailHeight,
        tailHalfWidth: tailHalfWidth,
      );
      _paintBadge(canvas, path);

      final iconSize = 15 * scale;
      // Phosphor glyphs use a 256x256 viewBox; scale down to icon size.
      final s = iconSize / 256;
      final icon = _parseSvgPath(_coffeeIconPath).transform(
        Float64List.fromList([
          s, 0, 0, 0, //
          0, s, 0, 0, //
          0, 0, 1, 0, //
          0, 0, 0, 1, //
        ]),
      );
      canvas.save();
      canvas.translate(
        canvasWidth / 2 - iconSize / 2,
        circleTop + diameter / 2 - iconSize / 2,
      );
      canvas.drawPath(icon, Paint()..color = _textColor);
      canvas.restore();
    });
  }

  /// Selected unrated cafe: a 38pt #0A0F0D circle with a 2pt white stroke
  /// drawn inside it, a 16pt Lucide coffee cup, and the pins' shadow. No
  /// tail: it is drawn centred on the cafe, like the rating pills.
  @visibleForTesting
  Future<Uint8List> rasterizeSelectedCoffeePin() async {
    final diameter = 38 * scale;
    final strokeWidth = 2 * scale;
    final shadowPad = 8 * scale;
    final size = (diameter + shadowPad * 2).ceil();

    return _rasterize(size, size, (canvas) {
      final center = Offset(size / 2, size / 2);
      final radius = diameter / 2;
      // Figma drop shadow: y 2, blur 6 (sigma 3), black at 20%.
      canvas.drawCircle(
        center.translate(0, 2 * scale),
        radius,
        Paint()
          ..color = const Color.fromRGBO(0, 0, 0, 0.20)
          ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 3 * scale),
      );
      canvas.drawCircle(center, radius, Paint()..color = _strokeColor);
      canvas.drawCircle(
        center,
        radius - strokeWidth,
        Paint()..color = _selectedColor,
      );
      _paintIcon(canvas, LucideIcons.coffee, center, 16 * scale, _iconColor);
    });
  }

  /// The chosen place: a 40pt Lucide map pin in brand green. Drawn with its
  /// tip on the place (`icon-anchor: bottom`), so the canvas ends at the
  /// glyph's bottom edge.
  @visibleForTesting
  Future<Uint8List> rasterizePlacePin() async {
    final size = (40 * scale).ceil();
    return _rasterize(size, size, (canvas) {
      _paintIcon(
        canvas,
        LucideIcons.mapPin,
        Offset(size / 2, size / 2),
        40 * scale,
        _pillColor,
      );
    });
  }

  /// Paints an icon-font glyph [size] tall, centred on [center].
  void _paintIcon(
    ui.Canvas canvas,
    IconData icon,
    Offset center,
    double size,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: size,
          height: 1,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
    painter.dispose();
  }

  Future<Uint8List> _rasterize(
    int width,
    int height,
    void Function(ui.Canvas canvas) draw,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );
    draw(canvas);
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  /// Rounded badge (stadium or circle) with a pointer tail at bottom-center.
  ui.Path _badgePath({
    required double left,
    required double top,
    required double width,
    required double height,
    required double centerX,
    required double tailHeight,
    required double tailHalfWidth,
  }) {
    final radius = height / 2;
    final bottom = top + height;

    final path = ui.Path();
    path.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, width, height),
        Radius.circular(radius),
      ),
    );

    // Anchor the tail's base corners on the badge outline so the pointer reads
    // identically for both shapes: a stadium's flat bottom keeps them at
    // `bottom`, a circle raises them onto the corner arc (no "shoulders").
    final flatHalf = (width / 2) - radius;
    final o = math.min(tailHalfWidth - flatHalf, radius);
    final baseY = o <= 0
        ? bottom
        : (bottom - radius) + math.sqrt(radius * radius - o * o);

    final tail = ui.Path()
      ..moveTo(centerX - tailHalfWidth, baseY)
      ..lineTo(centerX, bottom + tailHeight)
      ..lineTo(centerX + tailHalfWidth, baseY)
      ..close();
    return ui.Path.combine(ui.PathOperation.union, path, tail);
  }

  void _paintBadge(ui.Canvas canvas, ui.Path path) {
    canvas.drawPath(
      path.shift(Offset(0, 2 * scale)),
      Paint()
        ..color = _shadowColor
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 2.5 * scale),
    );
    canvas.drawPath(path, Paint()..color = _pillColor);
  }

  void _drawStar(ui.Canvas canvas, double cx, double cy, double radius) {
    const spikes = 5;
    final innerRadius = radius * 0.45;
    var rot = math.pi / 2 * 3;
    const step = math.pi / spikes;

    final path = ui.Path()..moveTo(cx, cy - radius);
    for (var i = 0; i < spikes; i++) {
      path.lineTo(cx + math.cos(rot) * radius, cy + math.sin(rot) * radius);
      rot += step;
      path.lineTo(
        cx + math.cos(rot) * innerRadius,
        cy + math.sin(rot) * innerRadius,
      );
      rot += step;
    }
    path
      ..lineTo(cx, cy - radius)
      ..close();
    canvas.drawPath(path, Paint()..color = _textColor);
  }

  TextPainter _layoutText(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    return painter;
  }

  /// Minimal SVG path-data parser covering the commands Phosphor glyph paths
  /// use (M, L, H, V, A→arcs via arcToPoint, C, Z and lowercase variants).
  static ui.Path _parseSvgPath(String data) {
    final path = ui.Path();
    final tokens = RegExp(
      r'[MmLlHhVvCcSsQqTtAaZz]|-?\d*\.?\d+(?:e[+-]?\d+)?',
    ).allMatches(data).map((m) => m.group(0)!).toList();

    var i = 0;
    var command = '';
    double x = 0, y = 0;
    double startX = 0, startY = 0;
    double prevCx = 0, prevCy = 0;
    var prevWasCurve = false;

    double read() => double.parse(tokens[i++]);

    while (i < tokens.length) {
      final token = tokens[i];
      if (RegExp(r'^[A-Za-z]$').hasMatch(token)) {
        command = token;
        i++;
        if (command == 'Z' || command == 'z') {
          path.close();
          x = startX;
          y = startY;
          prevWasCurve = false;
          continue;
        }
      }
      final relative = command.toLowerCase() == command;
      switch (command.toUpperCase()) {
        case 'M':
          final nx = read(), ny = read();
          x = relative ? x + nx : nx;
          y = relative ? y + ny : ny;
          path.moveTo(x, y);
          startX = x;
          startY = y;
          // Subsequent coordinate pairs are implicit LineTos.
          command = relative ? 'l' : 'L';
          prevWasCurve = false;
        case 'L':
          final nx = read(), ny = read();
          x = relative ? x + nx : nx;
          y = relative ? y + ny : ny;
          path.lineTo(x, y);
          prevWasCurve = false;
        case 'H':
          final nx = read();
          x = relative ? x + nx : nx;
          path.lineTo(x, y);
          prevWasCurve = false;
        case 'V':
          final ny = read();
          y = relative ? y + ny : ny;
          path.lineTo(x, y);
          prevWasCurve = false;
        case 'C':
          final c1x = relative ? x + read() : read();
          final c1y = relative ? y + read() : read();
          final c2x = relative ? x + read() : read();
          final c2y = relative ? y + read() : read();
          final nx = relative ? x + read() : read();
          final ny = relative ? y + read() : read();
          path.cubicTo(c1x, c1y, c2x, c2y, nx, ny);
          prevCx = c2x;
          prevCy = c2y;
          x = nx;
          y = ny;
          prevWasCurve = true;
        case 'S':
          final c1x = prevWasCurve ? 2 * x - prevCx : x;
          final c1y = prevWasCurve ? 2 * y - prevCy : y;
          final c2x = relative ? x + read() : read();
          final c2y = relative ? y + read() : read();
          final nx = relative ? x + read() : read();
          final ny = relative ? y + read() : read();
          path.cubicTo(c1x, c1y, c2x, c2y, nx, ny);
          prevCx = c2x;
          prevCy = c2y;
          x = nx;
          y = ny;
          prevWasCurve = true;
        case 'A':
          final rx = read(), ry = read();
          final rotation = read();
          final largeArc = read() != 0;
          final sweep = read() != 0;
          final nx = relative ? x + read() : read();
          final ny = relative ? y + read() : read();
          path.arcToPoint(
            Offset(nx, ny),
            radius: Radius.elliptical(rx, ry),
            rotation: rotation,
            largeArc: largeArc,
            clockwise: sweep,
          );
          x = nx;
          y = ny;
          prevWasCurve = false;
        default:
          // Unsupported command (Q/T not used by Phosphor glyphs): skip its
          // numeric arguments defensively.
          while (i < tokens.length &&
              !RegExp(r'^[A-Za-z]$').hasMatch(tokens[i])) {
            i++;
          }
          prevWasCurve = false;
      }
    }
    return path;
  }
}
