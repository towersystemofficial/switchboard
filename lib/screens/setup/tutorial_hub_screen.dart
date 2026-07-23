import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/system_provider.dart';
import '../../widgets/tour_overlay.dart';
import '../home_shell.dart';

class TutorialHubScreen extends StatelessWidget {
  const TutorialHubScreen({super.key});

  Future<void> _popToShell(BuildContext context) async {
    Navigator.of(context).popUntil((route) => route.isFirst);
    await Future.delayed(const Duration(milliseconds: 200));
  }

  /// Every tour ends back here rather than leaving the user stranded on
  /// whatever tab it last switched to.
  void _returnToHub(HomeShellState shell) {
    Navigator.of(shell.context).push(
      MaterialPageRoute(builder: (_) => const TutorialHubScreen()),
    );
  }

  Future<void> _runTabsTour(BuildContext context) async {
    final shell = homeShellKey.currentState;
    if (shell == null) return;
    await _popToShell(context);
    if (!shell.mounted) return;

    const labels = ['Home', 'History', 'Members', 'Stats', 'Settings'];
    const descriptions = [
      'The current fronting status and quick actions.',
      'A visual timeline of who has fronted and when.',
      'Everyone in your system: add, edit, group, and search.',
      'Charts and breakdowns of fronting patterns over time.',
      'Vault connection, profile, notifications, and this tutorial.',
    ];

    final steps = List.generate(5, (i) {
      return TourStep(
        title: labels[i],
        body: descriptions[i],
        onEnter: () => shell.goToTab(i),
        settleDelay: const Duration(milliseconds: 150),
      );
    });

    await startTour(shell.context, steps);
    _returnToHub(shell);
  }

  Future<void> _runAddMemberTour(BuildContext context) async {
    final shell = homeShellKey.currentState;
    if (shell == null) return;
    final groupsEnabled = context.read<SystemProvider>().groupsEnabled;

    await _popToShell(context);
    if (!shell.mounted) return;

    shell.goToTab(2);
    await Future.delayed(const Duration(milliseconds: 150));
    final members = shell.membersKey.currentState;
    if (members == null) return;

    final steps = <TourStep>[];
    if (groupsEnabled) {
      steps.add(TourStep(
        targetKey: members.fabKey,
        title: 'Add options',
        body: 'Tap this button to open the add menu: New Group or New Member.',
      ));
      steps.add(TourStep(
        targetKey: members.newMemberOptionKey,
        title: 'New Member',
        body: 'Then choose New Member here to create someone new.',
        onEnter: members.openFabMenuForTour,
        settleDelay: const Duration(milliseconds: 600),
      ));
    } else {
      steps.add(TourStep(
        targetKey: members.fabKey,
        title: 'Add a member',
        body: 'Tap this button any time to add a new member to your system.',
      ));
    }

    await startTour(shell.context, steps);
    _returnToHub(shell);
  }

  Future<void> _runLoggingTour(BuildContext context) async {
    final shell = homeShellKey.currentState;
    if (shell == null) return;
    await _popToShell(context);
    if (!shell.mounted) return;

    shell.goToTab(0);
    await Future.delayed(const Duration(milliseconds: 150));
    final dashboard = shell.dashboardKey.currentState;
    if (dashboard == null) return;

    final steps = [
      TourStep(
        targetKey: dashboard.fronterCardKey,
        title: 'Currently Fronting',
        body: 'Shows who is fronting right now. Tap it to expand into a '
            'per-person list, where you can end any one person\'s front.',
      ),
      TourStep(
        targetKey: dashboard.switchButtonKey,
        title: 'Switch Fronter',
        body: 'Opens a sheet with two modes: Set Fronter replaces everyone '
            'currently fronting with one person, Add Fronter adds someone '
            'without removing anyone else.',
      ),
      TourStep(
        targetKey: dashboard.recentHistoryKey,
        title: 'Recent History',
        body: 'A quick-glance list of the last few switches. The History '
            'tab has the full timeline with everything logged.',
      ),
    ];

    await startTour(shell.context, steps);
    _returnToHub(shell);
  }

