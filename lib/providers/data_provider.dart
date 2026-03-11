import 'package:flutter/material.dart';
import '../services/data_service.dart';
import '../models/user.dart';
import '../models/workout.dart';

class DataProvider extends ChangeNotifier {
  final DataService _dataService = DataService();

  User get user => _dataService.user;
  List<Workout> get workouts => _dataService.workouts;
  Map<String, dynamic> get exercises => _dataService.exercises;
  Workout? get currentWorkout => _dataService.currentWorkout;
  Workout? get savedWorkout => _dataService.savedWorkout;

  DataProvider() {
    _dataService.initFromStorage();
  }

  Future<void> save() async {
    await _dataService.save();
    notifyListeners();
  }

  void generateNextWorkout() {
    _dataService.generateNextWorkout();
    notifyListeners();
  }

  void completeWorkout() {
    // TODO: implement
    notifyListeners();
  }

  void updateUser(User newUser) {
    _dataService.user = newUser;
    save();
  }

  // Add more methods as needed
}