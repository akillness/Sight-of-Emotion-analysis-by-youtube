import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'screens/trends_screen.dart';
import 'models/database.dart';
import 'services/migration_service.dart';
import 'widgets/app_theme.dart';

// Custom Scroll Behavior to enable trackpad dragging
class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.trackpad,
  };
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final database = AppDatabase();
  
  print("kIsWeb value: $kIsWeb");
  
  /*
  if (kIsWeb) {
    final migrationService = MigrationService(database);
    try {
      await migrationService.migrateFromIndexedDB();
      print('Migration completed successfully');
    } catch (e) {
      print('Migration failed: $e');
    }
  }
  */
  
  runApp(MyApp(database: database));
}

class MyApp extends StatelessWidget {
  final AppDatabase database;
  
  const MyApp({super.key, required this.database});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YouTube 키워드 트렌드 분석(게임)',
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      scrollBehavior: MyCustomScrollBehavior(),
      home: const TrendsScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
