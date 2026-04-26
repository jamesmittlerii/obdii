// Port of RootTabView.swift — Jim Mittler
// 5-tab navigation: Settings | Gauges | Fuel | MIL | DTCs
// Mirrors Swift TabView with matching tab items.

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../viewmodels/diagnostics_viewmodel.dart';
import '../viewmodels/fuel_status_viewmodel.dart';
import '../viewmodels/gauges_viewmodel.dart';
import '../viewmodels/mil_status_viewmodel.dart';

import 'dashboard_view.dart';
import 'diagnostics_view.dart';
import 'fuel_status_view.dart';
import 'mil_status_view.dart';
import 'settings_view.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  late final CupertinoTabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = CupertinoTabController(initialIndex: 0);
    _tabController.addListener(_handleTabIndexChange);
  }

  void _handleTabIndexChange() {
    if (!mounted) return;
    _syncViewVisibility();
    setState(() {});
  }

  void _syncViewVisibility() {
    final selectedIndex = _tabController.index;
    context.read<GaugesViewModel>().setVisible(selectedIndex == 1);
    context.read<FuelStatusViewModel>().setVisible(selectedIndex == 2);
    context.read<MilStatusViewModel>().setVisible(selectedIndex == 3);
    context.read<DiagnosticsViewModel>().setVisible(selectedIndex == 4);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ensure interest registration matches initially selected tab.
    _syncViewVisibility();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabIndexChange);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const SettingsView(),
      const GaugesView(),
      const FuelStatusView(),
      const MilStatusView(),
      const DiagnosticsView(),
    ];

    return CupertinoTabScaffold(
      controller: _tabController,
      tabBar: CupertinoTabBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.settings),
            label: 'Settings',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.speedometer),
            label: 'Gauges',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.drop),
            label: 'Fuel',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.exclamationmark_shield),
            label: 'MIL',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.wrench),
            label: 'DTCs',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        return CupertinoTabView(
          builder: (context) => pages[index],
        );
      },
    );
  }
}
