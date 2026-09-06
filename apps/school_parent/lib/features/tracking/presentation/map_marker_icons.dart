import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// What a stop marker is currently saying about *this child's* own stop.
/// Each value is drawn with a different **shape and symbol**, not only a
/// different color — a parent with a color-vision deficiency still has to
/// be able to tell "the bus hasn't reached my child yet" from "my child is
/// already on board" at a glance (`design-system/MASTER.md` §12).
enum StopMarkerState {
  /// Still ahead of the bus: hollow circle, stop number inside.
  pending,

  /// Still ahead and it's the *next* stop the bus will reach: filled
  /// circle with a halo, stop number inside.
  next,

  /// The driver marked this child boarded: filled circle, check mark.
  boarded,

  /// The driver marked this child dropped off: filled circle, down arrow.
  droppedOff,
}

/// Marker bitmaps drawn on a [Canvas] at request time rather than shipped
/// as image assets.
///
/// Why draw instead of adding PNGs: the icons have to pick up the live
/// theme (light/dark token colors) and to carry a *number* that comes from
/// the trip's real stop order — neither of which a fixed asset can do —
/// and the alternative (bundling a sprite sheet per color per digit) would
/// add files and a pubspec entry for something the framework can rasterize
/// in under a millisecond. Everything here is plain geometry and digits: no
/// icon-font glyphs, so nothing depends on `--tree-shake-icons` keeping a
/// dynamically-referenced code point alive in a release web build.
///
/// Results are cached by the caller (see `_MarkerIconCache` in
/// live_trip_map.dart) because a rebuild happens on every GPS tick and the
/// icons only change when the theme, the stop number or the stop's state
/// does.
class MapMarkerIcons {
  MapMarkerIcons._();

  /// The bus itself: a real bus silhouette (body, windshield band, wheels)
  /// on a soft halo disc, drawn pointing north so the map's own
  /// `Marker.rotation` can turn it to the driver's real GPS heading.
  static Future<BitmapDescriptor> bus({
    required Color color,
    required Color onColor,
    required double devicePixelRatio,
  }) {
    const size = 46.0;
    return _render(size, devicePixelRatio, (canvas) {
      const center = Offset(size / 2, size / 2);

      // Soft ground shadow so the bus reads as being *above* the map,
      // not painted onto it.
      canvas.drawCircle(
        center.translate(0, 2),
        17,
        Paint()
          ..color = const Color(0xFF000000).withValues(alpha: 0.20)
          ..maskFilter = const ui.MaskFilter.blur(BlurStyle.normal, 4),
      );

      canvas.drawCircle(center, 20, Paint()..color = onColor);
      canvas.drawCircle(
        center,
        20,
        Paint()
          ..color = color.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      // The bus body: a rounded rectangle, long axis vertical, so
      // "forward" is unambiguous once rotated to the real heading.
      final body = RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: 19, height: 25),
        const Radius.circular(5),
      );
      canvas.drawRRect(body, Paint()..color = color);
      canvas.drawRRect(
        body.deflate(0.8),
        Paint()
          ..color = onColor.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );

      // Windshield band at the front (top).
      final windshield = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center.translate(0, -7.2),
          width: 13,
          height: 5.5,
        ),
        const Radius.circular(2),
      );
      canvas.drawRRect(windshield, Paint()..color = onColor);

