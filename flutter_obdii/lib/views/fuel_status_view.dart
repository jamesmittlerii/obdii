// Port of FuelStatusView.swift — Jim Mittler
// Displays fuel system status for Bank 1 and Bank 2.
// Shows waiting state while loading, empty state if no data.

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../viewmodels/fuel_status_viewmodel.dart';

class FuelStatusView extends StatefulWidget {
  const FuelStatusView({super.key});

  @override
  State<FuelStatusView> createState() => _FuelStatusViewState();
}

class _FuelStatusViewState extends State<FuelStatusView> {

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Fuel Control Status'),
      ),
      child: Consumer<FuelStatusViewModel>(
        builder: (context, vm, _) {
          // Waiting state
          if (vm.status == null) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CupertinoActivityIndicator(radius: 10),
                        SizedBox(width: 12),
                        Text(
                          'Waiting for data…',
                          style: TextStyle(color: CupertinoColors.secondaryLabel),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          // Loaded: show Bank 1 / Bank 2 (or empty message)
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
            children: [
              CupertinoListSection.insetGrouped(
                children: [
                  if (vm.bank1 != null)
                    _FuelRow(title: 'Bank 1', description: vm.bank1!.description),
                  if (vm.bank2 != null)
                    _FuelRow(title: 'Bank 2', description: vm.bank2!.description),
                  if (!vm.hasAnyStatus)
                    const CupertinoListTile(
                      leading: Icon(CupertinoIcons.info_circle, color: CupertinoColors.secondaryLabel),
                      title: Text(
                        'No Fuel System Status Codes',
                        style: TextStyle(color: CupertinoColors.secondaryLabel),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FuelRow extends StatelessWidget {
  final String title;
  final String description;

  const _FuelRow({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return CupertinoListTile(
      leading: const Icon(CupertinoIcons.drop_fill, color: CupertinoColors.activeBlue),
      title: Text(title),
      trailing: Text(
        description,
        style: const TextStyle(color: CupertinoColors.secondaryLabel),
      ),
    );
  }
}
