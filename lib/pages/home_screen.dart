import 'package:flutter/material.dart';

import '../components/square_button.dart';
import '../components/app_drawer.dart';
import 'health_data_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flutter Demo Home Page')),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(16),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                SquareActionButton(
                  label: 'Health Data',
                  icon: Icons.health_and_safety,
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const HealthDataScreen()));
                  },
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red,
                ),
                SquareActionButton(
                  label: 'Expenses Data',
                  icon: Icons.currency_bitcoin,
                  onPressed: () {},
                  backgroundColor: Colors.green.shade50,
                  foregroundColor: Colors.green,
                ),
                SquareActionButton(
                  label: 'Location Data',
                  icon: Icons.location_history,
                  onPressed: () {},
                  backgroundColor: Colors.orange.shade50,
                  foregroundColor: Colors.orange,
                ),
                SquareActionButton(label: 'Chat History', icon: Icons.chat, onPressed: () {}, backgroundColor: Colors.blue.shade50, foregroundColor: Colors.blue),
                SquareActionButton(label: 'Prompt', icon: Icons.book, onPressed: () {}, backgroundColor: Colors.deepPurple.shade50, foregroundColor: Colors.deepPurple),
                SquareActionButton(label: 'Result', icon: Icons.download_done, onPressed: () {}, backgroundColor: Colors.teal.shade50, foregroundColor: Colors.teal),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            child: SizedBox(
              width: double.infinity,
              height: 150,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade900,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Analyze Data'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
