import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/group.dart';
import '../providers/system_provider.dart';
import '../widgets/group_avatar.dart';
import '../widgets/member_avatar.dart';

enum _ExitAction { save, discard, cancel }

class GroupEditScreen extends StatefulWidget {
  final Group? group;
  const GroupEditScreen({super.key, required this.group});

  @override
  State<GroupEditScreen> createState() => _GroupEditScreenState();
}

class _GroupEditScreenState extends State<GroupEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late Set<String> _selectedMemberIds;
  File? _pickedAvatar;
  bool _dirty = false;

  bool get _isNew => widget.group == null;

  @override
  void initState() {
    super.initState();
    final g = widget.group;
    _nameController = TextEditingController(text: g?.name ?? '');
    _descriptionController = TextEditingController(text: g?.description ?? '');
    _selectedMemberIds = Set<String>.from(g?.memberIds ?? []);

    final initialName = _nameController.text;
    final initialDescription = _descriptionController.text;
    _nameController.addListener(() {
      if (!_dirty && _nameController.text != initialName) setState(() => _dirty = true);
    });
    _descriptionController.addListener(() {
      if (!_dirty && _descriptionController.text != initialDescription) setState(() => _dirty = true);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, maxWidth: 1600, imageQuality: 90);
    if (file == null) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: file.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Avatar',
          cropStyle: CropStyle.circle,
          aspectRatioPresets: const [CropAspectRatioPreset.square],
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Crop Avatar',
          cropStyle: CropStyle.circle,
          aspectRatioLockEnabled: true,
          aspectRatioPresets: const [CropAspectRatioPreset.square],
        ),
      ],
    );
    if (cropped != null) {
      setState(() {
        _pickedAvatar = File(cropped.path);
        _dirty = true;
      });
    }
  }

  Future<void> _save(SystemProvider provider) async {
    if (!_formKey.currentState!.validate()) return;
    final id = widget.group?.id ?? provider.newGroupId();

    final group = Group(
      id: id,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      avatarFilename: widget.group?.avatarFilename,
      colorHex: widget.group?.colorHex ?? '#9E9E9E',
      memberIds: _selectedMemberIds.toList(),
      createdAt: widget.group?.createdAt,
    );
    await provider.addOrUpdateGroup(group, avatarFile: _pickedAvatar);
    _dirty = false;
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete(SystemProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete group?'),
        content: Text('This removes "${widget.group!.name}" from your vault. '
            'Members in it are not affected -- they just won\'t be grouped anymore.'),
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
      await provider.deleteGroup(widget.group!);
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
    final existingAvatarPath = provider.avatarPath(widget.group?.avatarFilename);

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
          title: Text(_isNew ? 'New Group' : 'Edit Group'),
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
                  onTap: _pickAvatar,
                  child: Stack(
                    children: [
                      _pickedAvatar != null
                          ? CircleAvatar(radius: 48, backgroundImage: FileImage(_pickedAvatar!))
                          : GroupAvatar(
                              group: widget.group,
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
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Border color is set automatically from this avatar.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
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
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 24),
              const Text('Members in this group', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (provider.members.isEmpty)
                const Text('No members yet.', style: TextStyle(color: Colors.grey))
              else
                Card(
                  child: Column(
                    children: [
                      for (final member in provider.members)
                        CheckboxListTile(
                          secondary: MemberAvatar(
                            member: member,
                            radius: 18,
                            avatarFullPath: provider.avatarPath(member.avatarFilename),
                          ),
                          title: Text(member.name),
                          value: _selectedMemberIds.contains(member.id),
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                _selectedMemberIds.add(member.id);
                              } else {
                                _selectedMemberIds.remove(member.id);
                              }
                              _dirty = true;
                            });
                          },
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => _save(provider),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: Text(_isNew ? 'Add Group' : 'Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}