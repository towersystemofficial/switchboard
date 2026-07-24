import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/system_provider.dart';

/// App theme and avatar frame toggles are wired to real functionality.
/// Per-member frame decoration choice lives on each member's own edit
/// screen (like their color), not here.
class AestheticsSettingsScreen extends StatefulWidget {
  const AestheticsSettingsScreen({super.key});

  @override
  State<AestheticsSettingsScreen> createState() => _AestheticsSettingsScreenState();
}

class _AestheticsSettingsScreenState extends State<AestheticsSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SystemProvider>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('App theme', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          child: RadioGroup<String>(
            groupValue: provider.themeMode,
            onChanged: (value) {
              if (value != null) provider.setThemeMode(value);
            },
            child: const Column(
              children: [
                RadioListTile<String>(
                  title: Text('System'),
                  value: 'system',
                ),
                RadioListTile<String>(
                  title: Text('Light'),
                  value: 'light',
                ),
                RadioListTile<String>(
                  title: Text('Dark'),
                  value: 'dark',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Avatar frames', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text(
          'Each alter can pick their own frame decoration and metallic sheen from their profile.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Enable avatar decorations'),
                subtitle: const Text('Turns off everyone\'s frame decoration app-wide without changing their choice'),
                value: provider.decorationsEnabled,
                onChanged: (v) => provider.setDecorationsEnabled(v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
