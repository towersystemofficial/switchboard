import 'package:flutter/material.dart';

/// Full privacy policy. Reachable from Settings -> About, and linked from
/// the setup wizard's privacy step. Kept as a separate screen from
/// AboutScreen since it's meant to be read on its own (and possibly
/// linked to externally later, e.g. from a store listing).
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final headingStyle = Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold);
    const bodyStyle = TextStyle(height: 1.4);

    Widget section(String title, String body) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: headingStyle),
            const SizedBox(height: 6),
            Text(body, style: bodyStyle),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Last updated: July 22, 2026',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 16),
          section(
            'Overview',
            'SwitchBoard is a local-first, personal system-tracking app. It has no '
                'account system, no backend server operated by the developer, and no '
                'built-in analytics or advertising. This policy explains what data the '
                'app uses, where it lives, and when you may choose to transmit data.',
          ),
          section(
            'System-tracking data',
            'Member names, descriptions, avatars, fronting history, groups, settings, '
                'and other system-tracking data are stored locally in the folder you '
                'choose. SwitchBoard does not send this data to the developer or to '
                'an external service.',
          ),
          section(
            'Optional support and contact form',
            'If you choose to use Support & Contact and press Send, SwitchBoard sends '
                'the subject, message, and any optional reply email you provide to '
                'Web3Forms, a third-party form relay, so the developer can receive and '
                'respond to your feedback. Do not include system-tracking data or other '
                'sensitive information unless you intentionally want to share it. The '
                'form sends nothing until you press Send. Use of Web3Forms is subject '
                'to its own privacy practices.',
          ),
          section(
            'Data storage',
            'All system-tracking data you create lives as plain Markdown and CSV '
                'files, plus image and configuration files, inside the folder you '
                'choose on your device. The folder may be an Obsidian vault, but '
                'Obsidian is not required. You control that folder entirely. Moving, '
                'backing up, syncing, or deleting it is your responsibility, and the '
                'app cannot recover data if the folder is lost or corrupted outside '
                'the app. If you select a folder managed by a separate sync or backup '
                'service, that service may process the files under its own terms.',
          ),
          section(
            'Optional local network API',
            'Settings includes an optional, off-by-default "Local API" feature that '
                'exposes read-only data (current fronter, history, members, and stats) '
                'over your local network so a script or tool you run can query it. The '
                'API has no authentication, so anything on the same network may be able '
                'to read it while it is running. Only enable it on a network you trust '
                'and do not expose it to the public internet.',
          ),
          section(
            'Permissions',
            'The app requests device storage access to read and write your chosen '
                'folder, notification permission to show the fronting status banner, '
                'and optionally Do Not Disturb access if you enable the DND-bypass '
                'setting. Image access is used when you choose an avatar. Network '
                'access supports the optional Local API and Support & Contact form.',
          ),
          section(
            'Children\'s privacy',
            'SwitchBoard is not directed at children. It does not knowingly collect '
                'system-tracking information from children. The optional contact form '
                'should not be used to submit personal information about a child.',
          ),
          section(
            'No warranty',
            'SwitchBoard is provided "as is," without warranty of any kind, express '
                'or implied. The developer is not liable for any data loss, '
                'corruption, or other damages arising from use of the app. You are '
                'responsible for keeping your own backups of the selected data folder.',
          ),
          section(
            'Changes to this policy',
            'If this policy changes, the updated version will ship with a future '
                'app update and the date above will change accordingly.',
          ),
          section(
            'Contact',
            'Questions about this policy can be sent through Support & Contact in the '
                'app. Using that form transmits the information you submit through '
                'Web3Forms as described above.',
          ),
        ],
      ),
    );
  }
}
