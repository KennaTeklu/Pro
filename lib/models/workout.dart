class Workout {
  final String id;
  final DateTime date;
  final String type;
  final String name;
  final List<Exercise> exercises;
  WorkoutSummary? summary;
  double? recommendedRest;

  Workout({
    required this.id,
    required this.date,
    required this.type,
    required this.name,
    required this.exercises,
    this.summary,
    this.recommendedRest,
  });

  factory Workout.fromJson(Map<String, dynamic> json) {
    return Workout(
      id: json['id'],
      date: DateTime.parse(json['date']),
      type: json['type'],
      name: json['name'],
      exercises: (json['exercises'] as List)
          .map((e) => Exercise.fromJson(e))
          .toList(),
      summary: json['summary'] != null ? WorkoutSummary.fromJson(json['summary']) : null,
      recommendedRest: (json['recommendedRest'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'type': type,
      'name': name,
      'exercises': exercises.map((e) => e.toJson()).toList(),
      'summary': summary?.toJson(),
      'recommendedRest': recommendedRest,
    };
  }
}

class Exercise {
  final String id;
  final String name;
  final List<String> muscleGroup;
  Prescription prescribed;
  ActualPerformance? actual;
  bool skipped;
  String progressionNotes;
  String equipment;
  List<String> instructions;

  Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.prescribed,
    this.actual,
    this.skipped = false,
    required this.progressionNotes,
    required this.equipment,
    required this.instructions,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'],
      name: json['name'],
      muscleGroup: List<String>.from(json['muscleGroup']),
      prescribed: Prescription.fromJson(json['prescribed']),
      actual: json['actual'] != null ? ActualPerformance.fromJson(json['actual']) : null,
      skipped: json['skipped'] ?? false,
      progressionNotes: json['progressionNotes'],
      equipment: json['equipment'],
      instructions: List<String>.from(json['instructions']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'muscleGroup': muscleGroup,
      'prescribed': prescribed.toJson(),
      'actual': actual?.toJson(),
      'skipped': skipped,
      'progressionNotes': progressionNotes,
      'equipment': equipment,
      'instructions': instructions,
    };
  }
}

class Prescription {
  int sets;
  String reps;
  double? weight;
  int? duration;

  Prescription({required this.sets, required this.reps, this.weight, this.duration});

  factory Prescription.fromJson(Map<String, dynamic> json) {
    return Prescription(
      sets: json['sets'],
      reps: json['reps'],
      weight: (json['weight'] as num?)?.toDouble(),
      duration: json['duration'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sets': sets,
      'reps': reps,
      'weight': weight,
      'duration': duration,
    };
  }
}

class ActualPerformance {
  double weight;
  int sets;
  List<int>? reps;
  List<int>? durations;
  int rpe;
  String notes;
  DateTime completed;

  ActualPerformance({
    required this.weight,
    required this.sets,
    this.reps,
    this.durations,
    required this.rpe,
    required this.notes,
    required this.completed,
  });

  factory ActualPerformance.fromJson(Map<String, dynamic> json) {
    return ActualPerformance(
      weight: (json['weight'] as num).toDouble(),
      sets: json['sets'],
      reps: json['reps'] != null ? List<int>.from(json['reps']) : null,
      durations: json['durations'] != null ? List<int>.from(json['durations']) : null,
      rpe: json['rpe'],
      notes: json['notes'],
      completed: DateTime.parse(json['completed']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'weight': weight,
      'sets': sets,
      'reps': reps,
      'durations': durations,
      'rpe': rpe,
      'notes': notes,
      'completed': completed.toIso8601String(),
    };
  }
}

class WorkoutSummary {
  double totalVolume;
  double? averageRPE;
  int completedExercises;

  WorkoutSummary({required this.totalVolume, this.averageRPE, required this.completedExercises});

  factory WorkoutSummary.fromJson(Map<String, dynamic> json) {
    return WorkoutSummary(
      totalVolume: (json['totalVolume'] as num).toDouble(),
      averageRPE: (json['averageRPE'] as num?)?.toDouble(),
      completedExercises: json['completedExercises'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalVolume': totalVolume,
      'averageRPE': averageRPE,
      'completedExercises': completedExercises,
    };
  }
}