      // Two side windows.
      for (final dy in [-0.5, 5.5]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: center.translate(0, dy), width: 13, height: 4),
            const Radius.circular(1.5),
          ),
          Paint()..color = onColor.withValues(alpha: 0.85),
        );
      }

      // A thin waistline stripe, the way a real school-bus livery reads
      // even at this scale.
      canvas.drawRect(
        Rect.fromCenter(center: center.translate(0, 10.5), width: 17, height: 1.6),
        Paint()..color = onColor.withValues(alpha: 0.9),
      );

      // Wheels, peeking out from under the body.
      final wheelPaint = Paint()..color = const Color(0xFF1F2430);
      for (final dx in [-7.2, 7.2]) {
        canvas.drawCircle(center.translate(dx, 10.5), 2.6, wheelPaint);
      }
    });
  }

  /// This child's own stop. [number] is its 1-based position in today's
  /// real stop order; null when the driver hasn't computed the order yet,
  /// in which case the marker shows a dot instead of inventing a number.
  static Future<BitmapDescriptor> stop({
    required StopMarkerState state,
    required int? number,
    required Color color,
    required Color surface,
    required double devicePixelRatio,
  }) {
    const size = 46.0;
    return _render(size, devicePixelRatio, (canvas) {
      const center = Offset(size / 2, size / 2);
      final filled =
          state == StopMarkerState.next ||
          state == StopMarkerState.boarded ||
          state == StopMarkerState.droppedOff;

      if (state == StopMarkerState.next) {
        canvas.drawCircle(
          center,
          20,
          Paint()..color = color.withValues(alpha: 0.22),
        );
      }

      canvas.drawCircle(
        center.translate(0, 1),
        14,
        Paint()
          ..color = const Color(0xFF000000).withValues(alpha: 0.14)
          ..maskFilter = const ui.MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(center, 14, Paint()..color = surface);
      canvas.drawCircle(center, filled ? 14 : 13.5, Paint()..color = filled ? color : surface);
      canvas.drawCircle(
        center,
        12.5,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );

      final ink = filled ? surface : color;
      switch (state) {
        case StopMarkerState.boarded:
          final check = Path()
            ..moveTo(center.dx - 5.5, center.dy + 0.3)
            ..lineTo(center.dx - 1.6, center.dy + 4.4)
            ..lineTo(center.dx + 6, center.dy - 4.2);
          canvas.drawPath(
            check,
            Paint()
              ..color = ink
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round,
          );
        case StopMarkerState.droppedOff:
          final arrow = Path()
            ..moveTo(center.dx, center.dy - 5.5)
            ..lineTo(center.dx, center.dy + 3.5);
          canvas.drawPath(
            arrow,
            Paint()
              ..color = ink
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..strokeCap = StrokeCap.round,
          );
          final head = Path()
            ..moveTo(center.dx - 4.5, center.dy + 0.6)
            ..lineTo(center.dx, center.dy + 5.8)
            ..lineTo(center.dx + 4.5, center.dy + 0.6)
            ..close();
          canvas.drawPath(head, Paint()..color = ink);
        case StopMarkerState.pending:
        case StopMarkerState.next:
          if (number == null) {
            canvas.drawCircle(center, 4, Paint()..color = ink);
          } else {
            _drawCenteredText(canvas, '$number', center, ink, 13);
          }
      }
    });
  }

  /// The school — every trip's fixed final destination. A **rounded square
  /// with a roof**, so it is distinguishable from the round stop markers by
  /// silhouette alone.
  static Future<BitmapDescriptor> school({
    required Color color,
    required Color surface,
    required double devicePixelRatio,
  }) {
    const size = 46.0;
    return _render(size, devicePixelRatio, (canvas) {
      const center = Offset(size / 2, size / 2);
      final square = RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: 28, height: 28),
        const Radius.circular(9),
      );

      canvas.drawRRect(
        square.shift(const Offset(0, 1)),
        Paint()
          ..color = const Color(0xFF000000).withValues(alpha: 0.16)
          ..maskFilter = const ui.MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawRRect(square, Paint()..color = color);
      canvas.drawRRect(
        square.deflate(1.5),
        Paint()
          ..color = surface
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );

      // A small schoolhouse: roof triangle over a body rectangle.
      final roof = Path()
        ..moveTo(center.dx, center.dy - 7)
        ..lineTo(center.dx + 8, center.dy - 1)
        ..lineTo(center.dx - 8, center.dy - 1)
        ..close();
      canvas.drawPath(roof, Paint()..color = surface);
      canvas.drawRect(
        Rect.fromLTRB(
          center.dx - 5.5,
          center.dy - 1,
          center.dx + 5.5,
          center.dy + 7,
        ),
        Paint()..color = surface,
      );
      canvas.drawRect(
        Rect.fromLTRB(
          center.dx - 1.8,
          center.dy + 1.6,
          center.dx + 1.8,
          center.dy + 7,
        ),
        Paint()..color = color,
      );
    });
  }

  static void _drawCenteredText(
    Canvas canvas,
    String text,
    Offset center,
    Color color,
    double fontSize,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  /// Rasterizes [draw] (which works in logical pixels on a [size]×[size]
  /// square) at the screen's real pixel ratio, then hands the map the PNG
  /// plus that ratio so it lands on screen at the intended physical size on
  /// every display density.
  static Future<BitmapDescriptor> _render(
    double size,
    double devicePixelRatio,
    void Function(Canvas canvas) draw,
  ) async {
    // A ratio of 0 or NaN would produce a zero-pixel image the platform
    // side rejects; clamp to something sane rather than trusting whatever
    // MediaQuery reported.
    final ratio = devicePixelRatio.isFinite && devicePixelRatio > 0
        ? devicePixelRatio.clamp(1.0, 4.0)
        : 1.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(ratio);
    draw(canvas);

    final pixels = (size * ratio).round();
    final image = await recorder.endRecording().toImage(pixels, pixels);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return BitmapDescriptor.bytes(
        bytes!.buffer.asUint8List(),
        imagePixelRatio: ratio.toDouble(),
      );
    } finally {
      image.dispose();
    }
  }
}
