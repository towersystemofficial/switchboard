import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/custom_field_definition.dart';
import '../../models/member.dart';
import '../../providers/system_provider.dart';

class InformationScreen extends StatelessWidget {
  const InformationScreen({super.key});

  String _typeLabel(CustomFieldType type) {
    switch (type) {
      case CustomFieldType.text:
        return 'Text';
      case CustomFieldType.list:
        return 'List';
      case CustomFieldType.multiSelect:
        return 'Multi-select';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SystemProvider>();

    if (!provider.isVaultConfigured) {
      return const Center(child: Text('Set up your vault folder in General first.'));
    }

    return FutureBuilder<_VaultFileTree>(
      future: _loadTree(provider),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final tree = snapshot.data!;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('FronterLog/', style: TextStyle(fontFamily: 'monospace', color: Colors.grey)),
            ),

            _FileTile(
              filename: 'AboutSystem.md',
              exists: tree.rootFiles['AboutSystem.md'] ?? false,
              content: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.systemName.isEmpty ? '(no system name set)' : provider.systemName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (provider.systemAbout.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(provider.systemAbout),
                    ],
                  ],
                ),
              ),
            ),

            _FileTile(
              filename: 'config.md',
              exists: tree.rootFiles['config.md'] ?? false,
              content: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(
                      'Enabled optional fields',
                      provider.enabledDefaultFields.isEmpty
                          ? 'None'
                          : provider.enabledDefaultFields.join(', '),
                    ),
                    const SizedBox(height: 10),
                    _InfoRow(
                      'Custom pronoun options',
                      provider.customPronounOptions.isEmpty
                          ? 'None'
                          : provider.customPronounOptions.join(', '),
                    ),
                    const SizedBox(height: 10),
                    _InfoRow(
                      'Custom role options',
                      provider.customRoleOptions.isEmpty
                          ? 'None'
                          : provider.customRoleOptions.join(', '),
                    ),
                    if (provider.customFieldDefinitions.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Text('Custom fields',
                          style:
                              TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      for (final def in provider.customFieldDefinitions)
                        Text('\u2022 ${def.label} (${_typeLabel(def.type)})'),
                    ],
                  ],
                ),
              ),
            ),

            _FileTile(
              filename: 'fronting_log.csv',
              exists: tree.rootFiles['fronting_log.csv'] ?? false,
              content: Column(
                children: [
                  ListTile(
                    title: const Text('Total logged entries'),
                    trailing: Text('${provider.entries.length}'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Currently fronting'),
                    trailing: Text('${provider.activeEntries.length}'),
                  ),
                  if (provider.recentHistory.isNotEmpty) ...[
                    const Divider(height: 1),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text('Most recent',
                          style:
                              TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey)),
                    ),
                    for (final e in provider.recentHistory.take(5))
                      ListTile(
                        dense: true,
                        title: Text(provider.memberById(e.memberId)?.name ?? 'Unknown'),
                        subtitle: Text(
                          e.isActive
                              ? 'Since ${DateFormat('MMM d, h:mm a').format(e.start)}'
                              : '${DateFormat('MMM d, h:mm a').format(e.start)} '
                                '\u2192 ${DateFormat('h:mm a').format(e.end!)}',
                        ),
                      ),
                  ],
                ],
              ),
            ),

            _FolderTile(
              folderName: 'members/',
              itemCount: tree.memberFilenamesById.length,
              children: [
                for (final entry in _sortedMemberEntries(provider, tree))
                  _FileTile(
                    filename: entry.$2,
                    exists: true,
                    content: _MemberDetailContent(
                      member: entry.$1,
                      customFieldDefinitions: provider.customFieldDefinitions,
                      avatarPath: provider.avatarPath(entry.$1.avatarFilename),
                    ),
                  ),
              ],
            ),

            _FolderTile(
              folderName: 'avatars/',
              itemCount: tree.avatarFilenames.length,
              children: [
                if (tree.avatarFilenames.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    child: Text('No avatar files.'),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final filename in tree.avatarFilenames)
                          _AvatarThumbnail(
                            filename: filename,
                            fullPath: provider.avatarPath(filename),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  List<(Member, String)> _sortedMemberEntries(SystemProvider provider, _VaultFileTree tree) {
    final result = <(Member, String)>[];
    for (final entry in tree.memberFilenamesById.entries) {
      final member = provider.memberById(entry.key);
      if (member != null) result.add((member, entry.value));
    }
    result.sort((a, b) => a.$2.toLowerCase().compareTo(b.$2.toLowerCase()));
    return result;
  }

  Future<_VaultFileTree> _loadTree(SystemProvider provider) async {
    final rootFiles = await provider.vaultService.getRootFileExistence();
    final memberFilenamesById = await provider.vaultService.getMemberFilenamesById();
    final avatarFilenames = await provider.vaultService.listAvatarFilenames();
    return _VaultFileTree(
      rootFiles: rootFiles,
      memberFilenamesById: memberFilenamesById,
      avatarFilenames: avatarFilenames,
    );
  }
}

class _VaultFileTree {
  final Map<String, bool> rootFiles;
  final Map<String, String> memberFilenamesById;
  final List<String> avatarFilenames;

  _VaultFileTree({
    required this.rootFiles,
    required this.memberFilenamesById,
    required this.avatarFilenames,
  });
}

class _FileTile extends StatelessWidget {
  final String filename;
  final bool exists;
  final Widget content;

  const _FileTile({required this.filename, required this.exists, required this.content});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: Icon(
          Icons.description_outlined,
          color: exists ? null : Colors.grey.shade400,
        ),
        title: Text(
          filename,
          style: TextStyle(
            fontFamily: 'monospace',
            color: exists ? null : Colors.grey,
            fontStyle: exists ? FontStyle.normal : FontStyle.italic,
          ),
        ),
        subtitle: exists ? null : const Text('Not created yet', style: TextStyle(fontSize: 12)),
        children: exists ? [content] : [],
      ),
    );
  }
}

