import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/system_provider.dart';

class LocalApiScreen extends StatefulWidget {
  const LocalApiScreen({super.key});

  @override
  State<LocalApiScreen> createState() => _LocalApiScreenState();
}

class _LocalApiScreenState extends State<LocalApiScreen> {
  late TextEditingController _portController;

  @override
  void initState() {
    super.initState();
    _portController = TextEditingController();
  }

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SystemProvider>();
    _portController.text = provider.apiPort.toString();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Exposes read-only endpoints on your local network so a script or LLM tool '
          'can query current fronter, history, members, and stats directly from this app.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Enable local API server'),
                value: provider.apiEnabled,
                onChanged: provider.isVaultConfigured
                    ? (v) => provider.setApiEnabled(v)
                    : null,
              ),
              ListTile(
                title: const Text('Port'),
                trailing: SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _portController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                    onSubmitted: (v) {
                      final port = int.tryParse(v);
                      if (port != null && port > 1024 && port < 65536) {
                        provider.setApiPort(port);
                      }
                    },
                  ),
                ),
              ),
              if (provider.apiEnabled)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Try: http://<this-device-ip>:${provider.apiPort}/fronters/current',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}