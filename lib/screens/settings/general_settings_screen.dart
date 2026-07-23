import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../providers/system_provider.dart';
import '../setup/tutorial_hub_screen.dart';

class GeneralSettingsScreen extends StatefulWidget {
  const GeneralSettingsScreen({super.key});

  @override
  State<GeneralSettingsScreen> createState() => _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends State<GeneralSettingsScreen> {
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vault connected. A "FronterLog" folder was created inside it.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not set up vault: $e')),
        );
      }
    }
  }

  Future<void> _onToggleBypassDnd(SystemProvider provider, bool enabled) async {
    await provider.setNotificationBypassDnd(enabled);
    if (!enabled) return;

    final hasAccess = await provider.hasDndBypassAccess();
    if (!hasAccess) {
      await provider.requestDndBypassAccess();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Grant "Do Not Disturb access" for SwitchBoard on the screen that just '
              'opened, then come back and toggle this off and back on once to apply it.',
            ),
            duration: Duration(seconds: 6),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SystemProvider>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Obsidian Vault', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text(
          'Don\'t use Obsidian? That\'s fine -- any folder works, the app '
          'just reads and writes plain files there.',
          style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.folder_open),
            title: Text(provider.vaultPath ?? 'No vault selected'),
            subtitle: const Text('Members, avatars and the fronting log are stored here'),
            trailing: TextButton(
              onPressed: () => _pickVault(provider),
              child: Text(provider.isVaultConfigured ? 'Change' : 'Choose'),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Notifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text(
          'When on, the fronting status banner can stay visible even while your '
          'phone is in Do Not Disturb mode. It stays silent either way -- no '
          'sound or vibration, just the banner.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Card(
          child: SwitchListTile(
            title: const Text('Show fronting banner through Do Not Disturb'),
            value: provider.notificationBypassDnd,
            onChanged: (v) => _onToggleBypassDnd(provider, v),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Tutorial', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.school_outlined),
            title: const Text('Setup tutorial'),
            subtitle: const Text('Quick walkthroughs of specific features'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TutorialHubScreen()),
              );
            },
          ),
        ),
      ],
    );
  }
}