import 'package:equatable/equatable.dart';

import '../enums/membership_status.dart';
import '../enums/user_role.dart';

class SchoolMember extends Equatable {
  const SchoolMember({
    required this.uid,
    required this.schoolId,
    required this.role,
    required this.status,
    required this.isActive,
  });

  final String uid;
  final String schoolId;
  final UserRole role;
  final MembershipStatus status;
  final bool isActive;

  factory SchoolMember.fromMap(String uid, Map<String, dynamic> data) {
    final role = UserRole.tryParse(data['role']);
    final status = MembershipStatusX.tryFromValue(data['status'] as String?);
    if (role == null || status == null) {
      throw const FormatException(
        'School membership has an invalid role or status.',
      );
    }

    return SchoolMember(
      uid: uid,
      schoolId: data['schoolId'] as String? ?? '',
      role: role,
      status: status,
      isActive: data['isActive'] as bool? ?? false,
    );
  }

  bool get canAccessApp => isActive && status == MembershipStatus.approved;

  @override
  List<Object> get props => [uid, schoolId, role, status, isActive];
}

