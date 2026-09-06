import 'package:flutter_test/flutter_test.dart';
import 'package:school_admin/features/auth/presentation/cubit/auth_cubit.dart';
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
  group('resolveAuthState — cross-app role boundary (admin app)', () {
    test('approved admin is signed in', () {
      final state = resolveAuthState(_user(role: UserRole.admin));
      expect(state, isA<AuthSignedIn>());
    });

    test('approved staff is signed in (read-only role also allowed here)', () {
      final state = resolveAuthState(_user(role: UserRole.staff));
      expect(state, isA<AuthSignedIn>());
    });

    test('an approved, active parent account is rejected', () {
      final state = resolveAuthState(_user(role: UserRole.parent));
      expect(state, isA<AuthSignedOut>());
      expect(
        (state as AuthSignedOut).message,
        'This account is not an administrator or school staff account.',
      );
    });

    test('an approved, active driver account is rejected', () {
      final state = resolveAuthState(_user(role: UserRole.driver));
      expect(state, isA<AuthSignedOut>());
    });

    test('a pending admin sees pending-approval, not the dashboard', () {
      final state = resolveAuthState(
        _user(
          role: UserRole.admin,
          approved: false,
          membershipStatus: MembershipStatus.pending,
        ),
      );
      expect(state, isA<AuthPendingApproval>());
    });

    test('a suspended admin is disabled, not signed in', () {
      final state = resolveAuthState(
        _user(
          role: UserRole.admin,
          isActive: false,
          membershipStatus: MembershipStatus.suspended,
        ),
      );
      expect(state, isA<AuthDisabled>());
    });

    test('a rejected admin sees the rejected screen, not the dashboard', () {
      // isActive: false matches what every real reject write sets (see
      // SuperAdminRepository._setAdminStatus / drivers_repository.dart /
      // parents_repository.dart, which all tie isActive to the approved
      // status) — the previous isActive: true default here didn't reflect
      // real data and masked resolveAuthState checking isDisabled first,
      // which made this screen unreachable in production.
      final state = resolveAuthState(
        _user(
          role: UserRole.admin,
          isActive: false,
          approved: false,
          membershipStatus: MembershipStatus.rejected,
        ),
      );
      expect(state, isA<AuthRejected>());
    });

    test(
      'approved==false with membershipStatus==approved (inconsistent data) fails closed',
      () {
        final state = resolveAuthState(
          _user(role: UserRole.admin, approved: false),
        );
        expect(state, isA<AuthSignedOut>());
      },
    );
  });
}
