import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../providers/system_provider.dart';

class AccessibilitySettingsScreen extends StatefulWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  State<AccessibilitySettingsScreen> createState() => _AccessibilitySettingsScreenState();
}

class _AccessibilitySettingsScreenState extends State<AccessibilitySettingsScreen> {
  static const _dateFormatOptions = ['MMM d, y', 'MM/dd/yyyy', 'dd/MM/yyyy', 'yyyy-MM-dd'];
  static const _builtInSoundLabels = {'click': 'Click', 'chime': 'Chime', 'pop': 'Pop'};

  Future<void> _pickTimezone(SystemProvider provider) async {
    final names = tz.timeZoneDatabase.locations.keys.toList()..sort();
    final controller = TextEditingController();
    var filtered = names;

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(builder: (context, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: Column(
                  children: [
                    const Text('Choose timezone', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: 'Search (e.g. "New_York", "Tokyo")',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (query) {
                        setSheetState(() {
                          filtered = names
                              .where((n) => n.toLowerCase().contains(query.toLowerCase()))
                              .toList();
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, i) => ListTile(
                          title: Text(filtered[i]),
                          onTap: () => Navigator.of(context).pop(filtered[i]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
    if (selected != null) {
      await provider.setTimezoneName(selected);
    }
  }

  Future<void> _uploadSound(SystemProvider provider) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    final path = result?.files.single.path;
    if (path == null) return;
    await provider.addCustomSound(File(path));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sound uploaded.')),
      );
    }
  }

  Future<void> _deleteSound(SystemProvider provider, String filename) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete sound?'),
        content: Text('This removes "$filename" from your vault.'),
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
      await provider.deleteCustomSoundFile(filename);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SystemProvider>();
    final now = DateTime.now();
    final isDefaultScale = provider.textScale == SystemProvider.defaultTextScale;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Date & Time', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              RadioListTile<String>(
                title: const Text('12-hour'),
                subtitle: Text(DateFormat('h:mm a').format(now)),
                value: '12h',
                groupValue: provider.timeFormat,
                onChanged: (v) => provider.setTimeFormat(v!),
              ),
              RadioListTile<String>(
                title: const Text('24-hour'),
                subtitle: Text(DateFormat('HH:mm').format(now)),
                value: '24h',
                groupValue: provider.timeFormat,
                onChanged: (v) => provider.setTimeFormat(v!),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              for (final pattern in _dateFormatOptions)
                RadioListTile<String>(
                  title: Text(pattern),
                  subtitle: Text(DateFormat(pattern).format(now)),
                  value: pattern,
                  groupValue: provider.dateFormat,
                  onChanged: (v) => provider.setDateFormat(v!),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text('Timezone', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text(
          'By default, times follow whatever timezone this device is set to. '
          'Turn this off to keep a fixed timezone regardless of travel.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Use device timezone'),
                value: provider.useDeviceTimezone,
                onChanged: (v) => provider.setUseDeviceTimezone(v),
              ),
              if (!provider.useDeviceTimezone)
                ListTile(
                  title: const Text('Timezone'),
                  subtitle: Text(
                    provider.timezoneName.isEmpty ? 'Not set -- tap to choose' : provider.timezoneName,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _pickTimezone(provider),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text('Accessibility', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Sound effects on switch'),
                subtitle: const Text('Plays a sound when you set/add/remove a fronter'),
                value: provider.soundEffectsEnabled,
                onChanged: (v) => provider.setSoundEffectsEnabled(v),
              ),
              SwitchListTile(
                title: const Text('Reduce motion'),
                subtitle: const Text('Turns off card expand/collapse and menu animations'),
                value: provider.reduceMotion,
                onChanged: (v) => provider.setReduceMotion(v),
              ),
            ],
          ),
        ),
        if (provider.soundEffectsEnabled) ...[
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (final id in SystemProvider.builtInSoundIds)
                  RadioListTile<String>(
                    title: Text(_builtInSoundLabels[id] ?? id),
                    value: id,
                    groupValue: provider.selectedSoundId,
                    onChanged: (v) => provider.setSelectedSoundId(v!),
                    secondary: IconButton(
                      icon: const Icon(Icons.play_arrow),
                      onPressed: () => provider.previewSound(id),
                    ),
                  ),
                for (final filename in provider.customSounds)
                  RadioListTile<String>(
                    title: Text(filename),
                    value: filename,
                    groupValue: provider.selectedSoundId,
                    onChanged: (v) => provider.setSelectedSoundId(v!),
                    secondary: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.play_arrow),
                          onPressed: () => provider.previewSound(filename),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteSound(provider, filename),
                        ),
                      ],
                    ),
                  ),
                ListTile(
                  leading: const Icon(Icons.upload_file),
                  title: const Text('Upload custom sound'),
                  onTap: () => _uploadSound(provider),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Expanded(child: Text('Text size')),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: provider.textScale <= SystemProvider.minTextScale
                      ? null
                      : () => provider.decrementTextScale(),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    '${(provider.textScale * 100).round()}%',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: provider.textScale >= SystemProvider.maxTextScale
                      ? null
                      : () => provider.incrementTextScale(),
                ),
                TextButton(
                  onPressed: isDefaultScale ? null : () => provider.resetTextScale(),
                  child: const Text('Reset'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}