import 'package:school_shared/school_shared.dart';
import 'package:test/test.dart';

void main() {
  group('SchoolMember', () {
    test('allows only active approved memberships to access an app', () {
      const approvedMember = SchoolMember(
        uid: 'user-1',
        schoolId: 'school-1',
        role: UserRole.parent,
        status: MembershipStatus.approved,
        isActive: true,
      );
      const pendingMember = SchoolMember(
        uid: 'user-1',
        schoolId: 'school-1',
        role: UserRole.parent,
        status: MembershipStatus.pending,
        isActive: true,
      );
      const suspendedMember = SchoolMember(
        uid: 'user-1',
        schoolId: 'school-1',
        role: UserRole.parent,
        status: MembershipStatus.approved,
        isActive: false,
      );

      expect(approvedMember.canAccessApp, isTrue);
      expect(pendingMember.canAccessApp, isFalse);
      expect(suspendedMember.canAccessApp, isFalse);
    });

    test('rejects membership data with an unsupported role or status', () {
      expect(
        () => SchoolMember.fromMap('user-1', {
          'schoolId': 'school-1',
          'role': 'superAdmin',
          'status': 'approved',
          'isActive': true,
        }),
        throwsFormatException,
      );
      expect(
        () => SchoolMember.fromMap('user-1', {
          'schoolId': 'school-1',
          'role': 'parent',
          'status': 'unknown',
          'isActive': true,
        }),
        throwsFormatException,
      );
    });
  });

  group('AppUser', () {
    test('requires an approved active membership for parent access', () {
      final pendingParent = AppUser.fromMap('parent-1', {
        'schoolId': 'school-1',
        'role': 'parent',
        'isActive': true,
        'approved': false,
        'membershipStatus': 'pending',
        'name': 'Parent',
      });
      final approvedParent = AppUser.fromMap('parent-1', {
        'schoolId': 'school-1',
        'role': 'parent',
        'isActive': true,
        'approved': true,
        'membershipStatus': 'approved',
        'name': 'Parent',
      });

      expect(pendingParent.canAccessApp, isFalse);
      expect(approvedParent.canAccessApp, isTrue);
    });
  });
}
