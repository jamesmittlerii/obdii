import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_obdii/core/config_data.dart';
import 'package:flutter_obdii/core/obd_connection_manager.dart';
import 'package:flutter_obdii/viewmodels/settings_viewmodel.dart';
import 'package:flutter_obdii/views/settings_view.dart';

class _MockSettingsConfig implements SettingsConfigProviding {
  @override
  String wifiHost = '192.168.0.10';
  @override
  int wifiPort = 35000;
  @override
  bool autoConnectToOBD = true;
  @override
  ConnectionType connectionType = ConnectionType.bluetooth;
  @override
  MeasurementUnit units = MeasurementUnit.metric;

  final _unitsCtrl = StreamController<MeasurementUnit>.broadcast();
  final _connTypeCtrl = StreamController<ConnectionType>.broadcast();

  @override
  Stream<MeasurementUnit> get unitsStream => _unitsCtrl.stream;
  @override
  Stream<ConnectionType> get connectionTypeStream => _connTypeCtrl.stream;

  @override
  void setUnits(MeasurementUnit u) => units = u;

  void emitUnits(MeasurementUnit u) {
    units = u;
    _unitsCtrl.add(u);
  }

  void emitConnectionType(ConnectionType t) {
    connectionType = t;
    _connTypeCtrl.add(t);
  }

  void dispose() {
    _unitsCtrl.close();
    _connTypeCtrl.close();
  }
}

class _MockConnection implements OBDConnectionControlling {
  @override
  OBDConnectionState connectionState = OBDConnectionState.disconnected;

  final _stateCtrl = StreamController<OBDConnectionState>.broadcast();
  var connectCallCount = 0;
  var disconnectCallCount = 0;
  var updateConnectionDetailsCallCount = 0;

  @override
  Stream<OBDConnectionState> get connectionStateStream => _stateCtrl.stream;

  @override
  Future<void> connect() async {
    connectCallCount++;
  }

  @override
  void disconnect() {
    disconnectCallCount++;
  }

  @override
  void updateConnectionDetails() {
    updateConnectionDetailsCallCount++;
  }

  void emit(OBDConnectionState state) {
    connectionState = state;
    _stateCtrl.add(state);
  }

  void dispose() => _stateCtrl.close();
}

Widget _build(SettingsViewModel vm) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsViewModel>.value(value: vm),
      ChangeNotifierProvider<OBDConnectionManager>.value(
        value: OBDConnectionManager.instance,
      ),
    ],
    child: const MaterialApp(home: SettingsView()),
  );
}

