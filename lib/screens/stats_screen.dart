import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/member.dart';
import '../providers/system_provider.dart';
import '../utils/date_range.dart';
import '../widgets/member_avatar.dart';

enum _GraphType { bar, pie, list }

enum _InfoDisplayed { frequency, duration, timeOfDay, switchType }

enum _InfoType { most, least, average }

class _StatBucket {
  final String label;
  final Color color;
  final Member? member;
  final double sortValue;
  final String displayValue;

  const _StatBucket({
    required this.label,
    required this.color,
    required this.sortValue,
    required this.displayValue,
    this.member,
  });
}

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => StatsScreenState();
}

class StatsScreenState extends State<StatsScreen> {
  _GraphType _graphType = _GraphType.list;

  /// Exposed for the "Statistics page" tutorial.
  final GlobalKey graphTypeKey = GlobalKey();
  final GlobalKey dateRangeKey = GlobalKey();
  final GlobalKey infoDisplayedKey = GlobalKey();
  final GlobalKey sortByKey = GlobalKey();
  DateRangeOption _dateRange = DateRangeOption.allTime;
  _InfoDisplayed _infoDisplayed = _InfoDisplayed.frequency;
  _InfoType _infoType = _InfoType.most;
  DateTimeRange? _customRange;

  // Sub-filters for the two "which alters" breakdowns. Morning/Day/Night
  // left-to-right, Co-fronting/Solo left-to-right, per the ordering asked for.
  int _timeOfDayTabIndex = 0;
  int _switchTypeTabIndex = 0;

  static const _timeOfDayLabels = ['Morning', 'Day', 'Night'];
  static const _switchTypeLabels = ['Solo', 'Co-fronting'];

  DateTime? get _rangeStart => resolveDateRange(_dateRange, _customRange).start;

