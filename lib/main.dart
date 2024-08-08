import 'package:flutter/material.dart';
import 'package:masterwebserver/widgets/workplace/widget_workPlaceList.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'JsonServ/task_services.dart';
import 'Log/logger.dart';
import 'SQLite/database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Logger.initialize();
  await Logger.log('Application started');
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final databaseHelper = DatabaseHelper();
  final taskService = TaskService(databaseHelper);

  runApp(MyApp(taskService: taskService));
}

class MyApp extends StatelessWidget {
  final TaskService taskService;

  const MyApp({Key? key, required this.taskService}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: WorkplaceList( ),
    );
  }
}