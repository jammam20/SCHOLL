import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Draws the fleet-map's bus marker: a real bus silhouette (body, windshield
/// band, wheels) rather than a generic colour-hue pin, so an admin scanning
/// a map full of markers can tell "that's a bus" at a glance the way they
/// could with `BitmapDescriptor.defaultMarkerWithHue` for nothing more than
/// a coloured teardrop.
///
/// Drawn pointing north (the body's "front" is the top edge) so
/// `Marker.rotation` can turn it to the driver's real GPS heading, exactly
/// like `MapMarkerIcons.bus` in the parent app — the two are independent
/// files (each app already draws its own marker bitmaps rather than sharing
/// a `google_maps_flutter` dependency through `school_shared`) but use the
/// same visual language on purpose.
class BusMarkerIcons {
  BusMarkerIcons._();

  static final Map<String, BitmapDescriptor> _cache = {};

  /// Guards against the live-ops map's per-frame marker chase kicking off
  /// a redundant render for a bitmap that's already being rasterized —
  /// see `StopMarkerFactory`'s identical guard for why this matters once a
  /// map is driven by a repeating ticker rather than a one-off rebuild.
  static final Set<String> _pending = {};

  static String _key(Color color, double ratio) =>
      '${color.toARGB32()}:${ratio.toStringAsFixed(2)}';

  /// Returns the cached bitmap for this colour if one has already been
  /// rendered, so building a frame's marker set stays synchronous.
  static BitmapDescriptor? cached({
    required Color color,
    required double devicePixelRatio,
  }) => _cache[_key(color, devicePixelRatio)];

  /// Renders and caches one bus bitmap. Safe to call repeatedly — a cache
  /// hit does no drawing.
  static Future<void> prepare({
    required Color color,
    required double devicePixelRatio,
  }) async {
    final key = _key(color, devicePixelRatio);
    if (_cache.containsKey(key) || !_pending.add(key)) return;

    try {
      const logicalSize = 44.0;
      final ratio = devicePixelRatio.isFinite && devicePixelRatio > 0
          ? devicePixelRatio.clamp(1.0, 4.0)
          : 1.0;
      final pixels = (logicalSize * ratio).round();

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.scale(ratio);
      _paintBus(canvas, logicalSize, color);

      final image = await recorder.endRecording().toImage(pixels, pixels);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes == null) return;
        _cache[key] = BitmapDescriptor.bytes(
          bytes.buffer.asUint8List(),
          imagePixelRatio: ratio,
        );
      } finally {
        image.dispose();
      }
    } finally {
      _pending.remove(key);
    }
  }

  static void _paintBus(Canvas canvas, double size, Color color) {
    final center = Offset(size / 2, size / 2);

    // Ground shadow first, so the bus reads as floating above the map.
    canvas.drawCircle(
      center.translate(0, 2),
      17,
      Paint()
        ..color = const Color(0xFF000000).withValues(alpha: 0.20)
        ..maskFilter = const ui.MaskFilter.blur(BlurStyle.normal, 4),
    );

    // White halo disc behind the bus body — legible against dark satellite
    // tiles and light street tiles alike.
    canvas.drawCircle(center, 20, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      20,
      Paint()
        ..color = color.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // The bus body: a rounded rectangle, long axis vertical (north/south),
    // so "forward" is unambiguous once rotated to the real heading.
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 19, height: 25),
      const Radius.circular(5),
    );
    canvas.drawRRect(body, Paint()..color = color);
    canvas.drawRRect(
      body.deflate(0.8),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Windshield band at the front (top): tells the eye which end leads
    // even before the map has turned the bitmap to the live heading.
    final windshield = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center.translate(0, -7.2),
        width: 13,
        height: 5.5,
      ),
      const Radius.circular(2),
    );
    canvas.drawRRect(windshield, Paint()..color = Colors.white);

    // Two side windows.
    for (final dy in [-0.5, 5.5]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center.translate(0, dy), width: 13, height: 4),
          const Radius.circular(1.5),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
    }

    // A thin waistline stripe, the way a real school-bus livery reads even
    // at this scale.
    canvas.drawRect(
      Rect.fromCenter(center: center.translate(0, 10.5), width: 17, height: 1.6),
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );

    // Wheels, peeking out from under the body.
    final wheelPaint = Paint()..color = const Color(0xFF1F2430);
    for (final dx in [-7.2, 7.2]) {
      canvas.drawCircle(center.translate(dx, 10.5), 2.6, wheelPaint);
    }
  }
}
