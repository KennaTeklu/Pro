import 'dart:convert';

class User {
  String name;
  DateTime? birthDate;
  String gender;
  double? weight;      // lbs
  double? height;      // inches
  String experience;   // beginner, intermediate, advanced
  String goal;         // strength, hypertrophy, endurance, longevity, balanced
  DateTime created;
  UserSettings settings;
  List<AgingRisk> agingRisks;
  MenstrualData? menstrual;

  User({
    this.name = '',
    this.birthDate,
    this.gender = 'male',
    this.weight,
    this.height,
    this.experience = 'intermediate',
    this.goal = 'balanced',
    DateTime? created,
    UserSettings? settings,
    List<AgingRisk>? agingRisks,
    this.menstrual,
  })  : created = created ?? DateTime.now(),
        settings = settings ?? UserSettings(),
        agingRisks = agingRisks ?? [];

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      name: json['name'] ?? '',
      birthDate: json['birthDate'] != null ? DateTime.parse(json['birthDate']) : null,
      gender: json['gender'] ?? 'male',
      weight: (json['weight'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
      experience: json['experience'] ?? 'intermediate',
      goal: json['goal'] ?? 'balanced',
      created: json['created'] != null ? DateTime.parse(json['created']) : DateTime.now(),
      settings: json['settings'] != null ? UserSettings.fromJson(json['settings']) : UserSettings(),
      agingRisks: (json['agingRisks'] as List?)
          ?.map((r) => AgingRisk.fromJson(r))
          .toList() ?? [],
      menstrual: json['menstrual'] != null ? MenstrualData.fromJson(json['menstrual']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'birthDate': birthDate?.toIso8601String(),
      'gender': gender,
      'weight': weight,
      'height': height,
      'experience': experience,
      'goal': goal,
      'created': created.toIso8601String(),
      'settings': settings.toJson(),
      'agingRisks': agingRisks.map((r) => r.toJson()).toList(),
      'menstrual': menstrual?.toJson(),
    };
  }
}

class UserSettings {
  List<String> workoutDays;
  int restTime;
  double progressionRate;
  String theme;
  bool darkMode;
  bool bottomNavAutoHide;
  DateTime? competitionDate; // Added

  UserSettings({
    this.workoutDays = const ['monday', 'wednesday', 'friday'],
    this.restTime = 90,
    this.progressionRate = 0.02,
    this.theme = 'blue',
    this.darkMode = false,
    this.bottomNavAutoHide = false,
    this.competitionDate,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      workoutDays: List<String>.from(json['workoutDays'] ?? ['monday', 'wednesday', 'friday']),
      restTime: json['restTime'] ?? 90,
      progressionRate: (json['progressionRate'] as num?)?.toDouble() ?? 0.02,
      theme: json['theme'] ?? 'blue',
      darkMode: json['darkMode'] ?? false,
      bottomNavAutoHide: json['bottomNavAutoHide'] ?? false,
      competitionDate: json['competitionDate'] != null ? DateTime.parse(json['competitionDate']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'workoutDays': workoutDays,
      'restTime': restTime,
      'progressionRate': progressionRate,
      'theme': theme,
      'darkMode': darkMode,
      'bottomNavAutoHide': bottomNavAutoHide,
      'competitionDate': competitionDate?.toIso8601String(),
    };
  }
}

class AgingRisk {
  final String factor;
  final String severity;
  final String impact;
  final String recommendation;
  final List<String> exercises;

  AgingRisk({
    required this.factor,
    required this.severity,
    required this.impact,
    required this.recommendation,
    required this.exercises,
  });

  factory AgingRisk.fromJson(Map<String, dynamic> json) {
    return AgingRisk(
      factor: json['factor'],
      severity: json['severity'],
      impact: json['impact'],
      recommendation: json['recommendation'],
      exercises: List<String>.from(json['exercises']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'factor': factor,
      'severity': severity,
      'impact': impact,
      'recommendation': recommendation,
      'exercises': exercises,
    };
  }
}

class MenstrualData {
  DateTime? lastPeriodStart;
  int cycleLength;
  List<Map<String, dynamic>> symptoms;

  MenstrualData({this.lastPeriodStart, this.cycleLength = 28, this.symptoms = const []});

  factory MenstrualData.fromJson(Map<String, dynamic> json) {
    return MenstrualData(
      lastPeriodStart: json['lastPeriodStart'] != null ? DateTime.parse(json['lastPeriodStart']) : null,
      cycleLength: json['cycleLength'] ?? 28,
      symptoms: List<Map<String, dynamic>>.from(json['symptoms'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lastPeriodStart': lastPeriodStart?.toIso8601String(),
      'cycleLength': cycleLength,
      'symptoms': symptoms,
    };
  }
}
