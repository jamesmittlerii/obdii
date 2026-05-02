// Port of PIDToggleListView.swift — Jim Mittler
// Lists all available gauge PIDs in Enabled / Disabled sections.
// Supports drag-to-reorder (Enabled only), toggling, and search via AppBar icon.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/obdiipid.dart';
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
          final isMetric = vm.isMetric;

          return Scaffold(
            appBar: AppBar(
              title: _isSearching
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Search PIDs…',
                        border: InputBorder.none,
                      ),
                      onChanged: (q) => vm.searchText = q,
                    )
                  : const Text('Gauges'),
              actions: [
                if (_isSearching)
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Cancel search',
                    onPressed: () {
                      setState(() => _isSearching = false);
                      _searchController.clear();
                      vm.searchText = '';
                    },
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.search),
                    tooltip: 'Search PIDs',
                    onPressed: () => setState(() => _isSearching = true),
                  ),
              ],
            ),
            body: _buildList(vm, isMetric),
          );
        },
      ),
    );
  }

  Widget _buildList(PidToggleListViewModel vm, bool isMetric) {
    final enabled = vm.filteredEnabled;
    final disabled = vm.filteredDisabled;
    final noResults = enabled.isEmpty && disabled.isEmpty && vm.searchText.isNotEmpty;

    if (noResults) {
      return Center(
        child: Text(
          'No results for "${vm.searchText}"',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      proxyDecorator: (child, _, _) => Material(
        type: MaterialType.transparency,
        child: child,
      ),
      onReorder: (oldIndex, newIndex) {
        // Index 0 is the Enabled header; enabled rows are [1..enabled.length].
        // Flutter reports newIndex as insertion index in visual list.
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
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.8,
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
    final tile = ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(pid.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        pid.displayRange(isMetric),
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Switch(value: isOn, onChanged: onToggle),
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
