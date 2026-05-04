// Port of GaugesContainerView + GaugesView + GaugeListView — Jim Mittler
// Provides a segmented picker (Gauges | List) at the top.
// Gauges mode: adaptive grid of ring gauge tiles, each tappable → GaugeDetailView
// List mode:   inset list, full PID name + range subtitle, colored value trailing

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/gauges_viewmodel.dart';
import 'animated_tap_card.dart';
import 'gauge_detail_view.dart';
import 'ring_gauge_widget.dart';

// ─────────────────────────────────────────────
// Display mode (persisted, mirrors @AppStorage)
// ─────────────────────────────────────────────


// ─────────────────────────────────────────────
// Container — holds the segmented picker
// ─────────────────────────────────────────────

class GaugesView extends StatefulWidget {
  final bool isActive;

  const GaugesView({super.key, this.isActive = true});

  @override
  State<GaugesView> createState() => _GaugesViewState();
}

class _GaugesViewState extends State<GaugesView> {
  void _syncVisibility() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<GaugesViewModel>().setVisible(widget.isActive);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncVisibility();
  }

  @override
  void didUpdateWidget(covariant GaugesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _syncVisibility();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GaugesViewModel>(
      builder: (context, vm, _) {
        final mode = vm.displayMode;
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                floating: true,
                toolbarHeight: 0,
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(48),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: SegmentedButton<GaugesDisplayMode>(
                      segments: const [
                        ButtonSegment(
                          value: GaugesDisplayMode.gauges,
                          label: Text('Gauges', softWrap: false),
                        ),
                        ButtonSegment(
                          value: GaugesDisplayMode.list,
                          label: Text('List', softWrap: false),
                        ),
                      ],
                      selected: {mode},
                      onSelectionChanged: (s) => vm.setDisplayMode(s.first),
                    ),
                  ),
                ),
              ),
              if (vm.isEmpty)
                SliverFillRemaining(child: _emptyState())
              else if (mode == GaugesDisplayMode.gauges)
                _GaugesGrid(vm: vm)
              else
                _GaugesList(vm: vm),
            ],
          ),
        );
      },
    );
  }

  Widget _emptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.speed_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No gauges enabled.\nGo to Settings → Gauges to add some.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Grid mode
// ─────────────────────────────────────────────

class _GaugesGrid extends StatefulWidget {
  final GaugesViewModel vm;

  const _GaugesGrid({required this.vm});

  @override
  State<_GaugesGrid> createState() => _GaugesGridState();
}

class _GaugesGridState extends State<_GaugesGrid> {
  int? _draggingIndex;
  int? _hoverIndex;

  @override
  Widget build(BuildContext context) {
    final isMetric = widget.vm.isMetric;
    final tiles = widget.vm.tiles;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.0,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final tile = tiles[index];
            final isDragging = _draggingIndex == index;
            final isTargeted = _hoverIndex == index &&
                _draggingIndex != null &&
                _draggingIndex != index;

            return DragTarget<int>(
              onWillAcceptWithDetails: (d) => d.data != index,
              onAcceptWithDetails: (d) {
                final from = d.data;
                final to = index;
                setState(() { _draggingIndex = null; _hoverIndex = null; });
                // Defer the reorder until after the drag gesture fully unwinds.
                // Calling moveEnabled synchronously triggers notifyListeners(),
                // which rebuilds the Consumer mid-drag and confuses the gesture
                // recognizer, preventing subsequent drags.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) widget.vm.moveEnabled(from, to);
                });
              },
              onMove: (_) {
                if (_hoverIndex != index) setState(() => _hoverIndex = index);
              },
              onLeave: (_) {
                if (_hoverIndex == index) setState(() => _hoverIndex = null);
              },
              builder: (context, candidate, _) {
                return AnimatedScale(
                  scale: isTargeted ? 1.05 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: LongPressDraggable<int>(
                    data: index,
                    delay: const Duration(milliseconds: 400),
                    onDragStarted: () => setState(() => _draggingIndex = index),
                    onDragEnd: (_) {
                      if (mounted) setState(() {
                        _draggingIndex = null;
                        _hoverIndex = null;
                      });
                    },
                    onDraggableCanceled: (_, __) {
                      if (mounted) setState(() {
                        _draggingIndex = null;
                        _hoverIndex = null;
                      });
                    },
                    feedback: SizedBox(
                      width: 160,
                      height: 160,
                      child: Material(
                        elevation: 12,
                        shadowColor: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(12),
                        child: _GaugeTile(tile: tile, isMetric: isMetric),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.25,
                      child: _GaugeTile(tile: tile, isMetric: isMetric),
                    ),
                    child: _GaugeTile(
                      tile: tile,
                      isMetric: isMetric,
                      onTap: isDragging
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GaugeDetailView(pid: tile.pid),
                              ),
                            ),
                    ),
                  ),
                );
              },
            );
          },
          childCount: tiles.length,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Individual grid tile — ring gauge + label below
// ─────────────────────────────────────────────

class _GaugeTile extends StatelessWidget {
  final GaugeTile tile;
  final bool isMetric;
  final VoidCallback? onTap;

  const _GaugeTile({required this.tile, required this.isMetric, this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedTapCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 98/120 ratio from Swift tweak to reduce bottom whitespace.
            final gaugeHeight = constraints.maxWidth * 0.8167;
            return Column(
              children: [
                SizedBox(
                  height: gaugeHeight,
                  child: RingGaugeWidget(
                    pid: tile.pid,
                    stats: tile.stats,
                    isMetric: isMetric,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      tile.pid.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            );
          },
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
    final isMetric = vm.isMetric;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      sliver: SliverReorderableList(
        onReorder: (oldIndex, newIndex) {
          if (newIndex > oldIndex) newIndex -= 1;
          vm.moveEnabled(oldIndex, newIndex);
        },
        itemCount: vm.tiles.length,
        itemBuilder: (context, index) {
          final tile = vm.tiles[index];
          return ReorderableDelayedDragStartListener(
            key: ValueKey(tile.id),
            index: index,
            child: _GaugeListRow(tile: tile, isMetric: isMetric),
          );
        },
      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final valueText = stats != null
        ? pid.formattedValue(stats.latest.value, isMetric, includeUnits: true)
        : '— ${pid.unitLabel(isMetric)}';

    final valueColor = stats != null
        ? pid.colorForValue(stats.latest.value, isMetric)
        : Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.08),
          width: 0.5,
        ),
      ),
      elevation: 0,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GaugeDetailView(pid: pid)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        color: Colors.grey.shade500,
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
                  const SizedBox(width: 8),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
