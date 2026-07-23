import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/painting.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';

/// Rasterizes the map pin badges and registers them as style images —
/// port of the webapp's `drawPillCanvas` / `buildCoffeePinCanvas`
/// (nook-webapp `CafeMap.tsx`).
///
/// Rated cafes get a stadium "pill" (star + rating + pointer tail); unrated
/// cafes get a circular coffee badge when selected. One image is registered
/// per distinct rating and cached for the lifetime of the map style.
class MapPinImages {
  MapPinImages({required this.scale});

  /// Supersampling factor. Draw at this multiple of the logical size and
  /// compensate through the layer's icon-size (see [iconSizeFor]).
  final double scale;

  final Set<String> _registered = {};

  static const coffeeImageId = 'coffee-pin';

  static const _pillColor = Color(0xFF2D6A4F);
  static const _textColor = Color(0xFFFFFFFF);
  static const _shadowColor = Color.fromRGBO(15, 35, 20, 0.35);

  // Phosphor "Coffee" (regular weight) glyph path, viewBox 0 0 256 256 —
  // same path the webapp embeds.
  static const _coffeeIconPath =
      'M80,56V24a8,8,0,0,1,16,0V56a8,8,0,0,1-16,0Zm40,8a8,8,0,0,0,8-8V24a8,8,0,0,0-16,0V56A8,8,0,0,0,120,64Zm32,0a8,8,0,0,0,8-8V24a8,8,0,0,0-16,0V56A8,8,0,0,0,152,64Zm96,56v8a40,40,0,0,1-37.51,39.91,96.59,96.59,0,0,1-27,40.09H208a8,8,0,0,1,0,16H32a8,8,0,0,1,0-16H56.54A96.3,96.3,0,0,1,24,136V88a8,8,0,0,1,8-8H208A40,40,0,0,1,248,120ZM200,96H40v40a80.27,80.27,0,0,0,45.12,72h69.76A80.27,80.27,0,0,0,200,136Zm32,24a24,24,0,0,0-16-22.62V136a95.78,95.78,0,0,1-1.2,15A24,24,0,0,0,232,128Z';

  static String pillImageId(String ratingLabel) => 'pill-$ratingLabel';

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
    if (!_registered.contains(coffeeImageId)) {
      final bytes = await rasterizeCoffeePin();
      await controller.addImage(coffeeImageId, bytes);
      _registered.add(coffeeImageId);
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
      final bytes = await rasterizePill(entry.value);
      await controller.addImage(entry.key, bytes);
      _registered.add(entry.key);
    }
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

  /// Stadium pill with star, rating text, and a pointer tail. The tail tip
  /// lines up with `icon-anchor: bottom` (minus the shadow pad).
  @visibleForTesting
  Future<Uint8List> rasterizePill(String ratingLabel) async {
    final ratingStyle = TextStyle(
      color: _textColor,
      fontSize: 15 * scale,
      fontWeight: FontWeight.w500,
      fontFamily: 'Poppins',
    );

    final ratingPainter = _layoutText(ratingLabel, ratingStyle);

    final starSize = 12 * scale;
    final gap = 5 * scale;
    final paddingX = 12 * scale;
    final pillHeight = 32 * scale;
    final tailHeight = 9 * scale;
    final tailHalfWidth = 7 * scale;
    final borderWidth = 2.5 * scale;
    final shadowPad = 6 * scale;

    final contentWidth = starSize + gap + ratingPainter.width;
    final pillWidth = contentWidth + paddingX * 2;

    final canvasWidth = (pillWidth + borderWidth * 2 + shadowPad * 2).ceil();
    final canvasHeight =
        (pillHeight + tailHeight + borderWidth * 2 + shadowPad * 2).ceil();

    return _rasterize(canvasWidth, canvasHeight, (canvas) {
      final pillLeft = (canvasWidth - pillWidth) / 2;
      final pillTop = shadowPad + borderWidth;

      final path = _badgePath(
        left: pillLeft,
        top: pillTop,
        width: pillWidth,
        height: pillHeight,
        centerX: canvasWidth / 2,
        tailHeight: tailHeight,
        tailHalfWidth: tailHalfWidth,
      );
      _paintBadge(canvas, path);

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

  /// Circular coffee badge shown for selected unrated cafes — same pin
  /// silhouette as the rating pill but with a centered coffee glyph.
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
