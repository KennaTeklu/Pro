import 'dart:math';
import '../models/user.dart';
import '../models/workout.dart';
import '../models/muscle.dart';
import '../models/exercise_library.dart';
import '../utils/helpers.dart';
import 'local_storage.dart';

class DataService {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  User user = User();
  List<Workout> workouts = [];
  Map<String, dynamic> exercises = {}; // exerciseId -> exercise data (history, best, etc.)
  Workout? currentWorkout;
  Workout? savedWorkout;

  // Muscle last trained cache
  final Map<String, DateTime?> _muscleLastTrained = {};

  // Prescription anchor curves
  static const List<Map<String, double>> beginnerRepPoints = [
    {'intensity': 0.4, 'reps': 18},
    {'intensity': 0.6, 'reps': 15},
    {'intensity': 0.7, 'reps': 12},
    {'intensity': 0.8, 'reps': 10},
    {'intensity': 0.9, 'reps': 8},
    {'intensity': 0.95, 'reps': 6},
  ];

  static const List<Map<String, double>> beginnerSetPoints = [
    {'intensity': 0.4, 'sets': 3},
    {'intensity': 0.6, 'sets': 3},
    {'intensity': 0.7, 'sets': 3},
    {'intensity': 0.8, 'sets': 4},
    {'intensity': 0.9, 'sets': 4},
    {'intensity': 0.95, 'sets': 3},
  ];

  static const List<Map<String, double>> advancedRepPoints = [
    {'intensity': 0.4, 'reps': 12},
    {'intensity': 0.6, 'reps': 8},
    {'intensity': 0.7, 'reps': 5},
    {'intensity': 0.8, 'reps': 3},
    {'intensity': 0.9, 'reps': 2},
    {'intensity': 0.95, 'reps': 1},
  ];

  static const List<Map<String, double>> advancedSetPoints = [
    {'intensity': 0.4, 'sets': 3},
    {'intensity': 0.6, 'sets': 4},
    {'intensity': 0.7, 'sets': 5},
    {'intensity': 0.8, 'sets': 6},
    {'intensity': 0.9, 'sets': 7},
    {'intensity': 0.95, 'sets': 6},
  ];

  double _interpolate(List<Map<String, double>> points, double x, String key) {
    if (x <= points.first['intensity']!) return points.first[key]!;
    if (x >= points.last['intensity']!) return points.last[key]!;
    for (int i = 0; i < points.length - 1; i++) {
      if (x >= points[i]['intensity']! && x <= points[i + 1]['intensity']!) {
        final t = (x - points[i]['intensity']!) / (points[i + 1]['intensity']! - points[i]['intensity']!);
        return points[i][key]! + t * (points[i + 1][key]! - points[i][key]!);
      }
    }
    return points.first[key]!;
  }

  void initFromStorage() {
    final loaded = LocalStorage.loadData();
    if (loaded != null) {
      user = loaded.user;
      workouts = loaded.workouts;
      exercises = loaded.exercises;
    }
    _updateMuscleLastTrained();
    _loadSavedWorkoutFromStorage();
  }

  Future<void> save() async {
    await LocalStorage.saveData(user: user, workouts: workouts, exercises: exercises);
  }

  void _updateMuscleLastTrained() {
    _muscleLastTrained.clear();
    for (var muscle in MuscleDatabase.all) {
      _muscleLastTrained[muscle.name] = null;
    }
    for (var workout in workouts.reversed) {
      for (var ex in workout.exercises) {
        if (ex.actual != null && !ex.skipped) {
          for (var muscle in ex.muscleGroup) {
            if (_muscleLastTrained.containsKey(muscle) && _muscleLastTrained[muscle] == null) {
              _muscleLastTrained[muscle] = workout.date;
            }
          }
        }
      }
    }
  }

  DateTime? lastTrained(String muscle) => _muscleLastTrained[muscle];

  int daysSinceTrained(String muscle, {DateTime? asOfDate}) {
    final last = _muscleLastTrained[muscle];
    if (last == null) return 999999;
    final ref = asOfDate ?? DateTime.now();
    final diff = ref.difference(last).inDays;
    return diff < 0 ? 0 : diff;
  }

