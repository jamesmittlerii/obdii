// Port of GaugeDetailView.swift — Jim Mittler
// Detail screen for a single gauge/PID.
// Displays Current value, Statistics (min/max/samples), and Maximum Range.

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../core/config_data.dart';
import '../core/pid_interest_registry.dart';
import '../models/obdii_pid.dart';
import '../viewmodels/gauge_detail_viewmodel.dart';

class GaugeDetailView extends StatelessWidget {
  final ObdiiPid pid;

  const GaugeDetailView({super.key, required this.pid});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GaugeDetailViewModel(pid: pid),
      child: _GaugeDetailBody(pid: pid),
    );
  }
}

class _GaugeDetailBody extends StatelessWidget {
  final ObdiiPid pid;

  const _GaugeDetailBody({required this.pid});

  @override
  Widget build(BuildContext context) {
    return _GaugeDetailInterestScope(pid: pid);
  }
}

class _GaugeDetailInterestScope extends StatefulWidget {
  final ObdiiPid pid;

  const _GaugeDetailInterestScope({required this.pid});

  @override
  State<_GaugeDetailInterestScope> createState() =>
      _GaugeDetailInterestScopeState();
}

class _GaugeDetailInterestScopeState extends State<_GaugeDetailInterestScope> {
  late final String _interestToken;

  @override
  void initState() {
    super.initState();
    final registry = PidInterestRegistry.instance;
    _interestToken = registry.makeToken();
    registry.replace({widget.pid.pidCommand}, _interestToken);
  }

  @override
  void dispose() {
    PidInterestRegistry.instance.clear(_interestToken);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GaugeDetailViewModel>();
    final isMetric = context.watch<ConfigData>().units == MeasurementUnit.metric;
    final pid = widget.pid;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(pid.name),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
        children: [
          // ── Current ──────────────────────────────────
          _sectionHeader(context, 'Current'),
          CupertinoListSection.insetGrouped(
            children: [
              CupertinoListTile(
                title: vm.stats != null
                    ? Text(
                        pid.formattedValue(vm.stats!.latest.value, isMetric,
                            includeUnits: true),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: pid.colorForValue(vm.stats!.latest.value, isMetric),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      )
                    : Text(
                        '— ${pid.unitLabel(isMetric)}',
                        style: TextStyle(
                          fontSize: 28,
                          color: CupertinoColors.secondaryLabel.resolveFrom(context),
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Statistics ───────────────────────────────
          _sectionHeader(context, 'Statistics'),
          CupertinoListSection.insetGrouped(
            children: [
              if (vm.stats != null) ...[
                CupertinoListTile(
                  title: const Text('Min'),
                  trailing: Text(
                    pid.formattedValue(vm.stats!.min, isMetric, includeUnits: true),
                    style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                ),
                CupertinoListTile(
                  title: const Text('Max'),
                  trailing: Text(
                    pid.formattedValue(vm.stats!.max, isMetric, includeUnits: true),
                    style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                ),
                CupertinoListTile(
                  title: const Text('Samples'),
                  trailing: Text('${vm.stats!.sampleCount}'),
                ),
              ] else
                const CupertinoListTile(
                  title: Text('No data yet',
                      style: TextStyle(color: CupertinoColors.secondaryLabel)),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Maximum Range ─────────────────────────────
          _sectionHeader(context, 'Maximum Range'),
          CupertinoListSection.insetGrouped(
            children: [
              CupertinoListTile(
                title: Text(pid.displayRange(isMetric)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        title.toUpperCase(),
        style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              color: CupertinoTheme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}
