import 'custom_field_definition.dart';

/// App-wide configuration that lives in the vault (config.md), not on the
/// device -- so it survives reinstalls and travels with the vault.
class VaultConfig {
  final Set<String> enabledDefaultFields;
  final List<String> customPronounOptions;
  final List<String> customRoleOptions;
  /// Built-in role names the user has chosen to hide/delete from the
  /// picker. The names themselves stay in the constant defaultRoleOptions
  /// list -- this is just a per-vault "don't show these" set, so hiding
  /// one is always reversible (restore it in Settings -> Alter Fields).
  final List<String> hiddenDefaultRoleOptions;
  final List<CustomFieldDefinition> customFieldDefinitions;

  final String memberListView;
  final String memberSortField;
  final bool memberSortReverse;

  /// Whether the Groups/Subsystems feature is turned on.
  final bool groupsEnabled;

  /// 'system' / 'light' / 'dark'.
  final String themeMode;

  /// '12h' / '24h'.
  final String timeFormat;

  /// An intl DateFormat pattern string, e.g. 'MMM d, y', 'MM/dd/yyyy',
  /// 'dd/MM/yyyy', 'yyyy-MM-dd'.
  final String dateFormat;

  final bool soundEffectsEnabled;

  /// Which sound plays on switch -- a built-in pack id (e.g. 'click',
  /// 'chime', 'pop') or a custom filename under FronterLog/sounds/.
  final String selectedSoundId;

  final bool reduceMotion;

  /// Text scale multiplier, e.g. 1.0 = default, 1.2 = 20% larger.
  final double textScale;

  /// Master switch for per-member avatar frame decorations.
  final bool decorationsEnabled;

  /// If true (default), all displayed times follow whatever timezone the
  /// device's OS is currently set to -- exactly like before this setting
  /// existed. If false, [timezoneName] (an IANA zone like
  /// 'America/New_York') is used instead, staying fixed regardless of
  /// device location/travel.
  final bool useDeviceTimezone;
  final String timezoneName;

  VaultConfig({
    required this.enabledDefaultFields,
    required this.customPronounOptions,
    required this.customRoleOptions,
    this.hiddenDefaultRoleOptions = const [],
    required this.customFieldDefinitions,
    this.memberListView = 'grid',
    this.memberSortField = 'alphabetical',
    this.memberSortReverse = false,
    this.groupsEnabled = false,
    this.themeMode = 'system',
    this.timeFormat = '12h',
    this.dateFormat = 'MMM d, y',
    this.soundEffectsEnabled = false,
    this.selectedSoundId = 'click',
    this.reduceMotion = false,
    this.textScale = 1.0,
    this.decorationsEnabled = true,
    this.useDeviceTimezone = true,
    this.timezoneName = '',
  });

  factory VaultConfig.empty() => VaultConfig(
        enabledDefaultFields: {},
        customPronounOptions: [],
        customRoleOptions: [],
        customFieldDefinitions: [],
      );
}

/// System-level profile info (AboutSystem.md), separate from any one member.
class SystemProfile {
  final String name;
  final String about;
  final String? avatarFilename;

  SystemProfile({required this.name, required this.about, this.avatarFilename});

  factory SystemProfile.empty() => SystemProfile(name: '', about: '');
}