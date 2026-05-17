import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/health_service.dart';

class HealthSettingsScreen extends ConsumerWidget {
  const HealthSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(healthAuthorizationProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Health Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAuthorizationSection(authAsync, ref),
          const Divider(height: 40),
          _buildSyncInstructionsSection(),
          const Divider(height: 40),
          _buildDataTypesSection(),
        ],
      ),
    );
  }

  Widget _buildAuthorizationSection(AsyncValue<bool> authAsync, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Authorization Status', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        authAsync.when(
          data: (isAuthorized) => Card(
            elevation: 0,
            color: isAuthorized ? Colors.green.shade50 : Colors.orange.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: isAuthorized ? Colors.green.shade200 : Colors.orange.shade200),
            ),
            child: ListTile(
              leading: Icon(isAuthorized ? Icons.check_circle : Icons.warning_amber_rounded, color: isAuthorized ? Colors.green : Colors.orange, size: 32),
              title: Text(
                isAuthorized ? 'App is Authorized' : 'Authorization Required',
                style: TextStyle(fontWeight: FontWeight.bold, color: isAuthorized ? Colors.green.shade900 : Colors.orange.shade900),
              ),
              subtitle: Text(
                isAuthorized ? 'Connected to Health Connect' : 'Grant permissions to access Samsung Health data',
                style: TextStyle(color: isAuthorized ? Colors.green.shade700 : Colors.orange.shade700),
              ),
              trailing: isAuthorized
                  ? null
                  : ElevatedButton(
                      onPressed: () => ref.invalidate(healthAuthorizationProvider),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                      child: const Text('Authorize'),
                    ),
            ),
          ),
          loading: () => const Center(
            child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()),
          ),
          error: (err, _) => Center(
            child: Text('Error checking authorization: $err', style: const TextStyle(color: Colors.red)),
          ),
        ),
      ],
    );
  }

  Widget _buildSyncInstructionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Samsung Health Sync', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        const Text('To see data from Samsung Health, you must enable the sync in the Samsung Health app settings.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 16),
        _buildStepItem('1', 'Open the Samsung Health app.'),
        _buildStepItem('2', 'Go to Settings > Health Connect.'),
        _buildStepItem('3', 'Select this app and toggle "Allow all" or choose specific data types.'),
      ],
    );
  }

  Widget _buildStepItem(String stepNumber, String instruction) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.blue.shade900, shape: BoxShape.circle),
            child: Text(
              stepNumber,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(instruction, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  Widget _buildDataTypesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Monitored Data Types', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _buildDataTypeTile(Icons.directions_walk, 'Steps', 'Activity tracking'),
        _buildDataTypeTile(Icons.favorite, 'Heart Rate', 'Vitals monitoring'),
        _buildDataTypeTile(Icons.bedtime, 'Sleep', 'Rest analysis'),
      ],
    );
  }

  Widget _buildDataTypeTile(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue.shade900),
      title: Text(title),
      subtitle: Text(subtitle),
      contentPadding: EdgeInsets.zero,
    );
  }
}
