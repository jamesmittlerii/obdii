import 'package:flutter/cupertino.dart';

import '../widgets/check_engine_icon.dart';
import 'dashboard_view.dart';
import 'diagnostics_view.dart';
import 'fuel_status_view.dart';
import 'mil_status_view.dart';
import 'settings_view.dart';

class MainScaffoldCupertino extends StatefulWidget {
  const MainScaffoldCupertino({super.key});

  @override
  State<MainScaffoldCupertino> createState() => _MainScaffoldCupertinoState();
}

class _MainScaffoldCupertinoState extends State<MainScaffoldCupertino> {
  late final CupertinoTabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = CupertinoTabController(initialIndex: 0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      controller: _tabController,
      tabBar: CupertinoTabBar(
        items: [
          const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.settings),
            label: 'Settings',
          ),
          const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.speedometer),
            label: 'Gauges',
          ),
          const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.drop),
            label: 'Fuel',
          ),
          BottomNavigationBarItem(
            icon: CheckEngineIcon(color: CupertinoDynamicColor.resolve(CupertinoColors.inactiveGray, context)),
            activeIcon: CheckEngineIcon(color: CupertinoTheme.of(context).primaryColor),
            label: 'MIL',
          ),
          const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.wrench),
            label: 'DTCs',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        final isActive = _tabController.index == index;
        switch (index) {
          case 0:
            return const SettingsView();
          case 1:
            return GaugesView(isActive: isActive);
          case 2:
            return FuelStatusView(isActive: isActive);
          case 3:
            return MilStatusView(isActive: isActive);
          case 4:
            return DiagnosticsView(isActive: isActive);
          default:
            return const SettingsView();
        }
      },
    );
  }
}
