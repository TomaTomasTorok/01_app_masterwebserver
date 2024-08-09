import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../SQLite/database_helper.dart';
import '../model/task.dart';
import '../widgets/processProductData.dart';

class TaskService {
  final DatabaseHelper _databaseHelper;
  late String jsonFilePath;

  TaskService(this._databaseHelper) {
    _initJsonFilePath();
  }

  Future<void> _initJsonFilePath() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    jsonFilePath = path.join(documentsDir.path, 'tasks.json');
  }

  Future<void> synchronizeJsonWithDatabase() async {
    try {
      await _initJsonFilePath();
      final file = File(jsonFilePath);
      if (!await file.exists()) {
        print('JSON file does not exist: $jsonFilePath');
        return;
      }

      final jsonString = await file.readAsString();
      final List<dynamic> jsonList = json.decode(jsonString);

      for (var item in jsonList) {
        final task = Task.fromJson(json.encode(item));
        bool taskExists = await _databaseHelper.taskExists(task);
        if (!taskExists) {
          task.status = 'NEW';
          await _databaseHelper.insertTask(task);
          print('Inserted new task: ${task.product}');
        }
      }
    } catch (e) {
      print('Error synchronizing JSON with database: $e');
    }
  }

  Future<void> processNewTasks() async {
    try {
      final newTasks = await _databaseHelper.getNewTasks();
      for (var task in newTasks) {
        final productExists = await _databaseHelper.productExists(task.product, 'ff');
        if (productExists) {
          try {
            await processProductData(task.product, 'ff');
            task.status = 'DONE';
            await _databaseHelper.updateTask(task);
            print('Task processed successfully: ${task.product}');
          } catch (e) {
            print('Error processing task: ${task.product}. Error: $e');
            task.status = 'ERROR';
            await _databaseHelper.updateTask(task);
          }
        } else {
          print('Product ${task.product} does not exist in product_data for workplace ff');
          task.status = 'INVALID';
          await _databaseHelper.updateTask(task);
        }
      }
    } catch (e) {
      print('Error processing new tasks: $e');
    }
  }
}
