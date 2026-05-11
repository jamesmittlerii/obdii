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
import '../core/constants.dart';
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
  String? _shareStatus;
  bool _shareStatusIsError = false;

  static const _connectingLabel = 'Connecting…';

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<SettingsViewModel>(
        builder: (context, vm, _) {
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── 1. Gauges nav link ────────────────────────
                    _buildGaugesSection(context),
                    const SizedBox(height: 16),

                    // ── 2. Units ──────────────────────────────────
                    _buildUnitsSection(context, vm),
                    const SizedBox(height: 16),

                    // ── 3. Connection ────────────────────────────
                    _buildConnectionSection(context, vm),
                    
                    // ── 4. Connection Details (WiFi only) ─────────
                    if (vm.connectionType == ConnectionType.wifi) ...[
                      const SizedBox(height: 16),
                      _buildConnectionDetailsSection(context, vm),
                    ],
                    const SizedBox(height: 16),

                    // ── 5. Diagnostics ────────────────────────────
                    _buildDiagnosticsSection(context),
                    const SizedBox(height: 16),

                    // ── 6. About ──────────────────────────────────
                    _buildAboutSection(context, vm),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGaugesSection(BuildContext context) {
    return Card(
      child: ListTile(
        title: const Text('Gauges'),
        trailing: Icon(
          Icons.chevron_right,
          color: Theme.of(context).colorScheme.primary,
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const PidToggleListView()),
        ),
      ),
    );
  }

  Widget _buildUnitsSection(BuildContext context, SettingsViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, 'Units'),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            // SegmentedButton is intrinsic-width; Column crossAxisAlignment is start,
            // so without Center the control sits on the left.
            child: Center(
              child: SegmentedButton<MeasurementUnit>(
                // Avoid selected checkmark + Row(Flexible(label)): long labels like
                // "Imperial" wrap on first layout until a rebuild (e.g. after toggle).
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(alignment: Alignment.center),
                segments: const [
                  ButtonSegment(
                    value: MeasurementUnit.metric,
                    label: Text(
                      'Metric',
                      textAlign: TextAlign.center,
                      softWrap: false,
                      maxLines: 1,
                    ),
                  ),
                  ButtonSegment(
                    value: MeasurementUnit.imperial,
                    label: Text(
                      'Imperial',
                      textAlign: TextAlign.center,
                      softWrap: false,
                      maxLines: 1,
                    ),
                  ),
                ],
                selected: {vm.units},
                onSelectionChanged: (s) => vm.onUnitsChanged(s.first),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionSection(BuildContext context, SettingsViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, 'Connection'),
        Card(
          child: Column(
            children: [
              ListTile(
                title: const Text('Status'),
                trailing: _statusText(vm.connectionState),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Type'),
                trailing: DropdownButtonHideUnderline(
                  child: DropdownButton<ConnectionType>(
                    value: vm.connectionType,
                    isDense: true,
                    focusColor: Colors.transparent,
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: Theme.of(context).colorScheme.primary,
                    ),
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
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Automatically Connect'),
                value: vm.autoConnectToOBD,
                onChanged: vm.onAutoConnectChanged,
              ),
              const Divider(height: 1),
              Builder(
                builder: (context) {
                  final state = vm.connectionState;
                  final label = switch (state) {
                    OBDConnectionState.disconnected => 'Connect',
                    OBDConnectionState.connecting => _connectingLabel,
                    OBDConnectionState.connectedToAdapter => _connectingLabel,
                    OBDConnectionState.settingUpVehicle => _connectingLabel,
                    OBDConnectionState.connected => 'Disconnect',
                    OBDConnectionState.failed => 'Connect',
                  };
                  return TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                    onPressed: vm.isConnectButtonDisabled
                        ? null
                        : vm.handleConnectionButtonTap,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: state == OBDConnectionState.connecting ||
                              state == OBDConnectionState.connectedToAdapter ||
                              state == OBDConnectionState.settingUpVehicle
                          ? Row(
                              key: const ValueKey('loading'),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(label),
                                const SizedBox(width: 8),
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ],
                            )
                          : Text(label, key: const ValueKey('ready')),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionDetailsSection(BuildContext context, SettingsViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                      hintText: 'e.g. $defaultWifiHost',
                      hintStyle: TextStyle(color: Colors.grey.shade600),
                      border: InputBorder.none,
                    ),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    controller: TextEditingController.fromValue(
                      TextEditingValue(
                        text: vm.wifiHost,
                        selection: TextSelection.collapsed(offset: vm.wifiHost.length),
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
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    controller: TextEditingController.fromValue(
                      TextEditingValue(
                        text: vm.wifiPort.toString(),
                        selection: TextSelection.collapsed(offset: vm.wifiPort.toString().length),
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
    );
  }

  Widget _buildDiagnosticsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            trailing: _isGeneratingLogs
                ? null
                : Icon(
                    Icons.ios_share,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
            enabled: !_isGeneratingLogs,
            onTap: _shareLogs,
          ),
        ),
        if (_shareStatus != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 4),
            child: Text(
              _shareStatus!,
              style: TextStyle(
                color: _shareStatusIsError ? Colors.red : Colors.grey,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAboutSection(BuildContext context, SettingsViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, 'About'),
        Card(
          child: ListTile(
            title: Text(vm.appVersion.isNotEmpty ? vm.appVersion : 'Loading version…'),
          ),
        ),
      ],
    );
  }

  // ── Status trailing text ───────────────────────────────

  Widget _statusText(OBDConnectionState state) {
    final (label, color) = switch (state) {
      OBDConnectionState.disconnected => ('Disconnected', Colors.grey),
      OBDConnectionState.connecting => (_connectingLabel, Colors.orange),
      OBDConnectionState.connectedToAdapter =>
        ('Connected to Adapter...', Colors.blue),
      OBDConnectionState.settingUpVehicle =>
        ('Setting up vehicle...', Colors.orange),
      OBDConnectionState.connected => ('Connected', Colors.green),
      OBDConnectionState.failed => ('Failed', Colors.red),
    };
    return Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
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
      _shareStatus = null;
      _shareStatusIsError = false;
    });

    String? exportedPath;
    try {
      final vm = context.read<SettingsViewModel>();
      final (:fileName, :bytes) = await vm.prepareLogExport();

      if (Platform.isWindows) {
        exportedPath = await _exportLogsToWindows(fileName, bytes);
      } else {
        exportedPath = await _shareLogsToMobile(fileName, bytes);
      }
    } catch (e) {
      _handleShareError(e, exportedPath);
    } finally {
      if (mounted) setState(() => _isGeneratingLogs = false);
    }
  }

  Future<String?> _exportLogsToWindows(String fileName, List<int> bytes) async {
    final location = await getSaveLocation(
      suggestedName: fileName,
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'JSON',
          extensions: ['json'],
        ),
      ],
    );
    if (location == null) return null;
    
    final outFile = File(location.path);
    await outFile.writeAsBytes(bytes);
    if (mounted) {
      setState(() {
        _shareStatus = 'Log file exported to:\n${outFile.path}';
        _shareStatusIsError = false;
      });
    }
    return outFile.path;
  }

  Future<String> _shareLogsToMobile(String fileName, List<int> bytes) async {
    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(bytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: fileName,
      ),
    );
    return file.path;
  }

  void _handleShareError(Object e, String? exportedPath) {
    if (!mounted) return;
    final message = e.toString();
    final lowered = message.toLowerCase();
    final shareSheetUnavailable =
        lowered.contains('couldn\'t show you all the ways you could share') ||
            lowered.contains('could not show you all the ways you could share');
    setState(() {
      _shareStatusIsError = true;
      if (shareSheetUnavailable && exportedPath != null) {
        _shareStatus =
            'Share sheet unavailable on this device. Log file exported to:\n$exportedPath';
        _shareStatusIsError = false; // This is a success fallback
      } else {
        _shareStatus = message;
      }
    });
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
