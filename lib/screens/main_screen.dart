import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import 'dashboard_screen.dart';
import 'workout_screen.dart';
import 'history_screen.dart';
import 'library_screen.dart';
import 'progress_screen.dart';
import 'recovery_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    WorkoutScreen(),
    HistoryScreen(),
    LibraryScreen(),
    ProgressScreen(),
    RecoveryScreen(),
    SettingsScreen(),
  ];

  final List<String> _titles = const [
    'Dashboard',
    'Today\'s Workout',
    'History',
    'Library',
    'Progress',
    'Recovery',
    'Settings',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        actions: [
          // Resume workout button (if saved)
          Consumer<DataProvider>(
            builder: (context, dataProvider, child) {
              if (dataProvider.savedWorkout != null &&
                  (dataProvider.currentWorkout == null ||
                      dataProvider.currentWorkout!.id != dataProvider.savedWorkout!.id)) {
                return IconButton(
                  icon: const Icon(Icons.play_circle_filled),
                  onPressed: () {
                    // Resume workout
                    dataProvider.currentWorkout = dataProvider.savedWorkout;
                    setState(() => _currentIndex = 1);
                  },
                  tooltip: 'Resume Workout',
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.fitness_center), label: 'Workout'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.library_books), label: 'Library'),
          NavigationDestination(icon: Icon(Icons.show_chart), label: 'Progress'),
          NavigationDestination(icon: Icon(Icons.favorite), label: 'Recovery'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}