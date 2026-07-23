import 'dart:io';
import 'package:flutter/material.dart';
import '../models/group.dart';

/// Same visual language as MemberAvatar, but for Groups: colored ring only
/// (derived from the avatar's average color), never a fronting badge.
class GroupAvatar extends StatelessWidget {
  final Group? group;
  final double radius;
  final String? avatarFullPath;
  final bool showColorRing;

  const GroupAvatar({
    super.key,
    required this.group,
    this.radius = 24,
    this.avatarFullPath,
    this.showColorRing = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget core;
    if (group == null) {
      core = CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade300,
        child: Icon(Icons.people_outline, size: radius, color: Colors.grey.shade600),
      );
    } else {
      final path = avatarFullPath;
      if (path != null && File(path).existsSync()) {
        core = CircleAvatar(radius: radius, backgroundImage: FileImage(File(path)));
      } else {
        core = CircleAvatar(
          radius: radius,
          backgroundColor: group!.color,
          child: Text(
            group!.initials,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: radius * 0.7),
          ),
        );
      }
    }

    if (!showColorRing || group == null) return core;

    final ringWidth = (radius * 0.09).clamp(2.0, 4.0);
    return Container(
      padding: EdgeInsets.all(ringWidth),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: group!.color, width: ringWidth),
      ),
      child: core,
    );
  }
}