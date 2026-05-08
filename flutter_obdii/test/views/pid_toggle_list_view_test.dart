import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_obdii/core/config_data.dart';
import 'package:flutter_obdii/core/obdiipid.dart';
import 'package:flutter_obdii/core/pid_store.dart';
import 'package:flutter_obdii/viewmodels/pid_toggle_list_viewmodel.dart';
import 'package:flutter_obdii/views/pid_toggle_list_view.dart';

class _TestPidStore extends ChangeNotifier implements PidStore {
  _TestPidStore(this._pids);

  List<ObdiiPid> _pids;

  @override
  List<ObdiiPid> get pids => _pids;

  @override
  List<ObdiiPid> get enabledGauges =>
      _pids.where((p) => p.enabled && p.kind == ObdPidKind.gauge).toList();

  @override
  Stream<List<ObdiiPid>> get pidsStream => Stream.multi((controller) {
    controller.add(_pids);
    void listener() => controller.add(_pids);
    addListener(listener);
    controller.onCancel = () => removeListener(listener);
  });

  @override
  Future<void> load() async {}

  @override
  Future<void> toggle(ObdiiPid pid) async {
    final index = _pids.indexWhere((p) => p.id == pid.id);
    if (index == -1) return;
    _pids[index] = _pids[index].copyWith(enabled: !_pids[index].enabled);
    notifyListeners();
  }

  @override
  Future<void> moveEnabled(int fromIndex, int toIndex) async {
    final enabledIndices = _pids
        .asMap()
        .entries
        .where(
          (entry) =>
              entry.value.enabled && entry.value.kind == ObdPidKind.gauge,
        )
        .map((entry) => entry.key)
        .toList();
    if (fromIndex < 0 ||
        fromIndex >= enabledIndices.length ||
        toIndex < 0 ||
        toIndex >= enabledIndices.length) {
      return;
    }

    final enabled = enabledIndices.map((i) => _pids[i]).toList();
    final item = enabled.removeAt(fromIndex);
    enabled.insert(toIndex, item);

    final updated = List<ObdiiPid>.from(_pids);
    for (var i = 0; i < enabledIndices.length; i++) {
      updated[enabledIndices[i]] = enabled[i];
    }
    _pids = updated;
    notifyListeners();
  }
}

class _TestUnitsProvider implements UnitsProviding {
  _TestUnitsProvider(this.units);

  @override
  MeasurementUnit units;

  final _controller = StreamController<MeasurementUnit>.broadcast();

  @override
  Stream<MeasurementUnit> get unitsStream => _controller.stream;

  void dispose() => _controller.close();
}

ObdiiPid _pid({
  required String id,
  required bool enabled,
  required String name,
  required String command,
  String label = '',
  String units = 'RPM',
  ObdPidKind kind = ObdPidKind.gauge,
  ValueRange? typicalRange,
}) {
  return ObdiiPid(
    id: id,
    enabled: enabled,
    label: label.isEmpty ? name : label,
    name: name,
    pidCommand: command,
    units: units,
    kind: kind,
    typicalRange: typicalRange ?? const ValueRange(min: 0, max: 100),
  );
}

List<ObdiiPid> _pids() => [
  _pid(
    id: 'rpm',
    enabled: true,
    label: 'RPM',
    name: 'Engine RPM',
    command: '010C',
    units: 'RPM',
    typicalRange: const ValueRange(min: 0, max: 8000),
  ),
  _pid(
    id: 'speed',
    enabled: false,
    label: 'Speed',
    name: 'Vehicle Speed',
    command: '010D',
    units: 'km/h',
    typicalRange: const ValueRange(min: 0, max: 200),
  ),
  _pid(
    id: 'coolant',
    enabled: false,
    label: 'Coolant',
    name: 'Engine Coolant Temp',
    command: '0105',
    units: '°C',
    typicalRange: const ValueRange(min: -20, max: 120),
  ),
  _pid(
    id: 'status',
    enabled: false,
    name: 'Monitor Status',
    command: '0101',
    units: 'NA',
    kind: ObdPidKind.status,
  ),
];

Widget _build(PidToggleListViewModel viewModel) {
  return MaterialApp(home: PidToggleListView(viewModel: viewModel));
}

void main() {
  late _TestPidStore store;
  late _TestUnitsProvider unitsProvider;
  late PidToggleListViewModel viewModel;

  setUp(() {
    store = _TestPidStore(_pids());
    unitsProvider = _TestUnitsProvider(MeasurementUnit.metric);
    viewModel = PidToggleListViewModel(
      store: store,
      unitsProvider: unitsProvider,
    );
  });

  tearDown(() {
    viewModel.dispose();
    unitsProvider.dispose();
    store.dispose();
  });

  testWidgets('renders enabled and disabled PID sections', (tester) async {
    await tester.pumpWidget(_build(viewModel));
    await tester.pump();

    expect(find.text('Gauges'), findsOneWidget);
    expect(find.text('ENABLED'), findsOneWidget);
    expect(find.text('DISABLED'), findsOneWidget);
    expect(find.text('Engine RPM'), findsOneWidget);
    expect(find.text('Vehicle Speed'), findsOneWidget);
    expect(find.text('Engine Coolant Temp'), findsOneWidget);
    expect(find.text('Monitor Status'), findsNothing);
    expect(find.byType(ReorderableDragStartListener), findsOneWidget);
  });

  testWidgets('search shows no-results state and can be cancelled', (
    tester,
  ) async {
    await tester.pumpWidget(_build(viewModel));
    await tester.tap(find.byTooltip('Search PIDs'));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'no-such-pid');
    await tester.pump();

    expect(find.text('No results for "no-such-pid"'), findsOneWidget);
    expect(find.text('Engine RPM'), findsNothing);

    await tester.tap(find.byTooltip('Cancel search'));
    await tester.pump();

    expect(find.text('Gauges'), findsOneWidget);
    expect(find.text('Engine RPM'), findsOneWidget);
    expect(viewModel.searchText, isEmpty);
  });

  testWidgets('search filters rows by PID command', (tester) async {
    await tester.pumpWidget(_build(viewModel));
    await tester.tap(find.byTooltip('Search PIDs'));
    await tester.pump();

    await tester.enterText(find.byType(TextField), '010D');
    await tester.pump();

    expect(find.text('Vehicle Speed'), findsOneWidget);
    expect(find.text('Engine RPM'), findsNothing);
    expect(find.text('Engine Coolant Temp'), findsNothing);
    expect(find.byType(ReorderableDragStartListener), findsNothing);
  });

  testWidgets('switch toggles a disabled PID through the view model', (
    tester,
  ) async {
    await tester.pumpWidget(_build(viewModel));
    await tester.pump();

    final speedTile = find.ancestor(
      of: find.text('Vehicle Speed'),
      matching: find.byType(ListTile),
    );
    final speedSwitch = find.descendant(
      of: speedTile,
      matching: find.byType(Switch),
    );

    await tester.tap(speedSwitch);
    await tester.pump();

    expect(store.pids.firstWhere((p) => p.id == 'speed').enabled, isTrue);
    expect(viewModel.filteredEnabled.map((p) => p.id), contains('speed'));
  });
}
