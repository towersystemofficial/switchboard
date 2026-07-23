import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../providers/system_provider.dart';
import '../home_shell.dart';
import '../settings/privacy_policy_screen.dart';
import 'tutorial_hub_screen.dart';

/// Required first-run setup: a privacy summary, connect the Obsidian vault,
/// explain and ask for notification permission, then set a system
/// name/avatar. Shown once, in place of the normal Welcome->HomeShell
/// handoff, whenever the vault isn't configured yet.
class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  int _step = 0;
  final TextEditingController _nameController = TextEditingController();
  bool _nameInitDone = false;

  static const _titles = ['Your privacy', 'Connect your vault', 'Notifications', 'Set up your system'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pre-fill from whatever's already stored -- if this wizard shows
    // again against a vault that already has a name saved, the field
    // should actually show that instead of looking blank.
    if (!_nameInitDone) {
      _nameController.text = context.read<SystemProvider>().systemName;
      _nameInitDone = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickVault(SystemProvider provider) async {
    final status = await Permission.manageExternalStorage.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Storage access is required. Please grant "All files access" '
              'for SwitchBoard in your phone\'s Settings.',
            ),
          ),
        );
      }
      return;
    }
    try {
      final path = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select your Obsidian vault folder',
      );
      if (path != null) {
        await provider.setVaultPath(path);
        if (mounted) setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not set up vault: $e')),
        );
      }
    }
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
      if (mounted) setState(() {});
    }
  }

  Future<void> _continueFromNotifications(SystemProvider provider) async {
    await provider.requestNotificationPermission();
    if (mounted) setState(() => _step = 3);
  }

  void _finish() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => HomeShell(key: homeShellKey)),
    );
    // Give HomeShell a moment to mount, then offer the optional tutorial.
    Future.delayed(const Duration(milliseconds: 400), () {
      final ctx = homeShellKey.currentContext;
      if (ctx != null && ctx.mounted) {
        Navigator.of(ctx).push(
          MaterialPageRoute(builder: (_) => const TutorialHubScreen()),
        );
      }
    });
  }

  VoidCallback? _nextAction(SystemProvider provider, bool vaultDone, bool nameDone) {
    switch (_step) {
      case 0:
        return () => setState(() => _step = 1);
      case 1:
        return vaultDone ? () => setState(() => _step = 2) : null;
      case 2:
        return () => _continueFromNotifications(provider);
      default:
        return nameDone ? _finish : null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SystemProvider>();
    final vaultDone = provider.isVaultConfigured;
    // Gate on the actual visible field text, not provider.systemName --
    // if this wizard runs against a vault that already has a saved name
    // (e.g. reusing a test vault), the provider value could be non-empty
    // even with the field blank, letting Finish through unearned.
    final nameDone = _nameController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_step]),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: switch (_step) {
            0 => _buildPrivacyStep(),
            1 => _buildVaultStep(provider, vaultDone),
            2 => _buildNotificationsStep(),
            _ => _buildProfileStep(provider),
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Row(
            children: [
              if (_step > 0)
                TextButton(
                  onPressed: () => setState(() => _step -= 1),
                  child: const Text('Back'),
                ),
              const Spacer(),
              FilledButton(
                onPressed: _nextAction(provider, vaultDone, nameDone),
                child: Text(_step == 2 ? 'Continue' : (_step == 3 ? 'Finish' : 'Next')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your privacy', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'SwitchBoard doesn\'t have an account system and doesn\'t send your '
          'data anywhere. Members, avatars, and your fronting log all live as '
          'plain files inside the Obsidian vault folder you choose next. '
          'There\'s no analytics, no ads, and no network access beyond an '
          'optional local API you can turn on yourself later in Settings.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            leading: const Icon(Icons.policy_outlined),
            title: const Text('Read the full privacy policy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVaultStep(SystemProvider provider, bool vaultDone) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Welcome to SwitchBoard', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'First, pick the Obsidian vault folder where your members, avatars '
          'and fronting log will be stored. A "FronterLog" folder will be '
          'created inside it.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 8),
        const Text(
          'Don\'t use Obsidian? No problem -- you don\'t need it. Just pick '
          'or make any folder; the app reads and writes plain files there '
          'either way.',
          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            leading: const Icon(Icons.folder_open),
            title: Text(provider.vaultPath ?? 'No vault selected'),
            trailing: TextButton(
              onPressed: () => _pickVault(provider),
              child: Text(vaultDone ? 'Change' : 'Choose'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Stay in the loop', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'SwitchBoard shows who is currently fronting as a persistent, '
          'silent notification -- no sound or vibration, just a quiet '
          'reminder in your status bar. It needs notification permission '
          'to do that.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        const Text(
          'On the next screen, Android will ask to allow notifications -- '
          'choose Allow so the fronting banner can show up.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),
        const Card(
          child: ListTile(
            leading: Icon(Icons.notifications_active_outlined),
            title: Text('Fronting status notification'),
            subtitle: Text('Silent, persistent, shows who is fronting now'),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileStep(SystemProvider provider) {
    final avatarPath = provider.avatarPath(provider.systemAvatarFilename);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('About your system', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'A name and avatar for the system as a whole -- you can change '
          'these any time in Settings.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),
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
        const SizedBox(height: 20),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'System name', border: OutlineInputBorder()),
          onChanged: (v) {
            provider.setSystemName(v);
            setState(() {});
          },
        ),
      ],
    );
  }
}