import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config_data.dart';
import '../core/obd_connection_manager.dart';
import '../screenmodels/onboarding_screen_model.dart';
import '../viewmodels/settings_viewmodel.dart';
import '../widgets/check_engine_svg_icon.dart';
import 'dashboard_view.dart';
import 'diagnostics_view.dart';
import 'fuel_status_view.dart';
import 'mil_status_view.dart';
import 'onboarding_overlay.dart';
import 'pid_toggle_list_view.dart';
import 'settings_view.dart';

class MainScaffoldCupertino extends StatefulWidget {
  const MainScaffoldCupertino({super.key});

  @override
  State<MainScaffoldCupertino> createState() => _MainScaffoldCupertinoState();
}

class _MainScaffoldCupertinoState extends State<MainScaffoldCupertino> {
  static const _kSelectedTabKey = 'ui.selectedTab';
  late final CupertinoTabController _tabController;
  bool _showOnboarding = !ConfigData.instance.hasCompletedOnboarding;
  int _onboardingPageIndex = 0;
  bool _showGaugePicker = false;

  @override
  void initState() {
    super.initState();
    _tabController = CupertinoTabController(initialIndex: 0);
    _tabController.addListener(_onTabChanged);
    _loadSelectedTab();
    _syncOnboardingPreview();
  }

  Future<void> _loadSelectedTab() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_kSelectedTabKey);
    if (!mounted || saved == null) return;
    setState(() {
      _tabController.index = saved.clamp(0, 4);
      if (_showOnboarding) _syncOnboardingPreview();
    });
  }

  Future<void> _persistSelectedTab(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSelectedTabKey, index);
  }

  void _onTabChanged() {
    if (_showOnboarding) {
      _syncOnboardingPreview();
      return;
    }
    unawaited(_persistSelectedTab(_tabController.index));
  }

  void _syncOnboardingPreview() {
    if (!_showOnboarding) {
      _showGaugePicker = false;
      return;
    }
    if (OnboardingScreenModel.showGaugePicker(_onboardingPageIndex)) {
      _tabController.index = OnboardingScreenModel.settingsTabIndex;
      _showGaugePicker = true;
    } else {
      _showGaugePicker = false;
      final tab = OnboardingScreenModel.previewTabIndex(_onboardingPageIndex);
      if (tab != null) _tabController.index = tab;
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

  static const _tabBarHeight = 58.0;
  static const _onboardingNavGap = 12.0;

  double _onboardingBottomInset(BuildContext context) {
    final mq = MediaQuery.of(context);
    return mq.viewPadding.bottom + _tabBarHeight + _onboardingNavGap;
  }

  Widget _buildTabView(int index, bool isActive, bool interactionsEnabled) {
    switch (index) {
      case 0:
        return SettingsView(
          onOpenGaugePicker: interactionsEnabled
              ? () => setState(() => _showGaugePicker = true)
              : null,
          onShowIntroAgain: _restartOnboarding,
        );
      case 1:
        return GaugesView(
          isActive: isActive,
          enableGaugeDetail: interactionsEnabled,
        );
      case 2:
        return FuelStatusView(isActive: isActive);
      case 3:
        return MilStatusView(
          isActive: isActive,
          onMilSummaryTap: interactionsEnabled ? _openDtcTab : null,
        );
      case 4:
        return DiagnosticsView(isActive: isActive);
      default:
        return const SettingsView();
    }
  }

  List<Widget> _buildOnboardingLayers(
    BuildContext context,
    int? onboardingNavHighlight,
  ) {
    return [
      if (_showGaugePicker)
        PidToggleListView(
          onClose: _showOnboarding
              ? () {
                  // Keep picker open while onboarding controls the preview tab.
                }
              : () => setState(() => _showGaugePicker = false),
        ),
      if (_showOnboarding)
        OnboardingContentScrim(
          pageIndex: _onboardingPageIndex,
          onPageIndexChange: _setOnboardingPageIndex,
          onComplete: _completeOnboarding,
          bottomInset: _onboardingBottomInset(context),
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
    ];
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
    _tabController.index = OnboardingScreenModel.gaugesTabIndex;
    unawaited(_persistSelectedTab(OnboardingScreenModel.gaugesTabIndex));
    unawaited(OBDConnectionManager.instance.connect());
  }

  void _openDtcTab() {
    if (_showOnboarding) return;
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
    final interactionsEnabled = !_showOnboarding;
    final onboardingNavHighlight = _showOnboarding
        ? OnboardingScreenModel.highlightedNavTab(_onboardingPageIndex)
        : null;

    return Stack(
      fit: StackFit.expand,
      children: [
        CupertinoTabScaffold(
          controller: _tabController,
          tabBar: CupertinoTabBar(
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
                  color: CupertinoDynamicColor.resolve(
                    CupertinoColors.inactiveGray,
                    context,
                  ),
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
                return SafeArea(
                  bottom: false,
                  child: _buildTabView(index, isActive, interactionsEnabled),
                );
              },
            );
          },
        ),
        ..._buildOnboardingLayers(context, onboardingNavHighlight),
      ],
    );
  }
}
