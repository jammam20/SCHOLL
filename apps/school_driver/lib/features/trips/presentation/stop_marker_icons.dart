import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// What a stop pin on the driver's own route map is currently saying.
/// Mirrors `StopMarkerState` in the parent app's `map_marker_icons.dart` —
/// each state gets a different **shape and symbol**, not just a colour, so
/// it reads at a glance regardless of colour vision.
enum DriverStopMarkerState { pending, current, boarded, droppedOff, school }

/// Numbered, state-coloured stop pins for the driver's own route-overview
/// map — the same visual language as the admin fleet map's
/// `StopMarkerFactory` and the parent app's `MapMarkerIcons.stop`, drawn
/// here from scratch rather than shared through `school_shared` (this app
/// already depends on `google_maps_flutter` on its own, and a three-way
/// shared marker-drawing dependency would be a bigger change than this
/// map upgrade calls for).
class DriverStopMarkerIcons {
  DriverStopMarkerIcons._();

  static final Map<String, BitmapDescriptor> _cache = {};
  static final Set<String> _pending = {};

  static String _key(int number, DriverStopMarkerState state, Color color, double ratio) =>
      '$number:${state.name}:${color.toARGB32()}:${ratio.toStringAsFixed(2)}';

  static BitmapDescriptor? cached({
    required int number,
    required DriverStopMarkerState state,
    required Color color,
    required double devicePixelRatio,
  }) => _cache[_key(number, state, color, devicePixelRatio)];

  static Future<void> prepare({
    required int number,
    required DriverStopMarkerState state,
    required Color color,
    required double devicePixelRatio,
  }) async {
    final key = _key(number, state, color, devicePixelRatio);
    if (_cache.containsKey(key) || !_pending.add(key)) return;
    try {
      await _render(key, number, state, color, devicePixelRatio);
    } finally {
      _pending.remove(key);
    }
  }

  static Future<void> _render(
    String key,
    int number,
    DriverStopMarkerState state,
    Color color,
    double devicePixelRatio,
  ) async {
    final isCurrent = state == DriverStopMarkerState.current;
    final logicalSize = isCurrent ? 46.0 : 34.0;
    final size = logicalSize * devicePixelRatio;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);
    final radius = (34.0 * devicePixelRatio) / 2;

    if (isCurrent) {
      canvas.drawCircle(
        center,
        radius + 6 * devicePixelRatio,
        Paint()..color = color.withValues(alpha: 0.20),
      );
    }

    canvas.drawCircle(
      center,
      radius,
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );
    canvas.drawCircle(
      center,
      radius - 2.5 * devicePixelRatio,
      Paint()..color = color,
    );

    if (state == DriverStopMarkerState.droppedOff) {
      canvas.drawCircle(
        center,
        radius - 7.0 * devicePixelRatio,
        Paint()..color = Colors.white,
      );
    }

    switch (state) {
      case DriverStopMarkerState.boarded:
        final check = Path()
          ..moveTo(center.dx - 6 * devicePixelRatio, center.dy + 0.3 * devicePixelRatio)
          ..lineTo(center.dx - 1.8 * devicePixelRatio, center.dy + 4.8 * devicePixelRatio)
          ..lineTo(center.dx + 6.5 * devicePixelRatio, center.dy - 4.6 * devicePixelRatio);
        canvas.drawPath(
          check,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3 * devicePixelRatio
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      case DriverStopMarkerState.school:
        _drawSchoolGlyph(canvas, center, devicePixelRatio, Colors.white);
      case DriverStopMarkerState.droppedOff:
      case DriverStopMarkerState.pending:
      case DriverStopMarkerState.current:
        final ink = state == DriverStopMarkerState.droppedOff
            ? color
            : Colors.white;
        _drawCenteredText(canvas, '$number', center, ink, 15 * devicePixelRatio);
    }

    final image = await recorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) return;

    _cache[key] = BitmapDescriptor.bytes(
      bytes.buffer.asUint8List(),
      width: logicalSize,
      height: logicalSize,
    );
  }

  static void _drawSchoolGlyph(
    Canvas canvas,
    Offset center,
    double ratio,
    Color color,
  ) {
    final roof = Path()
      ..moveTo(center.dx, center.dy - 7 * ratio)
      ..lineTo(center.dx + 7 * ratio, center.dy - 1 * ratio)
      ..lineTo(center.dx - 7 * ratio, center.dy - 1 * ratio)
      ..close();
    canvas.drawPath(roof, Paint()..color = color);
    canvas.drawRect(
      Rect.fromLTRB(
        center.dx - 5 * ratio,
        center.dy - 1 * ratio,
        center.dx + 5 * ratio,
        center.dy + 6 * ratio,
      ),
      Paint()..color = color,
    );
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
}
