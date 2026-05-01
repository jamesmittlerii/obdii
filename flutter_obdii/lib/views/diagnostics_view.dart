// Port of DiagnosticsView.swift + DTCDetailView.swift — Jim Mittler
// Groups DTCs by severity (Critical / High / Moderate / Low).
// Each row: severity icon + "P0xxx • Title" + severity subtitle + disclosure arrow.
// Tapping navigates to DTCDetailView (Overview, Description, Causes, Remedies).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/diagnostics_viewmodel.dart';

class DiagnosticsView extends StatefulWidget {
  final bool isActive;

  const DiagnosticsView({super.key, this.isActive = true});

  @override
  State<DiagnosticsView> createState() => _DiagnosticsViewState();
}

class _DiagnosticsViewState extends State<DiagnosticsView> {
  void _syncVisibility() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DiagnosticsViewModel>().setVisible(widget.isActive);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncVisibility();
  }

  @override
  void didUpdateWidget(covariant DiagnosticsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _syncVisibility();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostic Codes'),
        centerTitle: false,
      ),
      body: Consumer<DiagnosticsViewModel>(
        builder: (context, vm, _) {
          // 1) Waiting for first data
          if (vm.codes == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(height: 16),
                  const Text('Waiting for data…',
                      style: TextStyle(color: Colors.grey)),
                  if (vm.connectionState != OBDConnectionState.connected)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Connect to a vehicle in Settings.',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ),
                ],
              ),
            );
          }

          // 2) Loaded but no codes
          if (vm.sections.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text('No Trouble Codes Found',
                      style: TextStyle(fontSize: 18)),
                  SizedBox(height: 4),
                  Text('All systems normal.',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          // 3) Sections by severity
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: vm.sections.length,
            itemBuilder: (context, index) {
              final section = vm.sections[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(severity: section.severity),
                  Card(
                    child: Column(
                      children: [
                        for (int i = 0; i < section.items.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          _DtcRow(dtc: section.items[i]),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Section header  (Critical / High / Moderate / Low)
// ─────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String severity;

  const _SectionHeader({required this.severity});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        severity.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: _severityColor(severity),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Color _severityColor(String s) {
    switch (s.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'moderate':
        return Colors.amber;
      case 'low':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}

// ─────────────────────────────────────────────
// Individual DTC row — matches Swift codeRow()
// ─────────────────────────────────────────────

class _DtcRow extends StatelessWidget {
  final dynamic dtc; // TroubleCodeMetadata

  const _DtcRow({required this.dtc});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _severityIcon(dtc.severity?.toString() ?? ''),
      title: Text(
        '${dtc.code} • ${dtc.title ?? dtc.code}',
        style: const TextStyle(fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        dtc.severity?.toString() ?? '',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _DtcDetailView(dtc: dtc)),
      ),
    );
  }

  Widget _severityIcon(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return const Icon(Icons.cancel_outlined, color: Colors.red);
      case 'high':
        return const Icon(Icons.electric_bolt, color: Colors.orange);
      case 'moderate':
        return const Icon(Icons.warning_amber_outlined, color: Colors.amber);
      case 'low':
      default:
        return const Icon(Icons.info_outline, color: Colors.blue);
    }
  }
}

// ─────────────────────────────────────────────
// DTC Detail  — port of DTCDetailView.swift
// Overview | Description | Causes | Remedies
// ─────────────────────────────────────────────

class _DtcDetailView extends StatelessWidget {
  final dynamic dtc; // TroubleCodeMetadata

  const _DtcDetailView({required this.dtc});

  @override
  Widget build(BuildContext context) {
    final causes = _stringList(dtc.causes);
    final remedies = _stringList(dtc.remedies);

    return Scaffold(
      appBar: AppBar(
        title: Text(dtc.code as String? ?? ''),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Overview
          _sectionHeader(context, 'Overview'),
          Card(
            child: Column(
              children: [
                _labeledRow('Code', dtc.code as String? ?? ''),
                const Divider(height: 1),
                _labeledRow('Title', dtc.title as String? ?? ''),
                const Divider(height: 1),
                _labeledRow('Severity', dtc.severity?.toString() ?? ''),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Description
          _sectionHeader(context, 'Description'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(dtc.description as String? ?? ''),
            ),
          ),
          const SizedBox(height: 16),

          // Causes
          if (causes.isNotEmpty) ...[
            _sectionHeader(context, 'Potential Causes'),
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < causes.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Text('• ${causes[i]}'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Remedies
          if (remedies.isNotEmpty) ...[
            _sectionHeader(context, 'Possible Remedies'),
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < remedies.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Text('• ${remedies[i]}'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
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

  Widget _labeledRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  List<String> _stringList(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw.cast<String>();
    return [];
  }
}
