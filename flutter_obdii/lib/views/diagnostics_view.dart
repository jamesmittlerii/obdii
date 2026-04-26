// Port of DiagnosticsView.swift + DTCDetailView.swift — Jim Mittler
// Groups DTCs by severity (Critical / High / Moderate / Low).
// Each row: severity icon + "P0xxx • Title" + severity subtitle + disclosure arrow.
// Tapping navigates to DTCDetailView (Overview, Description, Causes, Remedies).

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../core/obd_connection_manager.dart';
import '../viewmodels/diagnostics_viewmodel.dart';

class DiagnosticsView extends StatefulWidget {
  const DiagnosticsView({super.key});

  @override
  State<DiagnosticsView> createState() => _DiagnosticsViewState();
}

class _DiagnosticsViewState extends State<DiagnosticsView> {

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Diagnostic Codes'),
      ),
      child: Consumer2<DiagnosticsViewModel, OBDConnectionManager>(
        builder: (context, vm, mgr, _) {
          final topContentPadding = 64.0;
          // 1) Waiting for first data
          if (vm.codes == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: CupertinoActivityIndicator(radius: 18),
                  ),
                  const SizedBox(height: 16),
                  const Text('Waiting for data…',
                      style: TextStyle(color: CupertinoColors.secondaryLabel)),
                  if (mgr.connectionState != OBDConnectionState.connected)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Connect to a vehicle in Settings.',
                        style: TextStyle(
                            color: CupertinoColors.secondaryLabel.resolveFrom(context), fontSize: 12),
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
                  Icon(CupertinoIcons.check_mark_circled_solid,
                      size: 64, color: CupertinoColors.activeGreen),
                  SizedBox(height: 16),
                  Text('No Trouble Codes Found',
                      style: TextStyle(fontSize: 18)),
                  SizedBox(height: 4),
                  Text('All systems normal.',
                      style: TextStyle(color: CupertinoColors.secondaryLabel)),
                ],
              ),
            );
          }

          // 3) Sections by severity
          return ListView.builder(
            padding: EdgeInsets.fromLTRB(12, topContentPadding, 12, 12),
            itemCount: vm.sections.length,
            itemBuilder: (context, index) {
              final section = vm.sections[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(severity: section.severity),
                  CupertinoListSection.insetGrouped(
                    children: [
                      for (int i = 0; i < section.items.length; i++)
                        _DtcRow(dtc: section.items[i]),
                    ],
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
      padding: const EdgeInsets.only(left: 8, bottom: 0, top: 0),
      child: Text(
        severity,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.systemGrey,
        ),
      ),
    );
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
    return CupertinoListTile(
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
      trailing: const Icon(CupertinoIcons.chevron_forward, color: CupertinoColors.secondaryLabel),
      onTap: () => Navigator.push(
        context,
        CupertinoPageRoute(builder: (_) => _DtcDetailView(dtc: dtc)),
      ),
    );
  }

  Widget _severityIcon(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return const Icon(CupertinoIcons.xmark_circle, color: CupertinoColors.destructiveRed);
      case 'high':
        return const Icon(CupertinoIcons.exclamationmark_triangle, color: CupertinoColors.systemOrange);
      case 'moderate':
        return const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: CupertinoColors.systemYellow);
      case 'low':
      default:
        return const Icon(CupertinoIcons.info_circle, color: CupertinoColors.activeBlue);
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
    final topContentPadding = 64.0;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(dtc.code as String? ?? ''),
      ),
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, topContentPadding, 16, 16),
        children: [
          // Overview
          _sectionHeader(context, 'Overview'),
          CupertinoListSection.insetGrouped(
            children: [
              _labeledRow('Code', dtc.code as String? ?? ''),
              _labeledRow('Title', dtc.title as String? ?? ''),
              _labeledRow('Severity', dtc.severity?.toString() ?? ''),
            ],
          ),
          const SizedBox(height: 16),

          // Description
          _sectionHeader(context, 'Description'),
          CupertinoListSection.insetGrouped(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(dtc.description as String? ?? ''),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Causes
          if (causes.isNotEmpty) ...[
            _sectionHeader(context, 'Potential Causes'),
            CupertinoListSection.insetGrouped(
              children: [
                for (int i = 0; i < causes.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('• ${causes[i]}'),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Remedies
          if (remedies.isNotEmpty) ...[
            _sectionHeader(context, 'Possible Remedies'),
            CupertinoListSection.insetGrouped(
              children: [
                for (int i = 0; i < remedies.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('• ${remedies[i]}'),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 0, top: 0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.systemGrey,
        ),
      ),
    );
  }

  Widget _labeledRow(String label, String value) {
    return CupertinoListTile(
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(color: CupertinoColors.secondaryLabel),
            ),
          ),
          const Text(' - ', style: TextStyle(color: CupertinoColors.secondaryLabel)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
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
