// Port of GaugesContainerView + GaugesView + GaugeListView — Jim Mittler
// Provides a segmented picker (Gauges | List) at the top.
// Gauges mode: adaptive grid of ring gauge tiles, each tappable → GaugeDetailView
// List mode:   inset list, full PID name + range subtitle, colored value trailing

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config_data.dart';
import '../viewmodels/gauges_viewmodel.dart';
import 'gauge_detail_view.dart';
import 'ring_gauge_widget.dart';

// ─────────────────────────────────────────────
// Display mode (persisted, mirrors @AppStorage)
// ─────────────────────────────────────────────

enum _GaugesDisplayMode { gauges, list }

// ─────────────────────────────────────────────
// Container — holds the segmented picker
// ─────────────────────────────────────────────

class GaugesView extends StatefulWidget {
  const GaugesView({super.key});

  @override
  State<GaugesView> createState() => _GaugesViewState();
}

class _GaugesViewState extends State<GaugesView> {
  _GaugesDisplayMode _mode = _GaugesDisplayMode.gauges;
  static const _prefKey = 'gaugesDisplayMode';

  @override
  void initState() {
    super.initState();
    _loadMode();
  }

  Future<void> _loadMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw != null && mounted) {
      setState(() {
        _mode = raw == 'list' ? _GaugesDisplayMode.list : _GaugesDisplayMode.gauges;
      });
    }
  }

  Future<void> _setMode(_GaugesDisplayMode mode) async {
    setState(() => _mode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, mode == _GaugesDisplayMode.list ? 'list' : 'gauges');
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_mode == _GaugesDisplayMode.gauges ? 'Gauges' : 'List'),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 56, 16, 8),
            child: CupertinoSlidingSegmentedControl<_GaugesDisplayMode>(
              groupValue: _mode,
              children: const {
                _GaugesDisplayMode.gauges: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('Gauges'),
                ),
                _GaugesDisplayMode.list: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('List'),
                ),
              },
              onValueChanged: (v) {
                if (v != null) _setMode(v);
              },
            ),
          ),
          Expanded(
            child: Consumer<GaugesViewModel>(
        builder: (context, vm, _) {
          if (vm.isEmpty) {
            return _emptyState();
          }
          return _mode == _GaugesDisplayMode.gauges
              ? _GaugesGrid(vm: vm)
              : _GaugesList(vm: vm);
        },
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.speedometer, size: 64, color: CupertinoColors.secondaryLabel),
          SizedBox(height: 16),
          Text(
            'No gauges enabled.\nGo to Settings → Gauges to add some.',
            textAlign: TextAlign.center,
            style: TextStyle(color: CupertinoColors.secondaryLabel),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Grid mode
// ─────────────────────────────────────────────

class _GaugesGrid extends StatelessWidget {
  final GaugesViewModel vm;

  const _GaugesGrid({required this.vm});

  @override
  Widget build(BuildContext context) {
    final isMetric =
        context.watch<ConfigData>().units == MeasurementUnit.metric;

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: vm.tiles.length,
      itemBuilder: (context, index) {
        final tile = vm.tiles[index];
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (_) => GaugeDetailView(pid: tile.pid),
            ),
          ),
          child: _GaugeTile(tile: tile, isMetric: isMetric),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Individual grid tile — ring gauge + label below
// ─────────────────────────────────────────────

class _GaugeTile extends StatelessWidget {
  final GaugeTile tile;
  final bool isMetric;

  const _GaugeTile({required this.tile, required this.isMetric});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Expanded(
              child: RingGaugeWidget(
                pid: tile.pid,
                stats: tile.stats,
                isMetric: isMetric,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tile.pid.label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// List mode — matches GaugeListView.swift
// ─────────────────────────────────────────────

class _GaugesList extends StatelessWidget {
  final GaugesViewModel vm;

  const _GaugesList({required this.vm});

  @override
  Widget build(BuildContext context) {
    final isMetric =
        context.watch<ConfigData>().units == MeasurementUnit.metric;

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: vm.tiles.length + 1, // +1 for section header
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 0, top: 0),
            child: Text(
              'Gauges',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.systemGrey,
              ),
            ),
          );
        }
        final tile = vm.tiles[index - 1];
        return _GaugeListRow(tile: tile, isMetric: isMetric);
      },
    );
  }
}

class _GaugeListRow extends StatelessWidget {
  final GaugeTile tile;
  final bool isMetric;

  const _GaugeListRow({required this.tile, required this.isMetric});

  @override
  Widget build(BuildContext context) {
    final pid = tile.pid;
    final stats = tile.stats;

    final valueText = stats != null
        ? pid.formattedValue(stats.latest.value, isMetric, includeUnits: true)
        : '— ${pid.unitLabel(isMetric)}';

    final valueColor = stats != null
        ? pid.colorForValue(stats.latest.value, isMetric)
        : CupertinoColors.secondaryLabel;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        CupertinoPageRoute(builder: (_) => GaugeDetailView(pid: pid)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 1),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pid.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pid.displayRange(isMetric),
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  valueText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: valueColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(CupertinoIcons.chevron_forward, color: CupertinoColors.secondaryLabel, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