  double calculateSystemicRecoveryFactor() {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final recentWorkouts = workouts.where((w) => w.date.isAfter(sevenDaysAgo)).toList();
    if (recentWorkouts.isEmpty) return 1.0;

    double totalVolume = 0;
    int totalSets = 0;
    double rpeSum = 0;
    int rpeCount = 0;
    for (var w in recentWorkouts) {
      for (var ex in w.exercises) {
        if (ex.actual != null && !ex.skipped) {
          final a = ex.actual!;
          if (a.reps != null) {
            final totalReps = a.reps!.reduce((a, b) => a + b);
            totalVolume += a.weight * totalReps;
          } else if (a.durations != null) {
            totalVolume += a.durations!.reduce((a, b) => a + b);
          }
          totalSets += a.sets;
          if (a.rpe > 0) {
            rpeSum += a.rpe;
            rpeCount++;
          }
        }
      }
    }

    final userWeight = user.weight ?? 150;
    final relativeVolume = totalVolume / userWeight;
    final avgRPE = rpeCount > 0 ? rpeSum / rpeCount : 5.0;

    final fatigueFromFreq = (recentWorkouts.length * 10).clamp(0, 50).toDouble();
    final fatigueFromVolume = (relativeVolume / 500 * 30).clamp(0, 30);
    final fatigueFromRPE = ((avgRPE - 5) * 4).clamp(0, 20);
    final totalFatigue = fatigueFromFreq + fatigueFromVolume + fatigueFromRPE;
    final factor = 1.0 - (totalFatigue / 200);
    return factor.clamp(0.5, 1.0);
  }

  double _getPhaseMultiplier() {
    if (user.gender != 'female' || user.menstrual?.lastPeriodStart == null) return 1.0;
    final last = user.menstrual!.lastPeriodStart!;
    final today = DateTime.now();
    final daysSince = today.difference(last).inDays % user.menstrual!.cycleLength;
    if (daysSince < 5) return 0.6; // menstrual
    if (daysSince < 14) return 1.0; // follicular
    if (daysSince < 18) return 1.05; // ovulatory
    return 0.8; // luteal
  }

  String _generateCues(ExerciseDefinition def, List<Map<String, dynamic>> history) {
    if (history.isEmpty) return '';
    final last = history.last;
    if (last.containsKey('notes') && last['notes'].toString().toLowerCase().contains('form')) {
      return 'Last time you mentioned: "${last['notes']}"';
    }
    final name = def.name.toLowerCase();
    if (name.contains('squat')) return 'Keep chest up and knees tracking over toes.';
    if (name.contains('deadlift')) return 'Pull the slack out of the bar before lifting.';
    if (name.contains('bench')) return 'Drive through your heels and keep shoulders packed.';
    return '';
  }

