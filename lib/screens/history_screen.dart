import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/front_entry.dart';
import '../models/member.dart';
import '../providers/system_provider.dart';
import '../utils/date_range.dart';
import '../widgets/member_avatar.dart';

class _PositionedBar {
  final FrontEntry entry;
  final double top;
  final double height;
  final int lane;
  const _PositionedBar({
    required this.entry,
    required this.top,
    required this.height,
    required this.lane,
  });
}

class _TimelineGrid {
  final List<DateTime> majors;
  final List<DateTime> minors;
  final bool minorLabeled;
  const _TimelineGrid(this.majors, this.minors, this.minorLabeled);
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  bool _showTimeline = true;
  DateRangeOption _dateRange = DateRangeOption.twoWeeks;
  DateTimeRange? _customRange;
  FrontEntry? _openInfoEntry;
  Offset? _openInfoTapPosition;
  final TransformationController _timelineTransform = TransformationController();

  /// Exposed for the "History timeline" tutorial.
  final GlobalKey toggleKey = GlobalKey();
  final GlobalKey addEntryFabKey = GlobalKey();

  @override
  void dispose() {
    _timelineTransform.dispose();
    super.dispose();
  }

  /// Resets the timeline's zoom/pan to the default view. Public so
  /// HomeShell's app bar button -- which lives above this screen, at the
  /// same level as the "History" title -- can trigger it via a GlobalKey.
  void resetZoom() {
    setState(() => _timelineTransform.value = Matrix4.identity());
  }

