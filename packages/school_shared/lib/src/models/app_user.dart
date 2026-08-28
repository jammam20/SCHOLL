import 'package:equatable/equatable.dart';

import '../enums/membership_status.dart';
import '../enums/user_role.dart';

class AppUser extends Equatable {
  const AppUser({
    required this.uid,
    required this.schoolId,
    required this.role,
    required this.isActive,
    required this.approved,
    required this.membershipStatus,
    required this.name,
    this.email = '',
    this.phone,
    this.photoUrl,
  });

  final String uid;
  final String schoolId;
  final UserRole role;
  final bool isActive;
  final bool approved;
  final MembershipStatus membershipStatus;
  final String name;
  final String email;
  final String? phone;
  final String? photoUrl;

  factory AppUser.fromMap(
      String uid,
      Map<String, dynamic> data,
      ) {
    final role = UserRole.tryParse(data['role']);

    final membershipStatus =
    MembershipStatusX.tryFromValue(
      data['membershipStatus'] as String?,
    );

    if (role == null) {
      throw const FormatException(
        'Invalid or missing user role.',
      );
    }

    if (membershipStatus == null) {
      throw const FormatException(
        'Invalid or missing membership status.',
      );
    }

    return AppUser(
      uid: uid,
      schoolId: data['schoolId'] as String? ?? '',
      role: role,
      isActive: data['isActive'] as bool? ?? false,
      approved: data['approved'] as bool? ?? false,
      membershipStatus: membershipStatus,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String?,
      photoUrl: data['photoUrl'] as String?,
    );
  }

  bool get isPending =>
      membershipStatus == MembershipStatus.pending;

  bool get isRejected =>
      membershipStatus == MembershipStatus.rejected;

  bool get isDisabled =>
      !isActive ||
          membershipStatus == MembershipStatus.suspended ||
          membershipStatus == MembershipStatus.inactive;

  bool get canAccessApp =>
      isActive &&
          approved &&
          membershipStatus == MembershipStatus.approved;

  @override
  List<Object?> get props => [
    uid,
    schoolId,
    role,
    isActive,
    approved,
    membershipStatus,
    name,
    email,
    phone,
    photoUrl,
  ];
}
