import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/profile_options.dart';
import '../../models/custom_field_definition.dart';
import '../../providers/system_provider.dart';

class AlterFieldsScreen extends StatefulWidget {
  const AlterFieldsScreen({super.key});

  @override
  State<AlterFieldsScreen> createState() => _AlterFieldsScreenState();
}

class _AlterFieldsScreenState extends State<AlterFieldsScreen> {
  final _pronounInputController = TextEditingController();
  final _roleInputController = TextEditingController();

  @override
  void dispose() {
    _pronounInputController.dispose();
    _roleInputController.dispose();
    super.dispose();
  }

  Future<void> _showFieldEditor(
    BuildContext context,
    SystemProvider provider, {
    CustomFieldDefinition? existing,
  }) async {
    final labelController = TextEditingController(text: existing?.label ?? '');
    CustomFieldType type = existing?.type ?? CustomFieldType.text;
    final options = List<String>.from(existing?.options ?? []);
    final optionInputController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(builder: (context, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    existing == null ? 'New Field' : 'Edit Field',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: labelController,
                    decoration:
                        const InputDecoration(labelText: 'Field name', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  const Text('Type', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Text'),
                        selected: type == CustomFieldType.text,
                        onSelected: (_) => setSheetState(() => type = CustomFieldType.text),
                      ),
                      ChoiceChip(
                        label: const Text('List'),
                        selected: type == CustomFieldType.list,
                        onSelected: (_) => setSheetState(() => type = CustomFieldType.list),
                      ),
                      ChoiceChip(
                        label: const Text('Multi-select'),
                        selected: type == CustomFieldType.multiSelect,
                        onSelected: (_) => setSheetState(() => type = CustomFieldType.multiSelect),
                      ),
                    ],
                  ),
                  if (type == CustomFieldType.multiSelect) ...[
                    const SizedBox(height: 16),
                    const Text('Options', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final o in options)
                          Chip(
                            label: Text(o),
                            onDeleted: () => setSheetState(() => options.remove(o)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: optionInputController,
                            decoration: const InputDecoration(
                              hintText: 'Add option',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onSubmitted: (v) {
                              if (v.trim().isNotEmpty) {
                                setSheetState(() {
                                  options.add(v.trim());
                                  optionInputController.clear();
                                });
                              }
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle),
                          onPressed: () {
                            final v = optionInputController.text.trim();
                            if (v.isNotEmpty) {
                              setSheetState(() {
                                options.add(v);
                                optionInputController.clear();
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () {
                      final label = labelController.text.trim();
                      if (label.isEmpty) return;
                      final def = CustomFieldDefinition(
                        id: existing?.id ?? provider.newId(),
                        label: label,
                        type: type,
                        options: options,
                      );
                      if (existing == null) {
                        provider.addCustomFieldDefinition(def);
                      } else {
                        provider.updateCustomFieldDefinition(def);
                      }
                      Navigator.of(context).pop();
                    },
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    child: Text(existing == null ? 'Add Field' : 'Save Changes'),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  String _typeLabel(CustomFieldType type) {
    switch (type) {
      case CustomFieldType.text:
        return 'Text';
      case CustomFieldType.list:
        return 'List';
      case CustomFieldType.multiSelect:
        return 'Multi-select';
    }
  }

  Widget _buildOptionEditor({
    required List<String> defaultOptions,
    required List<String> customOptions,
    required TextEditingController controller,
    required String hint,
    required void Function(String) onAdd,
    required void Function(String) onRemove,
    List<String> hiddenDefaults = const [],
    void Function(String)? onHideDefault,
    void Function(String)? onRestoreDefault,
  }) {
    final visibleDefaults = defaultOptions.where((o) => !hiddenDefaults.contains(o));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in visibleDefaults)
                  onHideDefault == null
                      ? Chip(label: Text(option))
                      : Chip(
                          label: Text(option),
                          onDeleted: () => onHideDefault(option),
                          deleteIcon: const Icon(Icons.close, size: 16),
                        ),
                for (final option in customOptions)
                  Chip(
                    label: Text(option),
                    onDeleted: () => onRemove(option),
                    deleteIcon: const Icon(Icons.close, size: 16),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: hint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (v) {
                      if (v.trim().isNotEmpty) {
                        onAdd(v.trim());
                        controller.clear();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle),
                  onPressed: () {
                    final v = controller.text.trim();
                    if (v.isNotEmpty) {
                      onAdd(v);
                      controller.clear();
                    }
                  },
                ),
              ],
            ),
            if (onRestoreDefault != null && hiddenDefaults.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Hidden defaults', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in hiddenDefaults)
                    ActionChip(
                      avatar: const Icon(Icons.restore, size: 16),
                      label: Text(option),
                      onPressed: () => onRestoreDefault(option),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SystemProvider>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Built-in Fields', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text(
          'Name, Pronouns, and Color are always shown. Turn on any of these '
          'to add them to every member\'s profile. Turning one off hides it but '
          'keeps whatever was already entered.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              for (final key in toggleableDefaultFieldKeys)
                SwitchListTile(
                  title: Text(toggleableDefaultFieldLabels[key] ?? key),
                  value: provider.enabledDefaultFields.contains(key),
                  onChanged: (v) => provider.setDefaultFieldEnabled(key, v),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text('Groups / Subsystems', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text(
          'Turn this on if your system uses groups or subsystems. Adds a Group '
          'view to the Members tab -- a member can belong to more than one group.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Card(
          child: SwitchListTile(
            title: const Text('Enable Groups/Subsystems'),
            value: provider.groupsEnabled,
            onChanged: (v) => provider.setGroupsEnabled(v),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(
              child: Text('Custom Fields', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            TextButton.icon(
              onPressed: () => _showFieldEditor(context, provider),
              icon: const Icon(Icons.add),
              label: const Text('Add Field'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Fully custom fields -- like "Songs" or anything else your system wants to track.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 8),
        if (provider.customFieldDefinitions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No custom fields yet.'),
          )
        else
          Card(
            child: Column(
              children: [
                for (final def in provider.customFieldDefinitions)
                  ListTile(
                    title: Text(def.label),
                    subtitle: Text(_typeLabel(def.type)),
                    onTap: () => _showFieldEditor(context, provider, existing: def),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => provider.removeCustomFieldDefinition(def.id),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        const Text('Pronoun Options', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text(
          'The defaults are always available. Add more below.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 8),
        _buildOptionEditor(
          defaultOptions: defaultPronounOptions,
          customOptions: provider.customPronounOptions,
          controller: _pronounInputController,
          hint: 'Add a pronoun option',
          onAdd: (v) => provider.addCustomPronounOption(v),
          onRemove: (v) => provider.removeCustomPronounOption(v),
        ),
        const SizedBox(height: 24),
        const Text('Role Options', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text(
          'The built-in role list is always available. Add more below.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 8),
        _buildOptionEditor(
          defaultOptions: defaultRoleOptions,
          customOptions: provider.customRoleOptions,
          controller: _roleInputController,
          hint: 'Add a role option',
          onAdd: (v) => provider.addCustomRoleOption(v),
          onRemove: (v) => provider.removeCustomRoleOption(v),
          hiddenDefaults: provider.hiddenDefaultRoleOptions,
          onHideDefault: (v) => provider.hideDefaultRoleOption(v),
          onRestoreDefault: (v) => provider.restoreDefaultRoleOption(v),
        ),
      ],
    );
  }
}