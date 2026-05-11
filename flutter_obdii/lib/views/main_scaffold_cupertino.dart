import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/check_engine_svg_icon.dart';
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
  static const _kSelectedTabKey = 'ui.selectedTab';
  late final CupertinoTabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = CupertinoTabController(initialIndex: 0);
    _tabController.addListener(_onTabChanged);
    _loadSelectedTab();
  }

  Future<void> _loadSelectedTab() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_kSelectedTabKey);
    if (!mounted || saved == null) return;
    _tabController.index = saved.clamp(0, 4);
  }

  Future<void> _persistSelectedTab(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSelectedTabKey, index);
  }

  void _onTabChanged() {
    unawaited(_persistSelectedTab(_tabController.index));
  }

  void _openDtcTab() {
    _tabController.index = 4;
    unawaited(_persistSelectedTab(4));
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      controller: _tabController,
      tabBar: CupertinoTabBar(
        // Default is 50; a bit taller gives breathing room above/below icons+labels
        // (especially on Windows where the bar can feel tight).
        height: 58,
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
            icon: CheckEngineSvgIcon(
              size: 25,
              color: CupertinoDynamicColor.resolve(CupertinoColors.inactiveGray, context),
            ),
            activeIcon: CheckEngineSvgIcon(
              size: 27,
              color: CupertinoTheme.of(context).primaryColor,
            ),
            label: 'MIL',
          ),
          const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.wrench),
            label: 'DTCs',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        return AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) {
            final isActive = _tabController.index == index;
            
            Widget view;
            switch (index) {
              case 0:
                view = const SettingsView();
                break;
              case 1:
                view = GaugesView(isActive: isActive);
                break;
              case 2:
                view = FuelStatusView(isActive: isActive);
                break;
              case 3:
                view = MilStatusView(
                  isActive: isActive,
                  onMilSummaryTap: _openDtcTab,
                );
                break;
              case 4:
                view = DiagnosticsView(isActive: isActive);
                break;
              default:
                view = const SettingsView();
                break;
            }
            
            return SafeArea(
              bottom: false,
              child: view,
            );
          },
        );
      },
    );
  }
}
