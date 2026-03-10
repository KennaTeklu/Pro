import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user.dart';
import '../models/workout.dart';

class LocalStorage {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static bool hasData() {
    return _prefs.containsKey('workoutData');
  }

  static Map<String, dynamic>? loadRawData() {
    final String? data = _prefs.getString('workoutData');
    if (data != null) {
      return jsonDecode(data);
    }
    return null;
  }

  static Future<void> saveRawData(Map<String, dynamic> data) async {
    await _prefs.setString('workoutData', jsonEncode(data));
  }

  static Future<void> clearData() async {
    await _prefs.remove('workoutData');
  }

  // Methods for workout persistence
  static const String _workoutKey = 'currentWorkout';

  static void saveWorkout(Workout workout) {
    _prefs.setString(_workoutKey, jsonEncode(workout.toJson()));
  }

  static Workout? loadWorkout() {
    final String? data = _prefs.getString(_workoutKey);
    if (data != null) {
      try {
        return Workout.fromJson(jsonDecode(data));
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  static void removeWorkout() {
    _prefs.remove(_workoutKey);
  }

  // Convenience methods for our data structure
  static ({User user, List<Workout> workouts, Map<String, dynamic> exercises})? loadData() {
    final raw = loadRawData();
    if (raw == null) return null;
    try {
      final user = User.fromJson(raw['user'] ?? {});
      final workouts = (raw['workouts'] as List? ?? [])
          .map((w) => Workout.fromJson(w))
          .toList();
      final exercises = Map<String, dynamic>.from(raw['exercises'] ?? {});
      return (user: user, workouts: workouts, exercises: exercises);
    } catch (e) {
      print('Error parsing saved data: $e');
      return null;
    }
  }

  static Future<void> saveData({
    required User user,
    required List<Workout> workouts,
    required Map<String, dynamic> exercises,
  }) async {
    final Map<String, dynamic> data = {
      'user': user.toJson(),
      'workouts': workouts.map((w) => w.toJson()).toList(),
      'exercises': exercises,
    };
    await saveRawData(data);
  }
}

  static const String _workoutKey = 'savedWorkout';

  static Future<void> saveWorkout(Workout workout) async {
    await _prefs.setString(_workoutKey, jsonEncode(workout.toJson()));
  }

  static Workout? loadWorkout() {
    final String? data = _prefs.getString(_workoutKey);
    if (data == null) return null;
    try {
      return Workout.fromJson(jsonDecode(data));
    } catch (e) {
      return null;
    }
  }

  static Future<void> removeWorkout() async {
    await _prefs.remove(_workoutKey);
  }
