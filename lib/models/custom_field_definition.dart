/// The kind of input a custom profile field uses.
enum CustomFieldType { text, list, multiSelect }

/// Definition of a fully custom profile field the user created in Settings.
/// This describes the shape of the field (shared across all members); the
/// actual per-member values live in Member.customFieldValues, keyed by id.
class CustomFieldDefinition {
  final String id;
  String label;
  CustomFieldType type;

  /// Only used when type is CustomFieldType.multiSelect -- the set of
  /// selectable options for this field.
  List<String> options;

  CustomFieldDefinition({
    required this.id,
    required this.label,
    required this.type,
    List<String>? options,
  }) : options = options ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'type': type.name,
        'options': options,
      };

  factory CustomFieldDefinition.fromJson(Map<String, dynamic> json) {
    return CustomFieldDefinition(
      id: json['id'] as String,
      label: json['label'] as String? ?? '',
      type: CustomFieldType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => CustomFieldType.text,
      ),
      options: (json['options'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}