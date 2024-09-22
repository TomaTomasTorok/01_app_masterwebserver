import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../SQLite/database_helper.dart';
import '../model/task.dart';

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
    RandomAccessFile? lockedFile;
    try {
      final jsonFilePath = p.join(await jsonPath, 'tasks.json');
      final file = File(jsonFilePath);
      if (!await file.exists()) {
        print('JSON file does not exist: $jsonFilePath');
        return;
      }

      // Lock the file for exclusive access
      lockedFile = await file.open(mode: FileMode.append);
      await lockedFile.lock();

      // Read the entire file content
      await lockedFile.setPosition(0);
      List<int> fileContent = await lockedFile.read(await lockedFile.length());
      String jsonString = utf8.decode(fileContent);

      List<dynamic> jsonList = [];

      try {
        jsonList = json.decode(jsonString);
      } catch (e) {
        print('Error decoding JSON: $e');
        // Attempt to fix JSON by adding missing bracket
        if (jsonString.trim().endsWith(',')) {
          jsonString = jsonString.trim().replaceAll(RegExp(r',\s*$'), '');
        }
        if (!jsonString.trim().endsWith(']')) {
          jsonString += ']';
        }
        jsonList = json.decode(jsonString);
      }

      // Check if there are more than 100 records
      if (jsonList.length > 200) {
        // Remove the first 50 records
        jsonList = jsonList.sublist(100);

        // Write the updated list back to the file
        String updatedJsonString = json.encode(jsonList);
        await lockedFile.setPosition(0);
        await lockedFile.writeString(updatedJsonString);
        await lockedFile.truncate(updatedJsonString.length);
        print('Removed the first 50 records from the JSON file.');
      }

      // Original logic for processing tasks
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
    } finally {
      // Always unlock and close the file, even if an error occurred
      if (lockedFile != null) {
        await lockedFile.unlock();
        await lockedFile.close();
      }
    }
  }
}