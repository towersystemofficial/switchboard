/// Built-in pronoun and role options. These are always available in
/// addition to whatever the user adds as custom options in Settings.
const List<String> defaultPronounOptions = [
  'He/Him',
  'She/Her',
  'They/Them',
];

const List<String> defaultRoleOptions = [
  'Originator',
  'Host',
  'Protector',
  'Persecutor',
  'Little',
  'Main Fronter',
  'Introject',
  'Fictive',
  'Factive',
  'Caretaker',
  'Fragment',
  'Memory Holder',
  'Trauma Holder',
  'Worldbuilder',
  'Dormant/Dead',
];

/// The only fields shown by default are Name, Pronouns, and Color. Everything
/// below is opt-in, toggled on per-key in Settings -> Profile Fields.
const List<String> toggleableDefaultFieldKeys = [
  'roles',
  'species',
  'personality',
  'description',
  'notes',
];

const Map<String, String> toggleableDefaultFieldLabels = {
  'roles': 'Roles',
  'species': 'Species',
  'personality': 'Personality',
  'description': 'Description',
  'notes': 'Notes',
};