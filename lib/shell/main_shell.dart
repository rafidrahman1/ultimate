import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:motohealth/core/theme/app_theme.dart';
import 'package:motohealth/features/costs/costs_screen.dart';
import 'package:motohealth/features/costs/expense_form.dart';
import 'package:motohealth/features/dashboard/dashboard_screen.dart';
import 'package:motohealth/features/dashboard/odometer_form.dart';
import 'package:motohealth/features/fuel/fuel_form.dart';
import 'package:motohealth/features/fuel/fuel_screen.dart';
import 'package:motohealth/features/garage/bike_form.dart';
import 'package:motohealth/features/garage/garage_screen.dart';
import 'package:motohealth/features/garage/moto_models.dart';
import 'package:motohealth/features/garage/moto_store.dart';
import 'package:motohealth/features/papers/paper_form.dart';
import 'package:motohealth/features/papers/papers_screen.dart';
import 'package:motohealth/features/reminders/reminder_service.dart';
import 'package:motohealth/features/service/service_form.dart';
import 'package:motohealth/features/service/service_screen.dart';
import 'package:motohealth/shared/widgets/status_message.dart';

/// Five tabs for the selected bike: Home, Fuel, Service, Costs, Papers.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    ReminderService.requestPermission();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(motoStoreProvider);
    ref.listen(motoStoreProvider, (_, next) {
      final data = next.valueOrNull;
      if (data != null) ReminderService.sync(data);
    });

    final data = async.valueOrNull;
    if (data == null) {
      return Scaffold(
        body: Center(
          child: async.hasError
              ? const Text('Could not load your data.')
              : const CircularProgressIndicator(),
        ),
      );
    }
    final bike = data.selectedBike;
    if (bike == null) return const _Welcome();

    final screens = <Widget>[
      DashboardScreen(bike: bike, goTo: (i) => setState(() => _tab = i)),
      FuelScreen(bike: bike),
      ServiceScreen(bike: bike),
      CostsScreen(bike: bike),
      PapersScreen(bike: bike),
    ];

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.card),
          onTap: () => _openGarage(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(bike.name, overflow: TextOverflow.ellipsis),
                ),
                const Icon(Icons.arrow_drop_down_rounded),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Garage & settings',
            icon: const Icon(Icons.garage_outlined),
            onPressed: () => _openGarage(context),
          ),
        ],
      ),
      body: IndexedStack(index: _tab, children: screens),
      floatingActionButton: _fab(context, bike),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.speed_outlined),
            selectedIcon: Icon(Icons.speed_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_gas_station_outlined),
            selectedIcon: Icon(Icons.local_gas_station_rounded),
            label: 'Fuel',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_outlined),
            selectedIcon: Icon(Icons.build_rounded),
            label: 'Service',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments_rounded),
            label: 'Costs',
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description_rounded),
            label: 'Papers',
          ),
        ],
      ),
    );
  }

  Widget _fab(BuildContext context, Bike bike) {
    final (label, icon, onTap) = switch (_tab) {
      1 => (
        'Fill-up',
        Icons.add_rounded,
        () => showFuelForm(context, bike: bike),
      ),
      2 => (
        'Service',
        Icons.add_rounded,
        () => showServiceForm(context, bike: bike),
      ),
      3 => (
        'Expense',
        Icons.add_rounded,
        () => showExpenseForm(context, bike: bike),
      ),
      4 => (
        'Document',
        Icons.add_rounded,
        () => showPaperForm(context, bike: bike),
      ),
      _ => (
        'Odometer',
        Icons.speed_rounded,
        () => showOdometerForm(context, bike: bike),
      ),
    };
    return FloatingActionButton.extended(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
    );
  }

  void _openGarage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const GarageScreen()),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StatusMessage(
          icon: Icons.two_wheeler_rounded,
          title: 'Welcome to MotoHealth',
          subtitle:
              'Track fuel, mileage, servicing, costs and papers for your '
              'motorcycle. Start by adding your bike.',
          action: FilledButton.icon(
            onPressed: () => showBikeForm(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add my bike'),
          ),
        ),
      ),
    );
  }
}
