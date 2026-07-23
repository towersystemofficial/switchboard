import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/member.dart';
import '../models/front_entry.dart';
import '../models/custom_field_definition.dart';
import '../models/vault_config.dart';
import '../models/group.dart';

/// Handles all reading/writing to the Obsidian vault.
///
/// Layout created inside the chosen vault folder:
///   `<vault>/FronterLog/members/<n>.md   (YAML frontmatter + notes body)`
///   `<vault>/FronterLog/groups/<n>.md    (YAML frontmatter + description)`
///   `<vault>/FronterLog/avatars/<id>.<ext>`
///   `<vault>/FronterLog/fronting_log.csv    (member_id,start,end,notes)`
///   `<vault>/FronterLog/config.md           (app configuration)`
///   `<vault>/FronterLog/AboutSystem.md      (system-level profile info)`
class VaultService {
  static const _prefsVaultKey = 'vault_path';
  static const _prefsPortKey = 'api_port';
  static const _prefsApiEnabledKey = 'api_enabled';
  static const _prefsNotificationBypassDndKey = 'notification_bypass_dnd';
  static const _uuid = Uuid();

  String? _vaultPath;

  String? get vaultPath => _vaultPath;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _vaultPath = prefs.getString(_prefsVaultKey);
  }

  Future<void> setVaultPath(String path) async {
    _vaultPath = path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsVaultKey, path);
    await _ensureStructure();
  }

  Future<int> getApiPort() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefsPortKey) ?? 8787;
  }

  Future<void> setApiPort(int port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsPortKey, port);
  }

  Future<bool> getApiEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsApiEnabledKey) ?? false;
  }

  Future<void> setApiEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsApiEnabledKey, enabled);
  }

  // Device-local (not vault): this reflects an OS-level permission grant
  // that resets on reinstall, so it belongs with vault path / API port,
  // not in config.md.
  Future<bool> getNotificationBypassDnd() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsNotificationBypassDndKey) ?? false;
  }

  Future<void> setNotificationBypassDnd(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsNotificationBypassDndKey, enabled);
  }

  bool get isConfigured => _vaultPath != null && _vaultPath!.isNotEmpty;

  Directory get _rootDir => Directory(p.join(_vaultPath!, 'FronterLog'));
  Directory get _membersDir => Directory(p.join(_rootDir.path, 'members'));
  Directory get _groupsDir => Directory(p.join(_rootDir.path, 'groups'));
  Directory get _avatarsDir => Directory(p.join(_rootDir.path, 'avatars'));
  Directory get _soundsDir => Directory(p.join(_rootDir.path, 'sounds'));
  File get _logFile => File(p.join(_rootDir.path, 'fronting_log.csv'));
  File get _logMarkdownFile => File(p.join(_rootDir.path, 'fronting_log.md'));
  File get _configFile => File(p.join(_rootDir.path, 'config.md'));
  File get _aboutFile => File(p.join(_rootDir.path, 'AboutSystem.md'));

  Future<void> _ensureStructure() async {
    if (!isConfigured) return;
    await _membersDir.create(recursive: true);
    await _groupsDir.create(recursive: true);
    await _avatarsDir.create(recursive: true);
    await _soundsDir.create(recursive: true);
    if (!await _logFile.exists()) {
      await _logFile.writeAsString('member_id,start,end,notes\n');
    }
  }

  String newId() => _uuid.v4();

  // ---------------- Config (vault-based, survives reinstalls) ----------------

  Future<VaultConfig> loadConfig() async {
    if (!isConfigured) return VaultConfig.empty();
    await _ensureStructure();
    if (!await _configFile.exists()) return VaultConfig.empty();
    try {
      final content = await _configFile.readAsString();
      final meta = _parseFrontmatter(content).$1;

      List<CustomFieldDefinition> customFields = [];
      final rawDefs = meta['customFieldDefinitions'];
      if (rawDefs != null && rawDefs.isNotEmpty) {
        try {
          final list = jsonDecode(rawDefs) as List;
          customFields =
              list.map((e) => CustomFieldDefinition.fromJson(e as Map<String, dynamic>)).toList();
        } catch (_) {
          // Malformed JSON -- fall back to no custom fields rather than crash.
        }
      }

      final listView = meta['memberListView'];
      final sortField = meta['memberSortField'];
      final sortReverse = meta['memberSortReverse'];

      return VaultConfig(
        enabledDefaultFields: _parseList(meta['enabledDefaultFields']).toSet(),
        customPronounOptions: _parseList(meta['customPronounOptions']),
        customRoleOptions: _parseList(meta['customRoleOptions']),
        hiddenDefaultRoleOptions: _parseList(meta['hiddenDefaultRoleOptions']),
        customFieldDefinitions: customFields,
        memberListView: (listView != null && listView.isNotEmpty) ? listView : 'grid',
        memberSortField: (sortField != null && sortField.isNotEmpty) ? sortField : 'alphabetical',
        memberSortReverse: sortReverse == 'true',
        groupsEnabled: meta['groupsEnabled'] == 'true',
        themeMode: (meta['themeMode'] != null && meta['themeMode']!.isNotEmpty) ? meta['themeMode']! : 'system',
        timeFormat: (meta['timeFormat'] != null && meta['timeFormat']!.isNotEmpty) ? meta['timeFormat']! : '12h',
        dateFormat: (meta['dateFormat'] != null && meta['dateFormat']!.isNotEmpty) ? meta['dateFormat']! : 'MMM d, y',
        soundEffectsEnabled: meta['soundEffectsEnabled'] == 'true',
        selectedSoundId: (meta['selectedSoundId'] != null && meta['selectedSoundId']!.isNotEmpty)
            ? meta['selectedSoundId']!
            : 'click',
        reduceMotion: meta['reduceMotion'] == 'true',
        textScale: double.tryParse(meta['textScale'] ?? '') ?? 1.0,
        decorationsEnabled: meta['decorationsEnabled'] == null || meta['decorationsEnabled']!.isEmpty
            ? true
            : meta['decorationsEnabled'] == 'true',
        useDeviceTimezone: meta['useDeviceTimezone'] == null || meta['useDeviceTimezone']!.isEmpty
            ? true
            : meta['useDeviceTimezone'] == 'true',
        timezoneName: meta['timezoneName'] ?? '',
      );
    } catch (_) {
      return VaultConfig.empty();
    }
  }

  Future<void> saveConfig(VaultConfig config) async {
    await _ensureStructure();
    final buffer = StringBuffer();
    buffer.writeln('---');
    buffer.writeln(
        'enabledDefaultFields: [${config.enabledDefaultFields.map((f) => '"${_escape(f)}"').join(', ')}]');
    buffer.writeln(
        'customPronounOptions: [${config.customPronounOptions.map((o) => '"${_escape(o)}"').join(', ')}]');
    buffer.writeln(
        'customRoleOptions: [${config.customRoleOptions.map((o) => '"${_escape(o)}"').join(', ')}]');
    buffer.writeln(
        'hiddenDefaultRoleOptions: [${config.hiddenDefaultRoleOptions.map((o) => '"${_escape(o)}"').join(', ')}]');
    final defsJson = jsonEncode(config.customFieldDefinitions.map((d) => d.toJson()).toList());
    buffer.writeln('customFieldDefinitions: "${_escape(defsJson)}"');
    buffer.writeln('memberListView: "${config.memberListView}"');
    buffer.writeln('memberSortField: "${config.memberSortField}"');
    buffer.writeln('memberSortReverse: "${config.memberSortReverse}"');
    buffer.writeln('groupsEnabled: "${config.groupsEnabled}"');
    buffer.writeln('themeMode: "${config.themeMode}"');
    buffer.writeln('timeFormat: "${config.timeFormat}"');
    buffer.writeln('dateFormat: "${_escape(config.dateFormat)}"');
    buffer.writeln('soundEffectsEnabled: "${config.soundEffectsEnabled}"');
    buffer.writeln('selectedSoundId: "${_escape(config.selectedSoundId)}"');
    buffer.writeln('reduceMotion: "${config.reduceMotion}"');
    buffer.writeln('textScale: "${config.textScale}"');
    buffer.writeln('decorationsEnabled: "${config.decorationsEnabled}"');
    buffer.writeln('useDeviceTimezone: "${config.useDeviceTimezone}"');
    buffer.writeln('timezoneName: "${_escape(config.timezoneName)}"');
    buffer.writeln('---');
    buffer.writeln();
    buffer.writeln(
        'This file stores SwitchBoard app configuration. It is not meant to be edited '
        'by hand -- malformed entries here may reset to defaults.');
    await _configFile.writeAsString(buffer.toString());
  }

  Future<SystemProfile> loadSystemProfile() async {
    if (!isConfigured) return SystemProfile.empty();
    await _ensureStructure();
    if (!await _aboutFile.exists()) return SystemProfile.empty();
    try {
      final content = await _aboutFile.readAsString();
      final parsed = _parseFrontmatter(content);
      final meta = parsed.$1;
      return SystemProfile(
        name: meta['systemName'] ?? '',
        about: parsed.$2,
        avatarFilename: (meta['avatar'] != null && meta['avatar']!.isNotEmpty) ? meta['avatar'] : null,
      );
    } catch (_) {
      return SystemProfile.empty();
    }
  }

  Future<void> saveSystemProfile(SystemProfile profile) async {
    await _ensureStructure();
    final buffer = StringBuffer();
    buffer.writeln('---');
    buffer.writeln('systemName: "${_escape(profile.name)}"');
    buffer.writeln('avatar: "${profile.avatarFilename ?? ''}"');
    buffer.writeln('---');
    buffer.writeln();
    buffer.writeln(profile.about);
    await _aboutFile.writeAsString(buffer.toString());
  }

  Future<String> saveSystemAvatar(File source) async {
    await _ensureStructure();
    final ext = p.extension(source.path).isNotEmpty ? p.extension(source.path) : '.jpg';
    final filename = 'system$ext';
    final dest = File(p.join(_avatarsDir.path, filename));
    await source.copy(dest.path);
    return filename;
  }

