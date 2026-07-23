import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../constants/profile_options.dart';
import '../models/member.dart';
import '../models/front_entry.dart';
import '../models/custom_field_definition.dart';
import '../models/vault_config.dart';
import '../models/group.dart';
import '../services/vault_service.dart';
import '../services/notification_service.dart';
import '../services/api_server_service.dart';

class SystemProvider extends ChangeNotifier with WidgetsBindingObserver {
  final VaultService vaultService = VaultService();
  final NotificationService notificationService = NotificationService();
  late final ApiServerService apiServerService;

  List<Member> members = [];
  List<FrontEntry> entries = [];
  List<Group> groups = [];
  bool loading = true;
  bool apiEnabled = false;
  int apiPort = 8787;

  List<String> customPronounOptions = [];
  List<String> customRoleOptions = [];
  List<String> hiddenDefaultRoleOptions = [];
  Set<String> enabledDefaultFields = {};
  List<CustomFieldDefinition> customFieldDefinitions = [];
  String systemName = '';
  String systemAbout = '';
  String? systemAvatarFilename;

  String memberListView = 'grid';
  String memberSortField = 'alphabetical';
  bool memberSortReverse = false;
  bool groupsEnabled = false;
  bool notificationBypassDnd = false;
  String themeMode = 'system';
  String timeFormat = '12h';
  String dateFormat = 'MMM d, y';
  bool soundEffectsEnabled = false;
  String selectedSoundId = 'click';
  bool reduceMotion = false;
  double textScale = 1.0;
  List<String> customSounds = [];
  bool decorationsEnabled = true;
  bool useDeviceTimezone = true;
  String timezoneName = '';

  static const double minTextScale = 0.8;
  static const double maxTextScale = 1.6;
  static const double defaultTextScale = 1.0;

  /// Built-in sound ids, matching `assets/sounds/<id>.wav`. Anything else in
  /// selectedSoundId is treated as a custom filename in the vault's sounds/.
  static const Set<String> builtInSoundIds = {'click', 'chime', 'pop'};

  final AudioPlayer _audioPlayer = AudioPlayer();

  SystemProvider() {
    apiServerService = ApiServerService(
      getMembers: () => members,
      getEntries: () => entries,
    );
  }

  bool get isVaultConfigured => vaultService.isConfigured;
  String? get vaultPath => vaultService.vaultPath;

  List<String> get pronounOptions => [...defaultPronounOptions, ...customPronounOptions];
  List<String> get roleOptions =>
      [...defaultRoleOptions.where((o) => !hiddenDefaultRoleOptions.contains(o)), ...customRoleOptions];

  // ---------------- Co-fronting (active entries) ----------------

  List<FrontEntry> get activeEntries => entries.where((e) => e.isActive).toList();

  List<Member> get activeFronters {
    final result = <Member>[];
    for (final e in activeEntries) {
      final m = memberById(e.memberId);
      if (m != null) result.add(m);
    }
    return result;
  }

  bool isFronting(String memberId) =>
      activeEntries.any((e) => e.memberId == memberId);

  DateTime? mostRecentFrontTimeFor(String memberId) {
    DateTime? latest;
    for (final e in entries) {
      if (e.memberId != memberId) continue;
      if (latest == null || e.start.isAfter(latest)) latest = e.start;
    }
    return latest;
  }

  List<FrontEntry> get recentHistory {
    final sorted = [...entries]..sort((a, b) => b.start.compareTo(a.start));
    return sorted;
  }

