import '../models/workout.dart';

int calculateAge(DateTime birthDate) {
  final today = DateTime.now();
  int age = today.year - birthDate.year;
  if (today.month < birthDate.month ||
      (today.month == birthDate.month && today.day < birthDate.day)) {
    age--;
  }
  return age;
}

double estimate1RM(double weight, int reps) {
  if (weight <= 0) return 0;
  return weight * (1 + reps / 30);
}

double estimate1RMAdvanced(double weight, int reps) {
  if (weight <= 0) return 0;
  if (reps <= 10) {
    // Brzycki
    return weight * 36 / (37 - reps);
  } else {
    // Epley
    return weight * (1 + reps / 30);
  }
}

String formatNumber(double num) {
  if (num >= 1000000) {
    return '${(num / 1000000).toStringAsFixed(1)}M';
  } else if (num >= 1000) {
    return '${(num / 1000).toStringAsFixed(1)}K';
  }
  return num.toStringAsFixed(0);
}

double calculateTotalVolume(Workout workout) {
  double total = 0;
  for (var ex in workout.exercises) {
    if (ex.actual != null && !ex.skipped) {
      final a = ex.actual!;
      if (a.reps != null) {
        final totalReps = a.reps!.reduce((a, b) => a + b);
        total += a.weight * totalReps;
      } else if (a.durations != null) {
        total += a.durations!.reduce((a, b) => a + b);
      }
    }
  }
  return total;
}

double? calculateAverageRPE(Workout workout) {
  final rpes = workout.exercises
      .where((ex) => ex.actual != null && ex.actual!.rpe > 0)
      .map((ex) => ex.actual!.rpe)
      .toList();
  if (rpes.isEmpty) return null;
  return rpes.reduce((a, b) => a + b) / rpes.length;
}

int calculateRecommendedRestDays(Workout workout) {
  // Simplified version; can be expanded
  return 2;
}
