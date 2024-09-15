


  import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;  // Pridaný import pre 'p'
import '../SQLite/database_helper.dart';
import '../SQLite/database_helper.dart';
import '../SQLite/database_helper.dart';
import '../main.dart';
import 'jsonTaskService.dart';


  void showSettingsDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final currentLogPath = prefs.getString('logpath') ?? 'Default Log Path';
    final currentDbPath = prefs.getString('dbpath') ?? 'Default DB Path';
    final currentJsonPath = prefs.getString('jsonpath') ?? 'Default JSON Path';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('Log Files Path'),
                subtitle: Text(currentLogPath),
                trailing: Icon(Icons.folder),
                onTap: () => pickFolder(context, 'logpath', currentLogPath),
              ),
              ListTile(
                title: Text('SQLite DB Path'),
                subtitle: Text(currentDbPath),
                trailing: Icon(Icons.folder),
                onTap: () => pickFolder(context, 'dbpath', currentDbPath),
              ),
              ListTile(
                title: Text('JSON Files Path'),
                subtitle: Text(currentJsonPath),
                trailing: Icon(Icons.folder),
                onTap: () => pickFolder(context, 'jsonpath', currentJsonPath),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void pickFolder(BuildContext context, String key, String currentPath) async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, selectedDirectory);
      updateAppPaths();

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Path Updated'),
            content: Text('The ${key == 'logpath' ? 'Log' : key == 'dbpath' ? 'DB' : 'JSON'} path has been updated to:\n$selectedDirectory'),
            actions: <Widget>[
              TextButton(
                child: Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          );
        },
      );
    }
  }

  void updateAppPaths() async {
    final prefs = await SharedPreferences.getInstance();
    final newLogPath = prefs.getString('logpath');
    final newDbPath = prefs.getString('dbpath');
    final newJsonPath = prefs.getString('jsonpath');

    if (newLogPath != null && newLogPath.isNotEmpty) {
      await reinitializeLogging(newLogPath);
    }

    if (newDbPath != null && newDbPath.isNotEmpty) {
      await reinitializeDatabase(newDbPath);
    }

    if (newJsonPath != null && newJsonPath.isNotEmpty) {
      await reinitializeJsonPath(newJsonPath);
    }
  }
  Future<void> reinitializeJsonPath(String newJsonPath) async {
    // Update the JSON path in JsonTaskSynchronizer
    await JsonTaskSynchronizer.setJsonPath(newJsonPath);
    print('JSON path reinitialized with new path: $newJsonPath');
  }
  Future<void> reinitializeLogging(String newLogPath) async {
    await logFile.close();

    final logDir = Directory(newLogPath);
    if (!await logDir.exists()) await logDir.create(recursive: true);

    currentLogDate = DateTime.now();
    final formattedDate = '${currentLogDate.year}-${currentLogDate.month.toString().padLeft(2, '0')}-${currentLogDate.day.toString().padLeft(2, '0')}';
    final file = File(p.join(logDir.path, '${formattedDate}_app_log.txt'));

    if (!await file.exists()) await file.create();
    logFile = file.openWrite(mode: FileMode.append);

    print('Logging reinitialized with new path: $newLogPath');
  }
  Future<void> reinitializeDatabase(String newDbPath) async {
    // Close the current database connection
    await DatabaseHelper.closeDatabase();

    // Update the database path
    DatabaseHelper.setDatabasePath(newDbPath);

    // Create a new database helper instance to use the new path
    final dbHelper = DatabaseHelper();
    await dbHelper.database; // This will create or open the database at the new location

    print('Database reinitialized with new path: $newDbPath');
  }
  //
  // Future<void> restartServices() async {
  //   // Reinitialize your JsonTaskSynchronizer
  //   jsonTaskSynchronizer = JsonTaskSynchronizer(_databaseHelper);
  //
  //   // Reinitialize your TaskService
  //   _taskService = TaskService(_databaseHelper);
  //
  //   // If you have any other services that depend on the database or log files,
  //   // reinitialize them here
  //
  //   print('Services restarted with new configurations');
  // }