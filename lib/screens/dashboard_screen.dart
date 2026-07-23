import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/member.dart';
import '../providers/system_provider.dart';
import '../widgets/fronter_card.dart';
import '../widgets/member_avatar.dart';

enum _SwitchMode { set, add }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  /// Exposed for the "Log a switch" tutorial.
  final GlobalKey fronterCardKey = GlobalKey();
  final GlobalKey switchButtonKey = GlobalKey();
  final GlobalKey recentHistoryKey = GlobalKey();

  void _showSwitchSheet(BuildContext context, SystemProvider provider) {
    if (provider.members.isEmpty) {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => const Padding(
          padding: EdgeInsets.all(32),
          child: Text('Add a system member first, from the Members tab.'),
        ),
      );
      return;
    }

    _SwitchMode mode = _SwitchMode.set;
    String? setSelection;
    final Set<String> toggleSelection = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final canConfirm = mode == _SwitchMode.set
                ? setSelection != null
                : toggleSelection.isNotEmpty;

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Text('Who is fronting?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SegmentedButton<_SwitchMode>(
                        segments: const [
                          ButtonSegment(
                            value: _SwitchMode.set,
                            label: Text('Set Fronter'),
                            icon: Icon(Icons.swap_horiz),
                          ),
                          ButtonSegment(
                            value: _SwitchMode.add,
                            label: Text('Add Fronter'),
                            icon: Icon(Icons.person_add),
                          ),
                        ],
                        selected: {mode},
                        onSelectionChanged: (s) => setSheetState(() => mode = s.first),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                      child: Text(
                        mode == _SwitchMode.set
                            ? 'Pick one person to become the only fronter.'
                            : 'Pick anyone not currently fronting to add them.',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...provider.members.map((m) {
                      final currentlyFronting = provider.isFronting(m.id);
                      if (mode == _SwitchMode.set) {
                        final isSelected = setSelection == m.id;
                        return _SelectableMemberTile(
                          member: m,
                          selected: isSelected,
                          currentlyFronting: currentlyFronting,
                          disabled: currentlyFronting,
                          avatarPath: provider.avatarPath(m.avatarFilename),
                          trailing: Icon(
                            isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: isSelected
                                ? m.color
                                : (currentlyFronting ? Colors.black12 : Colors.black26),
                          ),
                          onTap: () => setSheetState(() => setSelection = m.id),
                        );
                      } else {
                        final isChecked = toggleSelection.contains(m.id);
                        return _SelectableMemberTile(
                          member: m,
                          selected: isChecked,
                          currentlyFronting: currentlyFronting,
                          disabled: currentlyFronting,
                          avatarPath: provider.avatarPath(m.avatarFilename),
                          trailing: Checkbox(
                            value: isChecked,
                            activeColor: m.color,
                            onChanged: currentlyFronting
                                ? null
                                : (checked) {
                                    setSheetState(() {
                                      if (checked == true) {
                                        toggleSelection.add(m.id);
                                      } else {
                                        toggleSelection.remove(m.id);
                                      }
                                    });
                                  },
                          ),
                          onTap: () {
                            setSheetState(() {
                              if (isChecked) {
                                toggleSelection.remove(m.id);
                              } else {
                                toggleSelection.add(m.id);
                              }
                            });
                          },
                        );
                      }
                    }),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: FilledButton(
                        onPressed: !canConfirm
                            ? null
                            : () async {
                                Navigator.of(context).pop();
                                if (mode == _SwitchMode.set) {
                                  if (setSelection != null) {
                                    await provider.replaceFronters([setSelection!]);
                                  }
                                } else {
                                  for (final id in toggleSelection) {
                                    await provider.addFronter(id);
                                  }
                                }
                              },
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                        child: Text(mode == _SwitchMode.set ? 'Set Fronter' : 'Add Fronter'),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SystemProvider>();

    if (!provider.isVaultConfigured) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Set up your Obsidian vault folder in Settings to get started.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    final history = provider.recentHistory.take(6).toList();

    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FronterCard(
            key: fronterCardKey,
            activeEntries: provider.activeEntries,
            memberFor: provider.memberById,
            avatarPathFor: provider.avatarPath,
            onRemove: (id) => provider.removeFronter(id),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: switchButtonKey,
                  onPressed: () => _showSwitchSheet(context, provider),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Switch Fronter'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
              if (provider.activeEntries.isNotEmpty) ...[
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => provider.clearAllFronters(),
                  icon: const Icon(Icons.logout),
                  label: const Text('End All'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Recent History',
            key: recentHistoryKey,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (history.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No switches logged yet.'),
            )
          else
            ...history.map((e) {
              final member = provider.memberById(e.memberId);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: MemberAvatar(
                    member: member,
                    radius: 18,
                    avatarFullPath: provider.avatarPath(member?.avatarFilename),
                  ),
                  title: Text(member?.name ?? 'Unknown'),
                  subtitle: Text(
                    e.isActive
                        ? 'Since ${provider.formatDateTime(e.start)}'
                        : '${provider.formatDateTime(e.start)} '
                          '\u2192 ${provider.formatTime(e.end!)}',
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// Shared row for the switch sheet: avatar, name, an optional small
/// "Fronting" tag showing current status, and a trailing selection control.
/// Disabled (currently-fronting) members can't be tapped or checked — this
/// sheet is only for starting new fronts; ending them happens on the card.
class _SelectableMemberTile extends StatelessWidget {
  final Member member;
  final bool selected;
  final bool currentlyFronting;
  final bool disabled;
  final String? avatarPath;
  final Widget trailing;
  final VoidCallback onTap;

  const _SelectableMemberTile({
    required this.member,
    required this.selected,
    required this.currentlyFronting,
    required this.disabled,
    required this.avatarPath,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.45 : 1.0,
      child: InkWell(
        onTap: disabled ? null : onTap,
        child: Container(
          color: selected ? member.color.withValues(alpha: 0.12) : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            children: [
              MemberAvatar(member: member, radius: 20, avatarFullPath: avatarPath),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.name, style: const TextStyle(fontSize: 16)),
                    if (member.roleDisplay.isNotEmpty)
                      Text(member.roleDisplay, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),
              if (currentlyFronting)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: member.color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Fronting',
                    style: TextStyle(fontSize: 11, color: member.color, fontWeight: FontWeight.w600),
                  ),
                ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}