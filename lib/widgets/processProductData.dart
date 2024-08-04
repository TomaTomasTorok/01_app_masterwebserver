import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../SQLite/database_helper.dart';

class ProductDataProcessor {
  final String productName;
  final String workplaceId;
  final DatabaseHelper databaseHelper;
  Map<String, WebSocketChannel> channels = {};
  Map<String, StreamController<String>> streamControllers = {};

  ProductDataProcessor(this.productName, this.workplaceId, this.databaseHelper);

  Future<void> processProductData() async {
    print('Starting processProductData for product: $productName, workplace: $workplaceId');
    try {
      final productData = await _fetchProductData();
      print('Product data fetched successfully. Grouping data...');
      final groupedData = _groupDataBySequenceAndMasterIP(productData);
      print('Data grouped. Preparing WebSocket channels...');

      await _prepareWebSocketChannels(groupedData);
      print('WebSocket channels prepared. Starting to process cycles...');

      await _processCycles(groupedData);

      print('All cycles completed successfully');
    } catch (e) {
      print('Error in processProductData: $e');
      rethrow;
    } finally {
      await _closeResources();
    }
  }

  Future<List<Map<String, dynamic>>> _fetchProductData() async {
    print('Fetching product data from database for $productName...');
    try {
      final productData = await databaseHelper.getProductDataWithMasterIP(productName, workplaceId);
      if (productData.isEmpty) {
        print('No data found for product $productName');
        throw Exception('No data for this product');
      }
      print('Fetched ${productData.length} records for product: $productName');
      return productData;
    } catch (e) {
      print('Error fetching product data: $e');
      rethrow;
    }
  }

  Map<int, Map<String, List<Map<String, dynamic>>>> _groupDataBySequenceAndMasterIP(List<Map<String, dynamic>> data) {
    print('Grouping data by sequence and Master IP...');
    Map<int, Map<String, List<Map<String, dynamic>>>> groupedData = {};
    for (var item in data) {
      final sequence = item['sequence'] as int;
      final masterIP = item['master_ip'] as String;
      groupedData.putIfAbsent(sequence, () => {});
      groupedData[sequence]!.putIfAbsent(masterIP, () => []);
      groupedData[sequence]![masterIP]!.add(item);
    }
    print('Data grouped. Sequences: ${groupedData.keys.toList()}');
    groupedData.forEach((sequence, data) {
      print('Sequence $sequence: ${data.keys.length} Master IPs');
    });
    return groupedData;
  }

  Future<void> _prepareWebSocketChannels(Map<int, Map<String, List<Map<String, dynamic>>>> groupedData) async {
    print('Preparing WebSocket channels...');
    Set<String> allMasterIPs = {};
    groupedData.values.forEach((sequenceData) => allMasterIPs.addAll(sequenceData.keys));
    print('Unique Master IPs: $allMasterIPs');

    for (var masterIP in allMasterIPs) {
      try {
        print('Connecting to WebSocket for $masterIP...');
        final channel = await WebSocketChannel.connect(Uri.parse('ws://$masterIP:81'));
        channels[masterIP] = channel;
        streamControllers[masterIP] = StreamController<String>.broadcast();

        channel.stream.listen(
              (message) {
            print('Received message from $masterIP: $message');
            streamControllers[masterIP]!.add(message.toString());
          },
          onError: (error) => print('Error on WebSocket for $masterIP: $error'),
          onDone: () => print('WebSocket connection closed for $masterIP'),
        );

        print('Successfully connected to WebSocket for $masterIP');
      } catch (e) {
        print('Error connecting to WebSocket for $masterIP: $e');
      }
    }

    if (channels.isEmpty) {
      print('Failed to connect to any WebSocket');
      throw Exception('Failed to connect to any WebSocket');
    }
    print('WebSocket channels prepared: ${channels.length} channels');
  }

  Future<void> _processCycles(Map<int, Map<String, List<Map<String, dynamic>>>> groupedData) async {
    List<int> sortedSequences = groupedData.keys.toList()..sort();
    print('Processing cycles. Sorted sequences: $sortedSequences');
    for (var sequence in sortedSequences) {
      print('Starting to process sequence $sequence');
      Map<String, List<Map<String, dynamic>>> sequenceData = groupedData[sequence]!;
      print('Sequence $sequence: Processing ${sequenceData.length} Master IPs');

      Map<String, bool> confirmations = {};
      for (var masterIP in sequenceData.keys) {
        confirmations[masterIP] = false;
        print('Sending data to $masterIP for sequence $sequence');
        _sendDataToMasterIP(masterIP, sequenceData[masterIP]!);
      }

      print('Waiting for confirmations for sequence $sequence...');
      try {
        await _waitForConfirmations(confirmations);
        print('Sequence $sequence completed. All confirmations received.');
      } catch (e) {
        print('Error processing sequence $sequence: $e');
        print('Stopping process due to missing confirmations.');
        rethrow; // Re-throw the exception to stop the entire process
      }
    }
  }

  void _sendDataToMasterIP(String masterIP, List<Map<String, dynamic>> data) {
    try {
      print('Formatting data for $masterIP. ${data.length} items to send.');
      var formattedData = [
        [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20],
        ...data.map((item) => [item['slave'], item['sequence'], item['sensor']])
      ];
      print('Sending data to $masterIP: ${formattedData.length} rows');
      channels[masterIP]!.sink.add(json.encode({"data": formattedData}));
      print('Data sent successfully to $masterIP');
    } catch (e) {
      print('Error sending data to $masterIP: $e');
    }
  }

  Future<void> _waitForConfirmations(Map<String, bool> confirmations) async {
    print('Waiting for confirmations from ${confirmations.length} Master IPs');
    await Future.wait(confirmations.keys.map((masterIP) async {
      print('Starting to listen for confirmation from $masterIP');
      await for (var message in streamControllers[masterIP]!.stream) {
        print('Processing message from $masterIP: $message');
        if (message.toString().trim().toLowerCase() == 'master:hotovo' ||
            message.toString().trim().toLowerCase() == 'master: hotovo') {
          confirmations[masterIP] = true;
          print('Received confirmation from $masterIP');
          break;
        } else {
          print('Unrecognized message from $masterIP: $message');
        }
      }
    }));

    bool allConfirmed = confirmations.values.every((confirmed) => confirmed);
    if (!allConfirmed) {
      print('Warning: Not all master IPs confirmed. Confirmation status:');
      confirmations.forEach((masterIP, confirmed) {
        print('$masterIP: ${confirmed ? "Confirmed" : "Not confirmed"}');
      });
      throw Exception('Not all Master IPs confirmed');
    } else {
      print('All Master IPs confirmed successfully');
    }
  }

  Future<void> _closeResources() async {
    print('Closing WebSocket channels and stream controllers...');
    for (var entry in channels.entries) {
      try {
        await entry.value.sink.close();
        print('Closed WebSocket channel for ${entry.key}');
      } catch (e) {
        print('Error closing WebSocket channel for ${entry.key}: $e');
      }
    }
    for (var controller in streamControllers.values) {
      await controller.close();
    }
    print('All WebSocket channels and stream controllers closed');
  }
}

Future<void> processProductData(String productName, String workplaceId) async {
  print('Starting processProductData function for $productName in workplace $workplaceId');
  final databaseHelper = DatabaseHelper();
  final processor = ProductDataProcessor(productName, workplaceId, databaseHelper);
  await processor.processProductData();
  print('processProductData function completed for $productName in workplace $workplaceId');
}