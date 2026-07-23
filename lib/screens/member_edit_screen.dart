import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/member.dart';
import '../models/group.dart';
import '../models/custom_field_definition.dart';
import '../providers/system_provider.dart';
import '../widgets/color_picker_dialog.dart';
import '../widgets/member_avatar.dart';
import 'avatar_decoration_screen.dart';

const String _otherPronounSentinel = 'Other';

enum _ExitAction { save, discard, cancel }

/// A field that looks like a dropdown but opens a checklist sheet, since
/// Flutter has no built-in multi-select dropdown widget. Used for Roles and
/// for any custom multi-select fields.
class _MultiSelectField extends StatelessWidget {
  final String label;
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  const _MultiSelectField({
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  Future<void> _open(BuildContext context) async {
    final working = Set<String>.from(selected);
    final result = await showModalBottomSheet<Set<String>>(
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
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  if (options.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Text('No options yet. Add some in Settings.'),
                    ),
                  for (final option in options)
                    CheckboxListTile(
                      title: Text(option),
                      value: working.contains(option),
                      onChanged: (checked) {
                        setSheetState(() {
                          if (checked == true) {
                            working.add(option);
                          } else {
                            working.remove(option);
                          }
                        });
                      },
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(working),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      child: const Text('Done'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        });
      },
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final display = selected.isEmpty ? 'None selected' : selected.join(', ');
    return InkWell(
      onTap: () => _open(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(display, overflow: TextOverflow.ellipsis, maxLines: 1),
      ),
    );
  }
}

/// Same idea as _MultiSelectField, but for Groups -- selection is tracked
/// by group id (not name), since group names aren't guaranteed unique.
class _GroupMultiSelectField extends StatelessWidget {
  final List<Group> groups;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;

  const _GroupMultiSelectField({
    required this.groups,
    required this.selectedIds,
    required this.onChanged,
  });

  Future<void> _open(BuildContext context) async {
    final working = Set<String>.from(selectedIds);
    final result = await showModalBottomSheet<Set<String>>(
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
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text('Groups', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  if (groups.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Text('No groups yet. Create one from the Members tab.'),
                    ),
                  for (final g in groups)
                    CheckboxListTile(
                      title: Text(g.name),
                      value: working.contains(g.id),
                      onChanged: (checked) {
                        setSheetState(() {
                          if (checked == true) {
                            working.add(g.id);
                          } else {
                            working.remove(g.id);
                          }
                        });
                      },
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(working),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      child: const Text('Done'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        });
      },
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final names = groups.where((g) => selectedIds.contains(g.id)).map((g) => g.name).join(', ');
    final display = names.isEmpty ? 'None selected' : names;
    return InkWell(
      onTap: () => _open(context),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Groups',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.arrow_drop_down),
        ),
        child: Text(display, overflow: TextOverflow.ellipsis, maxLines: 1),
      ),
    );
  }
}

class MemberEditScreen extends StatefulWidget {
  final Member? member;

  /// Set by the caller when opened from within a Group drilldown, so the
  /// avatar editor's preview can show the same gradient the member
  /// actually renders with in that group view.
  final Color? groupColorForPreview;

  const MemberEditScreen({super.key, required this.member, this.groupColorForPreview});

  @override
  State<MemberEditScreen> createState() => _MemberEditScreenState();
}

class _MemberEditScreenState extends State<MemberEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _pronounsOtherController;
  late TextEditingController _roleOtherController;
  late TextEditingController _speciesController;
  late TextEditingController _personalityController;
  late TextEditingController _descriptionController;
  late TextEditingController _notesController;
  late String _colorHex;
  late String _glowEffectId;
  late String _frameShapeId;
  String? _pronounSelection;
  late Set<String> _selectedRoles;
  Set<String> _selectedGroupIds = {};
  File? _pickedAvatar;
  bool _optionsInitDone = false;
  bool _customFieldsInitDone = false;
  bool _groupsInitDone = false;
  bool _listenersAttached = false;
  bool _dirty = false;

  final Map<String, TextEditingController> _customTextControllers = {};
  final Map<String, Set<String>> _customMultiSelectValues = {};

  bool get _isNew => widget.member == null;

