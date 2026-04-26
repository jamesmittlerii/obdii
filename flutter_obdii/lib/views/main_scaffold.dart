// Port of RootTabView.swift — Jim Mittler
// 5-tab navigation: Settings | Gauges | Fuel | MIL | DTCs
// Mirrors Swift TabView with matching tab items.

import 'package:flutter/material.dart';

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
    final pages = [
      const SettingsView(),
      GaugesView(isActive: _selectedIndex == 1),
      FuelStatusView(isActive: _selectedIndex == 2),
      MilStatusView(isActive: _selectedIndex == 3),
      DiagnosticsView(isActive: _selectedIndex == 4),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
          NavigationDestination(
            icon: Icon(Icons.speed_outlined),
            selectedIcon: Icon(Icons.speed),
            label: 'Gauges',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_gas_station_outlined),
            selectedIcon: Icon(Icons.local_gas_station),
            label: 'Fuel',
          ),
          NavigationDestination(
            icon: Icon(Icons.engineering_outlined),
            selectedIcon: Icon(Icons.engineering),
            label: 'MIL',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_outlined),
            selectedIcon: Icon(Icons.build),
            label: 'DTCs',
          ),
        ],
      ),
    );
  }
}