  DateTime? get _rangeEnd => resolveDateRange(_dateRange, _customRange).end;

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: _customRange ??
          DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
    );
    if (picked != null) {
      setState(() {
        _customRange = picked;
        _dateRange = DateRangeOption.custom;
      });
    }
  }

  int _daysInRange(SystemProvider provider) {
    DateTime start;
    final rs = _rangeStart;
    if (rs != null) {
      start = rs;
    } else if (provider.entries.isNotEmpty) {
      start = provider.entries.map((e) => e.start).reduce((a, b) => a.isBefore(b) ? a : b);
    } else {
      return 1;
    }
    final end = _rangeEnd ?? DateTime.now();
    final days = end.difference(start).inDays;
    return days < 1 ? 1 : days;
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  List<_StatBucket> _memberBuckets(
    SystemProvider provider,
    Map<String, double> raw,
    String Function(double) formatter,
  ) {
    final buckets = <_StatBucket>[];
    for (final m in provider.members) {
      final v = raw[m.id];
      if (v == null) continue;
      buckets.add(_StatBucket(
        label: m.name,
        color: m.color,
        member: m,
        sortValue: v,
        displayValue: formatter(v),
      ));
    }
    return buckets;
  }

  List<_StatBucket> _computeRawBuckets(SystemProvider provider) {
    final start = _rangeStart;
    final end = _rangeEnd;
    String countLabel(double v) => '${v.toInt()} switch${v.toInt() == 1 ? '' : 'es'}';

    switch (_infoDisplayed) {
      case _InfoDisplayed.frequency:
        final raw = provider.switchCountsByMember(start: start, end: end);
        return _memberBuckets(provider, raw.map((k, v) => MapEntry(k, v.toDouble())), countLabel);
      case _InfoDisplayed.duration:
        final source = _infoType == _InfoType.average
            ? provider.averageDurationByMember(start: start, end: end)
            : provider.totalDurationByMember(start: start, end: end);
        return _memberBuckets(
          provider,
          source.map((k, v) => MapEntry(k, v.inSeconds.toDouble())),
          (v) => _formatDuration(Duration(seconds: v.toInt())),
        );
      case _InfoDisplayed.timeOfDay:
        final bucketName = _timeOfDayLabels[_timeOfDayTabIndex];
        final raw = provider.switchCountsByMemberInTimeOfDay(bucketName, start: start, end: end);
        return _memberBuckets(provider, raw.map((k, v) => MapEntry(k, v.toDouble())), countLabel);
      case _InfoDisplayed.switchType:
        final typeName = _switchTypeLabels[_switchTypeTabIndex];
        final raw = provider.switchCountsByMemberForType(typeName, start: start, end: end);
        return _memberBuckets(provider, raw.map((k, v) => MapEntry(k, v.toDouble())), countLabel);
    }
  }

  /// "Average" means average-per-switch for duration (already handled by
  /// swapping the source map above), and average-per-day for the count
  /// based metrics (frequency/time-of-day/switch-type), since a raw count
  /// has nothing else meaningful to average against.
  List<_StatBucket> _finalizeBuckets(SystemProvider provider, List<_StatBucket> raw) {
    final isCountBased = _infoDisplayed != _InfoDisplayed.duration;
    var buckets = raw;
    if (_infoType == _InfoType.average && isCountBased) {
      final days = _daysInRange(provider);
      buckets = [
        for (final b in buckets)
          _StatBucket(
            label: b.label,
            color: b.color,
            member: b.member,
            sortValue: b.sortValue / days,
            displayValue: '${(b.sortValue / days).toStringAsFixed(2)}/day avg',
          ),
      ];
    }
    buckets = [...buckets]
      ..sort((a, b) => _infoType == _InfoType.least
          ? a.sortValue.compareTo(b.sortValue)
          : b.sortValue.compareTo(a.sortValue));
    return buckets;
  }

  Widget _dropdown<T>({
    Key? fieldKey,
    required String label,
    required T value,
    required Map<T, String> items,
    required ValueChanged<T> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      key: fieldKey,
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final entry in items.entries)
          DropdownMenuItem(value: entry.key, child: Text(entry.value, style: const TextStyle(fontSize: 13))),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget _buildControls(SystemProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _dropdown<_GraphType>(
                fieldKey: graphTypeKey,
                label: 'Graph type',
                value: _graphType,
                items: const {
                  _GraphType.list: 'List',
                  _GraphType.bar: 'Bar chart',
                  _GraphType.pie: 'Pie chart',
                },
                onChanged: (v) => setState(() => _graphType = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _dropdown<DateRangeOption>(
                fieldKey: dateRangeKey,
                label: 'Date range',
                value: _dateRange,
                items: dateRangeLabels,
                onChanged: (v) {
                  if (v == DateRangeOption.custom) {
                    _pickCustomRange();
                  } else {
                    setState(() => _dateRange = v);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _dropdown<_InfoDisplayed>(
                fieldKey: infoDisplayedKey,
                label: 'Information displayed',
                value: _infoDisplayed,
                items: const {
                  _InfoDisplayed.frequency: 'Switch frequency',
                  _InfoDisplayed.duration: 'Fronting duration',
                  _InfoDisplayed.timeOfDay: 'Time of fronting',
                  _InfoDisplayed.switchType: 'Switch type',
                },
                onChanged: (v) => setState(() => _infoDisplayed = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _dropdown<_InfoType>(
                fieldKey: sortByKey,
                label: 'Sort by',
                value: _infoType,
                items: const {
                  _InfoType.most: 'Most',
                  _InfoType.least: 'Least',
                  _InfoType.average: 'Average',
                },
                onChanged: (v) => setState(() => _infoType = v),
              ),
            ),
          ],
        ),
        if (_dateRange == DateRangeOption.custom && _customRange != null) ...[
          const SizedBox(height: 8),
          Text(
            '${provider.formatDate(_customRange!.start)} \u2013 ${provider.formatDate(_customRange!.end)}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ],
    );
  }

  Widget _buildSubTabs() {
    List<String>? labels;
    int currentIndex = 0;
    ValueChanged<int>? onTap;

    if (_infoDisplayed == _InfoDisplayed.timeOfDay) {
      labels = _timeOfDayLabels;
      currentIndex = _timeOfDayTabIndex;
      onTap = (i) => setState(() => _timeOfDayTabIndex = i);
    } else if (_infoDisplayed == _InfoDisplayed.switchType) {
      labels = _switchTypeLabels;
      currentIndex = _switchTypeTabIndex;
      onTap = (i) => setState(() => _switchTypeTabIndex = i);
    }

    if (labels == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DefaultTabController(
        length: labels.length,
        initialIndex: currentIndex,
        child: TabBar(
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          onTap: onTap,
          tabs: [for (final l in labels) Tab(text: l)],
        ),
      ),
    );
  }

  Widget _buildHorizontalBars(SystemProvider provider, List<_StatBucket> buckets) {
    final maxVal = buckets.map((b) => b.sortValue).reduce((a, b) => a > b ? a : b);
    final safeMax = maxVal <= 0 ? 1.0 : maxVal;

    return Column(
      children: [
        for (final b in buckets)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Row(
                    children: [
                      b.member != null
                          ? MemberAvatar(
                              member: b.member!,
                              radius: 12,
                              avatarFullPath: provider.avatarPath(b.member!.avatarFilename),
                            )
                          : CircleAvatar(radius: 12, backgroundColor: b.color),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          b.label,
                          style: const TextStyle(fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (b.sortValue / safeMax).clamp(0.02, 1.0),
                    child: Container(
                      height: 22,
                      decoration: BoxDecoration(
                        color: b.color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 64,
                  child: Text(
                    b.displayValue,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _showBucketDetail(BuildContext context, SystemProvider provider, _StatBucket b) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            b.member != null
                ? MemberAvatar(
                    member: b.member!,
                    radius: 20,
                    avatarFullPath: provider.avatarPath(b.member!.avatarFilename),
                  )
                : CircleAvatar(radius: 20, backgroundColor: b.color),
            const SizedBox(width: 12),
            Expanded(child: Text(b.label)),
          ],
        ),
        content: Text(b.displayValue, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  PieChartSectionData _buildPieSection(
    BuildContext context,
    List<_StatBucket> buckets,
    int i,
    double total,
  ) {
    final b = buckets[i];
    final pct = total <= 0 ? 0.0 : b.sortValue / total * 100;
    final isSmall = pct < 8;
    return PieChartSectionData(
      value: b.sortValue,
      color: b.color,
      title: isSmall ? '' : '${pct.toStringAsFixed(0)}%\n${b.label}',
      radius: 90,
      titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      badgePositionPercentageOffset: 1.3,
      badgeWidget: isSmall
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: b.color, width: 1),
              ),
              child: Text('${b.label} ${pct.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 9)),
            )
          : null,
    );
  }

  Widget _buildPieChart(BuildContext context, SystemProvider provider, List<_StatBucket> buckets) {
    final total = buckets.fold<double>(0, (sum, b) => sum + b.sortValue);
    return SizedBox(
      height: 280,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 40,
          pieTouchData: PieTouchData(
            touchCallback: (event, response) {
              if (event is! FlTapUpEvent) return;
              final index = response?.touchedSection?.touchedSectionIndex;
              if (index == null || index < 0 || index >= buckets.length) return;
              _showBucketDetail(context, provider, buckets[index]);
            },
          ),
          sections: [
            for (int i = 0; i < buckets.length; i++) _buildPieSection(context, buckets, i, total),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(BuildContext context, SystemProvider provider, List<_StatBucket> buckets) {
    switch (_graphType) {
      case _GraphType.bar:
        return _buildHorizontalBars(provider, buckets);
      case _GraphType.pie:
        return _buildPieChart(context, provider, buckets);
      case _GraphType.list:
        return const SizedBox.shrink();
    }
  }

  Widget _buildLegendList(SystemProvider provider, List<_StatBucket> buckets) {
    return Column(
      children: [
        for (final b in buckets)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: b.member != null
                  ? MemberAvatar(
                      member: b.member!,
                      radius: 18,
                      avatarFullPath: provider.avatarPath(b.member!.avatarFilename),
                    )
                  : CircleAvatar(radius: 18, backgroundColor: b.color),
              title: Text(b.label),
              trailing: Text(b.displayValue, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SystemProvider>();

    if (!provider.isVaultConfigured) {
      return const Center(child: Text('Set up your vault folder in Settings first.'));
    }
    if (provider.entries.isEmpty || provider.members.isEmpty) {
      return const Center(child: Text('Log some switches to see stats here.'));
    }

    final buckets = _finalizeBuckets(provider, _computeRawBuckets(provider));
    final showChart = _graphType != _GraphType.list;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildControls(provider),
        _buildSubTabs(),
        if (buckets.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text('No switches in this date range.')),
          )
        else ...[
          if (showChart) ...[
            _buildChart(context, provider, buckets),
            const SizedBox(height: 20),
          ],
          _buildLegendList(provider, buckets),
        ],
      ],
    );
  }
}