  Future<void> _runHistoryTour(BuildContext context) async {
    final shell = homeShellKey.currentState;
    if (shell == null) return;
    await _popToShell(context);
    if (!shell.mounted) return;

    shell.goToTab(1);
    await Future.delayed(const Duration(milliseconds: 150));
    final history = shell.historyKey.currentState;
    if (history == null) return;

    final steps = [
      const TourStep(
        // No target -- there may not even be an entry to point at, and
        // this is more "here's the concept" than "here's one control".
        title: 'The Timeline',
        body: 'Each bar is a fronting entry. Time runs bottom-to-top, so '
            'the most recent switch is at the top, not the bottom. Tap a '
            'bar for its details.',
      ),
      TourStep(
        targetKey: history.toggleKey,
        title: 'List / Timeline toggle',
        body: 'Switches between this timeline and a simpler tap-to-edit '
            'list view.',
      ),
      TourStep(
        targetKey: history.addEntryFabKey,
        title: 'Add a custom entry',
        body: 'Logs a fronting entry with a specific start and end time -- '
            'handy for backfilling something you forgot to log in the '
            'moment.',
      ),
    ];

    await startTour(shell.context, steps);
    _returnToHub(shell);
  }

  Future<void> _runStatsTour(BuildContext context) async {
    final shell = homeShellKey.currentState;
    if (shell == null) return;
    await _popToShell(context);
    if (!shell.mounted) return;

    shell.goToTab(3);
    await Future.delayed(const Duration(milliseconds: 150));
    final stats = shell.statsKey.currentState;
    if (stats == null) return;

    final steps = [
      TourStep(
        targetKey: stats.graphTypeKey,
        title: 'Graph type',
        body: 'Switches the chart between a list, a bar chart, or a pie '
            'chart.',
      ),
      TourStep(
        targetKey: stats.dateRangeKey,
        title: 'Date range',
        body: 'The same range picker used in History -- day, week, month, '
            'and so on, up to a custom range.',
      ),
      TourStep(
        targetKey: stats.infoDisplayedKey,
        title: 'Information displayed',
        body: 'Frequency, duration, time-of-day, or switch-type. The last '
            'two break down by member instead of by count, filtered by a '
            'tab bar that appears just for those.',
      ),
      TourStep(
        targetKey: stats.sortByKey,
        title: 'Sort by',
        body: 'Most, least, or average. Average means per-switch for '
            'duration, but per-day for the count-based metrics -- a raw '
            'count needs a day to average against.',
      ),
    ];

    await startTour(shell.context, steps);
    _returnToHub(shell);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tutorial')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Quick walkthroughs of specific features -- pick one to see it '
            'pointed out on the real screen.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_add_alt),
              title: const Text('Add a member'),
              subtitle: const Text('Where the add button lives'),
              onTap: () => _runAddMemberTour(context),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.explore_outlined),
              title: const Text('Explore the tabs'),
              subtitle: const Text('What each tab at the bottom does'),
              onTap: () => _runTabsTour(context),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Log a switch'),
              subtitle: const Text('Setting or adding a fronter from Home'),
              onTap: () => _runLoggingTour(context),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.history),
              title: const Text('History timeline'),
              subtitle: const Text('Reading the timeline and adding entries'),
              onTap: () => _runHistoryTour(context),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('Statistics page'),
              subtitle: const Text('What each of the four dropdowns does'),
              onTap: () => _runStatsTour(context),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () {
          Navigator.of(context).popUntil((route) => route.isFirst);
          homeShellKey.currentState?.goToTab(0);
        },
        tooltip: 'Go to Home',
        child: const Icon(Icons.home),
      ),
    );
  }
}