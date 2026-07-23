import 'package:flutter/material.dart';

/// A subsystem / group of members within the system. A member can belong
/// to any number of groups at once -- membership is tracked here (on the
/// group), not on the member.
class Group {
  final String id;
  String name;
  String description;
  String? avatarFilename;

  /// Automatically computed from the average color of the avatar image.
  /// Not user-editable -- recomputed whenever the avatar changes. Falls
  /// back to a neutral gray if there's no avatar.
  String colorHex;

  List<String> memberIds;

  final DateTime createdAt;
  final DateTime editedAt;

  Group({
    required this.id,
    required this.name,
    this.description = '',
    this.avatarFilename,
    this.colorHex = '#9E9E9E',
    List<String>? memberIds,
    DateTime? createdAt,
    DateTime? editedAt,
  })  : memberIds = memberIds ?? [],
        createdAt = createdAt ?? DateTime.now(),
        editedAt = editedAt ?? DateTime.now();

  Color get color {
    var hex = colorHex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  Group copyWith({
    String? name,
    String? description,
    String? avatarFilename,
    String? colorHex,
    List<String>? memberIds,
    DateTime? createdAt,
    DateTime? editedAt,
  }) {
    return Group(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      avatarFilename: avatarFilename ?? this.avatarFilename,
      colorHex: colorHex ?? this.colorHex,
      memberIds: memberIds ?? this.memberIds,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'avatar': avatarFilename,
        'color': colorHex,
        'memberIds': memberIds,
        'createdAt': createdAt.toIso8601String(),
        'editedAt': editedAt.toIso8601String(),
      };
}