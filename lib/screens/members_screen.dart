import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/member.dart';
import '../models/group.dart';
import '../providers/system_provider.dart';
import '../widgets/member_avatar.dart';
import '../widgets/group_avatar.dart';
import 'member_edit_screen.dart';
import 'group_edit_screen.dart';

enum _FilterType { role, pronoun, frontingStatus, group }

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => MembersScreenState();
}

class MembersScreenState extends State<MembersScreen> {
  bool _searchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  _FilterType? _filterType;
  String? _filterValue;

  bool _groupView = false;
  Group? _selectedGroup;
  bool _showingUngrouped = false;
  bool _fabMenuOpen = false;

  /// Exposed for the tutorial's "Add a member" walkthrough.
  final GlobalKey fabKey = GlobalKey();
  final GlobalKey newMemberOptionKey = GlobalKey();

  /// Opens the add-menu programmatically so a tour can spotlight the New
  /// Member option without needing a real tap mid-tour.
  void openFabMenuForTour() {
    if (mounted) setState(() => _fabMenuOpen = true);
  }

  /// Closes the add-menu if it's open -- called by HomeShell when the
  /// user switches away from this tab, so it doesn't stay open invisibly
  /// and reappear expanded next time they come back.
  void collapseFabMenu() {
    if (mounted && _fabMenuOpen) setState(() => _fabMenuOpen = false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---------------- Search ----------------

  (String?, String) _parseSearch(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return (null, '');
    final match = RegExp(r'^(role|pronoun|species|personality|notes|group):(.*)$',
            caseSensitive: false)
        .firstMatch(trimmed);
    if (match != null) {
      return (match.group(1)!.toLowerCase(), match.group(2)!.trim());
    }
    return (null, trimmed);
  }

  bool _matchesSearch(Member m, String? field, String value, SystemProvider provider) {
    if (value.isEmpty) return true;
    final v = value.toLowerCase();
    switch (field) {
      case 'role':
        return m.roleDisplay.toLowerCase().contains(v);
      case 'pronoun':
        return m.pronouns.toLowerCase().contains(v);
      case 'species':
        return m.species.toLowerCase().contains(v);
      case 'personality':
        return m.personality.toLowerCase().contains(v);
      case 'notes':
        return m.notes.toLowerCase().contains(v);
      case 'group':
        return provider.groupsForMember(m.id).any((g) => g.name.toLowerCase().contains(v));
      default:
        return m.name.toLowerCase().contains(v);
    }
  }

  List<String> _searchSuggestions(SystemProvider provider) {
    final raw = _searchQuery;
    final colonIndex = raw.indexOf(':');

    if (colonIndex == -1) {
      final typed = raw.trim().toLowerCase();
      if (typed.isEmpty) return [];
      const prefixes = ['role:', 'pronoun:', 'species:', 'personality:', 'notes:', 'group:'];
      return prefixes.where((p) => p.startsWith(typed)).toList();
    }

    final prefix = raw.substring(0, colonIndex).trim().toLowerCase();
    final valueTyped = raw.substring(colonIndex + 1).trim().toLowerCase();

    List<String> options;
    if (prefix == 'role') {
      options = provider.roleOptions;
    } else if (prefix == 'pronoun') {
      options = provider.pronounOptions;
    } else if (prefix == 'group') {
      options = provider.groups.map((g) => g.name).toList();
    } else {
      return [];
    }

    return options
        .where((o) => o.toLowerCase().contains(valueTyped))
        .map((o) => '$prefix:$o')
        .toList();
  }

  void _applySuggestion(String suggestion) {
    setState(() {
      _searchController.text = suggestion;
      _searchController.selection = TextSelection.collapsed(offset: suggestion.length);
      _searchQuery = suggestion;
    });
  }

  // ---------------- Filter ----------------

  bool _matchesFilter(Member m, SystemProvider provider) {
    if (_filterType == null || _filterValue == null) return true;
    switch (_filterType!) {
      case _FilterType.role:
        return m.roles.contains(_filterValue) || m.roleOther == _filterValue;
      case _FilterType.pronoun:
        return m.pronouns == _filterValue;
      case _FilterType.frontingStatus:
        final fronting = provider.isFronting(m.id);
        return _filterValue == 'fronting' ? fronting : !fronting;
      case _FilterType.group:
        return provider.groupsForMember(m.id).any((g) => g.name == _filterValue);
    }
  }

  String _filterChipLabel() {
    switch (_filterType!) {
      case _FilterType.role:
        return 'Role: $_filterValue';
      case _FilterType.pronoun:
        return 'Pronouns: $_filterValue';
      case _FilterType.frontingStatus:
        return _filterValue == 'fronting' ? 'Fronting now' : 'Not fronting';
      case _FilterType.group:
        return 'Group: $_filterValue';
    }
  }

  void _clearFilter() {
    setState(() {
      _filterType = null;
      _filterValue = null;
    });
  }

  Future<void> _openFilterSheet(SystemProvider provider) async {
    _FilterType? tempType = _filterType;
    String? tempValue = _filterValue;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(builder: (context, setSheetState) {
          Widget section(String title, _FilterType type, List<String> options) {
            if (options.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(title, style: Theme.of(context).textTheme.titleSmall),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: options.map((o) {
                      final selected = tempType == type && tempValue == o;
                      return ChoiceChip(
                        label: Text(o),
                        selected: selected,
                        onSelected: (_) {
                          setSheetState(() {
                            if (selected) {
                              tempType = null;
                              tempValue = null;
                            } else {
                              tempType = type;
                              tempValue = o;
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          }

          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Filter', style: Theme.of(context).textTheme.titleLarge),
                        ),
                        TextButton(
                          onPressed: () => setSheetState(() {
                            tempType = null;
                            tempValue = null;
                          }),
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  ),
                  section('Role', _FilterType.role, provider.roleOptions),
                  section('Pronouns', _FilterType.pronoun, provider.pronounOptions),
                  section('Fronting status', _FilterType.frontingStatus,
                      const ['fronting', 'notFronting']),
                  if (provider.groupsEnabled)
                    section('Group', _FilterType.group, provider.groups.map((g) => g.name).toList()),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          setState(() {
                            _filterType = tempType;
                            _filterValue = tempValue;
                          });
                          Navigator.of(context).pop();
                        },
                        child: const Text('Apply'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  // ---------------- Sort ----------------

  static const List<(String, String, bool)> _sortChoices = [
    ('Alphabetical (A \u2192 Z)', 'alphabetical', false),
    ('Alphabetical (Z \u2192 A)', 'alphabetical', true),
    ('Most recent fronter (newest first)', 'mostRecentFronter', false),
    ('Most recent fronter (oldest first)', 'mostRecentFronter', true),
    ('Last edited (newest first)', 'lastEdited', false),
    ('Last edited (oldest first)', 'lastEdited', true),
    ('Last created (newest first)', 'lastCreated', false),
    ('Last created (oldest first)', 'lastCreated', true),
  ];

  List<Member> _sorted(List<Member> members, SystemProvider provider) {
    final list = [...members];
    int cmp(Member a, Member b) {
      switch (provider.memberSortField) {
        case 'mostRecentFronter':
          final da = provider.mostRecentFrontTimeFor(a.id);
          final db = provider.mostRecentFrontTimeFor(b.id);
          if (da == null && db == null) {
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          }
          if (da == null) return 1;
          if (db == null) return -1;
          return db.compareTo(da);
        case 'lastEdited':
          return b.editedAt.compareTo(a.editedAt);
        case 'lastCreated':
          return b.createdAt.compareTo(a.createdAt);
        default:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    }

    list.sort(cmp);
    if (provider.memberSortReverse) return list.reversed.toList();
    return list;
  }

  // ---------------- Build ----------------

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SystemProvider>();

    if (!provider.isVaultConfigured) {
      return const Center(child: Text('Set up your vault folder in Settings first.'));
    }

    final isGrid = provider.memberListView != 'list';
    final drilledIn = _selectedGroup != null || _showingUngrouped;

    Widget content;
    if (drilledIn) {
      final drillMembers = _showingUngrouped
          ? provider.ungroupedMembers
          : provider.members.where((m) => _selectedGroup!.memberIds.contains(m.id)).toList();
      final sortedDrill = _sorted(drillMembers, provider);
      // Only a real selected group has a color to gradient from; the
      // Ungrouped bucket has no group, so it stays a plain solid ring.
      final gradientTop = _showingUngrouped ? null : _selectedGroup!.color;
      content = sortedDrill.isEmpty
          ? const Center(child: Text('No members here yet.'))
          : (isGrid
              ? _buildMemberGrid(sortedDrill, provider, gradientTopColor: gradientTop)
              : _buildMemberList(sortedDrill, provider, gradientTopColor: gradientTop));
    } else if (_groupView && provider.groupsEnabled) {
      content = _buildGroupsView(provider, isGrid);
    } else {
      final (searchField, searchValue) = _parseSearch(_searchQuery);
      final visibleMembers = _sorted(
        provider.members
            .where((m) => _matchesSearch(m, searchField, searchValue, provider))
            .where((m) => _matchesFilter(m, provider))
            .toList(),
        provider,
      );
      content = provider.members.isEmpty
          ? const Center(child: Text('No members yet. Tap + to add one.'))
          : visibleMembers.isEmpty
              ? const Center(child: Text('No members match your search/filter.'))
              : (isGrid
                  ? _buildMemberGrid(visibleMembers, provider)
                  : _buildMemberList(visibleMembers, provider));
    }

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              _buildToolbar(provider),
              if (!drilledIn && !_groupView && _filterType != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(
                      label: Text(_filterChipLabel()),
                      onDeleted: _clearFilter,
                    ),
                  ),
                ),
              Expanded(child: content),
            ],
          ),
          if (_fabMenuOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _fabMenuOpen = false),
                child: Container(color: Colors.black.withOpacity(0.4)),
              ),
            ),
        ],
      ),
      floatingActionButton: _buildFab(provider),
    );
  }

  // ---------------- Toolbar ----------------

  Widget _buildToolbar(SystemProvider provider) {
    if (_selectedGroup != null || _showingUngrouped) {
      final title = _showingUngrouped ? 'Ungrouped' : _selectedGroup!.name;
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back to groups',
              onPressed: () => setState(() {
                _selectedGroup = null;
                _showingUngrouped = false;
              }),
            ),
            Expanded(
              child: Text(title,
                  style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );
    }

    if (_groupView && provider.groupsEnabled) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.person_outline),
              tooltip: 'Switch to Member view',
              onPressed: () => setState(() => _groupView = false),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(provider.memberListView == 'list' ? Icons.grid_view : Icons.view_list),
              tooltip: provider.memberListView == 'list' ? 'Grid view' : 'List view',
              onPressed: () => provider
                  .setMemberListView(provider.memberListView == 'list' ? 'grid' : 'list'),
            ),
          ],
        ),
      );
    }

    if (_searchOpen) {
      final suggestions = _searchSuggestions(provider);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Close search',
                  onPressed: () => setState(() {
                    _searchOpen = false;
                    _searchController.clear();
                    _searchQuery = '';
                  }),
                ),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search, or "role:", "pronoun:", "group:"...',
                      border: InputBorder.none,
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Clear search',
                    onPressed: () => setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    }),
                  ),
              ],
            ),
          ),
          if (suggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: suggestions
                    .map((s) => ActionChip(label: Text(s), onPressed: () => _applySuggestion(s)))
                    .toList(),
              ),
            ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          if (provider.groupsEnabled)
            IconButton(
              icon: const Icon(Icons.groups_outlined),
              tooltip: 'Switch to Group view',
              onPressed: () => setState(() => _groupView = true),
            ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () => setState(() => _searchOpen = true),
          ),
          IconButton(
            icon: Icon(_filterType != null ? Icons.filter_alt : Icons.filter_alt_outlined),
            tooltip: 'Filter',
            onPressed: () => _openFilterSheet(provider),
          ),
          IconButton(
            icon: Icon(provider.memberListView == 'list' ? Icons.grid_view : Icons.view_list),
            tooltip: provider.memberListView == 'list' ? 'Grid view' : 'List view',
            onPressed: () => provider
                .setMemberListView(provider.memberListView == 'list' ? 'grid' : 'list'),
          ),
          PopupMenuButton<int>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            onSelected: (i) {
              final choice = _sortChoices[i];
              provider.setMemberSort(choice.$2, choice.$3);
            },
            itemBuilder: (context) => [
              for (var i = 0; i < _sortChoices.length; i++)
                CheckedPopupMenuItem<int>(
                  value: i,
                  checked: provider.memberSortField == _sortChoices[i].$2 &&
                      provider.memberSortReverse == _sortChoices[i].$3,
                  child: Text(_sortChoices[i].$1),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- Member grid/list ----------------

  Widget _buildMemberGrid(List<Member> members, SystemProvider provider, {Color? gradientTopColor}) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: members.length,
      itemBuilder: (context, i) {
        final member = members[i];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MemberEditScreen(member: member, groupColorForPreview: gradientTopColor),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  MemberAvatar(
                    member: member,
                    radius: 36,
                    avatarFullPath: provider.avatarPath(member.avatarFilename),
                    showFrontingBadge: provider.isFronting(member.id),
                    showColorRing: true,
                    gradientRingTopColor: gradientTopColor,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    member.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (member.roleDisplay.isNotEmpty)
                    Text(
                      member.roleDisplay,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMemberList(List<Member> members, SystemProvider provider, {Color? gradientTopColor}) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: members.length,
      itemBuilder: (context, i) {
        final member = members[i];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MemberEditScreen(member: member, groupColorForPreview: gradientTopColor),
              ),
            ),
            leading: MemberAvatar(
              member: member,
              radius: 22,
              avatarFullPath: provider.avatarPath(member.avatarFilename),
              showFrontingBadge: provider.isFronting(member.id),
              showColorRing: true,
              gradientRingTopColor: gradientTopColor,
            ),
            title: Text(member.name, overflow: TextOverflow.ellipsis),
            subtitle: member.roleDisplay.isNotEmpty ? Text(member.roleDisplay) : null,
            trailing: member.pronouns.isNotEmpty
                ? Text(member.pronouns, style: TextStyle(color: Colors.grey.shade600))
                : null,
          ),
        );
      },
    );
  }

  // ---------------- Group grid/list ----------------

  Widget _buildGroupsView(SystemProvider provider, bool isGrid) {
    final sortedGroups = [...provider.groups]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final ungrouped = provider.ungroupedMembers;

    if (sortedGroups.isEmpty && ungrouped.isEmpty) {
      return const Center(child: Text('No groups yet. Tap + to add one.'));
    }

    if (isGrid) {
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.85,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: sortedGroups.length + (ungrouped.isNotEmpty ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == sortedGroups.length) {
            return _ungroupedTile(isGrid: true, count: ungrouped.length);
          }
          return _groupTile(sortedGroups[i], provider, isGrid: true);
        },
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        for (final g in sortedGroups) _groupTile(g, provider, isGrid: false),
        if (ungrouped.isNotEmpty) _ungroupedTile(isGrid: false, count: ungrouped.length),
      ],
    );
  }

  Widget _groupTile(Group group, SystemProvider provider, {required bool isGrid}) {
    void onTap() => setState(() => _selectedGroup = group);
    void onLongPress() => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => GroupEditScreen(group: group)),
        );

    if (isGrid) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GroupAvatar(
                  group: group,
                  radius: 36,
                  avatarFullPath: provider.avatarPath(group.avatarFilename),
                  showColorRing: true,
                ),
                const SizedBox(height: 12),
                Text(
                  group.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${group.memberIds.length} member${group.memberIds.length == 1 ? '' : 's'}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        leading: GroupAvatar(
          group: group,
          radius: 22,
          avatarFullPath: provider.avatarPath(group.avatarFilename),
          showColorRing: true,
        ),
        title: Text(group.name, overflow: TextOverflow.ellipsis),
        subtitle: Text('${group.memberIds.length} member${group.memberIds.length == 1 ? '' : 's'}'),
      ),
    );
  }

  Widget _ungroupedTile({required bool isGrid, required int count}) {
    void onTap() => setState(() => _showingUngrouped = true);

    if (isGrid) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.grey.shade300,
                  child: Icon(Icons.person_outline, size: 36, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                const Text('Ungrouped', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('$count member${count == 1 ? '' : 's'}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: Colors.grey.shade300,
          child: Icon(Icons.person_outline, color: Colors.grey.shade600),
        ),
        title: const Text('Ungrouped'),
        subtitle: Text('$count member${count == 1 ? '' : 's'}'),
      ),
    );
  }

  // ---------------- FAB ----------------

  Widget _buildFab(SystemProvider provider) {
    if (!provider.groupsEnabled) {
      return FloatingActionButton(
        key: fabKey,
        heroTag: 'addMember',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MemberEditScreen(member: null)),
        ),
        child: const Icon(Icons.add),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _fabMiniOption(
          visible: _fabMenuOpen,
          heroTag: 'newGroup',
          icon: Icons.groups,
          label: 'New Group',
          onPressed: () {
            setState(() => _fabMenuOpen = false);
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GroupEditScreen(group: null)),
            );
          },
        ),
        const SizedBox(height: 12),
        _fabMiniOption(
          key: newMemberOptionKey,
          visible: _fabMenuOpen,
          heroTag: 'newMember',
          icon: Icons.person_add,
          label: 'New Member',
          onPressed: () {
            setState(() => _fabMenuOpen = false);
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MemberEditScreen(member: null)),
            );
          },
        ),
        const SizedBox(height: 12),
        FloatingActionButton(
          key: fabKey,
          heroTag: 'fabToggle',
          onPressed: () => setState(() => _fabMenuOpen = !_fabMenuOpen),
          child: Icon(_fabMenuOpen ? Icons.close : Icons.add),
        ),
      ],
    );
  }

  Widget _fabMiniOption({
    Key? key,
    required bool visible,
    required String heroTag,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    final reduceMotion = context.watch<SystemProvider>().reduceMotion;
    return AnimatedContainer(
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 540),
      curve: Curves.easeOut,
      height: visible ? 48 : 0,
      child: OverflowBox(
        minHeight: 48,
        maxHeight: 48,
        alignment: Alignment.bottomRight,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 450),
          child: IgnorePointer(
            ignoring: !visible,
            child: FloatingActionButton.extended(
              key: key,
              heroTag: heroTag,
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}