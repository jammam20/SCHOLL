import 'package:flutter_test/flutter_test.dart';
import 'package:school_admin/features/pickup_points/domain/nearest_pickup_point.dart';
import 'package:school_shared/school_shared.dart';

PickupPoint _point(
  String id, {
  required double lat,
  required double lng,
  double radius = 100,
  bool isActive = true,
}) => PickupPoint(
  id: id,
  schoolId: 'school-1',
  name: 'Point $id',
  latitude: lat,
  longitude: lng,
  radiusMeters: radius,
  isActive: isActive,
);

void main() {
  group('rankPickupPointsByDistance', () {
    final points = [
      _point('far', lat: 30.10, lng: 31.0),
      _point('near', lat: 30.001, lng: 31.0),
      _point('mid', lat: 30.01, lng: 31.0),
    ];

    test('orders by straight-line distance, nearest first', () {
      final ranked = rankPickupPointsByDistance(
        studentLatitude: 30.0,
        studentLongitude: 31.0,
        points: points,
      );

      expect(ranked.map((s) => s.point.id), ['near', 'mid', 'far']);
      expect(
        ranked[0].distanceMeters,
        lessThan(ranked[1].distanceMeters),
      );
    });

    test('excludes inactive points', () {
      final ranked = rankPickupPointsByDistance(
        studentLatitude: 30.0,
        studentLongitude: 31.0,
        points: [
          _point('inactive', lat: 30.0, lng: 31.0, isActive: false),
          _point('active', lat: 30.01, lng: 31.0),
        ],
      );

      expect(ranked.map((s) => s.point.id), ['active']);
    });

    test('respects the limit', () {
      final ranked = rankPickupPointsByDistance(
        studentLatitude: 30.0,
        studentLongitude: 31.0,
        points: points,
        limit: 2,
      );

      expect(ranked, hasLength(2));
    });

    test('returns empty when the student has no coordinate', () {
      expect(
        rankPickupPointsByDistance(
          studentLatitude: null,
          studentLongitude: null,
          points: points,
        ),
        isEmpty,
      );
    });

    test('returns empty for an out-of-range coordinate', () {
      expect(
        rankPickupPointsByDistance(
          studentLatitude: 999,
          studentLongitude: 31.0,
          points: points,
        ),
        isEmpty,
      );
    });

    test('withinRadius reflects the point own safe zone', () {
      final ranked = rankPickupPointsByDistance(
        studentLatitude: 30.0,
        studentLongitude: 31.0,
        points: [
          // ~111 m north of the student, so outside a 100 m zone but
          // inside a 500 m one.
          _point('tight', lat: 30.001, lng: 31.0, radius: 100),
          _point('loose', lat: 30.001, lng: 31.0, radius: 500),
        ],
      );

      final tight = ranked.firstWhere((s) => s.point.id == 'tight');
      final loose = ranked.firstWhere((s) => s.point.id == 'loose');
      expect(tight.withinRadius, isFalse);
      expect(loose.withinRadius, isTrue);
    });
  });

  group('formatDistance', () {
    test('uses metres below a kilometre', () {
      expect(formatDistance(420.4), '420 m');
    });

    test('uses one decimal kilometre above', () {
      expect(formatDistance(1550), '1.6 km');
    });
  });
}