class _FolderTile extends StatelessWidget {
  final String folderName;
  final int itemCount;
  final List<Widget> children;

  const _FolderTile({required this.folderName, required this.itemCount, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: const Icon(Icons.folder_outlined),
        title: Text('$folderName ($itemCount)', style: const TextStyle(fontFamily: 'monospace')),
        children: children,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value),
      ],
    );
  }
}

class _MemberDetailContent extends StatelessWidget {
  final Member member;
  final List<CustomFieldDefinition> customFieldDefinitions;
  final String? avatarPath;

  const _MemberDetailContent({
    required this.member,
    required this.customFieldDefinitions,
    required this.avatarPath,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <String, String>{
      if (member.pronouns.isNotEmpty) 'Pronouns': member.pronouns,
      if (member.roleDisplay.isNotEmpty) 'Roles': member.roleDisplay,
      if (member.species.isNotEmpty) 'Species': member.species,
      if (member.personality.isNotEmpty) 'Personality': member.personality,
      if (member.description.isNotEmpty) 'Description': member.description,
      if (member.notes.isNotEmpty) 'Notes': member.notes,
      for (final def in customFieldDefinitions)
        if (member.customFieldValues[def.id] != null &&
            member.customFieldValues[def.id].toString().isNotEmpty &&
            !(member.customFieldValues[def.id] is List &&
                (member.customFieldValues[def.id] as List).isEmpty))
          def.label: member.customFieldValues[def.id] is List
              ? (member.customFieldValues[def.id] as List).join(', ')
              : member.customFieldValues[def.id].toString(),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              avatarPath != null && File(avatarPath!).existsSync()
                  ? CircleAvatar(radius: 28, backgroundImage: FileImage(File(avatarPath!)))
                  : CircleAvatar(
                      radius: 28,
                      backgroundColor: member.color,
                      child: Text(member.initials, style: const TextStyle(color: Colors.white)),
                    ),
              const SizedBox(width: 14),
              Text(member.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 14),
          if (rows.isEmpty)
            const Text('No additional fields filled in.')
          else
            for (final entry in rows.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.key,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey)),
                    Text(entry.value),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _AvatarThumbnail extends StatelessWidget {
  final String filename;
  final String? fullPath;

  const _AvatarThumbnail({required this.filename, required this.fullPath});

  @override
  Widget build(BuildContext context) {
    final exists = fullPath != null && File(fullPath!).existsSync();
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundImage: exists ? FileImage(File(fullPath!)) : null,
            child: exists ? null : const Icon(Icons.broken_image_outlined),
          ),
          const SizedBox(height: 4),
          Text(
            filename,
            style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}