import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import '../SQLite/database_helper.dart';
import '../model/task.dart';
import 'package:path/path.dart' as p;
// Upravte triedu JsonTaskSynchronizer
class JsonTaskSynchronizer {
  final DatabaseHelper databaseHelper;
  static String? _jsonPath;

  JsonTaskSynchronizer(this.databaseHelper);

  static Future<void> setJsonPath(String newPath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jsonpath', newPath);
    _jsonPath = newPath;
  }

  static Future<String> get jsonPath async {
    if (_jsonPath == null) {
      final prefs = await SharedPreferences.getInstance();
      _jsonPath = prefs.getString('jsonpath');
      if (_jsonPath == null || _jsonPath!.isEmpty) {
        final documentsDir = await getApplicationDocumentsDirectory();
        _jsonPath = documentsDir.path;
      }
    }
    return _jsonPath!;
  }

  Future<void> synchronizeJsonWithDatabase(String workplace) async {
    try {
      final jsonFilePath = p.join(await jsonPath, 'tasks.json');
      final file = File(jsonFilePath);
      if (!await file.exists()) {
        print('JSON file does not exist: $jsonFilePath');
        return;
      }

      final jsonString = await file.readAsString();
      final List<dynamic> jsonList = json.decode(jsonString);

      for (var item in jsonList) {
        final task = Task.fromJson(json.encode(item));
        bool taskExists = await databaseHelper.taskExists(task);
        if (!taskExists) {
          task.status = 'NEW';
          await databaseHelper.insertTask(task);
          print('Inserted new task: ${task.product}');
        }
      }
    } catch (e) {
      print('Error synchronizing JSON with database: $e');
    }
  }
}