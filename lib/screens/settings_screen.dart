import 'package:flutter/material.dart';

import 'settings/general_settings_screen.dart';
import 'settings/profile_settings_screen.dart';
import 'settings/alter_fields_screen.dart';
import 'settings/aesthetics_settings_screen.dart';
import 'settings/accessibility_settings_screen.dart';
import 'settings/information_screen.dart';
import 'settings/local_api_screen.dart';
import 'settings/support_contact_screen.dart';
import 'settings/about_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = <_SettingsCategory>[
      _SettingsCategory('General', Icons.settings, 'Vault setup, tutorials', const GeneralSettingsScreen()),
      _SettingsCategory('Profile', Icons.badge_outlined, 'System name and info for new alters', const ProfileSettingsScreen()),
      _SettingsCategory('Alter Fields', Icons.dynamic_form, 'Pronouns, roles, and custom fields', const AlterFieldsScreen()),
      _SettingsCategory('Aesthetics', Icons.palette_outlined, 'Colors, themes, and frame styles', const AestheticsSettingsScreen()),
      _SettingsCategory('Accessibility', Icons.accessibility_new, 'Notifications, sound, UI effects', const AccessibilitySettingsScreen()),
      _SettingsCategory('Information', Icons.folder_open, 'Browse everything stored in your vault', const InformationScreen()),
      _SettingsCategory('Local API', Icons.api, 'Read-only access for scripts and tools', const LocalApiScreen()),
      _SettingsCategory('Support & Contact', Icons.volunteer_activism_outlined, 'Support the developer, send feedback', const SupportContactScreen()),
      _SettingsCategory('About', Icons.info_outline, 'App version and details', const AboutScreen()),
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final c = categories[i];
        return Card(
          child: ListTile(
            leading: Icon(c.icon),
            title: Text(c.title),
            subtitle: Text(c.subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: Text(c.title)),
                  body: c.screen,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SettingsCategory {
  final String title;
  final IconData icon;
  final String subtitle;
  final Widget screen;
  _SettingsCategory(this.title, this.icon, this.subtitle, this.screen);
}