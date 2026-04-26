// Port of RootTabView.swift — Jim Mittler
// 5-tab navigation: Settings | Gauges | Fuel | MIL | DTCs
// Mirrors Swift TabView with matching tab items.

import 'package:flutter/cupertino.dart';

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
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const SettingsView(),
      GaugesView(isActive: _selectedIndex == 1),
      FuelStatusView(isActive: _selectedIndex == 2),
      MilStatusView(isActive: _selectedIndex == 3),
      DiagnosticsView(isActive: _selectedIndex == 4),
    ];

    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
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
