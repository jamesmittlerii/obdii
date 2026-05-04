// Port of FuelStatusView.swift — Jim Mittler
// Displays fuel system status for Bank 1 and Bank 2.
// Shows waiting state while loading, empty state if no data.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/fuel_status_viewmodel.dart';

class FuelStatusView extends StatefulWidget {
  final bool isActive;

  const FuelStatusView({super.key, this.isActive = true});

  @override
  State<FuelStatusView> createState() => _FuelStatusViewState();
}

class _FuelStatusViewState extends State<FuelStatusView> {
  void _syncVisibility() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FuelStatusViewModel>().setVisible(widget.isActive);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncVisibility();
  }

  @override
  void didUpdateWidget(covariant FuelStatusView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _syncVisibility();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<FuelStatusViewModel>(
        builder: (context, vm, _) {
          // Waiting state
          if (vm.status == null) {
            return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              children: [
                Card(
                  child: ListTile(
                    leading: const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    title: const Text(
                      'Waiting for data…',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              ],
            );
          }

          // Loaded: show Bank 1 / Bank 2 (or empty message)
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              Card(
                child: Column(
                  children: [
                    if (vm.bank1 != null) ...[
                      _FuelRow(title: 'Bank 1', description: vm.bank1!.description),
                    ],
                    if (vm.bank1 != null && vm.bank2 != null)
                      const Divider(height: 1),
                    if (vm.bank2 != null) ...[
                      _FuelRow(title: 'Bank 2', description: vm.bank2!.description),
                    ],
                    if (!vm.hasAnyStatus)
                      const ListTile(
                        leading: Icon(Icons.info_outline, color: Colors.grey),
                        title: Text(
                          'No Fuel System Status Codes',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                  ],
                ),
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
    return ListTile(
      leading: const Icon(Icons.local_gas_station, color: Colors.blue),
      title: Text(title),
      trailing: Text(
        description,
        style: const TextStyle(color: Colors.grey),
      ),
    );
  }
}
