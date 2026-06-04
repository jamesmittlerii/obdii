// Port of RootTabView.swift — Jim Mittler
// 5-tab navigation: Settings | Gauges | Fuel | MIL | DTCs
// Mirrors Swift TabView with matching tab items.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config_data.dart';
import '../core/obd_connection_manager.dart';
import '../screenmodels/onboarding_screen_model.dart';
import '../viewmodels/settings_viewmodel.dart';
import 'dashboard_view.dart';
import '../widgets/check_engine_svg_icon.dart';
import 'diagnostics_view.dart';
import 'fuel_status_view.dart';
import 'mil_status_view.dart';
import 'onboarding_overlay.dart';
import 'pid_toggle_list_view.dart';
import 'settings_view.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  static const _kSelectedTabKey = 'ui.selectedTab';
  int _selectedIndex = 0;
  bool _showOnboarding = !ConfigData.instance.hasCompletedOnboarding;
  int _onboardingPageIndex = 0;
  bool _showGaugePicker = false;

  @override
  void initState() {
    super.initState();
    _loadSelectedTab();
    _syncOnboardingPreview();
  }

  Future<void> _loadSelectedTab() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_kSelectedTabKey);
    if (!mounted || saved == null) return;
    final clamped = saved.clamp(0, 4);
    setState(() {
      _selectedIndex = clamped;
      if (_showOnboarding) _syncOnboardingPreview();
    });
  }

  Future<void> _persistSelectedTab(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSelectedTabKey, index);
  }

  void _onDestinationSelected(int index) {
    if (_showOnboarding) return;
    setState(() => _selectedIndex = index);
    unawaited(_persistSelectedTab(index));
  }

  void _syncOnboardingPreview() {
    if (!_showOnboarding) {
      _showGaugePicker = false;
      return;
    }
    if (OnboardingScreenModel.showGaugePicker(_onboardingPageIndex)) {
      _selectedIndex = OnboardingScreenModel.settingsTabIndex;
      _showGaugePicker = true;
    } else {
      _showGaugePicker = false;
      final tab = OnboardingScreenModel.previewTabIndex(_onboardingPageIndex);
      if (tab != null) _selectedIndex = tab;
    }
  }

  void _setOnboardingPageIndex(int index) {
    setState(() {
      _onboardingPageIndex = index;
      _syncOnboardingPreview();
    });
  }

  void _restartOnboarding() {
    setState(() {
      _onboardingPageIndex = 0;
      _showOnboarding = true;
      _syncOnboardingPreview();
    });
  }

  static const _onboardingNavGap = 12.0;

  double _onboardingBottomInset(BuildContext context) {
    final mq = MediaQuery.of(context);
    final navHeight =
        NavigationBarTheme.of(context).height ?? kBottomNavigationBarHeight;
    return mq.viewPadding.bottom + navHeight + _onboardingNavGap;
  }

  Future<void> _completeOnboarding(bool startDemo) async {
    ConfigData.instance.hasCompletedOnboarding = true;
    setState(() {
      _showOnboarding = false;
      _showGaugePicker = false;
    });
    if (!startDemo) return;

    final settingsVm = context.read<SettingsViewModel>();
    settingsVm.connectionType = ConnectionType.demo;
    setState(() => _selectedIndex = OnboardingScreenModel.gaugesTabIndex);
    unawaited(_persistSelectedTab(OnboardingScreenModel.gaugesTabIndex));
    unawaited(OBDConnectionManager.instance.connect());
  }

  @override
  Widget build(BuildContext context) {
    final interactionsEnabled = !_showOnboarding;
    final pages = [
      SettingsView(
        onOpenGaugePicker: interactionsEnabled
            ? () => setState(() => _showGaugePicker = true)
            : null,
        onShowIntroAgain: _restartOnboarding,
      ),
      GaugesView(
        isActive: _selectedIndex == 1,
        enableGaugeDetail: interactionsEnabled,
      ),
      FuelStatusView(isActive: _selectedIndex == 2),
      MilStatusView(
        isActive: _selectedIndex == 3,
        onMilSummaryTap: interactionsEnabled
            ? () => _onDestinationSelected(4)
            : null,
      ),
      DiagnosticsView(isActive: _selectedIndex == 4),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);
    final bottomColor = Theme.of(context).scaffoldBackgroundColor;

    final onboardingNavHighlight = _showOnboarding
        ? OnboardingScreenModel.highlightedNavTab(_onboardingPageIndex)
        : null;

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
        child: SafeArea(
          bottom: false,
          child: Stack(
            fit: StackFit.expand,
            children: [
              IndexedStack(
                index: _selectedIndex,
                children: pages,
              ),
              if (_showGaugePicker)
                PidToggleListView(
                  onClose: _showOnboarding
                      ? () {}
                      : () => setState(() => _showGaugePicker = false),
                ),
              if (_showOnboarding)
                OnboardingContentScrim(
                  pageIndex: _onboardingPageIndex,
                  onPageIndexChange: _setOnboardingPageIndex,
                  onComplete: _completeOnboarding,
                  bottomInset: _onboardingBottomInset(context),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Stack(
        clipBehavior: Clip.none,
        children: [
          NavigationBar(
            elevation: 0,
            backgroundColor: Theme.of(context)
                    .navigationBarTheme
                    .backgroundColor
                    ?.withValues(alpha: 0.85) ??
                Colors.transparent,
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onDestinationSelected,
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
              const NavigationDestination(
                icon: Icon(Icons.speed_outlined),
                selectedIcon: Icon(Icons.speed),
                label: 'Gauges',
              ),
              const NavigationDestination(
                icon: Icon(Icons.local_gas_station_outlined),
                selectedIcon: Icon(Icons.local_gas_station),
                label: 'Fuel',
              ),
              NavigationDestination(
                icon: CheckEngineSvgIcon(
                  size: 25,
                  color: Theme.of(context)
                          .navigationBarTheme
                          .iconTheme
                          ?.resolve({})
                          ?.color ??
                      Theme.of(context).unselectedWidgetColor,
                ),
                selectedIcon: CheckEngineSvgIcon(
                  size: 27,
                  color: Theme.of(context)
                          .navigationBarTheme
                          .iconTheme
                          ?.resolve({WidgetState.selected})
                          ?.color ??
                      Theme.of(context).colorScheme.primary,
                ),
                label: 'MIL',
              ),
              const NavigationDestination(
                icon: Icon(Icons.build_outlined),
                selectedIcon: Icon(Icons.build),
                label: 'DTCs',
              ),
            ],
          ),
          if (_showOnboarding)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: OnboardingNavHighlight(
                highlightedIndex: onboardingNavHighlight,
              ),
            ),
        ],
      ),
    );
  }
}
