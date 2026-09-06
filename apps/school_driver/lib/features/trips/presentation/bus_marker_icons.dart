import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// The driver's own bus marker on their route-overview map: a real bus
/// silhouette (body, windshield band, wheels), drawn pointing north so
/// `Marker.rotation` can turn it to the live GPS heading — the same visual
/// language as the parent app's `MapMarkerIcons.bus` and the admin app's
/// `BusMarkerIcons.bus`, each its own small file rather than a shared
/// `google_maps_flutter` dependency added to `school_shared`.
class DriverBusMarkerIcon {
  DriverBusMarkerIcon._();

  static BitmapDescriptor? _cached;
  static double? _cachedRatio;
  static int? _cachedColor;
  static bool _rendering = false;

  /// Returns the cached bitmap if one has already been rendered for this
  /// colour/ratio, so building a frame stays synchronous.
  static BitmapDescriptor? cached({
    required Color color,
    required double devicePixelRatio,
  }) {
    if (_cached == null ||
        _cachedRatio != devicePixelRatio ||
        _cachedColor != color.toARGB32()) {
      return null;
    }
    return _cached;
  }

  static Future<void> prepare({
    required Color color,
    required double devicePixelRatio,
  }) async {
    if (_cached != null &&
        _cachedRatio == devicePixelRatio &&
        _cachedColor == color.toARGB32()) {
      return;
    }
    if (_rendering) return;
    _rendering = true;

    try {
      const logicalSize = 44.0;
      final ratio = devicePixelRatio.isFinite && devicePixelRatio > 0
          ? devicePixelRatio.clamp(1.0, 4.0)
          : 1.0;
      final pixels = (logicalSize * ratio).round();

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.scale(ratio);
      _paint(canvas, logicalSize, color);

      final image = await recorder.endRecording().toImage(pixels, pixels);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes == null) return;
        _cached = BitmapDescriptor.bytes(
          bytes.buffer.asUint8List(),
          imagePixelRatio: ratio,
        );
        _cachedRatio = devicePixelRatio;
        _cachedColor = color.toARGB32();
      } finally {
        image.dispose();
      }
    } finally {
      _rendering = false;
    }
  }

  static void _paint(Canvas canvas, double size, Color color) {
    final center = Offset(size / 2, size / 2);

    canvas.drawCircle(
      center.translate(0, 2),
      17,
      Paint()
        ..color = const Color(0xFF000000).withValues(alpha: 0.20)
        ..maskFilter = const ui.MaskFilter.blur(BlurStyle.normal, 4),
    );

    canvas.drawCircle(center, 20, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      20,
      Paint()
        ..color = color.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

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

    final windshield = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center.translate(0, -7.2), width: 13, height: 5.5),
      const Radius.circular(2),
    );
    canvas.drawRRect(windshield, Paint()..color = Colors.white);

    for (final dy in [-0.5, 5.5]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center.translate(0, dy), width: 13, height: 4),
          const Radius.circular(1.5),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
    }

    canvas.drawRect(
      Rect.fromCenter(center: center.translate(0, 10.5), width: 17, height: 1.6),
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );

    final wheelPaint = Paint()..color = const Color(0xFF1F2430);
    for (final dx in [-7.2, 7.2]) {
      canvas.drawCircle(center.translate(dx, 10.5), 2.6, wheelPaint);
    }
  }
}
