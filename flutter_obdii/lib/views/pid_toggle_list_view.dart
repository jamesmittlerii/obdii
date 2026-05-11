// Port of PIDToggleListView.swift — Jim Mittler
// Lists all available gauge PIDs in Enabled / Disabled sections.
// Supports drag-to-reorder (Enabled only), toggling, and search via AppBar icon.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/obdiipid.dart';
import '../viewmodels/pid_toggle_list_viewmodel.dart';

class PidToggleListView extends StatefulWidget {
  final PidToggleListViewModel? viewModel;

  const PidToggleListView({super.key, this.viewModel});

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
    final child = Consumer<PidToggleListViewModel>(
      builder: (context, vm, _) {
        final isMetric = vm.isMetric;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(
                Icons.chevron_left,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
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
            actionsPadding: const EdgeInsets.only(right: 8),
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
    );

    final injectedViewModel = widget.viewModel;
    if (injectedViewModel != null) {
      return ChangeNotifierProvider<PidToggleListViewModel>.value(
        value: injectedViewModel,
        child: child,
      );
    }

    return ChangeNotifierProvider(
      create: (_) => PidToggleListViewModel(),
      child: child,
    );
  }

  Widget _buildList(PidToggleListViewModel vm, bool isMetric) {
    final enabled = vm.filteredEnabled;
    final disabled = vm.filteredDisabled;

    if (enabled.isEmpty && disabled.isEmpty && vm.searchText.isNotEmpty) {
      return Center(
        child: Text(
          'No results for "${vm.searchText}"',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    int itemCount = 0;
    if (enabled.isNotEmpty) itemCount += enabled.length + 1;
    if (disabled.isNotEmpty) itemCount += disabled.length + 1;

    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      proxyDecorator: (child, _, _) =>
          Material(type: MaterialType.transparency, child: child),
      onReorder: (oldIndex, newIndex) =>
          _handleReorder(oldIndex, newIndex, vm, enabled.length),
      itemCount: itemCount,
      buildDefaultDragHandles: false,
      itemBuilder: (context, index) =>
          _buildListItem(context, index, vm, isMetric),
    );
  }

  void _handleReorder(
      int oldIndex, int newIndex, PidToggleListViewModel vm, int enabledLength) {
    // Index 0 is the Enabled header; enabled rows are [1..enabled.length].
    // Flutter reports newIndex as insertion index in visual list.
    final isFromEnabledRow = oldIndex > 0 && oldIndex <= enabledLength;
    final isToEnabledRegion = newIndex > 0 && newIndex <= enabledLength + 1;
    if (!isFromEnabledRow || !isToEnabledRegion) return;

    final from = oldIndex - 1;
    var to = newIndex - 1;
    if (to > from) to -= 1;
    if (to < 0) to = 0;
    if (to >= enabledLength) to = enabledLength - 1;
    if (to == from) return;

    vm.moveEnabled(from, to);
  }

  Widget _buildListItem(
      BuildContext context, int index, PidToggleListViewModel vm, bool isMetric) {
    final enabled = vm.filteredEnabled;
    final disabled = vm.filteredDisabled;

    if (enabled.isNotEmpty && index <= enabled.length) {
      return _buildEnabledSectionItem(context, index, enabled, vm, isMetric);
    }

    final disabledStart = enabled.isNotEmpty ? enabled.length + 1 : 0;
    if (disabled.isNotEmpty && index >= disabledStart) {
      return _buildDisabledSectionItem(context, index - disabledStart, disabled, vm, isMetric);
    }

    return const SizedBox.shrink();
  }

  Widget _buildEnabledSectionItem(BuildContext context, int index, List<ObdiiPid> enabled, PidToggleListViewModel vm, bool isMetric) {
    if (index == 0) {
      return _sectionHeader(context, 'Enabled', key: const Key('header_enabled'));
    }
    final pidIndex = index - 1;
    return _buildRow(enabled[pidIndex], pidIndex, vm, isMetric, prefix: 'enabled', isEnabledSection: true);
  }

  Widget _buildDisabledSectionItem(BuildContext context, int relativeIndex, List<ObdiiPid> disabled, PidToggleListViewModel vm, bool isMetric) {
    if (relativeIndex == 0) {
      return _sectionHeader(context, 'Disabled', key: const Key('header_disabled'));
    }
    final pidIndex = relativeIndex - 1;
    if (pidIndex < disabled.length) {
      return _buildRow(disabled[pidIndex], null, vm, isMetric, prefix: 'disabled', isEnabledSection: false);
    }
    return const SizedBox.shrink();
  }

  Widget _buildRow(
      ObdiiPid pid, int? reorderIndex, PidToggleListViewModel vm, bool isMetric,
      {required String prefix, required bool isEnabledSection}) {
    return _PidToggleRow(
      key: Key('${prefix}_${pid.id}'),
      pid: pid,
      isMetric: isMetric,
      isOn: pid.enabled,
      reorderIndex: reorderIndex,
      onToggle: (v) {
        final globalIdx = vm.pids.indexWhere((p) => p.id == pid.id);
        if (globalIdx >= 0) vm.toggle(globalIdx, v);
      },
      canReorder: vm.searchText.isEmpty && isEnabledSection,
    );
  }

  Widget _sectionHeader(
    BuildContext context,
    String title, {
    required Key key,
  }) {
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
      title: Text(
        pid.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
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
