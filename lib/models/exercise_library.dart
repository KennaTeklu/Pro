import 'muscle.dart';

class ExerciseDefinition {
  final String name;
  final List<String> muscles;
  final String equipment;
  final int defaultSets;
  final String defaultReps;
  final String progression;
  final List<String> instructions;
  final double strengthIndex;
  final double skillFactor;
  final String genderSuitability;
  final String prescriptionType;
  final int? defaultDuration;

  ExerciseDefinition({
    required this.name,
    required this.muscles,
    required this.equipment,
    required this.defaultSets,
    required this.defaultReps,
    required this.progression,
    required this.instructions,
    required this.strengthIndex,
    required this.skillFactor,
    required this.genderSuitability,
    required this.prescriptionType,
    this.defaultDuration,
  });
}

class ExerciseLibrary {
  static final Map<String, List<ExerciseDefinition>> all = {
    'quads': [],
    'hamstrings': [],
    'glutes': [],
    'chest': [],
    'back_lats': [],
    'rhomboids_reardelts': [],
    'traps': [],
    'shoulders_anterior': [],
    'shoulders_lateral': [],
    'biceps': [],
    'triceps': [],
    'forearms': [],
    'core_abs': [],
    'calves': [],
    'adductors': [],
    'abductors': [],
    'neck': [],
    'feet_ankles': [],
    'hands_grip': [],
  };

  static List<ExerciseDefinition> allExercises() {
    return all.values.expand((list) => list).toList();
  }

  static ExerciseDefinition? byName(String name) {
    try {
      return allExercises().firstWhere((ex) => ex.name == name);
    } catch (e) {
      return null;
    }
  }

  static List<ExerciseDefinition> forMuscle(String muscle) {
    return all[muscle] ?? [];
  }
}