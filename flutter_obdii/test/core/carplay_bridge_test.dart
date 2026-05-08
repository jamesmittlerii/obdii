import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_obdii/core/carplay_bridge.dart';
import 'package:flutter_obdii/core/config_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.jamesmittlerii.obdii/carplay_bridge');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    CarPlayBridge.debugIsSupportedPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('settingsChanged is a no-op on unsupported platforms', () async {
    CarPlayBridge.debugIsSupportedPlatformOverride = false;
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });

    await CarPlayBridge.settingsChanged(
      units: MeasurementUnit.imperial,
      connectionType: ConnectionType.wifi,
      autoConnectToOBD: true,
      wifiHost: '192.168.0.10',
      wifiPort: 35000,
    );

    expect(calls, isEmpty);
  });

  test('settingsChanged sends serialized settings to the bridge', () async {
    CarPlayBridge.debugIsSupportedPlatformOverride = true;
    late MethodCall receivedCall;
    messenger.setMockMethodCallHandler(channel, (call) async {
      receivedCall = call;
      return null;
    });

    await CarPlayBridge.settingsChanged(
      units: MeasurementUnit.imperial,
      connectionType: ConnectionType.wifi,
      autoConnectToOBD: true,
      wifiHost: '192.168.0.10',
      wifiPort: 35000,
    );

    expect(receivedCall.method, 'settingsChanged');
    expect(
      receivedCall.arguments,
      equals(<String, Object>{
        'units': 'imperial',
        'connectionType': 'wifi',
        'autoConnectToOBD': true,
        'wifiHost': '192.168.0.10',
        'wifiPort': 35000,
      }),
    );
  });

  test('gaugePreferencesChanged sends bridge notification', () async {
    CarPlayBridge.debugIsSupportedPlatformOverride = true;
    late MethodCall receivedCall;
    messenger.setMockMethodCallHandler(channel, (call) async {
      receivedCall = call;
      return null;
    });

    await CarPlayBridge.gaugePreferencesChanged();

    expect(receivedCall.method, 'gaugePreferencesChanged');
    expect(receivedCall.arguments, isNull);
  });

  test('bridge ignores platform exceptions', () async {
    CarPlayBridge.debugIsSupportedPlatformOverride = true;
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'native_error');
    });

    await expectLater(CarPlayBridge.gaugePreferencesChanged(), completes);
  });

  test('bridge ignores missing plugin exceptions', () async {
    CarPlayBridge.debugIsSupportedPlatformOverride = true;

    await expectLater(CarPlayBridge.gaugePreferencesChanged(), completes);
  });
}
