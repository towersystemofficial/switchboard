import 'package:flutter/material.dart';

/// A single system member / alter profile.
class Member {
  final String id;
  String name;
  String pronouns;
  List<String> roles;
  String roleOther;
  String species;
  String personality;
  String description;
  String notes;
  String colorHex;
  String? avatarFilename;

  /// Two fully independent cosmetic layers -- neither affects the other.
  /// 'none' / 'glow_halo' / 'wispy_swirl' / 'star_halo' -- see kGlowEffectCatalog.
  String glowEffectId;
  /// 'none' plus 24 ornamental charms -- see kFrameShapeCatalog.
  String frameShapeId;

  /// Set once when the member is first created, never modified after.
  /// Used for the "last created" sort.
  final DateTime createdAt;

  /// Mirrors the member file's actual last-modified time on disk. Not
  /// written into frontmatter -- recomputed from the file itself every
  /// time members are loaded, so it never drifts from reality. Used for
  /// the "last edited" sort.
  final DateTime editedAt;

  /// Values for fully custom fields (see CustomFieldDefinition), keyed by
  /// field id. String for text fields, List<String> for list/multiSelect.
  Map<String, dynamic> customFieldValues;

  Member({
    required this.id,
    required this.name,
    this.pronouns = '',
    List<String>? roles,
    this.roleOther = '',
    this.species = '',
    this.personality = '',
    this.description = '',
    this.notes = '',
    this.colorHex = '#7C83FD',
    this.avatarFilename,
    this.glowEffectId = 'none',
    this.frameShapeId = 'none',
    DateTime? createdAt,
    DateTime? editedAt,
    Map<String, dynamic>? customFieldValues,
  })  : roles = roles ?? [],
        createdAt = createdAt ?? DateTime.now(),
        editedAt = editedAt ?? DateTime.now(),
        customFieldValues = customFieldValues ?? {};

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

  /// Combined, human-readable role text: checked roles plus any one-off
  /// custom "Other" text, comma-separated.
  String get roleDisplay {
    final parts = [...roles];
    if (roleOther.trim().isNotEmpty) parts.add(roleOther.trim());
    return parts.join(', ');
  }

  Member copyWith({
    String? name,
    String? pronouns,
    List<String>? roles,
    String? roleOther,
    String? species,
    String? personality,
    String? description,
    String? notes,
    String? colorHex,
    String? avatarFilename,
    String? glowEffectId,
    String? frameShapeId,
    DateTime? createdAt,
    DateTime? editedAt,
    Map<String, dynamic>? customFieldValues,
  }) {
    return Member(
      id: id,
      name: name ?? this.name,
      pronouns: pronouns ?? this.pronouns,
      roles: roles ?? this.roles,
      roleOther: roleOther ?? this.roleOther,
      species: species ?? this.species,
      personality: personality ?? this.personality,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      colorHex: colorHex ?? this.colorHex,
      avatarFilename: avatarFilename ?? this.avatarFilename,
      glowEffectId: glowEffectId ?? this.glowEffectId,
      frameShapeId: frameShapeId ?? this.frameShapeId,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
      customFieldValues: customFieldValues ?? this.customFieldValues,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'pronouns': pronouns,
        'roles': roles,
        'roleOther': roleOther,
        'species': species,
        'personality': personality,
        'description': description,
        'notes': notes,
        'color': colorHex,
        'avatar': avatarFilename,
        'glowEffect': glowEffectId,
        'frameShape': frameShapeId,
        'createdAt': createdAt.toIso8601String(),
        'editedAt': editedAt.toIso8601String(),
        'customFields': customFieldValues,
      };
}