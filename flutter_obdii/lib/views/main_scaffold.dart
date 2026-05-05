// Port of RootTabView.swift — Jim Mittler
// 5-tab navigation: Settings | Gauges | Fuel | MIL | DTCs
// Mirrors Swift TabView with matching tab items.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const _kSelectedTabKey = 'ui.selectedTab';
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadSelectedTab();
  }

  Future<void> _loadSelectedTab() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_kSelectedTabKey);
    if (!mounted || saved == null) return;
    final clamped = saved.clamp(0, 4);
    setState(() => _selectedIndex = clamped);
  }

  Future<void> _persistSelectedTab(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSelectedTabKey, index);
  }

  void _onDestinationSelected(int index) {
    setState(() => _selectedIndex = index);
    unawaited(_persistSelectedTab(index));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const SettingsView(),
      GaugesView(isActive: _selectedIndex == 1),
      FuelStatusView(isActive: _selectedIndex == 2),
      MilStatusView(isActive: _selectedIndex == 3),
      DiagnosticsView(isActive: _selectedIndex == 4),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);
    final bottomColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      extendBody: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [topColor, bottomColor],
            stops: const [0.0, 0.4],
          ),
        ),
        child: IndexedStack(
          index: _selectedIndex,
          children: pages,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        elevation: 0,
        backgroundColor: Theme.of(context).navigationBarTheme.backgroundColor?.withValues(alpha: 0.85) ?? Colors.transparent,
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
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
