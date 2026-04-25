import 'dart:io';

import 'package:flutter/services.dart';

import 'config_data.dart';

/// Thin bridge for notifying native iOS CarPlay code about handset-originated
/// settings and gauge list changes.
class CarPlayBridge {
  CarPlayBridge._();

  static const MethodChannel _channel =
      MethodChannel('com.jamesmittlerii.obdii/carplay_bridge');

  static bool get _isSupportedPlatform => Platform.isIOS;

  static Future<void> settingsChanged({
    required MeasurementUnit units,
    required ConnectionType connectionType,
    required bool autoConnectToOBD,
    required String wifiHost,
    required int wifiPort,
  }) async {
    if (!_isSupportedPlatform) return;

    await _invoke('settingsChanged', <String, Object>{
      'units': units.name,
      'connectionType': connectionType.rawValue,
      'autoConnectToOBD': autoConnectToOBD,
      'wifiHost': wifiHost,
      'wifiPort': wifiPort,
    });
  }

  static Future<void> gaugePreferencesChanged() async {
    if (!_isSupportedPlatform) return;
    await _invoke('gaugePreferencesChanged');
  }

  static Future<void> _invoke(String method, [Map<String, Object>? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on PlatformException {
      // Keep bridge failures non-fatal so handset experience remains stable.
    } on MissingPluginException {
      // Allows unit/widget tests and non-iOS runs without channel wiring.
    }
  }
}
