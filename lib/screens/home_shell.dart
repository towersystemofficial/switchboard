import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/system_provider.dart';
import 'dashboard_screen.dart';
import 'history_screen.dart';
import 'members_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';

final GlobalKey<HomeShellState> homeShellKey = GlobalKey<HomeShellState>();

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  int _index = 0;
  final dashboardKey = GlobalKey<DashboardScreenState>();
  final historyKey = GlobalKey<HistoryScreenState>();
  final membersKey = GlobalKey<MembersScreenState>();
  final statsKey = GlobalKey<StatsScreenState>();

  late final List<Widget> _screens = [
    DashboardScreen(key: dashboardKey),
    HistoryScreen(key: historyKey),
    MembersScreen(key: membersKey),
    StatsScreen(key: statsKey),
    const SettingsScreen(),
  ];

  static const _titles = ['SwitchBoard', 'History', 'Members', 'Stats', 'Settings'];

  /// Changes the visible tab, collapsing the Members "+" menu first if
  /// we're leaving that tab with it open.
  void _setIndex(int i) {
    if (_index == 2 && i != 2) {
      membersKey.currentState?.collapseFabMenu();
    }
    if (mounted) setState(() => _index = i);
  }

  /// Switches the visible tab from outside this widget (used by tours).
  void goToTab(int i) => _setIndex(i);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SystemProvider>();

    if (provider.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          if (_index == 1)
            IconButton(
              icon: const Icon(Icons.center_focus_strong),
              tooltip: 'Reset zoom/pan',
              onPressed: () => historyKey.currentState?.resetZoom(),
            ),
        ],
      ),
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _setIndex,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Members'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Stats'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}