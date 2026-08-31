import 'package:flutter/material.dart';
import 'package:school_shared/school_shared.dart';

/// The five-color rotation used for a child's initial-avatar. Kept as a
/// fixed palette rather than derived from the theme so the *same* child
/// keeps the *same* color in light mode, dark mode and both languages —
/// for a parent of three, the color is how they tell the cards apart at a
/// glance, and it losing its meaning on a theme switch would defeat that.
const _avatarColors = [
  Color(0xFF155EEF),
  Color(0xFF0E9384),
  Color(0xFF7A5AF8),
  Color(0xFFE04F16),
  Color(0xFFC11574),
];

/// A stable color for one student id — same id, same color, every session.
Color childAvatarColor(String studentId) =>
    _avatarColors[studentId.hashCode.abs() % _avatarColors.length];

/// A child's initial in their own color, optionally ringed with a status
/// tone so the avatar itself carries "this one's bus is moving" without a
/// second badge competing for the same row.
class ChildAvatar extends StatelessWidget {
  const ChildAvatar({
    super.key,
    required this.student,
    this.size = 44,
    this.ringColor,
  });

  final Student student;
  final double size;

  /// When non-null, draws a tone-colored ring around the avatar. Null (the
  /// default) means "nothing notable is happening", and draws no ring at
  /// all rather than a neutral one that would still read as a signal.
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    final base = childAvatarColor(student.id);
    final initial = student.name.trim().isEmpty
        ? '?'
        : student.name.trim().characters.first.toUpperCase();
    final ring = ringColor;

    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: base, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.42,
          height: 1,
        ),
      ),
    );

    if (ring == null) return avatar;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: 2),
      ),
      child: avatar,
    );
  }
}
