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
    final prefs = await SharedPreferences.getInstance();
    final useMultipleJsonFiles = prefs.getBool('use_multiple_json_files') ?? false;

    if (useMultipleJsonFiles) {
      await synchronizeMultipleJsonFiles(workplace);
    } else {
      await synchronizeSingleJsonFile(workplace);
    }
  }

  Future<void> synchronizeSingleJsonFile(String workplace) async {
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

      // Check if there are more than 200 records
      if (jsonList.length > 200) {
        // Remove the first 100 records
        jsonList = jsonList.sublist(100);

        // Write the updated list back to the file
        String updatedJsonString = json.encode(jsonList);
        await lockedFile.setPosition(0);
        await lockedFile.writeString(updatedJsonString);
        await lockedFile.truncate(updatedJsonString.length);
        print('Removed the first 100 records from the JSON file.');
      }

      // Process tasks
      for (var item in jsonList) {
        final task = Task.fromJson(json.encode(item));
        if (task.forWorkstation == workplace) {
          bool taskExists = await databaseHelper.taskExists(task);
          if (!taskExists) {
            task.status = 'NEW';
            await databaseHelper.insertTask(task);
            print('Inserted new task: ${task.product}');
          }
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

  Future<void> synchronizeMultipleJsonFiles(String workplace) async {
    try {
      final directory = Directory(await jsonPath);
      final files = directory.listSync()
          .whereType<File>()
          .where((file) => p.basename(file.path).startsWith(workplace) && file.path.endsWith('.json'))
          .toList();

      for (var file in files) {
        RandomAccessFile? lockedFile;
        try {
          // Lock the file for exclusive access
          lockedFile = await file.open(mode: FileMode.append);
          await lockedFile.lock();

          // Read the entire file content
          await lockedFile.setPosition(0);
          List<int> fileContent = await lockedFile.read(await lockedFile.length());
          String jsonString = utf8.decode(fileContent);

          dynamic jsonData = json.decode(jsonString);
          List<dynamic> jsonList;

          if (jsonData is Map<String, dynamic>) {
            // If it's a single object, wrap it in a list
            jsonList = [jsonData];
          } else if (jsonData is List<dynamic>) {
            jsonList = jsonData;
          } else {
            throw FormatException('Unexpected JSON format in file: ${file.path}');
          }

          for (var item in jsonList) {
            final task = Task.fromJson(json.encode(item));
            bool taskExists = await databaseHelper.taskExists(task);
            if (!taskExists) {
              task.status = 'NEW';
              await databaseHelper.insertTask(task);
              print('Inserted new task: ${task.product}');
            }
          }

          // Delete the processed file
          await lockedFile.close();
          await file.delete();
          print('Deleted processed file: ${file.path}');
        } catch (e) {
          print('Error processing file ${file.path}: $e');
          if (e is FormatException) {
            print('JSON content: ${await file.readAsString()}');
          }
        } finally {
          // Always unlock and close the file, even if an error occurred
          if (lockedFile != null) {
            await lockedFile.unlock();
            await lockedFile.close();
          }
        }
      }
    } catch (e) {
      print('Error synchronizing multiple JSON files with database: $e');
    }
  }

}