import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/trends_screen.dart';
import 'models/database.dart';
import 'services/migration_service.dart';
import 'widgets/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final database = AppDatabase();
  final migrationService = MigrationService(database);
  
  try {
    await migrationService.migrateFromIndexedDB();
    print('Migration completed successfully');
  } catch (e) {
    print('Migration failed: $e');
  }
  
  runApp(MyApp(database: database));
}

class MyApp extends StatelessWidget {
  final AppDatabase database;
  
  const MyApp({super.key, required this.database});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YouTube 트렌드 분석',
      theme: AppTheme.lightTheme,
      home: const TrendsScreen(),
    );
  }
}