  Member? memberById(String id) {
    final matches = members.where((m) => m.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  // ---------------- Groups ----------------

  List<Group> groupsForMember(String memberId) =>
      groups.where((g) => g.memberIds.contains(memberId)).toList();

  List<Member> get ungroupedMembers =>
      members.where((m) => groups.every((g) => !g.memberIds.contains(m.id))).toList();

  Future<void> setGroupsEnabled(bool enabled) async {
    groupsEnabled = enabled;
    await _saveConfigToVault();
    notifyListeners();
  }

  /// Whether the app currently has the OS-level "Do Not Disturb access"
  /// permission granted (needed for the bypass toggle to actually work).
  Future<bool> hasDndBypassAccess() => notificationService.hasDndBypassAccess();

  /// Sends the user to the system settings screen to grant DND access.
  Future<void> requestDndBypassAccess() => notificationService.requestDndBypassAccess();

  /// Prompts for the runtime notification permission (Android 13+). Used
  /// by the setup wizard, right after it explains what it's for.
  Future<void> requestNotificationPermission() =>
      notificationService.requestNotificationsPermission();

  Future<void> setNotificationBypassDnd(bool enabled) async {
    notificationBypassDnd = enabled;
    await notificationService.setBypassDnd(enabled);
    await vaultService.setNotificationBypassDnd(enabled);
    await _updateNotification();
    notifyListeners();
  }

  // ---------------- Appearance / date & time formatting ----------------

  ThemeMode get flutterThemeMode {
    switch (themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(String mode) async {
    themeMode = mode;
    await _saveConfigToVault();
    notifyListeners();
  }

  Future<void> setTimeFormat(String format) async {
    timeFormat = format;
    await _saveConfigToVault();
    await _persistFrontingLog();
    notifyListeners();
  }

  Future<void> setDateFormat(String pattern) async {
    dateFormat = pattern;
    await _saveConfigToVault();
    await _persistFrontingLog();
    notifyListeners();
  }

  String get _timePattern => timeFormat == '24h' ? 'HH:mm' : 'h:mm a';

  /// Re-expresses [dt] in the chosen fixed timezone, if one's set --
  /// otherwise returns it untouched (device OS zone, the existing
  /// behavior). Falls back safely to the original value if the saved
  /// zone name isn't recognized (e.g. a typo, or an older/newer tz
  /// database that dropped a name).
  DateTime _effectiveDt(DateTime dt) {
    if (useDeviceTimezone || timezoneName.isEmpty) return dt;
    try {
      final location = tz.getLocation(timezoneName);
      return tz.TZDateTime.from(dt.toUtc(), location);
    } catch (_) {
      return dt;
    }
  }

  String formatTime(DateTime dt) => DateFormat(_timePattern).format(_effectiveDt(dt));
  String formatDate(DateTime dt) => DateFormat(dateFormat).format(_effectiveDt(dt));
  String formatDateTime(DateTime dt) => '${formatDate(dt)} ${formatTime(dt)}';

  Future<void> setUseDeviceTimezone(bool enabled) async {
    useDeviceTimezone = enabled;
    await _saveConfigToVault();
    await _persistFrontingLog();
    notifyListeners();
  }

  Future<void> setTimezoneName(String name) async {
    timezoneName = name;
    await _saveConfigToVault();
    await _persistFrontingLog();
    notifyListeners();
  }

  Future<void> setSoundEffectsEnabled(bool enabled) async {
    soundEffectsEnabled = enabled;
    await _saveConfigToVault();
    notifyListeners();
  }

  Future<void> setReduceMotion(bool enabled) async {
    reduceMotion = enabled;
    await _saveConfigToVault();
    notifyListeners();
  }

  Future<void> setTextScale(double scale) async {
    textScale = scale.clamp(minTextScale, maxTextScale);
    await _saveConfigToVault();
    notifyListeners();
  }

  Future<void> incrementTextScale() => setTextScale(textScale + 0.1);
  Future<void> decrementTextScale() => setTextScale(textScale - 0.1);
  Future<void> resetTextScale() => setTextScale(defaultTextScale);

  void _playSwitchSound() {
    if (soundEffectsEnabled) {
      previewSound(selectedSoundId);
    }
  }

  /// Plays a given sound id immediately, regardless of the on/off toggle --
  /// used both for real switches and for the preview button in Settings.
  Future<void> previewSound(String soundId) async {
    try {
      if (builtInSoundIds.contains(soundId)) {
        debugPrint('Playing built-in sound: sounds/$soundId.wav');
        await _audioPlayer.play(AssetSource('sounds/$soundId.wav'));
      } else {
        final path = vaultService.soundPath(soundId);
        debugPrint('Playing custom sound: $path (exists: ${path != null && await File(path).exists()})');
        if (path != null && await File(path).exists()) {
          await _audioPlayer.play(DeviceFileSource(path));
        }
      }
    } catch (e, st) {
      debugPrint('Sound playback failed: $e');
      debugPrint('$st');
    }
  }

  Future<void> setSelectedSoundId(String soundId) async {
    selectedSoundId = soundId;
    await _saveConfigToVault();
    notifyListeners();
  }

  Future<void> addCustomSound(File file) async {
    await vaultService.saveCustomSound(file);
    customSounds = await vaultService.listCustomSounds();
    notifyListeners();
  }

  Future<void> deleteCustomSoundFile(String filename) async {
    await vaultService.deleteCustomSound(filename);
    customSounds = await vaultService.listCustomSounds();
    if (selectedSoundId == filename) {
      await setSelectedSoundId('click');
    }
    notifyListeners();
  }

  Future<void> setDecorationsEnabled(bool enabled) async {
    decorationsEnabled = enabled;
    await _saveConfigToVault();
    notifyListeners();
  }

  Future<void> addOrUpdateGroup(Group group, {File? avatarFile}) async {
    if (avatarFile != null) {
      final filename = await vaultService.saveAvatar(group.id, avatarFile);
      group.avatarFilename = filename;
      group.colorHex = await vaultService.computeAverageColorHex(avatarFile);
    }
    await vaultService.saveGroup(group);
    await _loadAll();
    notifyListeners();
  }

  Future<void> deleteGroup(Group group) async {
    await vaultService.deleteGroup(group);
    await _loadAll();
    notifyListeners();
  }

  String newGroupId() => vaultService.newId();

  /// Sets which groups a member belongs to, from the member's side. Adds
  /// the member to any newly-checked groups and removes them from any
  /// unchecked ones -- only the groups that actually changed get re-saved.
  Future<void> setGroupsForMember(String memberId, Set<String> groupIds) async {
    var changed = false;
    for (final g in groups) {
      final shouldBeIn = groupIds.contains(g.id);
      final isIn = g.memberIds.contains(memberId);
      if (shouldBeIn && !isIn) {
        g.memberIds = [...g.memberIds, memberId];
        await vaultService.saveGroup(g);
        changed = true;
      } else if (!shouldBeIn && isIn) {
        g.memberIds = g.memberIds.where((id) => id != memberId).toList();
        await vaultService.saveGroup(g);
        changed = true;
      }
    }
    if (changed) {
      await _loadAll();
      notifyListeners();
    }
  }

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    loading = true;
    notifyListeners();
    await vaultService.load();
    await notificationService.init();
    apiEnabled = await vaultService.getApiEnabled();
    apiPort = await vaultService.getApiPort();
    notificationBypassDnd = await vaultService.getNotificationBypassDnd();
    await notificationService.setBypassDnd(notificationBypassDnd);
    if (vaultService.isConfigured) {
      await _loadAll();
      // Already been through first-run setup before -- safe to ask for
      // notification permission normally. On an actual first run, the
      // wizard's own notifications step asks for it instead, after
      // explaining what it's for.
      await notificationService.requestNotificationsPermission();
    }
    if (apiEnabled) {
      await apiServerService.start(apiPort);
    }
    loading = false;
    notifyListeners();
  }

  Future<void> setVaultPath(String path) async {
    await vaultService.setVaultPath(path);
    await _loadAll();
    notifyListeners();
  }

  Future<void> _loadAll() async {
    members = await vaultService.loadMembers();
    entries = await vaultService.loadFrontingLog();
    groups = await vaultService.loadGroups();

    final config = await vaultService.loadConfig();
    enabledDefaultFields = config.enabledDefaultFields;
    customPronounOptions = config.customPronounOptions;
    customRoleOptions = config.customRoleOptions;
    hiddenDefaultRoleOptions = config.hiddenDefaultRoleOptions;
    customFieldDefinitions = config.customFieldDefinitions;
    memberListView = config.memberListView;
    memberSortField = config.memberSortField;
    memberSortReverse = config.memberSortReverse;
    groupsEnabled = config.groupsEnabled;
    themeMode = config.themeMode;
    timeFormat = config.timeFormat;
    dateFormat = config.dateFormat;
    soundEffectsEnabled = config.soundEffectsEnabled;
    selectedSoundId = config.selectedSoundId;
    reduceMotion = config.reduceMotion;
    textScale = config.textScale;
    customSounds = await vaultService.listCustomSounds();
    decorationsEnabled = config.decorationsEnabled;
    useDeviceTimezone = config.useDeviceTimezone;
    timezoneName = config.timezoneName;

    final profile = await vaultService.loadSystemProfile();
    systemName = profile.name;
    systemAbout = profile.about;
    systemAvatarFilename = profile.avatarFilename;

    await vaultService.writeFrontingLogMarkdown(
      entries,
      members,
      datePattern: dateFormat,
      timePattern: _timePattern,
      tzConvert: _effectiveDt,
    );
    await _updateNotification();
  }

  /// Writes both the machine-readable CSV and the human-readable markdown
  /// table together, so they never drift out of sync with each other.
  Future<void> _persistFrontingLog() async {
    await vaultService.writeFrontingLog(entries);
    await vaultService.writeFrontingLogMarkdown(
      entries,
      members,
      datePattern: dateFormat,
      timePattern: _timePattern,
      tzConvert: _effectiveDt,
    );
  }

  Future<void> refresh() async {
    await _loadAll();
    notifyListeners();
  }

  String newId() => vaultService.newId();

  Future<void> _saveConfigToVault() async {
    if (!vaultService.isConfigured) return;
    await vaultService.saveConfig(VaultConfig(
      enabledDefaultFields: enabledDefaultFields,
      customPronounOptions: customPronounOptions,
      customRoleOptions: customRoleOptions,
      hiddenDefaultRoleOptions: hiddenDefaultRoleOptions,
      customFieldDefinitions: customFieldDefinitions,
      memberListView: memberListView,
      memberSortField: memberSortField,
      memberSortReverse: memberSortReverse,
      groupsEnabled: groupsEnabled,
      themeMode: themeMode,
      timeFormat: timeFormat,
      dateFormat: dateFormat,
      soundEffectsEnabled: soundEffectsEnabled,
      selectedSoundId: selectedSoundId,
      reduceMotion: reduceMotion,
      textScale: textScale,
      decorationsEnabled: decorationsEnabled,
      useDeviceTimezone: useDeviceTimezone,
      timezoneName: timezoneName,
    ));
  }

  Future<void> setSystemName(String name) async {
    systemName = name;
    if (vaultService.isConfigured) {
      await vaultService.saveSystemProfile(
        SystemProfile(name: systemName, about: systemAbout, avatarFilename: systemAvatarFilename),
      );
    }
    notifyListeners();
  }

  Future<void> setSystemAbout(String about) async {
    systemAbout = about;
    if (vaultService.isConfigured) {
      await vaultService.saveSystemProfile(
        SystemProfile(name: systemName, about: systemAbout, avatarFilename: systemAvatarFilename),
      );
    }
    notifyListeners();
  }

  Future<void> setSystemAvatar(File avatarFile) async {
    final filename = await vaultService.saveSystemAvatar(avatarFile);
    systemAvatarFilename = filename;
    await vaultService.saveSystemProfile(
      SystemProfile(name: systemName, about: systemAbout, avatarFilename: systemAvatarFilename),
    );
    notifyListeners();
  }

  // ---------------- Members screen display preferences ----------------

  Future<void> setMemberListView(String view) async {
    memberListView = view;
    await _saveConfigToVault();
    notifyListeners();
  }

  Future<void> setMemberSort(String field, bool reverse) async {
    memberSortField = field;
    memberSortReverse = reverse;
    await _saveConfigToVault();
    notifyListeners();
  }

  // ---------------- Custom pronoun/role options ----------------

  Future<void> addCustomPronounOption(String option) async {
    final trimmed = option.trim();
    if (trimmed.isEmpty || pronounOptions.contains(trimmed)) return;
    customPronounOptions = [...customPronounOptions, trimmed];
    await _saveConfigToVault();
    notifyListeners();
  }

  Future<void> removeCustomPronounOption(String option) async {
    customPronounOptions = customPronounOptions.where((o) => o != option).toList();
    await _saveConfigToVault();
    notifyListeners();
  }

  Future<void> addCustomRoleOption(String option) async {
    final trimmed = option.trim();
    if (trimmed.isEmpty || roleOptions.contains(trimmed)) return;
    customRoleOptions = [...customRoleOptions, trimmed];
    await _saveConfigToVault();
    notifyListeners();
  }

  Future<void> removeCustomRoleOption(String option) async {
    customRoleOptions = customRoleOptions.where((o) => o != option).toList();
    await _saveConfigToVault();
    notifyListeners();
  }

  /// Hides a built-in role from the picker without touching the constant
  /// list -- always reversible via restoreDefaultRoleOption.
  Future<void> hideDefaultRoleOption(String option) async {
    if (hiddenDefaultRoleOptions.contains(option)) return;
    hiddenDefaultRoleOptions = [...hiddenDefaultRoleOptions, option];
    await _saveConfigToVault();
    notifyListeners();
  }

  Future<void> restoreDefaultRoleOption(String option) async {
    hiddenDefaultRoleOptions = hiddenDefaultRoleOptions.where((o) => o != option).toList();
    await _saveConfigToVault();
    notifyListeners();
  }

  // ---------------- Toggleable / custom profile fields ----------------

  Future<void> setDefaultFieldEnabled(String key, bool enabled) async {
    if (enabled) {
      enabledDefaultFields.add(key);
    } else {
      enabledDefaultFields.remove(key);
    }
    await _saveConfigToVault();
    notifyListeners();
  }

  Future<void> addCustomFieldDefinition(CustomFieldDefinition def) async {
    customFieldDefinitions = [...customFieldDefinitions, def];
    await _saveConfigToVault();
    notifyListeners();
  }

  Future<void> updateCustomFieldDefinition(CustomFieldDefinition def) async {
    customFieldDefinitions =
        customFieldDefinitions.map((d) => d.id == def.id ? def : d).toList();
    await _saveConfigToVault();
    notifyListeners();
  }

  Future<void> removeCustomFieldDefinition(String id) async {
    customFieldDefinitions = customFieldDefinitions.where((d) => d.id != id).toList();
    await _saveConfigToVault();
    notifyListeners();
  }

  // ---------------- Members ----------------

  Future<void> addOrUpdateMember(Member member, {File? avatarFile}) async {
    if (avatarFile != null) {
      final filename = await vaultService.saveAvatar(member.id, avatarFile);
      member.avatarFilename = filename;
    }
    await vaultService.saveMember(member);
    await _loadAll();
    notifyListeners();
  }

  Future<void> deleteMember(Member member) async {
    await vaultService.deleteMember(member);
    await _loadAll();
    notifyListeners();
  }

  String newMemberId() => vaultService.newId();

  String? avatarPath(String? filename) => vaultService.avatarPath(filename);

  // ---------------- Fronting log ----------------

  Future<void> addFronter(String memberId, {String notes = ''}) async {
    if (isFronting(memberId)) return;
    entries.add(FrontEntry(memberId: memberId, start: DateTime.now(), notes: notes));
    await _persistFrontingLog();
    await _updateNotification();
    _playSwitchSound();
    notifyListeners();
  }

  Future<void> removeFronter(String memberId) async {
    final now = DateTime.now();
    bool changed = false;
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].memberId == memberId && entries[i].isActive) {
        entries[i] = entries[i].copyWith(end: now);
        changed = true;
      }
    }
    if (!changed) return;
    await _persistFrontingLog();
    await _updateNotification();
    _playSwitchSound();
    notifyListeners();
  }

