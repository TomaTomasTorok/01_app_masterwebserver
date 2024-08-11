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
  List<ProductDataProcessor> processors = []; // Zoznam na uloženie všetkých procesorov
  bool isStopTask=false;
   Task? finishedTask=null;
  bool isBolocked = false;

  late ProductDataProcessor processor;
  TaskService(this._databaseHelper) {
    _initJsonFilePath();
  }

  Future<void> _initJsonFilePath() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    jsonFilePath = path.join(documentsDir.path, 'tasks.json');
  }

  Future<void> cancelProcessor(String workplace) async {
   // isStopTask=true;
    try{
    for (var processor in processors) {
      processor.isCancel = true;
      print("Processor stopped for product: ${processor.productName}");
    }
    await  stopProcessing(workplace ,_databaseHelper);
    if(finishedTask != null){
    finishedTask!.status = 'Done';
    finishedTask!.workstationProcessed = 'Manual Done';
    await _databaseHelper.updateTask(finishedTask!);}
  }
    catch(e){print(e);}
  }

  Future<void> stopProcessing( String workplaceId, DatabaseHelper databaseHelper) async {
    try {
      final masterIPs = await databaseHelper.getMasterIPsForWorkplace(workplaceId);
      if (masterIPs.isEmpty) {

        return;
      }

      final data = {
        "data": [
          [0,2,3],
          [0,0,0]
        ]
      };



      for (var masterIP in masterIPs) {
        try {
          final uri = Uri.parse('ws://${masterIP['master_ip']}:81');
          if (!isValidIpAddress(masterIP['master_ip'])) {
            throw FormatException('Invalid IP address format');
          }

          WebSocket socket = await WebSocket.connect(uri.toString())
              .timeout(Duration(seconds: 5));
          final channel = IOWebSocketChannel(socket);


          channel.sink.add(json.encode(data));
          await Future.delayed(Duration(milliseconds: 100));
          channel.sink.close();

        } catch (e) {
          print('Error connecting to WebSocket for ${masterIP['master_ip']}: $e');
        }
      }
    } catch (e) {
      print('Unhandled error in startTesting: $e');

    }
  }



  Future<void> processNewTasks(String workplace) async {
    try {
      isBolocked= true;
      final newTasks = await _databaseHelper.getNewTasks(workplace);
     if (newTasks.isNotEmpty){
       await cancelProcessor(workplace);
       print("Ukončené ulohy nový task");
            }
     else{isBolocked= false;}
      for (var task in newTasks) {

        final productExists = await _databaseHelper.productExists(task.product, workplace);
        if (productExists) {
          try {
            task.status = 'Ongoing';
            await _databaseHelper.updateTask(task);
            // Tu vytvoríme objekt ProductDataProcessor a použijeme ho na spracovanie úlohy
            finishedTask=task;
            isBolocked= false;
             processor = ProductDataProcessor(task.product, workplace, _databaseHelper);
            processors.add(processor); // Pridáme processor do zoznamu
            await processor.processProductData();
            finishedTask=null;
            task.status = 'DONE';
            await _databaseHelper.updateTask(task);
            print('Task processed successfully: ${task.product}');
          } catch (e) {
            isBolocked= false;
            print('Error processing task: ${task.product}. Error: $e');
            finishedTask=null;
            task.status = 'ERROR';
            await _databaseHelper.updateTask(task);
          }
        } else {
          isBolocked= false;
          print('Product ${task.product} does not exist in product_data for workplace ff');
          finishedTask=null;
        //  task.status = 'INVALID';
        //  await _databaseHelper.updateTask(task);
        }


      }
    } catch (e) {
      isBolocked= false;
      print('Error processing new tasks: $e');
    }
  }
}