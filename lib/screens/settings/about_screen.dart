import 'package:flutter/material.dart';

import 'privacy_policy_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'SwitchBoard v0.1\n\n'
              'A personal, local-first system tracker. Your system-tracking data lives '
              'as plain files in a folder you choose. Data is only transmitted when '
              'you deliberately use a network feature, such as sending feedback.',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.policy_outlined),
            title: const Text('Privacy Policy'),
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
}
