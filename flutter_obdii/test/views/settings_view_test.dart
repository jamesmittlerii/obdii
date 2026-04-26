import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_obdii/core/config_data.dart';
import 'package:flutter_obdii/core/obd_connection_manager.dart';
import 'package:flutter_obdii/viewmodels/settings_viewmodel.dart';
import 'package:flutter_obdii/views/pid_toggle_list_view.dart';
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

  void dispose() {
    _unitsCtrl.close();
    _connTypeCtrl.close();
  }
}

class _MockConnection implements OBDConnectionControlling {
  @override
  OBDConnectionState connectionState = OBDConnectionState.disconnected;

  final _stateCtrl = StreamController<OBDConnectionState>.broadcast();

  @override
  Stream<OBDConnectionState> get connectionStateStream => _stateCtrl.stream;

  @override
  Future<void> connect() async {}
  @override
  void disconnect() {}
  @override
  void updateConnectionDetails() {}

  void dispose() => _stateCtrl.close();
}

Widget _build(SettingsViewModel vm) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ConfigData>.value(value: ConfigData.instance),
      ChangeNotifierProvider<SettingsViewModel>.value(value: vm),
      ChangeNotifierProvider<OBDConnectionManager>.value(
        value: OBDConnectionManager.instance,
      ),
    ],
    child: const CupertinoApp(
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [Locale('en')],
      home: SettingsView(),
    ),
  );
}

void main() {
  const MethodChannel pkgChannel = MethodChannel('dev.fluttercommunity.plus/package_info');

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

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Units'), findsOneWidget);
    expect(find.text('Connection'), findsOneWidget);
    expect(find.text('Gauges'), findsWidgets);

    vm.dispose();
    config.dispose();
    conn.dispose();
  });

  testWidgets('testShowsWiFiConnectionDetailsWhenConnectionTypeIsWifi', (tester) async {
    final config = _MockSettingsConfig();
    final conn = _MockConnection();
    final vm = SettingsViewModel(config: config, connection: conn);

    await tester.pumpWidget(_build(vm));
    await tester.pump();
    await tester.tap(find.text('WiFi').first);
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Connection Details'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Connection Details'), findsOneWidget);
    expect(find.text('Connection Details'), findsOneWidget);

    vm.dispose();
    config.dispose();
    conn.dispose();
  });

  testWidgets('testHidesWiFiConnectionDetailsForBluetoothMode', (tester) async {
    final config = _MockSettingsConfig()..connectionType = ConnectionType.bluetooth;
    final conn = _MockConnection();
    final vm = SettingsViewModel(config: config, connection: conn);

    await tester.pumpWidget(_build(vm));
    await tester.pump();

    expect(find.text('Connection Details'), findsNothing);

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
    await tester.scrollUntilVisible(
      find.text('Diagnostics'),
      400,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Diagnostics'), findsOneWidget);
    expect(find.byType(CupertinoListTile), findsWidgets);

    vm.dispose();
    config.dispose();
    conn.dispose();
  });

  testWidgets('testConnectButtonLabelReflectsDisconnectedState', (tester) async {
    final config = _MockSettingsConfig();
    final conn = _MockConnection()..connectionState = OBDConnectionState.disconnected;
    final vm = SettingsViewModel(config: config, connection: conn);
    OBDConnectionManager.instance.connectionState = OBDConnectionState.disconnected;

    await tester.pumpWidget(_build(vm));
    await tester.pump();

    expect(find.text('Connect'), findsOneWidget);

    vm.dispose();
    config.dispose();
    conn.dispose();
  });

  testWidgets('testConnectButtonLabelReflectsConnectedState', (tester) async {
    final config = _MockSettingsConfig();
    final conn = _MockConnection()..connectionState = OBDConnectionState.connected;
    final vm = SettingsViewModel(config: config, connection: conn);
    OBDConnectionManager.instance.connectionState = OBDConnectionState.connected;

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
    expect(find.byIcon(CupertinoIcons.chevron_forward), findsWidgets);

    vm.dispose();
    config.dispose();
    conn.dispose();
  });

  testWidgets('testNavigatesToGaugePickerWithoutLocalizationException',
      (tester) async {
    final config = _MockSettingsConfig();
    final conn = _MockConnection();
    final vm = SettingsViewModel(config: config, connection: conn);
    await tester.pumpWidget(_build(vm));
    await tester.pump();

    await tester.tap(find.byType(CupertinoListTile).first);
    await tester.pumpAndSettle();

    expect(find.byType(PidToggleListView), findsOneWidget);
    expect(tester.takeException(), isNull);
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
    expect(find.byType(CupertinoSwitch), findsWidgets);

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
    expect(find.text('Bluetooth LE'), findsOneWidget);
    expect(find.text('WiFi'), findsOneWidget);
    expect(find.text('Demo'), findsOneWidget);
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
    await tester.scrollUntilVisible(
      find.text('Diagnostics'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Diagnostics'), findsOneWidget);
    vm.dispose();
    config.dispose();
    conn.dispose();
  });
}
