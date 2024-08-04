import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'dart:io';
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
    final data = [
      [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20],
      [99,1,99]
    ];

    // Presmerovať na ProductForm
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductForm(
          workplace: workplaceId,
          masterIp: masterIPs.first['master_ip'], // Použijeme prvú Master IP
          product: {'product': productName},
        ),
      ),
    );

    // Odoslať dáta na všetky Master_ip adresy a spracovať odpovede
    for (var masterIP in masterIPs) {
      try {
        final uri = Uri.parse('ws://${masterIP['master_ip']}:81');
        if (!isValidIpAddress(masterIP['master_ip'])) {
          throw FormatException('Invalid IP address format');
        }

        final channel = WebSocketChannel.connect(uri);
        await channel.ready;

        channel.sink.add(json.encode({"data": data}));

        channel.stream.listen(
              (message) async {
            print('Received message from ${masterIP['master_ip']}: $message');
            await processAndSaveResponse(databaseHelper, workplaceId, productName, masterIP['master_ip'], message);

            // Notifikovať ProductForm o novom senzore
            // Toto bude vyžadovať úpravu v ProductForm, aby mohol prijímať tieto notifikácie
            // a aktualizovať svoje zobrazenie
            NotificationService.notify('new_sensor_added');
          },
          onDone: () {
            print('WebSocket closed for ${masterIP['master_ip']}');
          },
          onError: (error) {
            print('WebSocket error for ${masterIP['master_ip']}: $error');
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error with ${masterIP['master_ip']}: $error')));
          },
        );
      } catch (e) {
        print('Error connecting to WebSocket for ${masterIP['master_ip']}: $e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connection error with ${masterIP['master_ip']}: $e')));
      }
    }
  } catch (e) {
    print('Unhandled error in handleLearning: $e');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('An unexpected error occurred: $e')));
  }
}

bool isValidIpAddress(String ipAddress) {
  try {
    return InternetAddress.tryParse(ipAddress) != null;
  } catch (e) {
    return false;
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

Future<void> processAndSaveResponse(DatabaseHelper databaseHelper, String workplaceId, String productName, String masterIP, String response) async {
  final parts = response.split(':');
  if (parts.length == 3) {
    final slave = int.parse(parts[0]);
    final sensor = int.parse(parts[2]);

    // Získať aktuálnu najvyššiu hodnotu sequence pre daný produkt
    final maxSequence = await databaseHelper.getMaxSequenceForProduct(workplaceId, productName);
    final newSequence = maxSequence + 1;

    // Uložiť dáta do databázy
    await databaseHelper.insertProductData({
      'workplace_id': workplaceId,
      'product': productName,
      'master_ip': masterIP,
      'slave': slave,
      'sensor': sensor,
      'sequence': newSequence,
      'sensor_type': 'Learned', // Môžete upraviť podľa potreby
      'sensor_value': 0.0, // Môžete upraviť podľa potreby
    });

    print('Saved data for $productName: Slave $slave, Sensor $sensor, Sequence $newSequence');
  } else {
    print('Invalid response format: $response');
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