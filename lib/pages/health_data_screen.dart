import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/health_service.dart';

class HealthDataScreen extends ConsumerWidget {
  const HealthDataScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(healthAuthorizationProvider);
    final dataAsync = ref.watch(healthDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Data'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.refresh(healthDataProvider))],
      ),
      body: authAsync.when(
        data: (isAuthorized) {
          if (!isAuthorized) {
            return _buildNoPermissionView(context);
          }
          return dataAsync.when(
            data: (data) => data.isEmpty
                ? const Center(child: Text('No health data found for the last 24 hours.'))
                : ListView.builder(
                    itemCount: data.length,
                    itemBuilder: (context, index) {
                      final p = data[index];
                      return ListTile(leading: _getIconForType(p.typeString), title: Text('${p.typeString}: ${p.value}'), subtitle: Text(p.dateFrom.toString().split('.')[0]));
                    },
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Auth Error: $err')),
      ),
    );
  }

  Widget _buildNoPermissionView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Health permissions are required to view data.'),
          const SizedBox(height: 24),
          const Text('Please configure sharing in Health Settings.'),
        ],
      ),
    );
  }

  Widget _getIconForType(String type) {
    if (type.contains('STEPS')) return const Icon(Icons.directions_walk, color: Colors.blue);
    if (type.contains('HEART_RATE')) return const Icon(Icons.favorite, color: Colors.red);
    if (type.contains('SLEEP')) return const Icon(Icons.bedtime, color: Colors.indigo);
    return const Icon(Icons.health_and_safety);
  }
}
