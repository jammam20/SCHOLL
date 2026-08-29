import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../domain/trip_path.dart';

/// Draws numbered, state-coloured stop pins for the live-ops map.
///
/// Google Maps' built-in [BitmapDescriptor.defaultMarkerWithHue] can only
/// vary hue — it can't carry a stop's number, and the whole point of the
/// map upgrade is that an admin can see the expected path *in order*. So
/// each pin is rendered once onto a canvas and cached: a filled circle in
/// the stop's state colour with its 1-based sequence number in the middle.
///
/// Bitmaps are cached process-wide by (number, state, colour, ratio) — a
/// trip's stops don't change often, and regenerating a pin on every camera
/// move would be needlessly expensive.
class StopMarkerFactory {
  StopMarkerFactory._();

  static final Map<String, BitmapDescriptor> _cache = {};

  static String _key(int number, TripStopProgress progress, Color color, double ratio) =>
      '$number:${progress.name}:${color.toARGB32()}:${ratio.toStringAsFixed(2)}';

  /// Returns the cached pin if one exists, otherwise null — callers render
  /// with what's cached and repaint once [prepare] resolves, so building
  /// the marker set itself stays synchronous.
  static BitmapDescriptor? cached({
    required int number,
    required TripStopProgress progress,
    required Color color,
    required double devicePixelRatio,
  }) => _cache[_key(number, progress, color, devicePixelRatio)];

  /// Renders and caches one pin. Safe to call repeatedly for the same
  /// inputs — the second call is a cache hit and does no drawing.
  static Future<void> prepare({
    required int number,
    required TripStopProgress progress,
    required Color color,
    required double devicePixelRatio,
  }) async {
    final key = _key(number, progress, color, devicePixelRatio);
    if (_cache.containsKey(key)) return;

    final size = 34.0 * devicePixelRatio;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);
    final radius = size / 2;

    // A soft halo so a pin stays legible against dark satellite imagery
    // and light street tiles alike.
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

    // A dropped-off stop is drawn as a ring rather than a solid disc, so
    // the three states differ by *shape* as well as colour — colour alone
    // would be the only signal for a colour-blind admin.
    if (progress == TripStopProgress.droppedOff) {
      canvas.drawCircle(
        center,
        radius - 7.0 * devicePixelRatio,
        Paint()..color = Colors.white,
      );
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: '$number',
        style: TextStyle(
          color: progress == TripStopProgress.droppedOff ? color : Colors.white,
          fontSize: 15 * devicePixelRatio,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );

    final image = await recorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) return;

    _cache[key] = BitmapDescriptor.bytes(
      bytes.buffer.asUint8List(),
      width: 34,
      height: 34,
    );
  }
}
