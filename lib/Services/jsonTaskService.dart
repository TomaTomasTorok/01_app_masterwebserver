import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../SQLite/database_helper.dart';
import '../model/task.dart';

class JsonTaskSynchronizer {
  final DatabaseHelper databaseHelper;

  JsonTaskSynchronizer(this.databaseHelper, );

  Future<void> synchronizeJsonWithDatabase(String workplace) async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final jsonFilePath = path.join(documentsDir.path, 'tasks.json');

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
