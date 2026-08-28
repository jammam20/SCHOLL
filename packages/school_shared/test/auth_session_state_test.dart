import 'package:school_shared/school_shared.dart';
import 'package:test/test.dart';

void main() {
  const user = AppUser(
    uid: 'user-1',
    schoolId: 'school-1',
    role: UserRole.parent,
    isActive: true,
    approved: true,
    membershipStatus: MembershipStatus.approved,
    name: 'Parent',
  );

  group('AuthSessionState', () {
    test('equal states with the same data are equal', () {
      expect(const AuthSessionUnknown(), equals(const AuthSessionUnknown()));
      expect(
        const AuthSessionAuthenticated(user),
        equals(const AuthSessionAuthenticated(user)),
      );
    });

    test('states carrying different data are not equal', () {
      const otherUser = AppUser(
        uid: 'user-2',
        schoolId: 'school-1',
        role: UserRole.parent,
        isActive: true,
        approved: false,
        membershipStatus: MembershipStatus.pending,
        name: 'Other Parent',
      );

      expect(
        const AuthSessionPending(user),
        isNot(equals(const AuthSessionPending(otherUser))),
      );
    });

    test('unauthorized state may carry no user', () {
      const state = AuthSessionUnauthorized();
      expect(state.user, isNull);
    });

    test('error state wraps an AuthFailure', () {
      const failure = AuthFailure(AuthFailureCode.network);
      const state = AuthSessionError(failure);
      expect(state.failure, failure);
    });
  });

  group('AuthFailure', () {
    test('equal failures with the same code and message are equal', () {
      expect(
        const AuthFailure(AuthFailureCode.invalidCredentials),
        equals(const AuthFailure(AuthFailureCode.invalidCredentials)),
      );
      expect(
        const AuthFailure(AuthFailureCode.unknown, message: 'boom'),
        isNot(equals(const AuthFailure(AuthFailureCode.unknown))),
      );
    });
  });

  group('AuthFailureCodeX', () {
    test('tryFromValue resolves known values and rejects unknown ones', () {
      expect(
        AuthFailureCodeX.tryFromValue('invalidCredentials'),
        AuthFailureCode.invalidCredentials,
      );
      expect(AuthFailureCodeX.tryFromValue('not-a-real-code'), isNull);
      expect(AuthFailureCodeX.tryFromValue(null), isNull);
    });
  });
}
