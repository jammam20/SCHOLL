import 'package:school_shared/school_shared.dart';
import 'package:test/test.dart';

void main() {
  group('haversineMeters', () {
    test('is zero for the same point', () {
      expect(haversineMeters(30.0444, 31.2357, 30.0444, 31.2357), 0);
    });

    test('is symmetric', () {
      final a = haversineMeters(30.0444, 31.2357, 31.2001, 29.9187);
      final b = haversineMeters(31.2001, 29.9187, 30.0444, 31.2357);
      expect(a, closeTo(b, 0.0001));
    });

    test('matches a known Cairo-to-Alexandria-ish distance order of magnitude', () {
      // Roughly 180km apart — not asserting an exact figure, just that the
      // great-circle formula is producing a physically sane distance rather
      // than, say, a degrees-as-meters bug.
      final meters = haversineMeters(30.0444, 31.2357, 31.2001, 29.9187);
      expect(meters, greaterThan(150000));
      expect(meters, lessThan(210000));
    });
  });

  group('isValidLatLng', () {
    test('accepts real-world coordinates', () {
      expect(isValidLatLng(30.0444, 31.2357), isTrue);
      expect(isValidLatLng(-33.8688, 151.2093), isTrue);
    });

    test('accepts the exact boundary values', () {
      expect(isValidLatLng(90, 180), isTrue);
      expect(isValidLatLng(-90, -180), isTrue);
      expect(isValidLatLng(0, 0), isTrue);
    });

    test('rejects an out-of-range latitude', () {
      expect(isValidLatLng(90.1, 0), isFalse);
      expect(isValidLatLng(-90.1, 0), isFalse);
    });

    test('rejects an out-of-range longitude', () {
      expect(isValidLatLng(0, 180.1), isFalse);
      expect(isValidLatLng(0, -180.1), isFalse);
    });

    test('rejects a swapped lat/lng that happens to be out of range', () {
      // A common bug shape: passing (longitude, latitude) by mistake.
      expect(isValidLatLng(151.2093, -33.8688), isFalse);
    });
  });
}
