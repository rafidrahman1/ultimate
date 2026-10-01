import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:personal/features/dashboard/dashboard_layout_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('normalize drops unknown ids and appends missing cards', () {
    expect(
      normalizeDashboardCardOrder(['gaming', 'bogus', 'health', 'gaming']),
      [
        DashboardCardId.gaming,
        DashboardCardId.health,
        DashboardCardId.stableMonth,
        DashboardCardId.financial,
        DashboardCardId.mobility,
        DashboardCardId.calendar,
      ],
    );
  });

  test('reordering visible cards keeps hidden cards in their slots', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(dashboardCardOrderProvider);

    // Financial and gaming have no data, so they are hidden.
    const visible = [
      DashboardCardId.stableMonth,
      DashboardCardId.health,
      DashboardCardId.mobility,
      DashboardCardId.calendar,
    ];
    // Drag calendar (index 3) to the top.
    await container
        .read(dashboardCardOrderProvider.notifier)
        .reorderVisible(visible: visible, oldIndex: 3, newIndex: 0);

    expect(container.read(dashboardCardOrderProvider), [
      DashboardCardId.calendar,
      DashboardCardId.stableMonth,
      DashboardCardId.financial,
      DashboardCardId.health,
      DashboardCardId.gaming,
      DashboardCardId.mobility,
    ]);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('dashboard_card_order_v1')?.first, 'calendar');
  });
}
