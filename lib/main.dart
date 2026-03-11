import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/data_provider.dart';
import 'services/local_storage.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';
import 'screens/import_screen.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorage.init();
  await NotificationService().init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DataProvider(),
      child: Consumer<DataProvider>(
        builder: (context, dataProvider, child) {
          return FutureBuilder<ThemeData>(
            future: _loadTheme(),
            builder: (context, snapshot) {
              return MaterialApp(
                title: 'Progressive Overload',
                theme: snapshot.data ?? ThemeData.light(),
                darkTheme: ThemeData.dark(),
                themeMode: ThemeMode.system,
                home: LocalStorage.hasData() ? const MainScreen() : const ImportScreen(),
              );
            },
          );
        },
      ),
    );
  }

  Future<ThemeData> _loadTheme() async {
    final themeName = await ThemeService.getTheme();
    final darkMode = await ThemeService.getDarkMode();
    return ThemeService.getThemeData(themeName, darkMode);
  }
}