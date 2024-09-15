// import 'package:flutter/material.dart';
// import 'package:masterwebserver/widgets/workplace/widget_workPlaceList.dart';
// import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// import 'JsonServ/task_services.dart';
// import 'Log/logger.dart';
// import 'SQLite/database_helper.dart';
//
// import 'dart:async';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:path/path.dart' as p;
// import 'package:path_provider/path_provider.dart';
// import 'package:sqflite_common_ffi/sqflite_ffi.dart';
//
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//
//   await Logger.initialize();
//   await Logger.log('Application started');
//   sqfliteFfiInit();
//   databaseFactory = databaseFactoryFfi;
//
//   final databaseHelper = DatabaseHelper();
//   final taskService = TaskService(databaseHelper);
//
//   runApp(MyApp(taskService: taskService));
// }



import 'package:flutter/material.dart';
import 'package:masterwebserver/widgets/workplace/widget_workPlaceList.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'Log/logger.dart';
import 'SQLite/database_helper.dart';

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'Services/jsonTaskService.dart';
import 'Services/task_services.dart';

late IOSink logFile;
late ZoneSpecification _spec;
late DateTime currentLogDate;

void main() {
  _spec = ZoneSpecification(
    print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
      _log(line);
      parent.print(zone, line);
    },
  );

  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await _initializeLogging();

    runApp(await _buildApp());
  }, (error, stack) {
    _log('Uncaught error: $error');
    _log('Stack trace: $stack');
  }, zoneSpecification: _spec);
}


Future<void> _initializeLogging() async {
  final prefs = await SharedPreferences.getInstance();
  final customLogPath = prefs.getString('log_path');

  final logDir = customLogPath != null && customLogPath.isNotEmpty
      ? Directory(customLogPath)
      : Directory(p.join((await getApplicationDocumentsDirectory()).path, 'logs'));

  if (!await logDir.exists()) await logDir.create(recursive: true);

  currentLogDate = DateTime.now();
  final formattedDate = '${currentLogDate.year}-${currentLogDate.month.toString().padLeft(2, '0')}-${currentLogDate.day.toString().padLeft(2, '0')}';
  final file = File(p.join(logDir.path, '${formattedDate}_app_log.txt'));

  if (!await file.exists()) await file.create();
  logFile = file.openWrite(mode: FileMode.append);

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    _log('Flutter error: ${details.exception}');
    _log('Stack trace: ${details.stack}');
  };
}
void _log(String message) async {
  final now = DateTime.now();
  final timestamp = now.toIso8601String();

  if (now.day != currentLogDate.day) {
    await logFile.close();
    currentLogDate = now;
    await _initializeLogging();
  }

  final logLine = '$timestamp | $message';
  logFile.writeln(logLine);
}

Future<Widget> _buildApp() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  print('Application started');
  print('Database and services initialized');
  final prefs = await SharedPreferences.getInstance();
  final customDbPath = prefs.getString('dbpath');

  if (customDbPath != null && customDbPath.isNotEmpty) {
    // Use the custom DB path
    DatabaseHelper.setDatabasePath(customDbPath) ;

  }
  try {

    print('Tasks synchronized and processed');
  } catch (e, stackTrace) {
    print('Error processing tasks: $e');
    print('Stack trace: $stackTrace');
  }
  return MyApp();

}

class MyApp extends StatelessWidget {


  const MyApp({Key? key, }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
         appBarTheme: AppBarTheme(
             titleTextStyle:TextStyle(
               fontFamily: 'Courier', // Tu môžeš použiť jeden z preddefinovaných fontov
               fontSize: 25,
               fontWeight: FontWeight.bold,
               fontStyle: FontStyle.italic, // Pridanie kurzívy
               color: Colors.black, // Farba textu
             ),

         ),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: WorkplaceList(),
    );
  }
}

class AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      print('Application terminated');
      logFile.close();
    }
  }
}

Future<List<String>> getLogFiles() async {
  final prefs = await SharedPreferences.getInstance();
  final customLogPath = prefs.getString('log_path');

  final logDir = customLogPath != null && customLogPath.isNotEmpty
      ? Directory(customLogPath)
      : Directory(p.join((await getApplicationDocumentsDirectory()).path, 'logs'));

  if (!await logDir.exists()) return [];

  final files = await logDir.list().toList();
  return files
      .where((file) => file.path.endsWith('.txt'))
      .map((file) => p.basename(file.path))
      .toList()
    ..sort((a, b) => b.compareTo(a));
}

Future<String> readLogFile(String fileName) async {
  final prefs = await SharedPreferences.getInstance();
  final customLogPath = prefs.getString('log_path');

  final logDir = customLogPath != null && customLogPath.isNotEmpty
      ? Directory(customLogPath)
      : Directory(p.join((await getApplicationDocumentsDirectory()).path, 'logs'));

  final file = File(p.join(logDir.path, fileName));
  if (await file.exists()) {
    return await file.readAsString();
  }
  return 'No logs available.';
}