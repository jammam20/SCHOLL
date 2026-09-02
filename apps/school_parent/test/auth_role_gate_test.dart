import 'package:flutter_test/flutter_test.dart';
import 'package:school_parent/features/auth/presentation/cubit/auth_cubit.dart';
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
  group('resolveAuthState — cross-app role boundary (parent app)', () {
    test('approved parent is signed in', () {
      final state = resolveAuthState(_user(role: UserRole.parent));
      expect(state, isA<AuthSignedIn>());
    });

    // Regression test: this exact gap (no role check at all) previously let
    // any approved, active member of any role — driver, admin, staff — sign
    // into the parent app and reach the parent home shell.
    test('an approved, active driver account is rejected', () {
      final state = resolveAuthState(_user(role: UserRole.driver));
      expect(state, isA<AuthSignedOut>());
      expect(
        (state as AuthSignedOut).message,
        'This account is not a parent account.',
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

    test('a pending parent sees pending-approval, not the home page', () {
      final state = resolveAuthState(
        _user(
          role: UserRole.parent,
          approved: false,
          membershipStatus: MembershipStatus.pending,
        ),
      );
      expect(state, isA<AuthPendingApproval>());
    });

    test('a suspended parent is disabled, not signed in', () {
      final state = resolveAuthState(
        _user(
          role: UserRole.parent,
          isActive: false,
          membershipStatus: MembershipStatus.suspended,
        ),
      );
      expect(state, isA<AuthDisabled>());
    });

    test('a rejected parent sees the rejected screen, not the home page', () {
      final state = resolveAuthState(
        _user(
          role: UserRole.parent,
          approved: false,
          membershipStatus: MembershipStatus.rejected,
        ),
      );
      expect(state, isA<AuthRejected>());
    });
  });
}
