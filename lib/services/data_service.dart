import "dart:math";
import "dart:math";
import 'dart:math';
import 'dart:collection';
import 'dart:math' as math;
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
  Workout? savedWorkout; // for resume functionality

  // Muscle last trained cache
  final Map<String, DateTime?> _muscleLastTrained = {};

  // ---------- Initialization ----------
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

  // ---------- Muscle tracking ----------
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

  // ---------- Prescription anchor curves ----------
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

  // ---------- Prescription generation ----------
  Exercise generateExercisePrescription(ExerciseDefinition def, {double phaseMultiplier = 1.0}) {
    final exId = def.name.toLowerCase().replaceAll(' ', '_');
    final exData = exercises[exId] as Map<String, dynamic>? ?? {};
    final history = (exData['history'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final lastSession = history.isNotEmpty ? history.last : null;
    final bestWeight = exData['bestWeight'] as double?;

    // Training maturity
    final totalWorkouts = workouts.length;
    final maturity = 1 - (totalWorkouts / 100).clamp(0.0, 1.0).toDouble();

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
        final muscleSpecific = 1 / (1 + math.exp(k * (0.5 - recoveryPercent)));
        final systemic = calculateSystemicRecoveryFactor();
        recoveryFactor = 0.7 * muscleSpecific + 0.3 * systemic;
        recoveryFactor = recoveryFactor.clamp(0.5, 1.0);
      }
    }

    // Competition factor
    double compFactor = 1.0;
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

  // ---------- Workout generation ----------
  void generateNextWorkout() {
    final now = DateTime.now();
    final systemicFactor = calculateSystemicRecoveryFactor();
    final needsDeload = systemicFactor < 0.6;
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

  // ---------- Systemic recovery ----------
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

    final fatigueFromFreq = (recentWorkouts.length * 10).clamp(0, 50);
    final fatigueFromVolume = (relativeVolume / 500 * 30).clamp(0, 30);
    final fatigueFromRPE = ((avgRPE - 5) * 4).clamp(0, 20);
    final totalFatigue = fatigueFromFreq + fatigueFromVolume + fatigueFromRPE;
    final factor = 1.0 - (totalFatigue / 200);
    return factor.clamp(0.5, 1.0);
  }

  // ---------- Longevity score ----------
  Map<String, dynamic> calculateLongevityScore() {
    final scores = {
      'gripStrength': _gripStrengthScore(),
      'balance': _balanceScore(),
      'jointMobility': _jointMobilityScore(),
      'posture': _postureScore(),
      'muscleBalance': _muscleBalanceScore(),
      'consistency': _consistencyScore(),
      'trend': _trendScore(),
      'variety': _varietyScore(),
    };

    final age = user.birthDate != null ? calculateAge(user.birthDate!) : null;
    var weights = {
      'gripStrength': 0.15,
      'balance': 0.15,
      'jointMobility': 0.25,
      'posture': 0.20,
      'muscleBalance': 0.15,
      'consistency': 0.10,
      'trend': 0.0,
      'variety': 0.0,
    };

    if (age != null) {
      if (age < 30) {
        weights = {'gripStrength': 0.20, 'balance': 0.10, 'jointMobility': 0.15, 'posture': 0.15, 'muscleBalance': 0.25, 'consistency': 0.10, 'trend': 0.05, 'variety': 0.0};
      } else if (age < 50) {
        weights = {'gripStrength': 0.15, 'balance': 0.15, 'jointMobility': 0.25, 'posture': 0.15, 'muscleBalance': 0.10, 'consistency': 0.10, 'trend': 0.05, 'variety': 0.05};
      } else {
        weights = {'gripStrength': 0.10, 'balance': 0.25, 'jointMobility': 0.30, 'posture': 0.15, 'muscleBalance': 0.05, 'consistency': 0.05, 'trend': 0.05, 'variety': 0.05};
      }
    }

    double total = 0;
    double weightSum = 0;
    weights.forEach((key, w) {
      total += (scores[key] as double) * w;
      weightSum += w;
    });
    final finalScore = (total / weightSum).round();

    final risks = _assessAgingRisks(scores);
    final recommendations = _generateLongevityRecommendations(scores, risks);

    return {
      'score': finalScore,
      'breakdown': scores,
      'risks': risks,
      'recommendations': recommendations,
    };
  }

  double _gripStrengthScore() {
    const gripExercises = [
      'deadlift', 'pull_up', 'farmer_walk', 'dead_hang', 'wrist_curl', 'plate_pinch',
      'grippers', 'barbell_shrug', 'dumbbell_shrug', 'rack_pull'
    ];
    final userWeight = user.weight ?? 150;
    double bestScore = 0;
    for (var exId in gripExercises) {
      final exData = exercises[exId] as Map<String, dynamic>?;
      if (exData == null) continue;
      if (exId == 'dead_hang') {
        final duration = exData['bestWeight'] ?? exData['bestDuration'] ?? 0;
        if (duration > 0) {
          final score = (duration / 120 * 100).clamp(0, 100);
          if (score > bestScore) bestScore = score;
        }
        continue;
      }
      if (exData.containsKey('bestWeight')) {
        double gripLoad = 0;
        final bestWeight = (exData['bestWeight'] as num).toDouble();
        if (exId == 'farmer_walk') {
          gripLoad = bestWeight * 2;
        } else if (exId == 'pull_up') {
          gripLoad = userWeight + bestWeight;
        } else {
          gripLoad = bestWeight;
        }
        final ratio = gripLoad / userWeight;
        double score = 0;
        if (ratio >= 2.0) score = 100;
        else if (ratio >= 1.5) score = 90;
        else if (ratio >= 1.2) score = 75;
        else if (ratio >= 1.0) score = 60;
        else if (ratio >= 0.8) score = 40;
        else if (ratio >= 0.5) score = 20;
        if (score > bestScore) bestScore = score;
      }
    }
    return bestScore > 0 ? bestScore : 50;
  }

  double _balanceScore() {
    const balanceExercises = {
      'single_leg_stand', 'balance_board', 'yoga_tree', 'single_leg_rdl',
      'single_leg_squat', 'ankle_stability', 'pistol_squat', 'staggered_stance_deadlift'
    };
    const unilateralExercises = {
      'bulgarian_split_squat', 'single_leg_press', 'lunge', 'step_up',
      'single_leg_rdl', 'pistol_squat', 'single_leg_squat'
    };
    const ankleMuscles = ['peroneus_tertius', 'tibialis', 'foot_intrinsics'];

    final cutoff = DateTime.now().subtract(const Duration(days: 60));
    int balanceSessions = 0;
    DateTime? lastBalanceDate;
    int unilateralSessions = 0;

    for (var workout in workouts) {
      if (workout.date.isBefore(cutoff)) continue;
      bool hasBalance = false;
      bool hasUnilateral = false;
      for (var ex in workout.exercises) {
        if (ex.actual == null || ex.skipped) continue;
        if (balanceExercises.contains(ex.id)) hasBalance = true;
        if (unilateralExercises.contains(ex.id)) hasUnilateral = true;
      }
      if (hasBalance) {
        balanceSessions++;
        if (lastBalanceDate == null || workout.date.isAfter(lastBalanceDate)) {
          lastBalanceDate = workout.date;
        }
      }
      if (hasUnilateral) unilateralSessions++;
    }

    DateTime? mostRecentAnkle;
    for (var muscle in ankleMuscles) {
      final last = _muscleLastTrained[muscle];
      if (last != null && (mostRecentAnkle == null || last.isAfter(mostRecentAnkle))) {
        mostRecentAnkle = last;
      }
    }

    final freqScore = (balanceSessions / 8 * 100).clamp(0, 100);
    final recencyScore = lastBalanceDate == null ? 0 :
        (DateTime.now().difference(lastBalanceDate).inDays <= 7 ? 100 :
         DateTime.now().difference(lastBalanceDate).inDays <= 14 ? 80 :
         DateTime.now().difference(lastBalanceDate).inDays <= 30 ? 60 :
         DateTime.now().difference(lastBalanceDate).inDays <= 60 ? 40 : 20);
    final ankleScore = mostRecentAnkle == null ? 20 :
        (DateTime.now().difference(mostRecentAnkle).inDays <= 14 ? 100 :
         DateTime.now().difference(mostRecentAnkle).inDays <= 30 ? 80 :
         DateTime.now().difference(mostRecentAnkle).inDays <= 60 ? 60 : 40);
    final unilateralScore = (unilateralSessions / 4 * 100).clamp(0, 100);

    return (freqScore * 0.4 + recencyScore * 0.2 + ankleScore * 0.2 + unilateralScore * 0.2).roundToDouble();
  }

  double _jointMobilityScore() {
    final longevityMuscles = MuscleDatabase.longevity;
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 60));
    final muscleSessions = <String, int>{};
    for (var m in longevityMuscles) muscleSessions[m.name] = 0;
    for (var workout in workouts) {
      if (workout.date.isBefore(cutoff)) continue;
      for (var ex in workout.exercises) {
        if (ex.actual != null && !ex.skipped) {
          for (var m in ex.muscleGroup) {
            if (muscleSessions.containsKey(m)) muscleSessions[m] = muscleSessions[m]! + 1;
          }
        }
      }
    }

    double totalWeighted = 0;
    double totalWeight = 0;
    for (var muscle in longevityMuscles) {
      final last = _muscleLastTrained[muscle.name];
      int daysSince = last == null ? 999 : now.difference(last).inDays;
      double recency = daysSince <= 7 ? 1.0 : daysSince >= 60 ? 0.0 : 1.0 - (daysSince - 7) / 53;
      double freqBonus = (muscleSessions[muscle.name]!.clamp(0, 4) * 0.05).toDouble();
      double muscleScore = (recency + freqBonus).clamp(0, 1);
      double weight = muscle.agingRisk == 'high' ? 2.0 : muscle.agingRisk == 'medium' ? 1.5 : 1.0;
      totalWeighted += muscleScore * weight;
      totalWeight += weight;
    }
    if (totalWeight == 0) return 50;
    return (totalWeighted / totalWeight * 100).roundToDouble();
  }

  double _postureScore() {
    const postureMuscles = [
      {'name': 'neck', 'weight': 1.5},
      {'name': 'deep_neck', 'weight': 1.5},
      {'name': 'rhomboids', 'weight': 2.0},
      {'name': 'rear_delts', 'weight': 1.2},
      {'name': 'traps', 'weight': 1.0},
    ];
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 60));
    final muscleSessions = <String, int>{};
    for (var m in postureMuscles) muscleSessions[m['name'] as String] = 0;
    for (var workout in workouts) {
      if (workout.date.isBefore(cutoff)) continue;
      for (var ex in workout.exercises) {
        if (ex.actual != null && !ex.skipped) {
          for (var m in ex.muscleGroup) {
            if (muscleSessions.containsKey(m)) muscleSessions[m] = muscleSessions[m]! + 1;
          }
        }
      }
    }

    double totalWeighted = 0;
    double totalWeight = 0;
    for (var entry in postureMuscles) {
      final name = entry['name'] as String;
      final weight = entry['weight'] as double;
      final last = _muscleLastTrained[name];
      int daysSince = last == null ? 999 : now.difference(last).inDays;
      double recency = daysSince <= 14 ? 1.0 : daysSince >= 60 ? 0.0 : 1.0 - (daysSince - 14) / 46;
      double freqBonus = (muscleSessions[name]!.clamp(0, 4) * 0.05).toDouble();
      double muscleScore = (recency + freqBonus).clamp(0, 1);
      totalWeighted += muscleScore * weight;
      totalWeight += weight;
    }
    if (totalWeight == 0) return 50;
    return (totalWeighted / totalWeight * 100).roundToDouble();
  }

  double _muscleBalanceScore() {
    const push = ['chest', 'triceps', 'front_delts'];
    const pull = ['back', 'biceps', 'rear_delts'];
    double pushTotal = 0, pullTotal = 0;
    int pushCount = 0, pullCount = 0;
    for (var m in push) {
      final last = _muscleLastTrained[m];
      if (last != null) {
        final days = DateTime.now().difference(last).inDays;
        double recency = days <= 14 ? 1.0 : days >= 60 ? 0.0 : 1.0 - (days - 14) / 46;
        pushTotal += recency;
        pushCount++;
      }
    }
    for (var m in pull) {
      final last = _muscleLastTrained[m];
      if (last != null) {
        final days = DateTime.now().difference(last).inDays;
        double recency = days <= 14 ? 1.0 : days >= 60 ? 0.0 : 1.0 - (days - 14) / 46;
        pullTotal += recency;
        pullCount++;
      }
    }
    double pushAvg = pushCount > 0 ? pushTotal / pushCount : 0;
    double pullAvg = pullCount > 0 ? pullTotal / pullCount : 0;
    if (pushAvg == 0 && pullAvg == 0) return 0;
    double maxAvg = pushAvg > pullAvg ? pushAvg : pullAvg;
    double minAvg = pushAvg < pullAvg ? pushAvg : pullAvg;
    return (minAvg / maxAvg * 100).roundToDouble();
  }

  double _consistencyScore() {
    final now = DateTime.now();
    final eightWeeksAgo = now.subtract(const Duration(days: 56));
    var weeks = List.generate(8, (i) {
      final start = eightWeeksAgo.add(Duration(days: i * 7));
      final end = start.add(const Duration(days: 6));
      return {'start': start, 'end': end, 'count': 0};
    });
    for (var workout in workouts) {
      for (var week in weeks) {
        if (workout.date.isAfter(week['start'] as DateTime) && workout.date.isBefore(week['end'] as DateTime)) {
          week['count'] = (week['count'] as int) + 1;
          break;
        }
      }
    }
    final weeklyCounts = weeks.map((w) => w['count'] as int).toList();
    final avgWeekly = weeklyCounts.reduce((a, b) => a + b) / 8.0;
    double freqScore = avgWeekly >= 3.5 ? 40 : avgWeekly >= 2.5 ? 30 : avgWeekly >= 1.5 ? 20 : avgWeekly >= 0.5 ? 10 : 0;

    final streak = calculateStreak();
    double streakScore = streak >= 30 ? 30 : streak >= 14 ? 25 : streak >= 7 ? 20 : streak >= 3 ? 15 : streak >= 1 ? 10 : 0;

    double adherenceScore = 0;
    if (user.settings.workoutDays.isNotEmpty) {
      final fourWeeksAgo = now.subtract(const Duration(days: 28));
      int plannedCount = 0, actualCount = 0;
      for (var d = fourWeeksAgo; d.isBefore(now) || d.isAtSameMomentAs(now); d = d.add(const Duration(days: 1))) {
        final dayName = _weekdayName(d.weekday);
        if (user.settings.workoutDays.contains(dayName)) {
          plannedCount++;
          final hasWorkout = workouts.any((w) =>
              w.date.year == d.year && w.date.month == d.month && w.date.day == d.day);
          if (hasWorkout) actualCount++;
        }
      }
      if (plannedCount > 0) adherenceScore = actualCount / plannedCount * 20;
    }

    final mean = avgWeekly > 0 ? avgWeekly : 0.01;
    final variance = weeklyCounts.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / 8;
    final stdDev = math.sqrt(variance);
    final cv = mean > 0 ? stdDev / mean : 0;
    double regularityScore = cv <= 0.3 ? 10 : cv <= 0.5 ? 7 : cv <= 0.7 ? 4 : cv <= 1.0 ? 2 : 0;

    return freqScore + streakScore + adherenceScore + regularityScore;
  }

  double _trendScore() {
    final threeMonthsAgo = DateTime.now().subtract(const Duration(days: 90));
    const keyExercises = ['squat', 'deadlift', 'bench_press', 'overhead_press'];
    double totalImprovement = 0;
    int count = 0;
    for (var exId in keyExercises) {
      final exData = exercises[exId] as Map<String, dynamic>?;
      if (exData == null || !exData.containsKey('history')) continue;
      final history = (exData['history'] as List).cast<Map<String, dynamic>>();
      final recent = history.where((h) => DateTime.parse(h['date']).isAfter(threeMonthsAgo)).toList();
      if (recent.length < 2) continue;
      final oldest = recent.first;
      final newest = recent.last;
      final oldest1RM = estimate1RMAdvanced(oldest['weight'].toDouble(), (oldest['reps'] as List).reduce((a, b) => a > b ? a : b));
      final newest1RM = estimate1RMAdvanced(newest['weight'].toDouble(), (newest['reps'] as List).reduce((a, b) => a > b ? a : b));
      if (oldest1RM > 0) {
        final improvement = (newest1RM - oldest1RM) / oldest1RM;
        totalImprovement += improvement;
        count++;
      }
    }
    if (count == 0) return 50;
    final avgImprovement = totalImprovement / count;
    return (50 + avgImprovement * 250).clamp(0, 100).toDouble();
  }

  double _varietyScore() {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final longevityMuscles = MuscleDatabase.longevity.map((m) => m.name).toSet();
    final trained = <String>{};
    for (var workout in workouts) {
      if (workout.date.isBefore(thirtyDaysAgo)) continue;
      for (var ex in workout.exercises) {
        if (ex.actual != null && !ex.skipped) {
          for (var m in ex.muscleGroup) {
            if (longevityMuscles.contains(m)) trained.add(m);
          }
        }
      }
    }
    final percentage = trained.length / longevityMuscles.length * 100;
    return (percentage * 1.5).clamp(0, 100).toDouble();
  }

  List<Map<String, dynamic>> _assessAgingRisks(Map<String, double> scores) {
    final age = user.birthDate != null ? calculateAge(user.birthDate!) : null;
    final risks = <Map<String, dynamic>>[];
    void addRisk(String factor, String scoreKey, double idealMin, double severeThreshold,
                 String severity, String impact, String baseRec, List<String> exercises) {
      final score = scores[scoreKey]!;
      double adjustedIdeal = idealMin;
      if (age != null) {
        if (factor.contains('Neck')) adjustedIdeal += age > 50 ? 5 : 0;
        if (factor.contains('Grip')) adjustedIdeal += age > 60 ? 10 : 0;
        if (factor.contains('Balance')) adjustedIdeal += age > 50 ? 10 : 0;
        if (factor.contains('Joint')) adjustedIdeal += age > 50 ? 5 : 0;
        if (factor.contains('Trend')) adjustedIdeal += age > 50 ? 5 : 0;
      }
      if (score < severeThreshold) {
        risks.add({
          'factor': factor,
          'severity': severity,
          'impact': impact,
          'recommendation': '$baseRec (current score ${score.round()}/100)',
          'exercises': exercises,
        });
      } else if (score < adjustedIdeal) {
        risks.add({
          'factor': factor,
          'severity': 'Low',
          'impact': impact,
          'recommendation': 'Your ${factor.toLowerCase()} score is ${score.round()}/100. $baseRec',
          'exercises': exercises,
        });
      }
    }
    addRisk('Neck/Posture Weakness', 'posture', 70, 50, 'High',
        'Forward head posture, cervical degeneration, headaches',
        'Add neck strengthening 2x/week', ['neck_isometric', 'chin_tucks', 'face_pull']);
    addRisk('Low Grip Strength', 'gripStrength', 60, 40, 'Medium',
        'Reduced independence, difficulty with daily tasks',
        'Add grip training 2x/week', ['wrist_curl', 'hand_therapy', 'farmer_walks']);
    addRisk('Poor Balance', 'balance', 70, 40, 'High',
        'Increased fall risk, fractures, fear of falling',
        'Add balance exercises daily', ['ankle_stability', 'single_leg_stands', 'balance_board']);
    addRisk('Joint Stiffness', 'jointMobility', 60, 40, 'Medium',
        'Reduced range of motion, arthritis progression',
        'Add joint mobility work 3x/week', ['terminal_extension', 'ankle_stability', 'shoulder_circles']);
    addRisk('Muscle Imbalance (Push/Pull)', 'muscleBalance', 80, 60, 'Medium',
        'Postural issues, increased injury risk',
        'Incorporate more pulling exercises', ['face_pull', 'barbell_row', 'pull_up']);
    addRisk('Low Training Consistency', 'consistency', 70, 40, 'Low',
        'Missed training opportunities',
        'Aim for at least 3 workouts per week', []);
    addRisk('Neglected Longevity Muscles', 'variety', 70, 50, 'Medium',
        'Unaddressed joint health muscles',
        'Add more variety to target all joint health areas', []);
    addRisk('Strength Decline Trend', 'trend', 50, 30, 'Medium',
        'Possible loss of muscle mass or strength',
        'Consider a structured progressive overload program', []);
    return risks;
  }

  List<String> _generateLongevityRecommendations(Map<String, double> scores, List<Map<String, dynamic>> risks) {
    final recommendations = <String>[];
    for (var risk in risks) {
      String rec = risk['recommendation'] as String;
      if (risk['severity'] == 'High') rec = '⚠️ URGENT: $rec';
      recommendations.add(rec);
    }
    if (scores['posture']! >= 70 && scores['posture']! < 85) {
      recommendations.add('Your posture is good. Maintain with regular upper back work.');
    } else if (scores['posture']! >= 85) {
      recommendations.add('Excellent posture! Keep up the good work.');
    }
    if (scores['balance']! >= 60 && scores['balance']! < 80) {
      recommendations.add('Balance is decent. Aim for 2‑3 balance sessions per week to maintain.');
    } else if (scores['balance']! >= 80) {
      recommendations.add('Great balance! Continue your routine.');
    }
    if (scores['jointMobility']! >= 50 && scores['jointMobility']! < 75) {
      recommendations.add('Joint mobility is acceptable. Add one mobility session per week.');
    } else if (scores['jointMobility']! >= 75) {
      recommendations.add('Excellent joint mobility! Keep moving.');
    }
    if (scores['trend']! < 40) {
      recommendations.add('Your strength is declining. Consider a structured progressive overload program.');
    } else if (scores['trend']! > 75) {
      recommendations.add('Strong progress! Keep challenging yourself.');
    }
    if (scores['variety']! < 50) {
      recommendations.add("You're missing many longevity muscles. Try to include a wider variety of joint‑health exercises.");
    } else if (scores['variety']! >= 80) {
      recommendations.add('Excellent variety in your training! This is great for long‑term health.');
    }
    if (user.goal == 'longevity') {
      recommendations.add('Your goal is longevity. Keep focusing on joint health, balance, and consistency.');
    }
    if (recommendations.isNotEmpty) {
      recommendations.add('Reassess your longevity score in 4‑6 weeks to track progress.');
    }
    return recommendations.toSet().toList();
  }

  // ---------- Streak (override with rest‑aware) ----------
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

  // ---------- Save/Load workout ----------
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

  // ---------- Utility ----------
  String _weekdayName(int weekday) {
    const names = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    return names[weekday - 1];
  }
}
