import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Draws the fleet-map's bus marker: a simple, Uber-style directional puck
/// (a solid colour disc with a plain arrow) rather than a generic colour-hue
/// pin or a detailed bus silhouette — a rotated bus body reads as "an odd
/// tilted bus", not "turning that way", whereas a plain arrow's direction is
/// unambiguous at a glance even mid-turn, the same reason a ride-hailing
/// app's live map uses one.
///
/// Drawn pointing north at rest so `Marker.rotation` can turn it to the
/// driver's real GPS heading, exactly like `MapMarkerIcons.bus` in the
/// parent app — the two are independent files (each app already draws its
/// own marker bitmaps rather than sharing a `google_maps_flutter`
/// dependency through `school_shared`) but use the same visual language on
/// purpose.
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

    // Ground shadow first, so the puck reads as floating above the map.
    canvas.drawCircle(
      center.translate(0, 2),
      17,
      Paint()
        ..color = const Color(0xFF000000).withValues(alpha: 0.20)
        ..maskFilter = const ui.MaskFilter.blur(BlurStyle.normal, 4),
    );

    // White halo disc behind the solid colour puck — legible against dark
    // satellite tiles and light street tiles alike.
    canvas.drawCircle(center, 20, Paint()..color = Colors.white);
    canvas.drawCircle(center, 17, Paint()..color = color);
    canvas.drawCircle(
      center,
      17,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // One plain arrow, pointing "forward" (north/up) at rest — the only
    // shape this marker needs, so a rotation always reads as "heading
    // that way" rather than needing to be decoded from a vehicle shape.
    final arrow = Path()
      ..moveTo(center.dx, center.dy - 9)
      ..lineTo(center.dx + 7, center.dy + 6)
      ..lineTo(center.dx, center.dy + 2.5)
      ..lineTo(center.dx - 7, center.dy + 6)
      ..close();
    canvas.drawPath(arrow, Paint()..color = Colors.white);
  }
}
