import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:motohealth/core/theme/app_theme.dart';
import 'package:motohealth/features/ai/analyze_screen.dart';
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
import 'package:motohealth/shared/widgets/glass_nav_bar.dart';
import 'package:motohealth/shared/widgets/status_message.dart';

/// Five tabs for the selected bike: Home, Fuel, Service, Costs, Papers.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  static const _slide = Duration(milliseconds: 380);

  final _pages = PageController();
  final _position = ValueNotifier<double>(0);
  int _tab = 0;

  void _goTo(int i) {
    if (i == _tab && !_pages.hasClients) return;
    _pages.animateToPage(i, duration: _slide, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _pages.dispose();
    _position.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    ReminderService.requestPermission();
    _pages.addListener(() {
      final page = _pages.page;
      if (page != null) _position.value = page;
    });
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
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Could not load your data.'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => ref.invalidate(motoStoreProvider),
                      child: const Text('Try again'),
                    ),
                  ],
                )
              : const CircularProgressIndicator(),
        ),
      );
    }
    final bike = data.selectedBike;
    if (bike == null) return const _Welcome();

    final screens = <Widget>[
      for (final w in [
        DashboardScreen(bike: bike, goTo: _goTo),
        FuelScreen(bike: bike),
        ServiceScreen(bike: bike),
        CostsScreen(bike: bike),
        PapersScreen(bike: bike),
      ])
        _KeepAlive(child: w),
    ];

    return Scaffold(
      extendBody: true,
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
            tooltip: 'AI analysis',
            icon: const Icon(Icons.auto_awesome_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => AnalyzeScreen(bike: bike),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Garage & settings',
            icon: const Icon(Icons.garage_outlined),
            onPressed: () => _openGarage(context),
          ),
        ],
      ),
      body: PageView(
        controller: _pages,
        onPageChanged: (i) => setState(() => _tab = i),
        children: screens,
      ),
      floatingActionButton: _fab(context, bike),
      bottomNavigationBar: GlassNavBar(
        position: _position,
        onSelected: _goTo,
        items: const [
          GlassNavItem(
            icon: Icons.speed_outlined,
            selectedIcon: Icons.speed_rounded,
            label: 'Home',
          ),
          GlassNavItem(
            icon: Icons.local_gas_station_outlined,
            selectedIcon: Icons.local_gas_station_rounded,
            label: 'Fuel',
          ),
          GlassNavItem(
            icon: Icons.build_outlined,
            selectedIcon: Icons.build_rounded,
            label: 'Service',
          ),
          GlassNavItem(
            icon: Icons.payments_outlined,
            selectedIcon: Icons.payments_rounded,
            label: 'Costs',
          ),
          GlassNavItem(
            icon: Icons.description_outlined,
            selectedIcon: Icons.description_rounded,
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
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOutBack,
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: animation,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: FloatingActionButton.extended(
        key: ValueKey(_tab),
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
      ),
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

/// Keeps a tab's scroll position while it is paged out of view.
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
