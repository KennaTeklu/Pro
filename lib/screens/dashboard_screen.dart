import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/data_provider.dart';
import '../utils/helpers.dart';
import '../services/theme_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DataProvider>(
      builder: (context, dataProvider, child) {
        final user = dataProvider.user;
        final workouts = dataProvider.workouts;
        final currentWorkout = dataProvider.currentWorkout;
        final streak = dataProvider.calculateStreak(); // We need to expose this

        // Stats
        final totalWorkouts = workouts.length;
        final totalVolume = workouts.fold<double>(
          0,
          (sum, w) => sum + (w.summary?.totalVolume ?? 0),
        );
        final progress = _calculateOverallStrengthProgress(dataProvider);
        final longevityScore = _calculateLongevityScore(dataProvider);

        return Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User welcome card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor,
                          child: Text(
                            user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name.isNotEmpty ? user.name : 'User',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '🔥 $streak day${streak == 1 ? '' : 's'}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      user.experience.capitalize(),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Today's workout card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Today\'s Workout',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        if (currentWorkout != null)
                          Column(
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.fitness_center, color: Colors.blue),
                                title: Text(currentWorkout.name),
                                subtitle: Text('${currentWorkout.exercises.length} exercises'),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    // Navigate to workout screen
                                    // We need a way to switch tabs; maybe using a global key or provider
                                  },
                                  child: const Text('Start Workout'),
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              const Text('No workout scheduled.'),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    dataProvider.generateNextWorkout();
                                  },
                                  child: const Text('Generate Workout'),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Stats cards grid
                const Text(
                  'Statistics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.2,
                  children: [
                    _buildStatCard('Workouts', totalWorkouts.toString()),
                    _buildStatCard('Streak', streak.toString()),
                    _buildStatCard('Volume', formatNumber(totalVolume)),
                    _buildStatCard('Progress', '$progress%'),
                    _buildStatCard('Longevity', longevityScore.toString()),
                    _buildStatCard('Next', _getNextWorkoutDate(dataProvider)),
                  ],
                ),
                const SizedBox(height: 16),

                // Progress chart
                const Text(
                  'Progress Overview',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      height: 200,
                      child: _buildVolumeChart(dataProvider),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeChart(DataProvider dataProvider) {
    final workouts = dataProvider.workouts;
    if (workouts.isEmpty) {
      return const Center(child: Text('No data yet'));
    }

    // Take last 7 workouts
    final recent = workouts.reversed.take(7).toList().reversed.toList();
    final spots = <FlSpot>[];
    for (int i = 0; i < recent.length; i++) {
      spots.add(FlSpot(i.toDouble(), recent[i].summary?.totalVolume ?? 0));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < recent.length) {
                  return Text(
                    DateFormat('MM/dd').format(recent[value.toInt()].date),
                    style: const TextStyle(fontSize: 10),
                  );
                }
                return const Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withOpacity(0.1),
            ),
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }

  int _calculateOverallStrengthProgress(DataProvider dataProvider) {
    // Simplified version – use the one from helpers or data service
    // For now return a dummy
    return 0;
  }

  int _calculateLongevityScore(DataProvider dataProvider) {
    // Placeholder – we'll implement later
    return 0;
  }

  String _getNextWorkoutDate(DataProvider dataProvider) {
    if (dataProvider.workouts.isEmpty) return 'N/A';
    final last = dataProvider.workouts.last;
    final rest = last.recommendedRest ?? 2;
    final next = last.date.add(Duration(days: rest.round()));
    return DateFormat('MM/dd').format(next);
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}