  Future<void> replaceFronters(List<String> memberIds, {String notes = ''}) async {
    final now = DateTime.now();
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].isActive) {
        entries[i] = entries[i].copyWith(end: now);
      }
    }
    for (final id in memberIds) {
      entries.add(FrontEntry(memberId: id, start: now, notes: notes));
    }
    await _persistFrontingLog();
    await _updateNotification();
    _playSwitchSound();
    notifyListeners();
  }

  Future<void> clearAllFronters() async {
    final now = DateTime.now();
    bool changed = false;
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].isActive) {
        entries[i] = entries[i].copyWith(end: now);
        changed = true;
      }
    }
    if (!changed) return;
    await _persistFrontingLog();
    await _updateNotification();
    _playSwitchSound();
    notifyListeners();
  }

  Future<void> updateEntry(int index, FrontEntry updated) async {
    entries[index] = updated;
    entries.sort((a, b) => a.start.compareTo(b.start));
    await _persistFrontingLog();
    await _updateNotification();
    notifyListeners();
  }

  /// Inserts a brand-new, fully backfilled entry (used by History's "add
  /// custom entry" -- unlike [addFronter] this isn't tied to "now" and
  /// always has both a start and an end already set).
  Future<void> addManualEntry(FrontEntry entry) async {
    entries.add(entry);
    entries.sort((a, b) => a.start.compareTo(b.start));
    await _persistFrontingLog();
    await _updateNotification();
    notifyListeners();
  }

  Future<void> deleteEntry(FrontEntry entry) async {
    entries.remove(entry);
    await _persistFrontingLog();
    await _updateNotification();
    notifyListeners();
  }

  Future<void> _updateNotification() async {
    await notificationService.showCurrentFronters(
      activeFronters,
      avatarPathResolver: (filename) => vaultService.avatarPath(filename),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshNotificationOnResume();
    }
  }

  /// Re-applies the DND-bypass channel setting on resume, not just the
  /// notification's content -- this is what picks up a permission grant
  /// made in the system "Do Not Disturb access" screen without the user
  /// having to manually toggle the setting off and back on. Also handles
  /// the opposite case: if the toggle is on but the user backed out of
  /// that screen without actually granting access, turn it back off
  /// instead of leaving it stuck on with no real effect.
  Future<void> _refreshNotificationOnResume() async {
    if (notificationBypassDnd && !await notificationService.hasDndBypassAccess()) {
      await setNotificationBypassDnd(false);
      return;
    }
    await notificationService.setBypassDnd(notificationBypassDnd);
    await _updateNotification();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ---------------- Stats ----------------
  //
  // All stats methods take an optional [start]/[end] to scope results to a
  // date range (inclusive), filtering on entry.start. Pass nothing (both
  // null) for all-time.

  Iterable<FrontEntry> _entriesInRange(DateTime? start, DateTime? end) {
    return entries.where((e) {
      if (start != null && e.start.isBefore(start)) return false;
      if (end != null && e.start.isAfter(end)) return false;
      return true;
    });
  }

  Map<String, int> switchCountsByMember({DateTime? start, DateTime? end}) {
    final counts = <String, int>{};
    for (final e in _entriesInRange(start, end)) {
      counts[e.memberId] = (counts[e.memberId] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, Duration> totalDurationByMember({DateTime? start, DateTime? end}) {
    final totals = <String, Duration>{};
    for (final e in _entriesInRange(start, end)) {
      totals[e.memberId] = (totals[e.memberId] ?? Duration.zero) + e.duration;
    }
    return totals;
  }

  Map<String, Duration> averageDurationByMember({DateTime? start, DateTime? end}) {
    final totals = totalDurationByMember(start: start, end: end);
    final counts = switchCountsByMember(start: start, end: end);
    return {
      for (final id in totals.keys)
        id: Duration(seconds: totals[id]!.inSeconds ~/ (counts[id] ?? 1))
    };
  }

  /// Switch counts bucketed by hour-of-day (0-23), using the same
  /// timezone-effective time as [formatTime]/[formatDate] so this lines up
  /// with what the user sees elsewhere -- never bucket on raw [FrontEntry]
  /// times directly.
  Map<int, int> switchCountsByHour({DateTime? start, DateTime? end}) {
    final counts = <int, int>{for (var h = 0; h < 24; h++) h: 0};
    for (final e in _entriesInRange(start, end)) {
      final hour = _effectiveDt(e.start).hour;
      counts[hour] = (counts[hour] ?? 0) + 1;
    }
    return counts;
  }

  /// Switch counts bucketed into three broad parts of day: Morning
  /// (04:01-12:00), Day (12:01-20:00), Night (20:01-04:00, wraps past
  /// midnight). Uses the same timezone-effective time as
  /// [formatTime]/[formatDate] so buckets line up with what the user sees
  /// elsewhere.
  Map<String, int> switchCountsByTimeOfDay({DateTime? start, DateTime? end}) {
    final counts = {'Morning': 0, 'Day': 0, 'Night': 0};
    for (final e in _entriesInRange(start, end)) {
      final dt = _effectiveDt(e.start);
      final minutesOfDay = dt.hour * 60 + dt.minute;
      if (minutesOfDay >= 241 && minutesOfDay <= 720) {
        counts['Morning'] = counts['Morning']! + 1;
      } else if (minutesOfDay >= 721 && minutesOfDay <= 1200) {
        counts['Day'] = counts['Day']! + 1;
      } else {
        counts['Night'] = counts['Night']! + 1;
      }
    }
    return counts;
  }

  /// Whether [entry] overlapped in time with a front by a *different*
  /// member (co-fronting). Scans the full unfiltered [entries] list (not
  /// just the date-range-filtered subset) so overlap detection isn't
  /// skewed by the range cutting off one side of an overlapping pair.
  bool _isCoFronting(FrontEntry entry) {
    final entryEnd = entry.end ?? DateTime.now();
    for (final other in entries) {
      if (identical(other, entry) || other.memberId == entry.memberId) continue;
      final otherEnd = other.end ?? DateTime.now();
      if (entry.start.isBefore(otherEnd) && other.start.isBefore(entryEnd)) {
        return true;
      }
    }
    return false;
  }

  /// Switch counts split by whether each front overlapped another
  /// member's front (co-fronting) or ran alone (solo).
  Map<String, int> switchCountsByType({DateTime? start, DateTime? end}) {
    final counts = {'Co-fronting': 0, 'Solo': 0};
    for (final e in _entriesInRange(start, end)) {
      if (_isCoFronting(e)) {
        counts['Co-fronting'] = counts['Co-fronting']! + 1;
      } else {
        counts['Solo'] = counts['Solo']! + 1;
      }
    }
    return counts;
  }

  /// Switch counts per member, restricted to fronts that started within a
  /// single time-of-day bucket ('Morning', 'Day', or 'Night'). Used for the
  /// Stats screen's per-bucket tabs (answers "who fronted in the morning").
  Map<String, int> switchCountsByMemberInTimeOfDay(String bucket, {DateTime? start, DateTime? end}) {
    final counts = <String, int>{};
    for (final e in _entriesInRange(start, end)) {
      final dt = _effectiveDt(e.start);
      final minutesOfDay = dt.hour * 60 + dt.minute;
      String b;
      if (minutesOfDay >= 241 && minutesOfDay <= 720) {
        b = 'Morning';
      } else if (minutesOfDay >= 721 && minutesOfDay <= 1200) {
        b = 'Day';
      } else {
        b = 'Night';
      }
      if (b != bucket) continue;
      counts[e.memberId] = (counts[e.memberId] ?? 0) + 1;
    }
    return counts;
  }

  /// Switch counts per member, restricted to fronts of a single type
  /// ('Co-fronting' or 'Solo'). Used for the Stats screen's per-type tabs.
  Map<String, int> switchCountsByMemberForType(String type, {DateTime? start, DateTime? end}) {
    final counts = <String, int>{};
    for (final e in _entriesInRange(start, end)) {
      final actual = _isCoFronting(e) ? 'Co-fronting' : 'Solo';
      if (actual != type) continue;
      counts[e.memberId] = (counts[e.memberId] ?? 0) + 1;
    }
    return counts;
  }

  // ---------------- API server ----------------

  Future<void> setApiEnabled(bool enabled) async {
    apiEnabled = enabled;
    await vaultService.setApiEnabled(enabled);
    if (enabled) {
      await apiServerService.start(apiPort);
    } else {
      await apiServerService.stop();
    }
    notifyListeners();
  }

  Future<void> setApiPort(int port) async {
    apiPort = port;
    await vaultService.setApiPort(port);
    if (apiEnabled) {
      await apiServerService.start(port);
    }
    notifyListeners();
  }
}