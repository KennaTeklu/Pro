import 'package:flutter/material.dart';
import 'screens/import_screen.dart';
import 'screens/main_screen.dart';
import 'services/local_storage.dart';
import 'services/data_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorage.init();
  DataService().initFromStorage(); // load saved data
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Progressive Overload',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: LocalStorage.hasData() ? const MainScreen() : const ImportScreen(),
    );
  }
}
