// Port of PIDToggleListView.swift — Jim Mittler
// Lists all available gauge PIDs in Enabled / Disabled sections.
// Supports drag-to-reorder (Enabled only), toggling, and search via AppBar icon.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show ReorderableListView, ReorderableDragStartListener;
import 'package:provider/provider.dart';

import '../core/config_data.dart';
import '../models/obdii_pid.dart';
import '../viewmodels/pid_toggle_list_viewmodel.dart';

class PidToggleListView extends StatefulWidget {
  const PidToggleListView({super.key});

  @override
  State<PidToggleListView> createState() => _PidToggleListViewState();
}

class _PidToggleListViewState extends State<PidToggleListView> {
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PidToggleListViewModel(),
      child: Consumer<PidToggleListViewModel>(
        builder: (context, vm, _) {
          final isMetric =
              context.watch<ConfigData>().units == MeasurementUnit.metric;

          return CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(
              middle: _isSearching
                  ? CupertinoTextField(
                      controller: _searchController,
                      placeholder: 'Search PIDs…',
                      onChanged: (q) => vm.searchText = q,
                    )
                  : const Text('Gauges'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                if (_isSearching)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Icon(CupertinoIcons.clear),
                    onPressed: () {
                      setState(() => _isSearching = false);
                      _searchController.clear();
                      vm.searchText = '';
                    },
                  )
                else
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Icon(CupertinoIcons.search),
                    onPressed: () => setState(() => _isSearching = true),
                  ),
                ],
              ),
            ),
            child: _buildList(vm, isMetric),
          );
        },
      ),
    );
  }

  Widget _buildList(PidToggleListViewModel vm, bool isMetric) {
    final enabled = vm.filteredEnabled;
    final disabled = vm.filteredDisabled;
    final noResults = enabled.isEmpty && disabled.isEmpty && vm.searchText.isNotEmpty;
    final topContentPadding = 64.0;

    if (noResults) {
      return Center(
        child: Text(
          'No results for "${vm.searchText}"',
          style: const TextStyle(color: CupertinoColors.secondaryLabel),
        ),
      );
    }

    return ReorderableListView.builder(
      padding: EdgeInsets.fromLTRB(0, topContentPadding, 0, 8),
      onReorder: (oldIndex, newIndex) {
        // Index 0 is the Enabled header; enabled rows are [1..enabled.length].
        // Flutter's newIndex is reported as insertion index in the visual list,
        // so adjust once here and pass normalized enabled-subset indices to VM.
        final isFromEnabledRow = oldIndex > 0 && oldIndex <= enabled.length;
        final isToEnabledRegion = newIndex > 0 && newIndex <= enabled.length + 1;
        if (!isFromEnabledRow || !isToEnabledRegion) return;

        final from = oldIndex - 1;
        var to = newIndex - 1;
        if (to > from) to -= 1;
        if (to < 0) to = 0;
        if (to >= enabled.length) to = enabled.length - 1;
        if (to == from) return;

        vm.moveEnabled(from, to);
      },
      itemCount: enabled.length + (enabled.isNotEmpty ? 1 : 0) +
          disabled.length + (disabled.isNotEmpty ? 1 : 0),
      buildDefaultDragHandles: false,
      itemBuilder: (context, index) {
        // Section header: Enabled
        if (enabled.isNotEmpty && index == 0) {
          return _sectionHeader(context, 'Enabled', key: const Key('header_enabled'));
        }
        // Enabled rows
        if (enabled.isNotEmpty && index <= enabled.length) {
          final pidIndex = index - 1;
          final pid = enabled[pidIndex];
          return _PidToggleRow(
            key: Key('enabled_${pid.id}'),
            pid: pid,
            isMetric: isMetric,
            isOn: pid.enabled,
            reorderIndex: pidIndex,
            onToggle: (v) {
              final globalIdx = vm.pids.indexWhere((p) => p.id == pid.id);
              if (globalIdx >= 0) vm.toggle(globalIdx, v);
            },
            canReorder: vm.searchText.isEmpty,
          );
        }

        // Offset past the enabled section
        final disabledStart = enabled.isNotEmpty ? enabled.length + 1 : 0;

        // Section header: Disabled
        if (disabled.isNotEmpty && index == disabledStart) {
          return _sectionHeader(context, 'Disabled',
              key: const Key('header_disabled'));
        }

        // Disabled rows
        final pid = disabled[index - disabledStart - 1];
        return _PidToggleRow(
          key: Key('disabled_${pid.id}'),
          pid: pid,
          isMetric: isMetric,
          isOn: pid.enabled,
          reorderIndex: null, // not reorderable
          onToggle: (v) {
            final globalIdx = vm.pids.indexWhere((p) => p.id == pid.id);
            if (globalIdx >= 0) vm.toggle(globalIdx, v);
          },
          canReorder: false,
        );
      },
    );
  }

  Widget _sectionHeader(BuildContext context, String title, {required Key key}) {
    return Container(
      key: key,
      color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
      
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.systemGrey,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Individual PID toggle row
// ─────────────────────────────────────────────

class _PidToggleRow extends StatelessWidget {
  final ObdiiPid pid;
  final bool isMetric;
  final bool isOn;
  final int? reorderIndex; // non-null = draggable
  final ValueChanged<bool> onToggle;
  final bool canReorder;

  const _PidToggleRow({
    super.key,
    required this.pid,
    required this.isMetric,
    required this.isOn,
    required this.reorderIndex,
    required this.onToggle,
    required this.canReorder,
  });

  @override
  Widget build(BuildContext context) {
    final tile = CupertinoListTile(
      title: Text(pid.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        pid.displayRange(isMetric),
        style: const TextStyle(fontSize: 12),
      ),
      trailing: CupertinoSwitch(value: isOn, onChanged: onToggle),
    );

    if (canReorder && reorderIndex != null) {
      return ReorderableDragStartListener(
        index: reorderIndex! + 1, // +1 because index 0 is the header
        child: tile,
      );
    }

    return tile;
  }
}
