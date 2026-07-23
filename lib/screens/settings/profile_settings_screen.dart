import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/system_provider.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _aboutController;
  bool _initDone = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initDone) {
      final provider = context.read<SystemProvider>();
      _nameController = TextEditingController(text: provider.systemName);
      _aboutController = TextEditingController(text: provider.systemAbout);
      _initDone = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar(SystemProvider provider) async {
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
      await provider.setSystemAvatar(File(cropped.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SystemProvider>();
    final avatarPath = provider.avatarPath(provider.systemAvatarFilename);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'This is about your system as a whole -- useful for orienting new '
          'or younger alters, or just as a home base.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 16),
        Center(
          child: GestureDetector(
            onTap: () => _pickAvatar(provider),
            child: Stack(
              children: [
                (avatarPath != null && File(avatarPath).existsSync())
                    ? CircleAvatar(radius: 48, backgroundImage: FileImage(File(avatarPath)))
                    : CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.grey.shade300,
                        child: Icon(Icons.groups, size: 48, color: Colors.grey.shade600),
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
        const SizedBox(height: 16),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'System name', border: OutlineInputBorder()),
          onChanged: (v) => provider.setSystemName(v),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _aboutController,
          decoration: const InputDecoration(
            labelText: 'About this system',
            hintText: 'Anything you want a new or younger alter to know',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          maxLines: 8,
          onChanged: (v) => provider.setSystemAbout(v),
        ),
      ],
    );
  }
}