  @override
  void initState() {
    super.initState();
    final m = widget.member;
    _nameController = TextEditingController(text: m?.name ?? '');
    _pronounsOtherController = TextEditingController();
    _roleOtherController = TextEditingController(text: m?.roleOther ?? '');
    _speciesController = TextEditingController(text: m?.species ?? '');
    _personalityController = TextEditingController(text: m?.personality ?? '');
    _descriptionController = TextEditingController(text: m?.description ?? '');
    _notesController = TextEditingController(text: m?.notes ?? '');
    _colorHex = m?.colorHex ?? '#7C83FD';
    _glowEffectId = m?.glowEffectId ?? 'none';
    _frameShapeId = m?.frameShapeId ?? 'none';
    _selectedRoles = Set<String>.from(m?.roles ?? []);
    // Dirty-tracking listeners are NOT attached here -- see didChangeDependencies.
    // Attaching them this early would catch the _pronounsOtherController.text
    // assignment that happens during setup below, falsely marking the form
    // dirty before the user has touched anything.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<SystemProvider>();
    final m = widget.member;

    if (!_optionsInitDone) {
      if (m != null && m.pronouns.isNotEmpty) {
        if (provider.pronounOptions.contains(m.pronouns)) {
          _pronounSelection = m.pronouns;
        } else {
          _pronounSelection = _otherPronounSentinel;
          _pronounsOtherController.text = m.pronouns;
        }
      }
      _optionsInitDone = true;
    }

    if (!_customFieldsInitDone) {
      final existingValues = m?.customFieldValues ?? {};
      for (final def in provider.customFieldDefinitions) {
        if (def.type == CustomFieldType.multiSelect) {
          final raw = existingValues[def.id];
          _customMultiSelectValues[def.id] =
              raw is List ? Set<String>.from(raw.map((e) => e.toString())) : <String>{};
        } else {
          final raw = existingValues[def.id];
          String text;
          if (def.type == CustomFieldType.list && raw is List) {
            text = raw.map((e) => e.toString()).join('\n');
          } else {
            text = raw?.toString() ?? '';
          }
          _customTextControllers[def.id] = TextEditingController(text: text);
        }
      }
      _customFieldsInitDone = true;
    }

    if (!_groupsInitDone) {
      if (m != null) {
        _selectedGroupIds = provider.groupsForMember(m.id).map((g) => g.id).toSet();
      }
      _groupsInitDone = true;
    }

    // Attach dirty-tracking listeners last, once every initial value
    // (including the custom-pronoun text copy above) has already been set.
    if (!_listenersAttached) {
      final controllers = [
        _nameController,
        _pronounsOtherController,
        _roleOtherController,
        _speciesController,
        _personalityController,
        _descriptionController,
        _notesController,
        ..._customTextControllers.values,
      ];
      for (final c in controllers) {
        final initialText = c.text;
        c.addListener(() {
          // Only an actual text change counts as "dirty" -- tapping into a
          // field moves the cursor, which also notifies listeners, but
          // that's not an edit.
          if (!_dirty && c.text != initialText) setState(() => _dirty = true);
        });
      }
      _listenersAttached = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pronounsOtherController.dispose();
    _roleOtherController.dispose();
    _speciesController.dispose();
    _personalityController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    for (final c in _customTextControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _openAvatarEditor(SystemProvider provider, String? existingAvatarPath) async {
    final previewMember =
        (widget.member ?? Member(id: 'preview', name: '?')).copyWith(colorHex: _colorHex);
    final result = await Navigator.of(context).push<AvatarEditResult>(
      MaterialPageRoute(
        builder: (_) => AvatarDecorationScreen(
          previewMember: previewMember,
          initialAvatarPath: existingAvatarPath,
          initialPickedAvatar: _pickedAvatar,
          initialGlowEffectId: _glowEffectId,
          initialFrameShapeId: _frameShapeId,
          decorationsEnabled: provider.decorationsEnabled,
          gradientRingTopColor: widget.groupColorForPreview,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _pickedAvatar = result.pickedAvatar;
        _glowEffectId = result.glowEffectId;
        _frameShapeId = result.frameShapeId;
        _dirty = true;
      });
    }
  }

  String get _finalPronouns {
    if (_pronounSelection == null) return '';
    if (_pronounSelection == _otherPronounSentinel) return _pronounsOtherController.text.trim();
    return _pronounSelection!;
  }

  Future<void> _save(SystemProvider provider) async {
    if (!_formKey.currentState!.validate()) return;
    final id = widget.member?.id ?? provider.newMemberId();

    final customValues = <String, dynamic>{};
    for (final def in provider.customFieldDefinitions) {
      if (def.type == CustomFieldType.multiSelect) {
        customValues[def.id] = (_customMultiSelectValues[def.id] ?? {}).toList();
      } else if (def.type == CustomFieldType.list) {
        final lines = (_customTextControllers[def.id]?.text ?? '')
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
        customValues[def.id] = lines;
      } else {
        customValues[def.id] = (_customTextControllers[def.id]?.text ?? '').trim();
      }
    }

    final member = Member(
      id: id,
      name: _nameController.text.trim(),
      pronouns: _finalPronouns,
      roles: _selectedRoles.toList(),
      roleOther: _roleOtherController.text.trim(),
      species: _speciesController.text.trim(),
      personality: _personalityController.text.trim(),
      description: _descriptionController.text.trim(),
      notes: _notesController.text,
      colorHex: _colorHex,
      avatarFilename: widget.member?.avatarFilename,
      glowEffectId: _glowEffectId,
      frameShapeId: _frameShapeId,
      createdAt: widget.member?.createdAt,
      customFieldValues: customValues,
    );
    await provider.addOrUpdateMember(member, avatarFile: _pickedAvatar);
    if (provider.groupsEnabled) {
      await provider.setGroupsForMember(id, _selectedGroupIds);
    }
    _dirty = false;
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete(SystemProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete member?'),
        content: Text('This removes ${widget.member!.name}\'s profile file from your vault. '
            'Fronting history entries will remain but show as unknown.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _dirty = false;
      await provider.deleteMember(widget.member!);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<_ExitAction> _confirmUnsavedChanges() async {
    final result = await showDialog<_ExitAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text('You have unsaved changes. Save them before leaving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_ExitAction.cancel),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_ExitAction.discard),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_ExitAction.save),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    return result ?? _ExitAction.cancel;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SystemProvider>();
    final color = Color(int.parse('FF${_colorHex.replaceFirst('#', '')}', radix: 16));
    final existingAvatarPath = provider.avatarPath(widget.member?.avatarFilename);
    final enabled = provider.enabledDefaultFields;

    return PopScope(
      canPop: !_dirty,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final action = await _confirmUnsavedChanges();
        if (!context.mounted) return;
        if (action == _ExitAction.save) {
          await _save(provider);
        } else if (action == _ExitAction.discard) {
          _dirty = false;
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? 'New Member' : 'Edit Member'),
          actions: [
            if (!_isNew)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(provider),
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: GestureDetector(
                  onTap: () => _openAvatarEditor(provider, existingAvatarPath),
                  child: Stack(
                    children: [
                      _pickedAvatar != null
                          ? CircleAvatar(radius: 48, backgroundImage: FileImage(_pickedAvatar!))
                          : MemberAvatar(
                              member: widget.member,
                              radius: 48,
                              avatarFullPath: existingAvatarPath,
                            ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          child: const Icon(Icons.edit, size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _pronounSelection,
                decoration: const InputDecoration(labelText: 'Pronouns', border: OutlineInputBorder()),
                items: [
                  for (final option in provider.pronounOptions)
                    DropdownMenuItem(value: option, child: Text(option)),
                  const DropdownMenuItem(value: _otherPronounSentinel, child: Text('Other')),
                ],
                onChanged: (v) => setState(() {
                  _pronounSelection = v;
                  _dirty = true;
                }),
              ),
              if (_pronounSelection == _otherPronounSentinel) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _pronounsOtherController,
                  decoration:
                      const InputDecoration(labelText: 'Custom pronouns', border: OutlineInputBorder()),
                ),
              ],
              const SizedBox(height: 16),

              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Color'),
                trailing: CircleAvatar(backgroundColor: color, radius: 16),
                onTap: () async {
                  final picked = await showColorPickerDialog(context, _colorHex);
                  if (picked != null) {
                    setState(() {
                      _colorHex = picked;
                      _dirty = true;
                    });
                  }
                },
              ),

              if (provider.groupsEnabled) ...[
                const SizedBox(height: 16),
                _GroupMultiSelectField(
                  groups: provider.groups,
                  selectedIds: _selectedGroupIds,
                  onChanged: (s) => setState(() {
                    _selectedGroupIds = s;
                    _dirty = true;
                  }),
                ),
              ],

              if (enabled.contains('roles')) ...[
                const SizedBox(height: 16),
                _MultiSelectField(
                  label: 'Roles',
                  options: provider.roleOptions,
                  selected: _selectedRoles,
                  onChanged: (s) => setState(() {
                    _selectedRoles = s;
                    _dirty = true;
                  }),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _roleOtherController,
                  decoration: const InputDecoration(
                    labelText: 'Other (just for this member)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],

              if (enabled.contains('species')) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _speciesController,
                  decoration: const InputDecoration(labelText: 'Species', border: OutlineInputBorder()),
                ),
              ],

              if (enabled.contains('personality')) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _personalityController,
                  decoration: const InputDecoration(
                    labelText: 'Personality',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                ),
              ],

              if (enabled.contains('description')) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                ),
              ],

              if (enabled.contains('notes')) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 6,
                ),
              ],

              if (provider.customFieldDefinitions.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text('Custom Fields', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                for (final def in provider.customFieldDefinitions) ...[
                  if (def.type == CustomFieldType.multiSelect)
                    _MultiSelectField(
                      label: def.label,
                      options: def.options,
                      selected: _customMultiSelectValues[def.id] ?? {},
                      onChanged: (s) => setState(() {
                        _customMultiSelectValues[def.id] = s;
                        _dirty = true;
                      }),
                    )
                  else
                    TextFormField(
                      controller: _customTextControllers[def.id],
                      decoration: InputDecoration(
                        labelText:
                            def.type == CustomFieldType.list ? '${def.label} (one per line)' : def.label,
                        border: const OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: def.type == CustomFieldType.list ? 4 : 1,
                    ),
                  const SizedBox(height: 12),
                ],
              ],

              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _save(provider),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: Text(_isNew ? 'Add Member' : 'Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}