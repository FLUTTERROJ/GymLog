import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/profile_service.dart';
import 'history/history_screen.dart';
import 'home/home_screen.dart';
import 'trainer/trainees_screen.dart';

/// Bottom-nav container. Trainees get Today + History; trainers get Trainees.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final isTrainer = context.watch<ProfileService>().profile?.isTrainer ?? false;

    if (isTrainer) {
      return const TraineesScreen();
    }

    return Scaffold(
      // IndexedStack keeps each tab's scroll position while switching.
      body: IndexedStack(
        index: _index,
        children: const [HomeScreen(), HistoryScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }
}
