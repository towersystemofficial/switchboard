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
            'Last updated: 2026',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 16),
          section(
            'Overview',
            'SwitchBoard is a local-only, personal system-tracking app. It has no '
                'account system, no backend server operated by the developer, and no '
                'built-in analytics or advertising. This policy explains what data the '
                'app touches and where it lives.',
          ),
          section(
            'Data collection',
            'The developer of SwitchBoard does not collect, receive, or have access '
                'to any data you enter into the app. Nothing you type or upload -- '
                'member names, descriptions, avatars, fronting history, or anything '
                'else -- is transmitted to the developer or to any third party by '
                'this app.',
          ),
          section(
            'Data storage',
            'All data you create lives as plain Markdown and CSV files, plus image '
                'files, inside the Obsidian vault folder you choose on your own '
                'device. You control that folder entirely -- moving, backing up, '
                'syncing, or deleting it is your responsibility, and the app has no '
                'way to recover data if that folder is lost or corrupted outside the '
                'app.',
          ),
          section(
            'Optional local network API',
            'Settings includes an optional, off-by-default "Local API" feature that '
                'exposes read-only data (current fronter, history, members, stats) '
                'over your local network so a script or tool you run yourself can '
                'query it. This has no authentication, so anything on the same '
                'network could read it while it\'s running. It only runs when you '
                'explicitly enable it, and only on your local network -- it is not '
                'reachable from the internet.',
          ),
          section(
            'Permissions',
            'The app requests device storage access (to read/write your chosen '
                'vault folder), notification permission (to show the fronting '
                'status banner), and optionally "Do Not Disturb" access (only if you '
                'enable the DND-bypass toggle in Settings). None of these permissions '
                'are used to collect or transmit data anywhere.',
          ),
          section(
            'Children\'s privacy',
            'SwitchBoard is not directed at children and does not knowingly collect '
                'information from anyone, of any age, since it does not collect '
                'information at all.',
          ),
          section(
            'No warranty',
            'SwitchBoard is provided "as is," without warranty of any kind, express '
                'or implied. The developer is not liable for any data loss, '
                'corruption, or other damages arising from use of the app. You are '
                'responsible for keeping your own backups of your vault.',
          ),
          section(
            'Changes to this policy',
            'If this policy changes, the updated version will ship with a future '
                'app update and the date above will change accordingly.',
          ),
          section(
            'Contact',
            'Questions about this policy can be directed to the developer through '
                'the app\'s listed support channel.',
          ),
        ],
      ),
    );
  }
}