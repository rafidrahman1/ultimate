import 'package:flutter/material.dart';

import '../pages/health_settings_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: Colors.blue.shade900),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 40, color: Colors.blue),
            ),
            accountName: const Text('User Name', style: TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: const Text('user@example.com'),
          ),
          ListTile(
            leading: const Icon(Icons.health_and_safety),
            title: const Text('Health Settings'),
            subtitle: const Text('Sync & permissions'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const HealthSettingsScreen()));
            },
          ),
          ListTile(leading: const Icon(Icons.currency_bitcoin), title: const Text('Expenses Settings'), onTap: () => Navigator.pop(context)),
          ListTile(leading: const Icon(Icons.location_history), title: const Text('Location Settings'), onTap: () => Navigator.pop(context)),
          ListTile(leading: const Icon(Icons.chat), title: const Text('Chat History Settings'), onTap: () => Navigator.pop(context)),
          const Divider(),
          ListTile(leading: const Icon(Icons.settings), title: const Text('General Settings'), onTap: () => Navigator.pop(context)),
          ListTile(leading: const Icon(Icons.info_outline), title: const Text('About'), onTap: () => Navigator.pop(context)),
          const Divider(),
          ListTile(leading: const Icon(Icons.logout), title: const Text('Logout'), onTap: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}