// ---------------- File-tree info (for the Information browser) ----------------

  /// Which top-level vault files actually exist right now, by filename.
  Future<Map<String, bool>> getRootFileExistence() async {
    if (!isConfigured) return {};
    await _ensureStructure();
    return {
      'AboutSystem.md': await _aboutFile.exists(),
      'config.md': await _configFile.exists(),
      'fronting_log.csv': await _logFile.exists(),
    };
  }

  /// Maps member id -> the actual filename currently on disk for them
  /// (accounts for name-collision suffixes like "Kai (2).md").
  Future<Map<String, String>> getMemberFilenamesById() async {
    if (!isConfigured) return {};
    await _ensureStructure();
    final files = _membersDir.listSync().whereType<File>().where((f) => f.path.endsWith('.md'));
    final map = <String, String>{};
    for (final f in files) {
      try {
        final content = await f.readAsString();
        final meta = _parseFrontmatter(content).$1;
        final id = meta['id'];
        if (id != null) map[id] = p.basename(f.path);
      } catch (_) {
        // Skip unreadable files.
      }
    }
    return map;
  }

  /// Every avatar filename actually present in the avatars folder.
  Future<List<String>> listAvatarFilenames() async {
    if (!isConfigured) return [];
    await _ensureStructure();
    final files = _avatarsDir.listSync().whereType<File>();
    return (files.map((f) => p.basename(f.path)).toList())..sort();
  }

  // ---------------- Average color from an avatar image ----------------

  /// Downsamples the image and averages its pixel colors, for use as a
  /// group's automatic border color. Falls back to a neutral gray on any
  /// failure (corrupt file, decode error, etc.) rather than throwing.
  Future<String> computeAverageColorHex(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 32);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return '#9E9E9E';
      final pixels = byteData.buffer.asUint8List();
      int r = 0, g = 0, b = 0, count = 0;
      for (var i = 0; i < pixels.length; i += 4) {
        r += pixels[i];
        g += pixels[i + 1];
        b += pixels[i + 2];
        count++;
      }
      if (count == 0) return '#9E9E9E';
      r ~/= count;
      g ~/= count;
      b ~/= count;
      return '#${r.toRadixString(16).padLeft(2, '0')}'
          '${g.toRadixString(16).padLeft(2, '0')}'
          '${b.toRadixString(16).padLeft(2, '0')}';
    } catch (_) {
      return '#9E9E9E';
    }
  }

  // ---------------- Members ----------------

  Future<List<Member>> loadMembers() async {
    if (!isConfigured) return [];
    await _ensureStructure();
    final files = _membersDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.md'))
        .toList();
    final members = <Member>[];
    for (final f in files) {
      try {
        final content = await f.readAsString();
        final stat = await f.stat();
        members.add(_memberFromMarkdown(
          content,
          p.basenameWithoutExtension(f.path),
          editedAt: stat.modified,
          fallbackCreatedAt: stat.modified,
        ));
      } catch (_) {
        // Skip unreadable/malformed files rather than crashing the app.
      }
    }
    members.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return members;
  }

  Future<void> saveMember(Member m) async {
    await _ensureStructure();
    final newFilename = await _resolveFilename(_membersDir, m.id, m.name);

    final files = _membersDir.listSync().whereType<File>().where((f) => f.path.endsWith('.md'));
    for (final f in files) {
      if (p.basename(f.path) == newFilename) continue;
      try {
        final content = await f.readAsString();
        final meta = _parseFrontmatter(content).$1;
        if (meta['id'] == m.id) {
          await f.delete();
        }
      } catch (_) {
        // Unreadable file -- leave it alone rather than guess.
      }
    }

    final file = File(p.join(_membersDir.path, newFilename));
    await file.writeAsString(_memberToMarkdown(m));
  }

  Future<void> deleteMember(Member m) async {
    final files = _membersDir.listSync().whereType<File>().where((f) => f.path.endsWith('.md'));
    for (final f in files) {
      try {
        final content = await f.readAsString();
        final meta = _parseFrontmatter(content).$1;
        if (meta['id'] == m.id) {
          await f.delete();
          break;
        }
      } catch (_) {
        // Unreadable file -- leave it alone.
      }
    }
    if (m.avatarFilename != null) {
      final avatar = File(p.join(_avatarsDir.path, m.avatarFilename!));
      if (await avatar.exists()) await avatar.delete();
    }
  }

  // ---------------- Groups ----------------

  Future<List<Group>> loadGroups() async {
    if (!isConfigured) return [];
    await _ensureStructure();
    final files = _groupsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.md'))
        .toList();
    final groups = <Group>[];
    for (final f in files) {
      try {
        final content = await f.readAsString();
        final stat = await f.stat();
        groups.add(_groupFromMarkdown(
          content,
          p.basenameWithoutExtension(f.path),
          editedAt: stat.modified,
          fallbackCreatedAt: stat.modified,
        ));
      } catch (_) {
        // Skip unreadable/malformed files.
      }
    }
    groups.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return groups;
  }

  Future<void> saveGroup(Group g) async {
    await _ensureStructure();
    final newFilename = await _resolveFilename(_groupsDir, g.id, g.name);

    final files = _groupsDir.listSync().whereType<File>().where((f) => f.path.endsWith('.md'));
    for (final f in files) {
      if (p.basename(f.path) == newFilename) continue;
      try {
        final content = await f.readAsString();
        final meta = _parseFrontmatter(content).$1;
        if (meta['id'] == g.id) {
          await f.delete();
        }
      } catch (_) {
        // Unreadable file -- leave it alone.
      }
    }

    final file = File(p.join(_groupsDir.path, newFilename));
    await file.writeAsString(_groupToMarkdown(g));
  }

  Future<void> deleteGroup(Group g) async {
    final files = _groupsDir.listSync().whereType<File>().where((f) => f.path.endsWith('.md'));
    for (final f in files) {
      try {
        final content = await f.readAsString();
        final meta = _parseFrontmatter(content).$1;
        if (meta['id'] == g.id) {
          await f.delete();
          break;
        }
      } catch (_) {
        // Unreadable file -- leave it alone.
      }
    }
    if (g.avatarFilename != null) {
      final avatar = File(p.join(_avatarsDir.path, g.avatarFilename!));
      if (await avatar.exists()) await avatar.delete();
    }
  }

  /// Shared collision-safe filename resolution used by both members and
  /// groups: named after the entity, falls back to its id if unnamed, and
  /// appends " (2)", " (3)", etc. on collision within the given directory.
  Future<String> _resolveFilename(Directory dir, String id, String name) async {
    final base = _sanitizeFilename(name.trim().isEmpty ? id : name.trim());
    var candidate = '$base.md';
    var suffix = 2;
    while (await _filenameTakenByAnotherEntity(dir, candidate, id)) {
      candidate = '$base ($suffix).md';
      suffix++;
    }
    return candidate;
  }

  Future<bool> _filenameTakenByAnotherEntity(Directory dir, String filename, String excludeId) async {
    final lower = filename.toLowerCase();
    if (lower == 'config.md' || lower == 'aboutsystem.md') return true;
    final file = File(p.join(dir.path, filename));
    if (!await file.exists()) return false;
    try {
      final content = await file.readAsString();
      final meta = _parseFrontmatter(content).$1;
      return meta['id'] != excludeId;
    } catch (_) {
      return true;
    }
  }

  String _sanitizeFilename(String s) {
    var cleaned = s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
    cleaned = cleaned.trim();
    if (cleaned.isEmpty) cleaned = 'Unnamed';
    if (cleaned.length > 80) cleaned = cleaned.substring(0, 80);
    return cleaned;
  }

  Future<String> saveAvatar(String ownerId, File source) async {
    await _ensureStructure();
    final ext = p.extension(source.path).isNotEmpty ? p.extension(source.path) : '.jpg';
    final filename = '$ownerId$ext';
    final dest = File(p.join(_avatarsDir.path, filename));
    await source.copy(dest.path);
    return filename;
  }

  String? avatarPath(String? filename) {
    if (filename == null || !isConfigured) return null;
    return p.join(_avatarsDir.path, filename);
  }

  // ---------------- Custom notification sounds ----------------

  /// Copies an uploaded sound file into the vault, handling name collisions
  /// with a " (2)", " (3)" suffix (same idea as member/group filenames).
  Future<String> saveCustomSound(File source) async {
    await _ensureStructure();
    final ext = p.extension(source.path).isNotEmpty ? p.extension(source.path) : '.mp3';
    final baseName = _sanitizeFilename(p.basenameWithoutExtension(source.path));
    var candidate = '$baseName$ext';
    var suffix = 2;
    while (await File(p.join(_soundsDir.path, candidate)).exists()) {
      candidate = '$baseName ($suffix)$ext';
      suffix++;
    }
    final dest = File(p.join(_soundsDir.path, candidate));
    await source.copy(dest.path);
    return candidate;
  }

  Future<List<String>> listCustomSounds() async {
    if (!isConfigured) return [];
    await _ensureStructure();
    if (!await _soundsDir.exists()) return [];
    final files = _soundsDir.listSync().whereType<File>();
    return files.map((f) => p.basename(f.path)).toList()..sort();
  }

  Future<void> deleteCustomSound(String filename) async {
    final file = File(p.join(_soundsDir.path, filename));
    if (await file.exists()) await file.delete();
  }

  String? soundPath(String? filename) {
    if (filename == null || !isConfigured) return null;
    return p.join(_soundsDir.path, filename);
  }

  String _memberToMarkdown(Member m) {
    final buffer = StringBuffer();
    buffer.writeln('---');
    buffer.writeln('id: ${m.id}');
    buffer.writeln('name: "${_escape(m.name)}"');
    buffer.writeln('pronouns: "${_escape(m.pronouns)}"');
    buffer.writeln('roles: [${m.roles.map((r) => '"${_escape(r)}"').join(', ')}]');
    buffer.writeln('roleOther: "${_escape(m.roleOther)}"');
    buffer.writeln('species: "${_escape(m.species)}"');
    buffer.writeln('personality: "${_escape(m.personality)}"');
    buffer.writeln('description: "${_escape(m.description)}"');
    buffer.writeln('color: "${m.colorHex}"');
    buffer.writeln('avatar: "${m.avatarFilename ?? ''}"');
    buffer.writeln('glowEffect: "${m.glowEffectId}"');
    buffer.writeln('frameShape: "${m.frameShapeId}"');
    buffer.writeln('createdAt: "${m.createdAt.toIso8601String()}"');
    for (final entry in m.customFieldValues.entries) {
      final value = entry.value;
      if (value is List) {
        final items = value.map((v) => '"${_escape(v.toString())}"').join(', ');
        buffer.writeln('custom_${entry.key}: [$items]');
      } else {
        buffer.writeln('custom_${entry.key}: "${_escape(value.toString())}"');
      }
    }
    buffer.writeln('---');
    buffer.writeln();
    buffer.writeln(m.notes);
    return buffer.toString();
  }

  Member _memberFromMarkdown(
    String content,
    String fallbackId, {
    required DateTime editedAt,
    DateTime? fallbackCreatedAt,
  }) {
    final parsed = _parseFrontmatter(content);
    final meta = parsed.$1;
    final body = parsed.$2;

    final customValues = <String, dynamic>{};
    for (final key in meta.keys) {
      if (key.startsWith('custom_')) {
        final fieldId = key.substring('custom_'.length);
        final raw = meta[key]!;
        if (raw.trim().startsWith('[')) {
          customValues[fieldId] = _parseList(raw);
        } else {
          customValues[fieldId] = raw;
        }
      }
    }

    DateTime createdAt;
    final rawCreatedAt = meta['createdAt'];
    if (rawCreatedAt != null && rawCreatedAt.isNotEmpty) {
      try {
        createdAt = DateTime.parse(rawCreatedAt);
      } catch (_) {
        createdAt = fallbackCreatedAt ?? DateTime.now();
      }
    } else {
      createdAt = fallbackCreatedAt ?? DateTime.now();
    }

    return Member(
      id: meta['id'] ?? fallbackId,
      name: meta['name'] ?? 'Unnamed',
      pronouns: meta['pronouns'] ?? '',
      roles: _parseList(meta['roles']),
      roleOther: meta['roleOther'] ?? '',
      species: meta['species'] ?? '',
      personality: meta['personality'] ?? '',
      description: meta['description'] ?? '',
      colorHex: (meta['color'] != null && meta['color']!.isNotEmpty) ? meta['color']! : '#7C83FD',
      avatarFilename: (meta['avatar'] != null && meta['avatar']!.isNotEmpty) ? meta['avatar'] : null,
      glowEffectId: (meta['glowEffect'] != null && meta['glowEffect']!.isNotEmpty) ? meta['glowEffect']! : 'none',
      frameShapeId: (meta['frameShape'] != null && meta['frameShape']!.isNotEmpty) ? meta['frameShape']! : 'none',
      notes: body,
      createdAt: createdAt,
      editedAt: editedAt,
      customFieldValues: customValues,
    );
  }

  String _groupToMarkdown(Group g) {
    final buffer = StringBuffer();
    buffer.writeln('---');
    buffer.writeln('id: ${g.id}');
    buffer.writeln('name: "${_escape(g.name)}"');
    buffer.writeln('avatar: "${g.avatarFilename ?? ''}"');
    buffer.writeln('color: "${g.colorHex}"');
    buffer.writeln('memberIds: [${g.memberIds.map((id) => '"${_escape(id)}"').join(', ')}]');
    buffer.writeln('createdAt: "${g.createdAt.toIso8601String()}"');
    buffer.writeln('---');
    buffer.writeln();
    buffer.writeln(g.description);
    return buffer.toString();
  }

  Group _groupFromMarkdown(
    String content,
    String fallbackId, {
    required DateTime editedAt,
    DateTime? fallbackCreatedAt,
  }) {
    final parsed = _parseFrontmatter(content);
    final meta = parsed.$1;
    final body = parsed.$2;

    DateTime createdAt;
    final rawCreatedAt = meta['createdAt'];
    if (rawCreatedAt != null && rawCreatedAt.isNotEmpty) {
      try {
        createdAt = DateTime.parse(rawCreatedAt);
      } catch (_) {
        createdAt = fallbackCreatedAt ?? DateTime.now();
      }
    } else {
      createdAt = fallbackCreatedAt ?? DateTime.now();
    }

    return Group(
      id: meta['id'] ?? fallbackId,
      name: meta['name'] ?? 'Unnamed Group',
      description: body,
      avatarFilename: (meta['avatar'] != null && meta['avatar']!.isNotEmpty) ? meta['avatar'] : null,
      colorHex: (meta['color'] != null && meta['color']!.isNotEmpty) ? meta['color']! : '#9E9E9E',
      memberIds: _parseList(meta['memberIds']),
      createdAt: createdAt,
      editedAt: editedAt,
    );
  }

  List<String> _parseList(String? raw) {
    if (raw == null) return [];
    var s = raw.trim();
    if (s.startsWith('[') && s.endsWith(']')) {
      s = s.substring(1, s.length - 1);
    }
    if (s.trim().isEmpty) return [];
    return s.split(',').map((e) {
      var v = e.trim();
      if (v.length >= 2 &&
          ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'")))) {
        v = v.substring(1, v.length - 1);
      }
      return v.replaceAll('\\"', '"');
    }).where((e) => e.isNotEmpty).toList();
  }

  String _escape(String s) => s.replaceAll('"', '\\"');

  (Map<String, String>, String) _parseFrontmatter(String content) {
    final lines = content.split('\n');
    if (lines.isEmpty || lines.first.trim() != '---') {
      return (<String, String>{}, content.trim());
    }
    final meta = <String, String>{};
    int i = 1;
    for (; i < lines.length; i++) {
      if (lines[i].trim() == '---') {
        i++;
        break;
      }
      final line = lines[i];
      final idx = line.indexOf(':');
      if (idx == -1) continue;
      final key = line.substring(0, idx).trim();
      var value = line.substring(idx + 1).trim();
      if (value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }
      meta[key] = value.replaceAll('\\"', '"');
    }
    final body = (i <= lines.length) ? lines.sublist(i).join('\n').trim() : '';
    return (meta, body);
  }

  // ---------------- Fronting log ----------------

  Future<List<FrontEntry>> loadFrontingLog() async {
    if (!isConfigured) return [];
    await _ensureStructure();
    final content = await _logFile.readAsString();
    if (content.trim().isEmpty) return [];
    final rows = const CsvToListConverter(eol: '\n').convert(content);
    if (rows.isEmpty) return [];
    final dataRows = rows.first.isNotEmpty && rows.first.first.toString() == 'member_id'
        ? rows.skip(1)
        : rows;
    final entries = <FrontEntry>[];
    for (final row in dataRows) {
      if (row.isEmpty || row.first.toString().trim().isEmpty) continue;
      try {
        entries.add(FrontEntry.fromCsvRow(row));
      } catch (_) {
        // Skip malformed rows.
      }
    }
    entries.sort((a, b) => a.start.compareTo(b.start));
    return entries;
  }

  Future<void> writeFrontingLog(List<FrontEntry> entries) async {
    await _ensureStructure();
    final rows = <List<String>>[
      ['member_id', 'start', 'end', 'notes'],
      ...entries.map((e) => e.toCsvRow()),
    ];
    final csv = const ListToCsvConverter(eol: '\n').convert(rows);
    await _logFile.writeAsString('$csv\n');
  }

  /// Writes a human-readable Obsidian table (member NAMES, not IDs) as a
  /// companion to the CSV. This file is fully regenerated every time --
  /// the CSV remains the source of truth for machine parsing.
  Future<void> writeFrontingLogMarkdown(
    List<FrontEntry> entries,
    List<Member> members, {
    String datePattern = 'MMM d, y',
    String timePattern = 'h:mm a',
    DateTime Function(DateTime)? tzConvert,
  }) async {
    await _ensureStructure();
    final convert = tzConvert ?? (DateTime d) => d;
    final nameById = {for (final m in members) m.id: m.name};
    final sorted = [...entries]..sort((a, b) => b.start.compareTo(a.start)); // most recent first

    final dateFormat = DateFormat(datePattern);
    final timeFormat = DateFormat(timePattern);

    final buffer = StringBuffer();
    buffer.writeln('# Fronting Log');
    buffer.writeln();
    buffer.writeln(
        'Do not edit by hand, changes here will be overwritten. This file pulls from the CSV.');
    buffer.writeln();
    buffer.writeln('| Date | Start | End | Member | Notes |');
    buffer.writeln('|---|---|---|---|---|');

    for (final e in sorted) {
      final name = nameById[e.memberId] ?? '(unknown member)';
      final date = dateFormat.format(convert(e.start));
      final startTime = timeFormat.format(convert(e.start));
      final endTime = e.end != null ? timeFormat.format(convert(e.end!)) : 'Ongoing';
      final notes = e.notes.replaceAll('|', '\\|').replaceAll('\n', ' ');
      buffer.writeln('| $date | $startTime | $endTime | $name | $notes |');
    }

    await _logMarkdownFile.writeAsString(buffer.toString());
  }
}