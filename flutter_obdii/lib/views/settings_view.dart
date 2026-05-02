// Port of SettingsView.swift — Jim Mittler
// Sections (in order matching Swift):
//   1. (unnamed) — Gauges NavigationLink → PidToggleListView
//   2. Units — Segmented picker (Metric | Imperial)
//   3. Connection — Status (text), Type (picker), Auto-Connect (toggle), Connect button
//   4. Connection Details (WiFi only) — Host, Port inline fields
//   5. Diagnostics — Share Logs button (uses share_plus)
//   6. About — version string

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _isGeneratingLogs = false;
  String? _shareError;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: false,
      ),
      body: Consumer<SettingsViewModel>(
        builder: (context, vm, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── 1. Gauges nav link ────────────────────────
              Card(
                child: ListTile(
                  title: const Text('Gauges'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PidToggleListView()),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── 2. Units ──────────────────────────────────
              _sectionHeader(context, 'Units'),
              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: SegmentedButton<MeasurementUnit>(
                    segments: const [
                      ButtonSegment(
                        value: MeasurementUnit.metric,
                        label: Text('Metric'),
                      ),
                      ButtonSegment(
                        value: MeasurementUnit.imperial,
                        label: Text('Imperial'),
                      ),
                    ],
                    selected: {vm.units},
                    onSelectionChanged: (s) => vm.onUnitsChanged(s.first),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── 3. Connection ────────────────────────────
              _sectionHeader(context, 'Connection'),
              Card(
                child: Column(
                  children: [
                    // Status row
                    ListTile(
                      title: const Text('Status'),
                      trailing: _statusText(vm.connectionState),
                    ),
                    const Divider(height: 1),

                    // Type picker
                    ListTile(
                      title: const Text('Type'),
                      trailing: DropdownButton<ConnectionType>(
                        value: vm.connectionType,
                        underline: const SizedBox(),
                        items: ConnectionType.values
                            .map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(t.displayName),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) vm.onConnectionTypeChanged(v);
                        },
                      ),
                    ),
                    const Divider(height: 1),

                    // Automatically Connect toggle
                    SwitchListTile(
                      title: const Text('Automatically Connect'),
                      value: vm.autoConnectToOBD,
                      onChanged: vm.onAutoConnectChanged,
                    ),
                    const Divider(height: 1),

                    // Connect / Disconnect button (centered text, blue)
                    Builder(
                      builder: (context) {
                        final state = vm.connectionState;
                        final label = switch (state) {
                          OBDConnectionState.disconnected => 'Connect',
                          OBDConnectionState.connecting => 'Connecting…',
                          OBDConnectionState.connected => 'Disconnect',
                          OBDConnectionState.failed => 'Connect',
                        };
                        return TextButton(
                          onPressed: vm.isConnectButtonDisabled
                              ? null
                              : vm.handleConnectionButtonTap,
                          child: state == OBDConnectionState.connecting
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(label),
                                    const SizedBox(width: 8),
                                    const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                  ],
                                )
                              : Text(label),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // ── 4. Connection Details (WiFi only) ─────────
              if (vm.connectionType == ConnectionType.wifi) ...[
                const SizedBox(height: 16),
                _sectionHeader(context, 'Connection Details'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('Host'),
                        trailing: SizedBox(
                          width: 180,
                          child: TextField(
                            textAlign: TextAlign.right,
                            decoration: InputDecoration(
                              hintText: 'e.g. 192.168.0.10',
                              hintStyle: TextStyle(color: Colors.grey.shade600),
                              border: InputBorder.none,
                            ),
                            keyboardType: TextInputType.url,
                            autocorrect: false,
                            controller: TextEditingController.fromValue(
                              TextEditingValue(
                                text: vm.wifiHost,
                                selection: TextSelection.collapsed(
                                    offset: vm.wifiHost.length),
                              ),
                            ),
                            onChanged: vm.onWifiHostChanged,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('Port'),
                        trailing: SizedBox(
                          width: 100,
                          child: TextField(
                            textAlign: TextAlign.right,
                            decoration: InputDecoration(
                              hintText: 'e.g. 35000',
                              hintStyle: TextStyle(color: Colors.grey.shade600),
                              border: InputBorder.none,
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            controller: TextEditingController.fromValue(
                              TextEditingValue(
                                text: vm.wifiPort.toString(),
                                selection: TextSelection.collapsed(
                                    offset: vm.wifiPort.toString().length),
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
                ),
              ],
              const SizedBox(height: 16),

              // ── 5. Diagnostics ────────────────────────────
              _sectionHeader(context, 'Diagnostics'),
              Card(
                child: ListTile(
                  title: _isGeneratingLogs
                      ? const Row(
                          children: [
                            SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 10),
                            Text('Preparing Logs…'),
                          ],
                        )
                      : const Text('Share Logs'),
                  enabled: !_isGeneratingLogs,
                  onTap: _shareLogs,
                ),
              ),
              if (_shareError != null)
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4),
                  child: Text(
                    _shareError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 16),

              // ── 6. About ──────────────────────────────────
              _sectionHeader(context, 'About'),
              Card(
                child: ListTile(
                  title: Text(vm.appVersion.isNotEmpty
                      ? vm.appVersion
                      : 'Loading version…'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Status trailing text ───────────────────────────────

  Widget _statusText(OBDConnectionState state) {
    final (label, color) = switch (state) {
      OBDConnectionState.disconnected => ('Disconnected', Colors.grey),
      OBDConnectionState.connecting => ('Connecting…', Colors.orange),
      OBDConnectionState.connected => ('Connected', Colors.green),
      OBDConnectionState.failed => ('Failed', Colors.red),
    };
    return Text(label, style: TextStyle(color: color));
  }

  // ── Section header ─────────────────────────────────────

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8, top: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  // ── Share Logs ─────────────────────────────────────────

  Future<void> _shareLogs() async {
    setState(() {
      _isGeneratingLogs = true;
      _shareError = null;
    });

    String? exportedPath;
    try {
      final vm = context.read<SettingsViewModel>();
      final (:fileName, :bytes) = await vm.prepareLogExport();

      if (Platform.isWindows) {
        final location = await getSaveLocation(
          suggestedName: fileName,
          acceptedTypeGroups: const [
            XTypeGroup(
              label: 'JSON',
              extensions: ['json'],
            ),
          ],
        );
        if (location == null) {
          return;
        }
        final outFile = File(location.path);
        await outFile.writeAsBytes(bytes);
        exportedPath = outFile.path;
        if (mounted) {
          setState(() {
            _shareError = 'Log file exported to:\n$exportedPath';
          });
        }
        return;
      }

      // Write to temp file
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);
      exportedPath = file.path;

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          subject: fileName,
        ),
      );
    } catch (e) {
      if (mounted) {
        final message = e.toString();
        final lowered = message.toLowerCase();
        final shareSheetUnavailable = lowered.contains('couldn\'t show you all the ways you could share') ||
            lowered.contains('could not show you all the ways you could share');
        setState(() {
          if (shareSheetUnavailable && exportedPath != null) {
            _shareError =
                'Share sheet unavailable on this device. Log file exported to:\n$exportedPath';
          } else {
            _shareError = message;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _isGeneratingLogs = false);
    }
  }
}

// ── Extension helpers ─────────────────────────────────────

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
