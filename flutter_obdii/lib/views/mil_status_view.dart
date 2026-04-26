// Port of MILStatusView.swift — Jim Mittler
// Displays MIL (Check Engine Light) status and readiness monitors.
// Section 1: Malfunction Indicator Lamp (waiting / on / off)
// Section 2: Readiness Monitors sorted Not Ready → Ready

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../viewmodels/mil_status_viewmodel.dart';

class MilStatusView extends StatefulWidget {
  const MilStatusView({super.key});

  @override
  State<MilStatusView> createState() => _MilStatusViewState();
}

class _MilStatusViewState extends State<MilStatusView> {

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('MIL Status'),
      ),
      child: Consumer<MilStatusViewModel>(
        builder: (context, vm, _) {
          final topContentPadding = 64.0;
          return ListView(
            padding: EdgeInsets.fromLTRB(16, topContentPadding, 16, 16),
            children: [
              // ── Malfunction Indicator Lamp ───────────────
              _sectionHeader(context, 'Malfunction Indicator Lamp'),
              CupertinoListSection.insetGrouped(children: [_milContent(context, vm)]),
              const SizedBox(height: 16),

              // ── Readiness Monitors ───────────────────────
              if (vm.status != null) ...[
                _sectionHeader(context, 'Readiness Monitors'),
                CupertinoListSection.insetGrouped(
                  children: [
                    for (int i = 0; i < vm.sortedSupportedMonitors.length; i++)
                      _MonitorRow(monitor: vm.sortedSupportedMonitors[i]),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _milContent(BuildContext context, MilStatusViewModel vm) {
    if (vm.status == null) {
      // Waiting
      return const CupertinoListTile(
        leading: CupertinoActivityIndicator(radius: 10),
        title: Text(
          'Waiting for data…',
          style: TextStyle(color: CupertinoColors.secondaryLabel),
        ),
      );
    } else if (vm.hasStatus) {
      final milOn = vm.status!.milOn;
      return CupertinoListTile(
        leading: Icon(
          CupertinoIcons.exclamationmark_triangle_fill,
          color: milOn ? CupertinoColors.systemOrange : CupertinoColors.activeBlue,
          size: 28,
        ),
        title: Text(
          vm.headerText,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      );
    } else {
      return const CupertinoListTile(
        leading: Icon(CupertinoIcons.info_circle, color: CupertinoColors.secondaryLabel),
        title: Text('No MIL Status', style: TextStyle(color: CupertinoColors.secondaryLabel)),
      );
    }
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 0, top: 0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.systemGrey,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Individual readiness monitor row
// ─────────────────────────────────────────────

class _MonitorRow extends StatelessWidget {
  final dynamic monitor; // ReadinessMonitor from flutter_obd2

  const _MonitorRow({required this.monitor});

  @override
  Widget build(BuildContext context) {
    final bool ready = monitor.ready as bool;
    return CupertinoListTile(
      leading: Icon(
        CupertinoIcons.speedometer,
        color: ready ? CupertinoColors.activeBlue : CupertinoColors.systemOrange,
        size: 22,
      ),
      title: Text(monitor.name as String),
      trailing: Text(
        ready ? 'Ready' : 'Not Ready',
        style: const TextStyle(color: CupertinoColors.secondaryLabel),
      ),
    );
  }
}
