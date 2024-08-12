import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:web_socket_channel/io.dart';
import '../SQLite/database_helper.dart';
import '../model/task.dart';
import '../widgets/processProductData.dart';
import '../widgets/workplace/workplace_testing.dart';

class TaskService {
  final DatabaseHelper _databaseHelper;
  late String jsonFilePath;
  final List<ProductDataProcessor> _processors = [];
  Task? _finishedTask;
  bool isBlocked = false;
  final DateTime _now = DateTime.now();

  TaskService(this._databaseHelper) {
    _initJsonFilePath();
  }

  Future<void> _initJsonFilePath() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    jsonFilePath = path.join(documentsDir.path, 'tasks.json');
  }

  Future<void> cancelProcessor(String workplace) async {
    try {
      for (var processor in _processors) {
        processor.isCancel = true;
        print("Processor stopped for product: ${processor.productName}");
      }
      await _stopProcessing(workplace);
      _updateFinishedTaskIfExists();
      _processors.clear();
    } catch (e) {
      print("Error in cancelProcessor: $e");
    }
  }

  void _updateFinishedTaskIfExists() {
    if (_finishedTask != null) {
      _finishedTask!.status = 'Done';
      _finishedTask!.workstationProcessed = 'Manual Done';
      _finishedTask!.timestampProcessed = _now.toUtc();
      _databaseHelper.updateTask(_finishedTask!);
    }
  }

  Future<void> _stopProcessing(String workplaceId) async {
    try {
      final masterIPs = await _databaseHelper.getMasterIPsForWorkplace(workplaceId);
      if (masterIPs.isEmpty) return;

      final data = {
        "data": [
          [0, 2, 3],
          [0, 0, 0]
        ]
      };

      for (var masterIP in masterIPs) {
        await _sendStopSignalToMasterIP(masterIP['master_ip'], data);
      }
    } catch (e) {
      print('Unhandled error in stopProcessing: $e');
    }
  }

  Future<void> _sendStopSignalToMasterIP(String masterIP, Map<String, dynamic> data) async {
    try {
      if (!isValidIpAddress(masterIP)) {
        throw FormatException('Invalid IP address format');
      }

      final uri = Uri.parse('ws://$masterIP:81');
      WebSocket socket = await WebSocket.connect(uri.toString())
          .timeout(Duration(seconds: 5));
      final channel = IOWebSocketChannel(socket);

      channel.sink.add(json.encode(data));
      await Future.delayed(Duration(milliseconds: 100));
      await channel.sink.close();
    } catch (e) {
      print('Error connecting to WebSocket for $masterIP: $e');
    }
  }

  Future<void> processNewTasks(String workplace) async {
    try {
      isBlocked = true;
      final newTasks = await _databaseHelper.getNewTasks(workplace);

      if (newTasks.isNotEmpty) {
        await cancelProcessor(workplace);
        print("Terminated tasks for new task");
      } else {
        isBlocked = false;
        return;
      }

      for (var task in newTasks) {
        await _processTask(task, workplace);
      }
    } catch (e) {
      isBlocked = false;
      print('Error processing new tasks: $e');
    }
  }

  Future<void> _processTask(Task task, String workplace) async {
    final productExists = await _databaseHelper.productExists(task.product, workplace);
    if (!productExists) {
      print('Product ${task.product} does not exist in product_data for workplace $workplace');
      return;
    }

    try {
      task.status = 'Ongoing';
      await _databaseHelper.updateTask(task);
      _finishedTask = task;
      isBlocked = false;

      final processor = ProductDataProcessor(task.product, workplace, _databaseHelper);
      _processors.add(processor);
      await processor.processProductData();
      if(processor.isCancel==false) {
        _updateTaskOnCompletion(task, workplace);
      }
      _processors.remove(processor);
      print('Task processed successfully: ${task.product}');
    } catch (e) {
      _handleTaskProcessingError(task, e);
    }
  }

  void _updateTaskOnCompletion(Task task, String workplace) {
    _finishedTask = null;
    task.status = 'DONE';
    task.workstationProcessed = workplace;
    task.timestampProcessed = _now.toUtc();
    _databaseHelper.updateTask(task);
  }

  void _handleTaskProcessingError(Task task, dynamic error) {
    isBlocked = false;
    print('Error processing task: ${task.product}. Error: $error');
    _finishedTask = null;
    task.status = 'ERROR';
    _databaseHelper.updateTask(task);
  }
}