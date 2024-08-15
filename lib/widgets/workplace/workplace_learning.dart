import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'dart:async';
import '../../SQLite/database_helper.dart';
import '../widget_productForm.dart';

Future<Function> handleLearning(BuildContext context, String workplaceId, DatabaseHelper databaseHelper, Function finishCallback) async {
  Map<String, WebSocketChannel> channels = {};
  bool isFinished = false;

  try {
    final productName = await showProductNameDialog(context);
    if (productName == null || productName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Product name is required')));
      return () {};
    }

    final masterIPs = await databaseHelper.getMasterIPsForWorkplace(workplaceId);
    if (masterIPs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No Master IPs found for this workplace')));
      return () {};
    }

    final data = {
      "data": [
        [0],
        [99,1,99]
      ]
    };

    // Zobrazenie prekrytia načítavania
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        );
      },
    );

    bool hasError = false;

    for (var masterIP in masterIPs) {
      try {
        final uri = Uri.parse('ws://${masterIP['master_ip']}:81');
        final channel = WebSocketChannel.connect(uri);
        channels[masterIP['master_ip']] = channel;
        await channel.ready;
        channel.sink.add(json.encode(data));

        channel.stream.listen(
              (message) async {
            try {
           //   print('Received message from ${masterIP['master_ip']}: $message');
              await processAndSaveResponse(databaseHelper, workplaceId, productName, masterIP['master_ip'], message.toString());
              NotificationService.notify('new_sensor_added');
            } catch (e) {
              print('Error processing message from ${masterIP['master_ip']}: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error processing data from ${masterIP['master_ip']}: $e')),
              );
            }
          },
          onError: (error) => print('WebSocket error from ${masterIP['master_ip']}: $error'),
          onDone: () => print('WebSocket connection closed for ${masterIP['master_ip']}'),
        );
      } catch (e) {
        print('Error connecting to WebSocket for ${masterIP['master_ip']}: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection error with ${masterIP['master_ip']}: $e')),
        );
        hasError = true;
        break;  // Prerušíme cyklus pri prvej chybe
      }
    }

    // Odstránenie prekrytia načítavania
    Navigator.of(context).pop();

    if (hasError) {
      return () {};  // Vrátime prázdnu funkciu v prípade chyby
    }

    void onFinishLearning() {
      if (!isFinished) {
        isFinished = true;
        for (var channel in channels.values) {
          channel.sink.close();
        }
        finishCallback();
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductForm(
          workplace: workplaceId,
          masterIp: masterIPs.first['master_ip'],
          product: {'product': productName},
          isLearningMode: true,
          onFinishLearning: onFinishLearning,
        ),
      ),
    );

    // Return a function that closes all WebSocket connections
    return () {
      if (!isFinished) {
        isFinished = true;
        for (var channel in channels.values) {
          channel.sink.close();
        }
        finishCallback();
        print('Cleaning up learning process for $workplaceId');
      }
    };
  } catch (e) {
    // Odstránenie prekrytia načítavania v prípade chyby
    Navigator.of(context).pop();
    print('Unhandled error in handleLearning: $e');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('An unexpected error occurred: $e')));
    return () {};
  }
}

Future<String?> showProductNameDialog(BuildContext context) async {
  final TextEditingController controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Enter Product Name'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: "Product Name"),
        ),
        actions: <Widget>[
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: Text('OK'),
            onPressed: () => Navigator.of(context).pop(controller.text),
          ),
        ],
      );
    },
  );
}

Future<void> processAndSaveResponse(
    DatabaseHelper databaseHelper,
    String workplaceId,
    String productName,
    String masterIP,
    String response
    ) async {
  final parts = response.split(':');
  if (parts.length == 3) {
    final slave = int.parse(parts[0]);
    final sensor = int.parse(parts[2]);

    final maxSequence = await databaseHelper.getMaxSequenceForProduct(workplaceId, productName);
    final newSequence = maxSequence + 1;

    await databaseHelper.insertProductData({
      'workplace_id': workplaceId,
      'product': productName,
      'master_ip': masterIP,
      'slave': slave,
      'sensor': sensor,
      'sequence': newSequence,
      'sensor_type': 'Learned',
      'sensor_value': 0.0,
    });

    print('Saved data for $productName: Slave $slave, Sensor $sensor, Sequence $newSequence');
  } else {
    print('Invalid response format: $response');
    throw FormatException('Invalid response format received from Master IP');
  }
}

class NotificationService {
  static final List<Function> _listeners = [];

  static void addListener(Function listener) {
    _listeners.add(listener);
  }

  static void removeListener(Function listener) {
    _listeners.remove(listener);
  }

  static void notify(String message) {
    for (var listener in _listeners) {
      listener(message);
    }
  }
}