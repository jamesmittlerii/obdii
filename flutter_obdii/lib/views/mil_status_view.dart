// Port of MILStatusView.swift — Jim Mittler
// Displays MIL (Check Engine Light) status and readiness monitors.
// Section 1: Malfunction Indicator Lamp (waiting / on / off)
// Section 2: Readiness Monitors sorted Not Ready → Ready

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/mil_status_viewmodel.dart';

class MilStatusView extends StatefulWidget {
  final bool isActive;

  const MilStatusView({super.key, this.isActive = true});

  @override
  State<MilStatusView> createState() => _MilStatusViewState();
}

class _MilStatusViewState extends State<MilStatusView> {
  void _syncVisibility() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MilStatusViewModel>().setVisible(widget.isActive);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncVisibility();
  }

  @override
  void didUpdateWidget(covariant MilStatusView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _syncVisibility();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<MilStatusViewModel>(
        builder: (context, vm, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              // ── Malfunction Indicator Lamp ───────────────
              _sectionHeader(context, 'Malfunction Indicator Lamp'),
              Card(
                child: _milContent(context, vm),
              ),
              const SizedBox(height: 16),

              // ── Readiness Monitors ───────────────────────
              if (vm.status != null) ...[
                _sectionHeader(context, 'Readiness Monitors'),
                Card(
                  child: Column(
                    children: [
                      for (int i = 0;
                          i < vm.sortedSupportedMonitors.length;
                          i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _MonitorRow(monitor: vm.sortedSupportedMonitors[i]),
                      ],
                    ],
                  ),
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
      return const ListTile(
        leading: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text(
          'Waiting for data…',
          style: TextStyle(color: Colors.grey),
        ),
      );
    } else if (vm.hasStatus) {
      final milOn = vm.status!.milOn;
      return ListTile(
        leading: Icon(
          Icons.build,
          color: milOn ? Colors.orange : Colors.blue,
          size: 28,
        ),
        title: Text(
          vm.headerText,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      );
    } else {
      return const ListTile(
        leading: Icon(Icons.info_outline, color: Colors.grey),
        title: Text('No MIL Status', style: TextStyle(color: Colors.grey)),
      );
    }
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.8,
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
    return ListTile(
      leading: Icon(
        Icons.speed,
        color: ready ? Colors.blue : Colors.orange,
        size: 22,
      ),
      title: Text(monitor.name as String),
      trailing: Text(
        ready ? 'Ready' : 'Not Ready',
        style: const TextStyle(color: Colors.grey),
      ),
    );
  }
}
