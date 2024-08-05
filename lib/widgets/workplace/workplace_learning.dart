import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'dart:async';
import '../../SQLite/database_helper.dart';
import '../widget_productForm.dart';

Future<void> handleLearning(BuildContext context, String workplaceId, DatabaseHelper databaseHelper) async {
  try {
    // Požiadať užívateľa o názov produktu
    final productName = await showProductNameDialog(context);
    if (productName == null || productName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Product name is required')));
      return;
    }

    // Získať všetky Master_ip adresy pre dané pracovisko
    final masterIPs = await databaseHelper.getMasterIPsForWorkplace(workplaceId);
    if (masterIPs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No Master IPs found for this workplace')));
      return;
    }

    // Pripraviť dáta na odoslanie
    final data = {
      "data": [
        [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20],
        [99,1,99]
      ]
    };

    // Inicializácia WebSocket spojení a odoslanie dát
    Map<String, WebSocketChannel> channels = {};
    for (var masterIP in masterIPs) {
      try {
        final uri = Uri.parse('ws://${masterIP['master_ip']}:81');
        final channel = WebSocketChannel.connect(uri);
        channels[masterIP['master_ip']] = channel;
        await channel.ready;
        channel.sink.add(json.encode(data));
      } catch (e) {
        print('Error connecting to WebSocket for ${masterIP['master_ip']}: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection error with ${masterIP['master_ip']}: $e')),
        );
      }
    }

    // Presmerovať na ProductForm
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductForm(
          workplace: workplaceId,
          masterIp: masterIPs.first['master_ip'],
          product: {'product': productName},
          isLearningMode: true,
        ),
      ),
    );

    // Spracovanie odpovedí
    List<Future> futures = [];
    for (var entry in channels.entries) {
      futures.add(_processWebSocketMessages(
        context,
        entry.key,
        entry.value,
        databaseHelper,
        workplaceId,
        productName,
      ));
    }

    // Čakanie na dokončenie všetkých WebSocket spojení
    await Future.wait(futures);

    // Zatvorenie všetkých WebSocket spojení
    for (var channel in channels.values) {
      await channel.sink.close();
    }

    // Zobrazenie pop-up okna o ukončení procesu učenia
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        Future.delayed(Duration(seconds: 2), () {
          Navigator.of(context).pop(true);
        });
        return AlertDialog(
          title: Text('Learning Process Finished'),
          content: Text('The learning process has been completed for all Master IPs.'),
        );
      },
    );

  } catch (e) {
    print('Unhandled error in handleLearning: $e');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('An unexpected error occurred: $e')));
  }
}

Future<void> _processWebSocketMessages(
    BuildContext context,
    String masterIP,
    WebSocketChannel channel,
    DatabaseHelper databaseHelper,
    String workplaceId,
    String productName,
    ) async {
  await for (var message in channel.stream) {
    try {
      print('Received message from $masterIP: $message');
      await processAndSaveResponse(databaseHelper, workplaceId, productName, masterIP, message.toString());
      NotificationService.notify('new_sensor_added');
    } catch (e) {
      print('Error processing message from $masterIP: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing data from $masterIP: $e')),
      );
    }
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