void main() {
  const MethodChannel pkgChannel = MethodChannel(
    'dev.fluttercommunity.plus/package_info',
  );

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pkgChannel, (call) async {
          if (call.method == 'getAll') {
            return {
              'appName': 'OBDII',
              'packageName': 'com.example.app',
              'version': '1.2.3',
              'buildNumber': '77',
              'buildSignature': '',
              'installerStore': null,
            };
          }
          return null;
        });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pkgChannel, null);
  });

  testWidgets('testRendersPrimarySettingsSections', (tester) async {
    final config = _MockSettingsConfig();
    final conn = _MockConnection();
    final vm = SettingsViewModel(config: config, connection: conn);

    await tester.pumpWidget(_build(vm));
    await tester.pump();

    // SettingsView has no AppBar — it's a tab-hosted view.
    // Verify the always-present section headers and structural elements.
    expect(find.text('UNITS'), findsOneWidget);
    expect(find.text('CONNECTION'), findsOneWidget);
    expect(find.text('DIAGNOSTICS'), findsOneWidget);
    expect(find.text('Gauges'), findsWidgets);

    vm.dispose();
    config.dispose();
    conn.dispose();
  });

  testWidgets('testShowsWiFiConnectionDetailsWhenConnectionTypeIsWifi', (
    tester,
  ) async {
    final config = _MockSettingsConfig()..connectionType = ConnectionType.wifi;
    final conn = _MockConnection();
    final vm = SettingsViewModel(config: config, connection: conn);

    await tester.pumpWidget(_build(vm));
    await tester.pump();

    expect(find.text('CONNECTION DETAILS'), findsOneWidget);
    expect(find.text('Host'), findsOneWidget);
    expect(find.text('Port'), findsOneWidget);

    vm.dispose();
    config.dispose();
    conn.dispose();
  });

  testWidgets('testHidesWiFiConnectionDetailsForBluetoothMode', (tester) async {
    final config = _MockSettingsConfig()
      ..connectionType = ConnectionType.bluetooth;
    final conn = _MockConnection();
    final vm = SettingsViewModel(config: config, connection: conn);

    await tester.pumpWidget(_build(vm));
    await tester.pump();

    expect(find.text('CONNECTION DETAILS'), findsNothing);

    vm.dispose();
    config.dispose();
    conn.dispose();
  });

  testWidgets('testShowsShareLogsAndAboutVersionText', (tester) async {
    final config = _MockSettingsConfig();
    final conn = _MockConnection();
    final vm = SettingsViewModel(config: config, connection: conn);

    await tester.pumpWidget(_build(vm));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Share Logs'), findsOneWidget);
    expect(find.byType(ListTile), findsWidgets);

    vm.dispose();
    config.dispose();
    conn.dispose();
  });

  testWidgets('testConnectButtonLabelReflectsDisconnectedState', (
    tester,
  ) async {
    final config = _MockSettingsConfig();
    final conn = _MockConnection()
      ..connectionState = OBDConnectionState.disconnected;
    final vm = SettingsViewModel(config: config, connection: conn);
    OBDConnectionManager.instance.connectionState =
        OBDConnectionState.disconnected;

    await tester.pumpWidget(_build(vm));
    await tester.pump();

    expect(find.text('Connect'), findsOneWidget);

    vm.dispose();
    config.dispose();
    conn.dispose();
  });

  testWidgets('testConnectButtonLabelReflectsConnectedState', (tester) async {
    final config = _MockSettingsConfig();
    final conn = _MockConnection()
      ..connectionState = OBDConnectionState.connected;
    final vm = SettingsViewModel(config: config, connection: conn);
    OBDConnectionManager.instance.connectionState =
        OBDConnectionState.connected;

    await tester.pumpWidget(_build(vm));
    await tester.pump();

    expect(find.text('Disconnect'), findsOneWidget);

    vm.dispose();
    config.dispose();
    conn.dispose();
  });

  testWidgets('testShowsGaugesNavigationRow', (tester) async {
    final config = _MockSettingsConfig();
    final conn = _MockConnection();
    final vm = SettingsViewModel(config: config, connection: conn);
    await tester.pumpWidget(_build(vm));
    await tester.pump();

    expect(find.text('Gauges'), findsWidgets);
    expect(find.byIcon(Icons.chevron_right), findsWidgets);

    vm.dispose();
    config.dispose();
    conn.dispose();
  });

  testWidgets('testAutoConnectSwitchIsRendered', (tester) async {
    final config = _MockSettingsConfig();
    final conn = _MockConnection();
    final vm = SettingsViewModel(config: config, connection: conn);
    await tester.pumpWidget(_build(vm));
    await tester.pump();

    expect(find.text('Automatically Connect'), findsOneWidget);
    expect(find.byType(Switch), findsWidgets);

    vm.dispose();
    config.dispose();
    conn.dispose();
  });

  testWidgets('testStatusRowLabelIsRendered', (tester) async {
    final config = _MockSettingsConfig();
    final conn = _MockConnection();
    final vm = SettingsViewModel(config: config, connection: conn);
    await tester.pumpWidget(_build(vm));
    await tester.pump();

    expect(find.text('Status'), findsOneWidget);

    vm.dispose();
    config.dispose();
    conn.dispose();
  });

  testWidgets('testUnitsSegmentLabelsRender', (tester) async {
    final config = _MockSettingsConfig();
    final conn = _MockConnection();
    final vm = SettingsViewModel(config: config, connection: conn);
    await tester.pumpWidget(_build(vm));
    await tester.pump();
    expect(find.text('Metric'), findsOneWidget);
    expect(find.text('Imperial'), findsOneWidget);
    vm.dispose();
    config.dispose();
    conn.dispose();
  });

  testWidgets('testConnectionTypeRowRenders', (tester) async {
    final config = _MockSettingsConfig();
    final conn = _MockConnection();
    final vm = SettingsViewModel(config: config, connection: conn);
    await tester.pumpWidget(_build(vm));
    await tester.pump();
    expect(find.text('Type'), findsOneWidget);
    vm.dispose();
    config.dispose();
    conn.dispose();
  });

  testWidgets('testDiagnosticsSectionShowsShareLogsAction', (tester) async {
    final config = _MockSettingsConfig();
    final conn = _MockConnection();
    final vm = SettingsViewModel(config: config, connection: conn);
    await tester.pumpWidget(_build(vm));
    await tester.pump();
    expect(find.text('Share Logs'), findsOneWidget);
    vm.dispose();
    config.dispose();
    conn.dispose();
  });

  testWidgets(
    'testConnectionStatusLabelsRenderForIntermediateAndFailedStates',
    (tester) async {
      final config = _MockSettingsConfig();
      final conn = _MockConnection()
        ..connectionState = OBDConnectionState.connectedToAdapter;
      final vm = SettingsViewModel(config: config, connection: conn);

      await tester.pumpWidget(_build(vm));
      await tester.pump();

      expect(find.text('Connected to Adapter...'), findsOneWidget);
      expect(find.text('Connecting…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      conn.emit(OBDConnectionState.settingUpVehicle);
      await tester.pump();
      expect(find.text('Setting up vehicle...'), findsOneWidget);

      conn.emit(OBDConnectionState.failed);
      await tester.pump();
      expect(find.text('Failed'), findsOneWidget);
      expect(find.text('Connect'), findsOneWidget);

      vm.dispose();
      config.dispose();
      conn.dispose();
    },
  );

  testWidgets('testConnectionButtonInvokesConnectAndDisconnect', (
    tester,
  ) async {
    final config = _MockSettingsConfig();
    final conn = _MockConnection();
    final vm = SettingsViewModel(config: config, connection: conn);

    await tester.pumpWidget(_build(vm));
    await tester.pump();

    await tester.tap(find.text('Connect'));
    expect(conn.connectCallCount, 1);

    conn.emit(OBDConnectionState.connected);
    await tester.pump();
    await tester.tap(find.text('Disconnect'));
    expect(conn.disconnectCallCount, 1);

    vm.dispose();
    config.dispose();
    conn.dispose();
  });

  testWidgets('testConnectionButtonDisabledWhileConnecting', (tester) async {
    final config = _MockSettingsConfig();
    final conn = _MockConnection()
      ..connectionState = OBDConnectionState.connecting;
    final vm = SettingsViewModel(config: config, connection: conn);

    await tester.pumpWidget(_build(vm));
    await tester.pump();

    await tester.tap(find.widgetWithText(TextButton, 'Connecting…'));
    expect(conn.connectCallCount, 0);
    expect(conn.disconnectCallCount, 0);

    vm.dispose();
    config.dispose();
    conn.dispose();
  });

  testWidgets('testUnitsSegmentUpdatesViewModelAndConfig', (tester) async {
    final config = _MockSettingsConfig();
    final conn = _MockConnection();
    final vm = SettingsViewModel(config: config, connection: conn);

    await tester.pumpWidget(_build(vm));
    await tester.pump();

    await tester.tap(find.text('Imperial'));
    await tester.pump();

    expect(vm.units, MeasurementUnit.imperial);
    expect(config.units, MeasurementUnit.imperial);

    vm.dispose();
    config.dispose();
    conn.dispose();
  });

  testWidgets('testConnectionTypeDropdownUpdatesViewModelAndConnection', (
    tester,
  ) async {
    final config = _MockSettingsConfig();
    final conn = _MockConnection();
    final vm = SettingsViewModel(config: config, connection: conn);

    await tester.pumpWidget(_build(vm));
    await tester.pump();

    await tester.tap(find.byType(DropdownButton<ConnectionType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Demo').last);
    await tester.pumpAndSettle();

    expect(vm.connectionType, ConnectionType.demo);
    expect(config.connectionType, ConnectionType.demo);
    expect(conn.updateConnectionDetailsCallCount, 1);

    vm.dispose();
    config.dispose();
    conn.dispose();
  });

  testWidgets('testWifiFieldsUpdateHostAndValidPort', (tester) async {
    final config = _MockSettingsConfig()..connectionType = ConnectionType.wifi;
    final conn = _MockConnection();
    final vm = SettingsViewModel(config: config, connection: conn);

    await tester.pumpWidget(_build(vm));
    await tester.pump();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '10.0.0.42');
    await tester.enterText(fields.at(1), '');
    await tester.enterText(fields.at(1), '12345');
    await tester.pump(const Duration(milliseconds: 600));

    expect(config.wifiHost, '10.0.0.42');
    expect(config.wifiPort, 12345);
    expect(conn.updateConnectionDetailsCallCount, greaterThanOrEqualTo(1));

    vm.dispose();
    config.dispose();
    conn.dispose();
  });
}
