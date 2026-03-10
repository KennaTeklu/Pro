import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import '../services/data_service.dart';
import '../services/local_storage.dart';
import '../models/user.dart';
import '../models/workout.dart';
import 'main_screen.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  bool _isLoading = false;

  Future<void> _importJson() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result != null) {
      setState(() => _isLoading = true);
      try {
        String content = utf8.decode(result.files.single.bytes!);
        Map<String, dynamic> json = jsonDecode(content);
        // TODO: Validate and load into DataService
        // For now, just save raw and restart
        await LocalStorage.saveRawData(json);
        DataService().initFromStorage();
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainScreen()),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startFresh() {
    // Set empty data and go to settings
    DataService().user = User();
    DataService().workouts = [];
    DataService().exercises = {};
    DataService().save();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainScreen()),
    );
    // Optionally navigate to settings tab
  }

  Future<void> _loadSample() async {
    setState(() => _isLoading = true);
    try {
      // Load the sample data from assets (we'll add an assets folder later)
      // For now, we'll create a minimal sample
      final sampleUser = User(name: 'Sample User', birthDate: DateTime(1990, 5, 15));
      final sampleWorkouts = <Workout>[];
      // ... populate sample workouts
      DataService().user = sampleUser;
      DataService().workouts = sampleWorkouts;
      DataService().exercises = {};
      await DataService().save();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading sample: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.fitness_center, size: 80, color: Colors.blue),
                    const Text('Progressive Overload',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text(
                        'Track your progress, maintain consistency, and optimize your workouts',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey)),
                    const SizedBox(height: 40),

                    _buildOptionCard(
                      icon: Icons.upload_file,
                      title: 'Import JSON Data',
                      description: 'Upload your existing workout data',
                      features: ['Import workout history', 'Import exercise progress', 'Import user settings'],
                      onTap: _importJson,
                    ),
                    const SizedBox(height: 16),
                    _buildOptionCard(
                      icon: Icons.add_circle_outline,
                      title: 'Start Fresh Program',
                      description: 'Begin a new workout program',
                      features: ['Personalized workout plan', 'Progressive overload system', 'Recovery tracking'],
                      onTap: _startFresh,
                    ),
                    const SizedBox(height: 16),
                    _buildOptionCard(
                      icon: Icons.science_outlined,
                      title: 'Sample Data',
                      description: 'Try the system with pre-loaded sample data',
                      features: ['5 sample workouts', '10+ exercises', 'Progress tracking'],
                      onTap: _loadSample,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String description,
    required List<String> features,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 40, color: Colors.blue),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(description, style: const TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 16),
              ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check, color: Colors.green, size: 18),
                    const SizedBox(width: 8),
                    Text(f),
                  ],
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }
}
