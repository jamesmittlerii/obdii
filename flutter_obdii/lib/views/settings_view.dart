// Port of SettingsView.swift — Jim Mittler
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/config_data.dart';
import '../core/obd_connection_manager.dart';
import '../viewmodels/settings_viewmodel.dart';
import 'pid_toggle_list_view.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  String _appVersion = '';
  bool _isGeneratingLogs = false;
  String? _shareError;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _appVersion = '${info.appName} v${info.version} build:${info.buildNumber}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Settings'),
      ),
      child: Consumer<SettingsViewModel>(
        builder: (context, vm, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
            children: [
              _sectionHeader(context, 'Gauges'),
              CupertinoListSection.insetGrouped(
                children: [
                  CupertinoListTile(
                    title: const Text('Gauges'),
                    trailing: const Icon(CupertinoIcons.chevron_forward),
                    onTap: () => Navigator.push(
                      context,
                      CupertinoPageRoute(builder: (_) => const PidToggleListView()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _sectionHeader(context, 'Units'),
              CupertinoListSection.insetGrouped(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: CupertinoSlidingSegmentedControl<MeasurementUnit>(
                      groupValue: vm.units,
                      children: const {
                        MeasurementUnit.metric: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('Metric'),
                        ),
                        MeasurementUnit.imperial: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('Imperial'),
                        ),
                      },
                      onValueChanged: (v) {
                        if (v != null) vm.onUnitsChanged(v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _sectionHeader(context, 'Connection'),
              CupertinoListSection.insetGrouped(
                children: [
                  CupertinoListTile(
                    title: const Text('Status'),
                    trailing: _statusText(vm.connectionState),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Expanded(child: Text('Type')),
                        CupertinoSlidingSegmentedControl<ConnectionType>(
                          groupValue: vm.connectionType,
                          children: {
                            for (final t in ConnectionType.values)
                              t: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: Text(t.displayName),
                              ),
                          },
                          onValueChanged: (v) {
                            if (v != null) vm.onConnectionTypeChanged(v);
                          },
                        ),
                      ],
                    ),
                  ),
                  CupertinoListTile(
                    title: const Text('Automatically Connect'),
                    trailing: CupertinoSwitch(
                      value: vm.autoConnectToOBD,
                      onChanged: vm.onAutoConnectChanged,
                    ),
                  ),
                  Consumer<OBDConnectionManager>(
                    builder: (context, mgr, _) {
                      final state = mgr.connectionState;
                      final label = switch (state) {
                        OBDConnectionState.disconnected => 'Connect',
                        OBDConnectionState.connecting => 'Connecting…',
                        OBDConnectionState.connected => 'Disconnect',
                        OBDConnectionState.failed => 'Connect',
                      };
                      return Center(
                        child: CupertinoButton(
                          onPressed: vm.isConnectButtonDisabled
                              ? null
                              : vm.handleConnectionButtonTap,
                          child: state == OBDConnectionState.connecting
                              ? const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Connecting…'),
                                    SizedBox(width: 8),
                                    CupertinoActivityIndicator(radius: 8),
                                  ],
                                )
                              : Text(label),
                        ),
                      );
                    },
                  ),
                ],
              ),
              if (vm.connectionType == ConnectionType.wifi) ...[
                const SizedBox(height: 16),
                _sectionHeader(context, 'Connection Details'),
                CupertinoListSection.insetGrouped(
                  children: [
                    CupertinoListTile(
                      title: const Text('Host'),
                      trailing: SizedBox(
                        width: 180,
                        child: CupertinoTextField(
                          textAlign: TextAlign.right,
                          placeholder: 'e.g. 192.168.0.10',
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          controller: TextEditingController.fromValue(
                            TextEditingValue(
                              text: vm.wifiHost,
                              selection: TextSelection.collapsed(
                                offset: vm.wifiHost.length,
                              ),
                            ),
                          ),
                          onChanged: vm.onWifiHostChanged,
                        ),
                      ),
                    ),
                    CupertinoListTile(
                      title: const Text('Port'),
                      trailing: SizedBox(
                        width: 100,
                        child: CupertinoTextField(
                          textAlign: TextAlign.right,
                          placeholder: 'e.g. 35000',
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          controller: TextEditingController.fromValue(
                            TextEditingValue(
                              text: vm.wifiPort.toString(),
                              selection: TextSelection.collapsed(
                                offset: vm.wifiPort.toString().length,
                              ),
                            ),
                          ),
                          onChanged: (v) {
                            final port = int.tryParse(v);
                            if (port != null) vm.onWifiPortChanged(port);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              _sectionHeader(context, 'Diagnostics'),
              CupertinoListSection.insetGrouped(
                children: [
                  CupertinoListTile(
                    title: _isGeneratingLogs
                        ? const Row(
                            children: [
                              CupertinoActivityIndicator(radius: 8),
                              SizedBox(width: 10),
                              Text('Preparing Logs…'),
                            ],
                          )
                        : const Text('Share Logs'),
                    onTap: _isGeneratingLogs ? null : _shareLogs,
                  ),
                ],
              ),
              if (_shareError != null)
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4),
                  child: Text(
                    _shareError!,
                    style: const TextStyle(
                      color: CupertinoColors.destructiveRed,
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              _sectionHeader(context, 'About'),
              CupertinoListSection.insetGrouped(
                children: [
                  CupertinoListTile(
                    title: Text(_appVersion.isNotEmpty ? _appVersion : 'Loading version…'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statusText(OBDConnectionState state) {
    final (label, color) = switch (state) {
      OBDConnectionState.disconnected => ('Disconnected', CupertinoColors.secondaryLabel),
      OBDConnectionState.connecting => ('Connecting…', CupertinoColors.systemOrange),
      OBDConnectionState.connected => ('Connected', CupertinoColors.activeGreen),
      OBDConnectionState.failed => ('Failed', CupertinoColors.destructiveRed),
    };
    return Text(label, style: TextStyle(color: color));
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8, top: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: CupertinoTheme.of(context).primaryColor,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Future<void> _shareLogs() async {
    setState(() {
      _isGeneratingLogs = true;
      _shareError = null;
    });

    try {
      final logs = await _collectLogs();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(logs);
      final bytes = utf8.encode(jsonStr);

      final info = await PackageInfo.fromPlatform();
      final fileName =
          '${info.appName.replaceAll(' ', '_')}-v${info.version}-logs.json';

      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          subject: fileName,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _shareError = e.toString());
      }
    } finally {
      if (mounted) setState(() => _isGeneratingLogs = false);
    }
  }

  Future<Map<String, dynamic>> _collectLogs() async {
    final mgr = OBDConnectionManager.instance;
    final cfg = ConfigData.instance;
    final info = await PackageInfo.fromPlatform();

    return {
      'timestamp': DateTime.now().toIso8601String(),
      'appVersion': '${info.version}+${info.buildNumber}',
      'connectionType': cfg.connectionType.toString(),
      'units': cfg.units.toString(),
      'connectionState': mgr.connectionState.toString(),
      'wifiHost': cfg.wifiHost,
      'wifiPort': cfg.wifiPort,
    };
  }
}

extension ConnectionTypeDisplayName on ConnectionType {
  String get displayName {
    switch (this) {
      case ConnectionType.demo:
        return 'Demo';
      case ConnectionType.wifi:
        return 'WiFi';
      case ConnectionType.bluetooth:
        return 'Bluetooth LE';
    }
  }
}
