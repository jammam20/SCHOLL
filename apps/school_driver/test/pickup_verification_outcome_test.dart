import 'package:flutter_test/flutter_test.dart';
import 'package:school_driver/features/pickup_verification/data/pickup_verification_repository.dart';
import 'package:school_shared/school_shared.dart';

void main() {
  group('PickupVerificationRepository.outcomeFor', () {
    test('a driver visual check records what the driver actually observed', () {
      expect(
        PickupVerificationRepository.outcomeFor(
          method: PickupVerificationMethod.driverManual,
          driverConfirmed: true,
        ),
        PickupVerificationStatus.verified,
      );
      expect(
        PickupVerificationRepository.outcomeFor(
          method: PickupVerificationMethod.driverManual,
          driverConfirmed: false,
        ),
        PickupVerificationStatus.failed,
      );
    });

    test('code-based methods never report verified — nothing checks the code yet', () {
      for (final method in [
        PickupVerificationMethod.qrCode,
        PickupVerificationMethod.otp,
      ]) {
        for (final confirmed in [true, false]) {
          expect(
            PickupVerificationRepository.outcomeFor(
              method: method,
              driverConfirmed: confirmed,
            ),
            PickupVerificationStatus.pending,
            reason: '$method must stay pending (driverConfirmed: $confirmed)',
          );
        }
      }
    });
  });
}