  Exercise generateExercisePrescription(ExerciseDefinition def, {double phaseMultiplier = 1.0}) {
    final exId = def.name.toLowerCase().replaceAll(' ', '_');
    final exData = exercises[exId] as Map<String, dynamic>? ?? {};
    final history = (exData['history'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final lastSession = history.isNotEmpty ? history.last : null;
    final bestWeight = exData['bestWeight'] as double?;

    // Training maturity
    final totalWorkouts = workouts.length;
    final maturity = 1 - exp(-totalWorkouts / 100); // saturates after ~300 workouts

    // Progression rate
    double baseProgression = user.settings.progressionRate;
    double skillFactor = def.skillFactor;
    double progressionRate = baseProgression * (0.5 + 0.5 * maturity) * skillFactor;
    if (exData.containsKey('progression')) {
      progressionRate = (exData['progression'] as num?)?.toDouble() ?? progressionRate;
    }

    // RPE adjustment
    if (lastSession != null && lastSession.containsKey('rpe')) {
      final lastRPE = lastSession['rpe'] as int;
      if (lastRPE <= 7) progressionRate *= 1.5;
      else if (lastRPE >= 9) progressionRate *= 0.5;
    }

    // Trend analysis (simplified)
    double? trendWeight;
    if (history.length >= 3) {
      final recent = history.sublist(history.length - 3);
      final weights = recent.map((e) => (e['weight'] as num).toDouble()).toList();
      // linear regression slope
      final n = 3;
      final sumX = 0 + 1 + 2; // indices 0,1,2
      final sumY = weights.reduce((a, b) => a + b);
      final sumXY = weights.asMap().entries.map((e) => e.key * e.value).reduce((a, b) => a + b);
      final sumX2 = 0*0 + 1*1 + 2*2;
      final b = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
      final a = (sumY - b * sumX) / n;
      trendWeight = a + b * 3;
      trendWeight = trendWeight.clamp(weights.last * 0.8, weights.last * 1.2);
    }

    // Base weight (using strengthIndex)
    double baseWeight;
    if (bestWeight != null && bestWeight > 0) {
      baseWeight = trendWeight ?? bestWeight;
    } else {
      double userWeight = user.weight ?? 150;
      double strengthIndex = def.strengthIndex;
      if (user.birthDate != null) {
        final age = calculateAge(user.birthDate!);
        if (age > 60) strengthIndex *= 0.7;
        else if (age > 50) strengthIndex *= 0.8;
        else if (age > 40) strengthIndex *= 0.9;
      }
      final estimated1RM = userWeight * strengthIndex;
      baseWeight = (estimated1RM * 0.6 / 5).round() * 5.0; // start at 60% of estimated 1RM
    }

    // Recovery factor
    double recoveryFactor = 1.0;
    if (def.muscles.isNotEmpty) {
      final primaryMuscle = def.muscles.first;
      final daysSince = daysSinceTrained(primaryMuscle);
      final muscleDef = MuscleDatabase.byName(primaryMuscle);
      if (muscleDef != null) {
        final recoveryPercent = daysSince >= muscleDef.restDays
            ? 1.0
            : daysSince / muscleDef.restDays;
        // sigmoid for muscle specific
        const k = 6.0;
        final muscleSpecific = 1 / (1 + exp(k * (0.5 - recoveryPercent)));
        final systemic = calculateSystemicRecoveryFactor();
        recoveryFactor = 0.7 * muscleSpecific + 0.3 * systemic;
        recoveryFactor = recoveryFactor.clamp(0.5, 1.0);
      }
    }

    // Competition factor
    double compFactor = 1.0;
    if (user.competitionDate != null) {
      final meetDate = user.competitionDate!;
      final daysToMeet = meetDate.difference(DateTime.now()).inDays;
      if (daysToMeet >= 0) {
        if (daysToMeet <= 7) compFactor = 0.8;
        else if (daysToMeet <= 21) compFactor = 1.05;
      }
    }

    // Prescribed weight
    double prescribedWeight = baseWeight * (1 + progressionRate) * phaseMultiplier * recoveryFactor * compFactor;
    prescribedWeight = (prescribedWeight / 2.5).round() * 2.5;
    if (prescribedWeight < 5) prescribedWeight = 5;

    // Estimate 1RM and intensity
    double estimated1RM = prescribedWeight;
    if (lastSession != null && lastSession.containsKey('reps') && lastSession['reps'] is List) {
      final bestReps = (lastSession['reps'] as List).map((e) => e as int).reduce((a, b) => a > b ? a : b);
      estimated1RM = estimate1RM(lastSession['weight'].toDouble(), bestReps);
    } else if (bestWeight != null && exData.containsKey('bestReps')) {
      final bestReps = exData['bestReps'] as int;
      estimated1RM = estimate1RM(bestWeight, bestReps);
    } else {
      final userWeight = user.weight ?? 150;
      estimated1RM = userWeight * def.strengthIndex;
    }
    estimated1RM = estimated1RM.clamp(prescribedWeight, double.infinity);
    double intensity = prescribedWeight / estimated1RM;
    intensity = intensity.clamp(0.0, 0.95);

    // Prescription type
    final presType = def.prescriptionType;

    if (presType == 'time') {
      final defaultDuration = def.defaultDuration ?? 60;
      return Exercise(
        id: exId,
        name: def.name,
        muscleGroup: def.muscles,
        prescribed: Prescription(
          sets: def.defaultSets,
          reps: '',
          weight: prescribedWeight,
          duration: defaultDuration,
        ),
        progressionNotes: 'Time‑based: ${def.defaultSets} sets of ${defaultDuration}s holds.',
        equipment: def.equipment,
        instructions: def.instructions,
      );
    }

    // For reps and amrap
    final beginnerReps = _interpolate(beginnerRepPoints, intensity, 'reps');
    final beginnerSets = _interpolate(beginnerSetPoints, intensity, 'sets');
    final advancedReps = _interpolate(advancedRepPoints, intensity, 'reps');
    final advancedSets = _interpolate(advancedSetPoints, intensity, 'sets');

    double targetReps = (1 - maturity) * beginnerReps + maturity * advancedReps;
    double targetSets = (1 - maturity) * beginnerSets + maturity * advancedSets;

    // Goal adjustment
    double goalFactor = 1.0;
    if (user.goal == 'strength') goalFactor = 0.9;
    else if (user.goal == 'hypertrophy') goalFactor = 1.1;
    else if (user.goal == 'endurance') goalFactor = 1.2;
    targetReps *= goalFactor;

    int sets = targetSets.round().clamp(1, 10);
    int repsTarget = targetReps.round().clamp(1, 20);
    int rangeWidth = maturity < 0.5 ? 2 : 1;
    int repRangeLow = (repsTarget - rangeWidth).clamp(1, 20);
    int repRangeHigh = (repsTarget + rangeWidth).clamp(1, 20);
    String repsDisplay;
    if (presType == 'amrap') {
      repsDisplay = '$repRangeLow-$repRangeHigh (AMRAP)';
    } else {
      repsDisplay = '$repRangeLow-$repRangeHigh';
    }

    // Progression notes
    String zoneDesc;
    if (intensity < 0.65) zoneDesc = 'Hypertrophy/Endurance';
    else if (intensity < 0.8) zoneDesc = 'Strength';
    else zoneDesc = 'Peaking';
    String phase = maturity < 0.3 ? 'Beginner' : (maturity < 0.7 ? 'Intermediate' : 'Advanced');
    String cues = _generateCues(def, history);
    String progNotes = '$phase · $zoneDesc: $sets×$repsDisplay @ ${prescribedWeight.toStringAsFixed(0)} lbs. ${def.progression} $cues';

    return Exercise(
      id: exId,
      name: def.name,
      muscleGroup: def.muscles,
      prescribed: Prescription(
        sets: sets,
        reps: repsDisplay,
        weight: prescribedWeight,
      ),
      progressionNotes: progNotes,
      equipment: def.equipment,
      instructions: def.instructions,
    );
  }

  void generateNextWorkout() {
    final now = DateTime.now();
    final systemicFactor = calculateSystemicRecoveryFactor();
    final needsDeload = systemicFactor < 0.6;
    final compDate = user.competitionDate;
    bool isTapering = false;
    if (compDate != null) {
      final daysToMeet = compDate.difference(now).inDays;
      if (daysToMeet <= 7 && daysToMeet >= 0) isTapering = true;
    }

    // Split selection
    final splits = [
      {'id': 'full_body_a', 'name': 'Full Body A', 'focus': ['quads','chest','back','shoulders'], 'restAfter': 2},
      {'id': 'full_body_b', 'name': 'Full Body B', 'focus': ['hamstrings','back','chest','biceps'], 'restAfter': 2},
      {'id': 'longevity_day', 'name': 'Longevity & Joint Health', 'focus': ['neck','forearms','feet_ankles','rhomboids'], 'restAfter': 1},
      {'id': 'push_day', 'name': 'Push Day', 'focus': ['chest','shoulders','triceps'], 'restAfter': 3},
      {'id': 'pull_day', 'name': 'Pull Day', 'focus': ['back','biceps','rhomboids'], 'restAfter': 3},
    ];

    String? lastWorkoutId;
    if (workouts.isNotEmpty) {
      lastWorkoutId = workouts.last.type;
    }
    int lastIndex = splits.indexWhere((s) => s['id'] == lastWorkoutId);
    if (lastIndex == -1) lastIndex = 0;
    int nextIndex = (lastIndex + 1) % splits.length;
    var split = splits[nextIndex];

    if (needsDeload && !isTapering) {
      final recoverySplit = splits.firstWhere((s) => s['id'] == 'longevity_day', orElse: () => split);
      split = recoverySplit;
    }

    final phaseMultiplier = _getPhaseMultiplier();

    // Build the workout
    currentWorkout = Workout(
      id: 'workout_${now.millisecondsSinceEpoch}',
      date: now,
      type: split['id'] as String,
      name: '${split['name']}${needsDeload && !isTapering ? ' (Deload)' : isTapering ? ' (Taper)' : ''}',
      exercises: [],
    );

    // Muscle selection logic
    final allMuscles = MuscleDatabase.all.map((m) => m.name).toList();
    final muscleWorkCount = <String, int>{};
    for (var muscle in allMuscles) muscleWorkCount[muscle] = 0;
    for (var workout in workouts) {
      for (var ex in workout.exercises) {
        if (ex.actual != null && !ex.skipped) {
          for (var m in ex.muscleGroup) {
            if (muscleWorkCount.containsKey(m)) muscleWorkCount[m] = muscleWorkCount[m]! + 1;
          }
        }
      }
    }

    Set<String> targetMuscles = Set.from(split['focus'] as List<String>);
    final focusCount = targetMuscles.length;
    int accessoryTarget = (DateTime.now().millisecondsSinceEpoch % 3) + 2; // 2-4
    accessoryTarget = accessoryTarget.clamp(0, 8 - focusCount);

    final candidateMuscles = allMuscles
        .where((m) => !targetMuscles.contains(m))
        .toList()
      ..sort((a, b) => muscleWorkCount[a]!.compareTo(muscleWorkCount[b]!));
    final topNeglected = candidateMuscles.take(5).toList();

    if (topNeglected.isNotEmpty && accessoryTarget > 0) {
      // Weighted random selection
      final weights = List.generate(topNeglected.length, (idx) => 1 / (idx + 1));
      final totalWeight = weights.reduce((a, b) => a + b);
      final selectedIndices = <int>{};
      while (selectedIndices.length < accessoryTarget && selectedIndices.length < topNeglected.length) {
        double rand = DateTime.now().millisecondsSinceEpoch % totalWeight.toInt() / totalWeight;
        double cumulative = 0;
        for (int i = 0; i < weights.length; i++) {
          cumulative += weights[i];
          if (rand < cumulative) {
            selectedIndices.add(i);
            break;
          }
        }
      }
      for (var idx in selectedIndices) {
        targetMuscles.add(topNeglected[idx]);
      }
    } else {
      for (var m in topNeglected.take(accessoryTarget)) {
        targetMuscles.add(m);
      }
    }

    // Generate exercises
    for (var mg in targetMuscles) {
      final exercisesForMuscle = ExerciseLibrary.forMuscle(mg);
      if (exercisesForMuscle.isEmpty) continue;
      final randomIdx = DateTime.now().millisecondsSinceEpoch % exercisesForMuscle.length;
      final def = exercisesForMuscle[randomIdx];
      double multiplier = phaseMultiplier;
      if (needsDeload && !isTapering) multiplier *= 0.8;
      final exercise = generateExercisePrescription(def, phaseMultiplier: multiplier);
      currentWorkout!.exercises.add(exercise);
    }

    // Shuffle
    currentWorkout!.exercises.shuffle();

    _saveCurrentWorkoutToStorage();
  }

  int calculateStreak() {
    if (workouts.isEmpty) return 0;
    final sorted = List<Workout>.from(workouts)..sort((a, b) => a.date.compareTo(b.date));
    int streak = 1;
    Workout last = sorted.first;
    for (int i = 1; i < sorted.length; i++) {
      final current = sorted[i];
      final daysDiff = current.date.difference(last.date).inDays;
      final requiredRest = last.recommendedRest ?? 2;
      if (daysDiff <= requiredRest) {
        streak++;
      } else {
        streak = 1;
      }
      last = current;
    }
    final today = DateTime.now();
    final lastWorkout = sorted.last;
    final daysSinceLast = today.difference(lastWorkout.date).inDays;
    final lastRest = lastWorkout.recommendedRest ?? 2;
    if (daysSinceLast <= lastRest) {
      final hasToday = workouts.any((w) =>
          w.date.year == today.year &&
          w.date.month == today.month &&
          w.date.day == today.day);
      if (!hasToday) streak++;
    }
    return streak;
  }

  void _saveCurrentWorkoutToStorage() {
    if (currentWorkout != null) {
      savedWorkout = currentWorkout;
      LocalStorage.saveWorkout(currentWorkout!);
    } else {
      LocalStorage.removeWorkout();
      savedWorkout = null;
    }
  }

  void _loadSavedWorkoutFromStorage() {
    savedWorkout = LocalStorage.loadWorkout();
  }

  void clearSavedWorkout() {
    LocalStorage.removeWorkout();
    savedWorkout = null;
  }
}