  static const double _pixelsPerHour = 40;
  static const double _minBarHeight = 28;
  static const double _barWidth = 22;
  static const double _laneSpacing = _barWidth * 1.0;
  static const double _lanePitch = _barWidth + _laneSpacing;
  static const double _gutterWidth = 58;
  static const double _laneAreaLeftPad = _barWidth * 0.75;

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: _customRange ??
          DateTimeRange(start: now.subtract(const Duration(days: 14)), end: now),
    );
    if (picked != null) {
      setState(() {
        _customRange = picked;
        _dateRange = DateRangeOption.custom;
        _openInfoEntry = null;
        _openInfoTapPosition = null;
      });
    }
  }

  DateTime _startOfWeek(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: (day.weekday - DateTime.monday) % 7));
  }

  /// Picks the gridline tiers: an hour-based minor scale for short ranges,
  /// stepping up to week-major/day-minor for ~3 months, then
  /// month-major/week-minor for anything longer (year, all time, or a
  /// long custom span).
  _TimelineGrid _buildGrid(DateTime rangeStart, DateTime rangeEnd) {
    final span = rangeEnd.difference(rangeStart);

    int? hourStep;
    if (_dateRange == DateRangeOption.day || span <= const Duration(hours: 30)) {
      hourStep = 1;
    } else if (_dateRange == DateRangeOption.week ||
        (_dateRange == DateRangeOption.custom && span <= const Duration(days: 8))) {
      hourStep = 2;
    } else if (_dateRange == DateRangeOption.twoWeeks ||
        (_dateRange == DateRangeOption.custom && span <= const Duration(days: 15))) {
      hourStep = 2;
    } else if (_dateRange == DateRangeOption.month ||
        (_dateRange == DateRangeOption.custom && span <= const Duration(days: 32))) {
      hourStep = 4;
    }

    if (hourStep != null) {
      final majors = <DateTime>[];
      var dayCursor = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
      if (dayCursor.isBefore(rangeStart)) dayCursor = dayCursor.add(const Duration(days: 1));
      while (dayCursor.isBefore(rangeEnd)) {
        majors.add(dayCursor);
        dayCursor = dayCursor.add(const Duration(days: 1));
      }

      final minors = <DateTime>[];
      var hourCursor = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
      while (hourCursor.isBefore(rangeStart)) {
        hourCursor = hourCursor.add(Duration(hours: hourStep));
      }
      while (hourCursor.isBefore(rangeEnd)) {
        if (hourCursor.hour != 0) minors.add(hourCursor);
        hourCursor = hourCursor.add(Duration(hours: hourStep));
      }
      return _TimelineGrid(majors, minors, true);
    }

    final isWeekTier = _dateRange == DateRangeOption.threeMonths ||
        (_dateRange == DateRangeOption.custom && span <= const Duration(days: 100));
    if (isWeekTier) {
      final majors = <DateTime>[];
      var weekCursor = _startOfWeek(rangeStart);
      if (weekCursor.isBefore(rangeStart)) weekCursor = weekCursor.add(const Duration(days: 7));
      while (weekCursor.isBefore(rangeEnd)) {
        majors.add(weekCursor);
        weekCursor = weekCursor.add(const Duration(days: 7));
      }
      final minors = <DateTime>[];
      var dayCursor = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
      if (dayCursor.isBefore(rangeStart)) dayCursor = dayCursor.add(const Duration(days: 1));
      while (dayCursor.isBefore(rangeEnd)) {
        minors.add(dayCursor);
        dayCursor = dayCursor.add(const Duration(days: 1));
      }
      return _TimelineGrid(majors, minors, false);
    }

    // Month-major / week-minor -- year, all time, or a long custom span.
    final majors = <DateTime>[];
    var monthCursor = DateTime(rangeStart.year, rangeStart.month, 1);
    if (monthCursor.isBefore(rangeStart)) {
      monthCursor = DateTime(monthCursor.year, monthCursor.month + 1, 1);
    }
    while (monthCursor.isBefore(rangeEnd)) {
      majors.add(monthCursor);
      monthCursor = DateTime(monthCursor.year, monthCursor.month + 1, 1);
    }
    final minors = <DateTime>[];
    var weekCursor = _startOfWeek(rangeStart);
    if (weekCursor.isBefore(rangeStart)) weekCursor = weekCursor.add(const Duration(days: 7));
    while (weekCursor.isBefore(rangeEnd)) {
      minors.add(weekCursor);
      weekCursor = weekCursor.add(const Duration(days: 7));
    }
    return _TimelineGrid(majors, minors, false);
  }

  /// Lays out bars top-to-bottom in pixel space (already reversed so the
  /// most recent time is near the top). Since later entries are always
  /// positioned at-or-above everything placed before them, "no overlap"
  /// for a new entry means its bottom edge sits at or above the lane's
  /// last-used top edge -- tracking tops (not bottoms) is what lets a
  /// lane free up and get reused instead of every entry drifting into a
  /// brand-new lane forever.
  List<_PositionedBar> _layoutBars(
    List<FrontEntry> entries,
    DateTime rangeStart,
    DateTime rangeEnd,
    double Function(DateTime) topFor,
  ) {
    final sorted = [...entries]..sort((a, b) => a.start.compareTo(b.start));

    final laneTops = <double>[];
    final result = <_PositionedBar>[];
    for (final e in sorted) {
      final clippedStart = e.start.isBefore(rangeStart) ? rangeStart : e.start;
      final rawEnd = e.end ?? DateTime.now();
      final clippedEnd = rawEnd.isAfter(rangeEnd) ? rangeEnd : rawEnd;

      final topEdge = topFor(clippedEnd); // later time -> smaller pixel value -> visual top
      final bottomEdge = topFor(clippedStart); // earlier time -> larger pixel value -> visual bottom
      final rawHeight = bottomEdge - topEdge;
      final height = rawHeight < _minBarHeight ? _minBarHeight : rawHeight;
      final top = topEdge;
      final bottom = top + height;

      // Require half a bar-width of clearance, not just non-overlap --
      // enough to keep touching bars visually distinct without being as
      // aggressive as a full bar-width (which split lanes too eagerly).
      int? foundLane;
      for (var i = 0; i < laneTops.length; i++) {
        if (bottom <= laneTops[i] - _barWidth / 2) {
          foundLane = i;
          break;
        }
      }
      if (foundLane != null) {
        laneTops[foundLane] = top;
      } else {
        foundLane = laneTops.length;
        laneTops.add(top);
      }

      result.add(_PositionedBar(entry: e, top: top, height: height, lane: foundLane));
    }
    return result;
  }

  Future<void> _editEntry(BuildContext context, SystemProvider provider, FrontEntry entry) async {
    DateTime start = entry.start;
    DateTime? end = entry.end;
    final notesController = TextEditingController(text: entry.notes);

    Future<DateTime?> pickDateTime(DateTime initial) async {
      final date = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2015),
        lastDate: DateTime.now().add(const Duration(days: 1)),
      );
      if (date == null) return null;
      if (!context.mounted) return null;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
      );
      if (time == null) return null;
      return DateTime(date.year, date.month, date.day, time.hour, time.minute);
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit fronting entry'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Start'),
                      subtitle: Text(provider.formatDateTime(start)),
                      trailing: const Icon(Icons.edit),
                      onTap: () async {
                        final picked = await pickDateTime(start);
                        if (picked != null) setState(() => start = picked);
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('End'),
                      subtitle: Text(end != null ? provider.formatDateTime(end!) : 'Still fronting'),
                      trailing: const Icon(Icons.edit),
                      onTap: () async {
                        final picked = await pickDateTime(end ?? DateTime.now());
                        if (picked != null) setState(() => end = picked);
                      },
                    ),
                    if (end != null)
                      TextButton(
                        onPressed: () => setState(() => end = null),
                        child: const Text('Mark as still fronting'),
                      ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(labelText: 'Notes'),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    await provider.deleteEntry(entry);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Delete'),
                ),
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () async {
                    final index = provider.entries.indexOf(entry);
                    final updated = entry.copyWith(
                      start: start,
                      end: end,
                      clearEnd: end == null,
                      notes: notesController.text,
                    );
                    await provider.updateEntry(index, updated);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addCustomEntry(BuildContext context, SystemProvider provider) async {
    if (provider.members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a member before logging a custom entry.')),
      );
      return;
    }

    String? memberId;
    DateTime? start;
    DateTime? end;
    final notesController = TextEditingController();
    String? errorText;
    bool showingPicker = false;

    Future<DateTime?> pickDateTime(DateTime initial) async {
      final date = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2015),
        lastDate: DateTime.now().add(const Duration(days: 1)),
      );
      if (date == null) return null;
      if (!context.mounted) return null;
      final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
      if (time == null) return null;
      return DateTime(date.year, date.month, date.day, time.hour, time.minute);
    }

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            final screenHeight = MediaQuery.of(dialogContext).size.height;

            final Widget content = showingPicker
                ? _buildInlinePicker(
                    dialogContext,
                    provider,
                    screenHeight: screenHeight,
                    onBack: () => setState(() => showingPicker = false),
                    onPicked: (id) => setState(() {
                      memberId = id;
                      showingPicker = false;
                    }),
                  )
                : _buildEntryForm(
                    dialogContext,
                    provider,
                    memberId: memberId,
                    onOpenPicker: () => setState(() => showingPicker = true),
                    startText: start != null ? provider.formatDateTime(start!) : 'Tap to set',
                    endText: end != null ? provider.formatDateTime(end!) : 'Tap to set',
                    onPickStart: () async {
                      final picked = await pickDateTime(start ?? DateTime.now());
                      if (picked != null) setState(() => start = picked);
                    },
                    onPickEnd: () async {
                      final picked = await pickDateTime(end ?? start ?? DateTime.now());
                      if (picked != null) setState(() => end = picked);
                    },
                    notesController: notesController,
                    errorText: errorText,
                    onCancel: () => Navigator.of(dialogContext).pop(),
                    onSave: () async {
                      if (memberId == null || start == null || end == null) {
                        setState(() => errorText = 'Fronter, start, and end are all required.');
                        return;
                      }
                      if (!end!.isAfter(start!)) {
                        setState(() => errorText = 'End must be after start.');
                        return;
                      }
                      final newEntry = FrontEntry(
                        memberId: memberId!,
                        start: start!,
                        end: end!,
                        notes: notesController.text,
                      );
                      await provider.addManualEntry(newEntry);
                      if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                    },
                  );

            return Dialog(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeInOut,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween(begin: 0.96, end: 1.0).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Container(
                      key: ValueKey(showingPicker),
                      child: content,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEntryForm(
    BuildContext context,
    SystemProvider provider, {
    required String? memberId,
    required VoidCallback onOpenPicker,
    required String startText,
    required String endText,
    required VoidCallback onPickStart,
    required VoidCallback onPickEnd,
    required TextEditingController notesController,
    required String? errorText,
    required VoidCallback onCancel,
    required VoidCallback onSave,
  }) {
    final member = memberId != null ? provider.memberById(memberId) : null;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add custom fronting entry', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onOpenPicker,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  member != null
                      ? MemberAvatar(
                          member: member,
                          radius: 26,
                          avatarFullPath: provider.avatarPath(member.avatarFilename),
                          showColorRing: true,
                        )
                      : Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade400, width: 1.5),
                          ),
                          child: Icon(Icons.person_outline, size: 28, color: Colors.grey.shade400),
                        ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      member?.name ?? '_______________',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: member != null ? FontWeight.bold : FontWeight.normal,
                        color: member != null ? null : Colors.grey.shade400,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
          const Divider(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Start'),
            subtitle: Text(startText),
            trailing: const Icon(Icons.edit),
            onTap: onPickStart,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('End'),
            subtitle: Text(endText),
            trailing: const Icon(Icons.edit),
            onTap: onPickEnd,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: notesController,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
            maxLines: 3,
          ),
          if (errorText != null) ...[
            const SizedBox(height: 8),
            Text(errorText, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: onCancel, child: const Text('Cancel')),
              const SizedBox(width: 8),
              FilledButton(onPressed: onSave, child: const Text('Save')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInlinePicker(
    BuildContext context,
    SystemProvider provider, {
    required double screenHeight,
    required VoidCallback onBack,
    required ValueChanged<String> onPicked,
  }) {
    final isGrid = provider.memberListView != 'list';
    final members = [...provider.members]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return SizedBox(
      height: screenHeight * 0.7,
      width: double.maxFinite,
      child: Column(
        children: [
          Row(
            children: [
              IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack, tooltip: 'Back'),
              Expanded(
                child: Text('Choose fronter', style: Theme.of(context).textTheme.titleMedium),
              ),
              IconButton(
                icon: Icon(provider.memberListView == 'list' ? Icons.grid_view : Icons.view_list),
                tooltip: provider.memberListView == 'list' ? 'Grid view' : 'List view',
                onPressed: () =>
                    provider.setMemberListView(provider.memberListView == 'list' ? 'grid' : 'list'),
              ),
            ],
          ),
          Expanded(
            child: members.isEmpty
                ? const Center(child: Text('No members yet.'))
                : (isGrid
                    ? _buildPickerGrid(members, provider, onPicked)
                    : _buildPickerList(members, provider, onPicked)),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerGrid(List<Member> members, SystemProvider provider, ValueChanged<String> onPicked) {
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
            onTap: () => onPicked(member.id),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  MemberAvatar(
                    member: member,
                    radius: 32,
                    avatarFullPath: provider.avatarPath(member.avatarFilename),
                    showFrontingBadge: provider.isFronting(member.id),
                    showColorRing: true,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    member.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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

  Widget _buildPickerList(List<Member> members, SystemProvider provider, ValueChanged<String> onPicked) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      itemCount: members.length,
      itemBuilder: (context, i) {
        final member = members[i];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            onTap: () => onPicked(member.id),
            leading: MemberAvatar(
              member: member,
              radius: 20,
              avatarFullPath: provider.avatarPath(member.avatarFilename),
              showFrontingBadge: provider.isFronting(member.id),
              showColorRing: true,
            ),
            title: Text(member.name, overflow: TextOverflow.ellipsis),
            subtitle: member.roleDisplay.isNotEmpty ? Text(member.roleDisplay) : null,
          ),
        );
      },
    );
  }

  Widget _buildControls() {
    return Row(
      children: [
        ToggleButtons(
          key: toggleKey,
          isSelected: [_showTimeline, !_showTimeline],
          onPressed: (i) => setState(() {
            _showTimeline = i == 0;
            _openInfoEntry = null;
            _openInfoTapPosition = null;
          }),
          borderRadius: BorderRadius.circular(8),
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Icon(Icons.view_timeline_outlined),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Icon(Icons.list),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<DateRangeOption>(
            value: _dateRange,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Date range',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(),
            ),
            items: [
              for (final entry in dateRangeLabels.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value, style: const TextStyle(fontSize: 13))),
            ],
            onChanged: (v) {
              if (v == null) return;
              if (v == DateRangeOption.custom) {
                _pickCustomRange();
              } else {
                setState(() {
                  _dateRange = v;
                  _openInfoEntry = null;
                  _openInfoTapPosition = null;
                });
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildList(SystemProvider provider, List<FrontEntry> history) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: history.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final entry = history[i];
        final member = provider.memberById(entry.memberId);
        final h = entry.duration.inHours;
        final m = entry.duration.inMinutes % 60;
        return ListTile(
          leading: MemberAvatar(
            member: member,
            radius: 20,
            avatarFullPath: provider.avatarPath(member?.avatarFilename),
          ),
          title: Text(member?.name ?? 'Unknown'),
          subtitle: Text(
            entry.isActive
                ? 'Since ${provider.formatDateTime(entry.start)} \u00b7 ongoing'
                : '${provider.formatDateTime(entry.start)} \u2192 '
                  '${provider.formatTime(entry.end!)} \u00b7 ${h}h ${m}m',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _editEntry(context, provider, entry),
        );
      },
    );
  }

  Widget _buildTimelineBar(BuildContext context, SystemProvider provider, _PositionedBar bar) {
    final member = provider.memberById(bar.entry.memberId);
    return Positioned(
      top: bar.top,
      left: _laneAreaLeftPad + bar.lane * _lanePitch,
      width: _barWidth,
      height: bar.height,
      child: GestureDetector(
        onTapDown: (details) {
          final barLeft = _laneAreaLeftPad + bar.lane * _lanePitch;
          setState(() {
            _openInfoEntry = bar.entry;
            _openInfoTapPosition = Offset(
              barLeft + details.localPosition.dx,
              bar.top + details.localPosition.dy,
            );
          });
        },
        child: Container(
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: (member?.color ?? Colors.grey).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: MemberAvatar(
                member: member,
                radius: 9,
                avatarFullPath: provider.avatarPath(member?.avatarFilename),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The tap-info card, positioned at the actual tap point in the *same*
  /// coordinate space as the bars (not a screen-fixed overlay), so it
  /// scrolls with the timeline instead of floating in place.
  Widget _buildInlineInfoCard(
    BuildContext context,
    SystemProvider provider,
    FrontEntry entry,
    Offset tapPosition,
    double contentWidth,
    double totalHeight,
  ) {
    final member = provider.memberById(entry.memberId);
    const cardWidth = 220.0;
    const estimatedHeight = 175.0;

    double left = tapPosition.dx + 12;
    if (left + cardWidth > contentWidth - 4) {
      left = tapPosition.dx - cardWidth - 12;
    }
    if (left < 4) left = 4;
    if (left + cardWidth > contentWidth - 4) left = contentWidth - cardWidth - 4;

    double top = tapPosition.dy - estimatedHeight / 2;
    if (top + estimatedHeight > totalHeight - 4) top = totalHeight - estimatedHeight - 4;
    if (top < 4) top = 4;

    return Positioned(
      left: left,
      top: top,
      width: cardWidth,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  MemberAvatar(
                    member: member,
                    radius: 18,
                    avatarFullPath: provider.avatarPath(member?.avatarFilename),
                    showColorRing: true,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      member?.name ?? 'Unknown',
                      style: Theme.of(context).textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Edit',
                    onPressed: () {
                      setState(() {
                        _openInfoEntry = null;
                        _openInfoTapPosition = null;
                      });
                      _editEntry(context, provider, entry);
                    },
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Close',
                    onPressed: () => setState(() {
                      _openInfoEntry = null;
                      _openInfoTapPosition = null;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text('Start: ${provider.formatDateTime(entry.start)}', style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 3),
              Text(
                'End: ${entry.end != null ? provider.formatDateTime(entry.end!) : 'N/A (still fronting)'}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 6),
              Text(
                entry.notes.isEmpty ? 'No notes' : entry.notes,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeline(
    BuildContext context,
    SystemProvider provider,
    List<FrontEntry> entries,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    final rawTotalMinutes = rangeEnd.difference(rangeStart).inSeconds / 60.0;
    final totalMinutes = rawTotalMinutes < 60 ? 60.0 : rawTotalMinutes;
    final totalHeight = totalMinutes / 60 * _pixelsPerHour;

    // Reversed: later times map to smaller pixel values, so the most
    // recent moment in the range sits at the top of the scroll view.
    // Uses seconds rather than whole minutes so brief or close-together
    // overlaps don't get rounded away when deciding if bars collide.
    double topFor(DateTime t) {
      final minutesFromStart = t.difference(rangeStart).inSeconds / 60.0;
      return totalHeight - (minutesFromStart / 60 * _pixelsPerHour);
    }

    final positioned = _layoutBars(entries, rangeStart, rangeEnd, topFor);
    final grid = _buildGrid(rangeStart, rangeEnd);
    final maxLane = positioned.isEmpty ? 0 : positioned.map((b) => b.lane).reduce((a, b) => a > b ? a : b);
    final contentWidth = _laneAreaLeftPad + (maxLane + 1) * _lanePitch + 8;
    final totalWidth = _gutterWidth + contentWidth;

    final content = SizedBox(
      width: totalWidth,
      height: totalHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _gutterWidth,
            height: totalHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (final d in grid.majors)
                  Positioned(
                    top: topFor(d) - 6,
                    left: 0,
                    child: Text(
                      provider.formatDate(d),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ),
                if (grid.minorLabeled)
                  for (final t in grid.minors)
                    Positioned(
                      top: topFor(t) - 5,
                      left: 0,
                      child: Text(
                        provider.formatTime(t),
                        style: TextStyle(fontSize: 8, color: Colors.grey.shade500),
                      ),
                    ),
              ],
            ),
          ),
          SizedBox(
            width: contentWidth,
            height: totalHeight,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      if (_openInfoEntry != null) {
                        setState(() {
                          _openInfoEntry = null;
                          _openInfoTapPosition = null;
                        });
                      }
                    },
                  ),
                ),
                for (final d in grid.majors)
                  Positioned(
                    top: topFor(d),
                    left: 0,
                    width: contentWidth,
                    child: Container(height: 1, color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                for (final t in grid.minors)
                  Positioned(
                    top: topFor(t),
                    left: 0,
                    width: contentWidth,
                    child: Container(height: 1, color: Colors.grey.withValues(alpha: 0.12)),
                  ),
                for (final bar in positioned) _buildTimelineBar(context, provider, bar),
                if (_openInfoEntry != null && _openInfoTapPosition != null)
                  _buildInlineInfoCard(
                    context,
                    provider,
                    _openInfoEntry!,
                    _openInfoTapPosition!,
                    contentWidth,
                    totalHeight,
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        // Zooming out is capped at "the whole width fits in view" (i.e.
        // every lane visible without horizontal scrolling); zooming in is
        // capped at 4x. minScale can't exceed 1.0 (that would force an
        // initial zoom-in), and is floored so it's never zero/negative.
        final fitScale = totalWidth <= 0 ? 1.0 : viewportWidth / totalWidth;
        final minScale = (fitScale < 1.0 ? fitScale : 1.0).clamp(0.02, 1.0);

        return InteractiveViewer(
          transformationController: _timelineTransform,
          constrained: false,
          minScale: minScale,
          maxScale: 4.0,
          // Zero margin -- panning is bounded to the graph's own edges,
          // no scrolling out into empty space beyond it.
          boundaryMargin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: content,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SystemProvider>();

    if (!provider.isVaultConfigured) {
      return const Center(child: Text('Set up your vault folder in Settings first.'));
    }

    final resolved = resolveDateRange(_dateRange, _customRange);
    final rangeEnd = resolved.end ?? DateTime.now();
    DateTime rangeStart;
    if (resolved.start != null) {
      rangeStart = resolved.start!;
    } else if (provider.entries.isNotEmpty) {
      rangeStart = provider.entries.map((e) => e.start).reduce((a, b) => a.isBefore(b) ? a : b);
    } else {
      rangeStart = rangeEnd.subtract(const Duration(days: 14));
    }

    final filtered = provider.entries.where((e) {
      final entryEnd = e.end ?? DateTime.now();
      if (entryEnd.isBefore(rangeStart)) return false;
      if (e.start.isAfter(rangeEnd)) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.start.compareTo(a.start));

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: _buildControls(),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No fronting history in this range.'))
                : (_showTimeline
                    ? _buildTimeline(context, provider, filtered, rangeStart, rangeEnd)
                    : _buildList(provider, filtered)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: addEntryFabKey,
        onPressed: () => _addCustomEntry(context, provider),
        tooltip: 'Add custom entry',
        child: const Icon(Icons.add),
      ),
    );
  }
}