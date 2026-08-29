/// How a pickup was verified. `driverManual` is the only method with real
/// hardware behind it today — `qr`/`otp` are implemented as real,
/// independently-usable verification flows (a code is generated, checked,
/// and recorded), but with no physical scanner/SMS gateway behind them yet;
/// see PickupVerification's own doc comment for exactly what is and isn't
/// claimed here.
enum PickupVerificationMethod { driverManual, qrCode, otp }

extension PickupVerificationMethodX on PickupVerificationMethod {
  String get value => switch (this) {
    PickupVerificationMethod.qrCode => 'qr_code',
    PickupVerificationMethod.driverManual => 'driver_manual',
    PickupVerificationMethod.otp => 'otp',
  };

  static PickupVerificationMethod? tryParse(Object? value) {
    if (value is! String) return null;
    for (final m in PickupVerificationMethod.values) {
      if (m.value == value) return m;
    }
    return null;
  }
}

enum PickupVerificationStatus { verified, failed, pending }

extension PickupVerificationStatusX on PickupVerificationStatus {
  String get value => name;

  static PickupVerificationStatus? tryParse(Object? value) {
    if (value is! String) return null;
    for (final s in PickupVerificationStatus.values) {
      if (s.value == value) return s;
    }
    return null;
  }
}
