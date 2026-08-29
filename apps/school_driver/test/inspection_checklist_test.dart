import 'package:flutter_test/flutter_test.dart';
import 'package:school_driver/features/inspections/domain/inspection_checklist.dart';

Map<String, bool> allPassing() => {
  for (final item in InspectionItem.values) item.value: true,
};

void main() {
  group('isInspectionPassed', () {
    test('passes only when every listed item passes', () {
      expect(isInspectionPassed(allPassing()), isTrue);
    });

    test('any single failed item fails the whole inspection', () {
      for (final item in InspectionItem.values) {
        final items = allPassing()..[item.value] = false;
        expect(
          isInspectionPassed(items),
          isFalse,
          reason: 'failing ${item.value} must fail the inspection',
        );
      }
    });

    test('a missing answer counts as a fail, never as an assumed pass', () {
      for (final item in InspectionItem.values) {
        final items = allPassing()..remove(item.value);
        expect(
          isInspectionPassed(items),
          isFalse,
          reason: 'unanswered ${item.value} must not pass',
        );
      }
    });

    test('an empty checklist does not pass', () {
      expect(isInspectionPassed(const {}), isFalse);
    });

    test('unknown extra keys cannot substitute for a real item', () {
      final items = allPassing()
        ..remove(InspectionItem.brakes.value)
        ..['not_a_real_item'] = true;
      expect(isInspectionPassed(items), isFalse);
    });
  });

  group('failedInspectionItems', () {
    test('is empty for a fully passing checklist', () {
      expect(failedInspectionItems(allPassing()), isEmpty);
    });

    test('names both failed and unanswered items, in checklist order', () {
      final items = allPassing()
        ..[InspectionItem.tires.value] = false
        ..remove(InspectionItem.doors.value);
      expect(failedInspectionItems(items), [
        InspectionItem.tires,
        InspectionItem.doors,
      ]);
    });
  });

  group('wire values', () {
    test('multi-word items use snake_case, matching other enums', () {
      expect(InspectionItem.emergencyEquipment.value, 'emergency_equipment');
      expect(InspectionItem.brakes.value, 'brakes');
    });

    test('inspection type round-trips through its stored value', () {
      for (final type in InspectionType.values) {
        expect(InspectionTypeX.tryParse(type.value), type);
      }
      expect(InspectionTypeX.tryParse('nonsense'), isNull);
      expect(InspectionTypeX.tryParse(null), isNull);
    });

    test('inspection item round-trips through its stored value', () {
      for (final item in InspectionItem.values) {
        expect(InspectionItemX.tryParse(item.value), item);
      }
      expect(InspectionItemX.tryParse('nonsense'), isNull);
    });
  });
}
