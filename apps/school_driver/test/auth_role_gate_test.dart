import 'package:flutter_test/flutter_test.dart';
import 'package:school_driver/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:school_shared/school_shared.dart';

AppUser _user({
  required UserRole role,
  bool isActive = true,
  bool approved = true,
  MembershipStatus membershipStatus = MembershipStatus.approved,
}) {
  return AppUser(
    uid: 'uid-1',
    schoolId: 'school-1',
    role: role,
    isActive: isActive,
    approved: approved,
    membershipStatus: membershipStatus,
    name: 'Test User',
  );
}

void main() {
  group('resolveAuthState — cross-app role boundary (driver app)', () {
    test('approved driver is signed in', () {
      final state = resolveAuthState(_user(role: UserRole.driver));
      expect(state, isA<AuthSignedIn>());
    });

    test('an approved, active parent account is rejected', () {
      final state = resolveAuthState(_user(role: UserRole.parent));
      expect(state, isA<AuthSignedOut>());
      expect(
        (state as AuthSignedOut).message,
        'This account is not a driver account.',
      );
    });

    test('an approved, active admin account is rejected', () {
      final state = resolveAuthState(_user(role: UserRole.admin));
      expect(state, isA<AuthSignedOut>());
    });

    test('an approved, active staff account is rejected', () {
      final state = resolveAuthState(_user(role: UserRole.staff));
      expect(state, isA<AuthSignedOut>());
    });

    test('a pending driver sees pending-approval, not the trip list', () {
      final state = resolveAuthState(
        _user(
          role: UserRole.driver,
          approved: false,
          membershipStatus: MembershipStatus.pending,
        ),
      );
      expect(state, isA<AuthPendingApproval>());
    });

    test('a suspended driver is disabled, not signed in', () {
      final state = resolveAuthState(
        _user(
          role: UserRole.driver,
          isActive: false,
          membershipStatus: MembershipStatus.suspended,
        ),
      );
      expect(state, isA<AuthDisabled>());
    });

    test('a rejected driver sees the rejected screen, not the trip list', () {
      final state = resolveAuthState(
        _user(
          role: UserRole.driver,
          approved: false,
          membershipStatus: MembershipStatus.rejected,
        ),
      );
      expect(state, isA<AuthRejected>());
    });
  });
}
