import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import '../../SQLite/database_helper.dart';

class TestingManager {
  Map<String, bool> testingState = {};
  Map<String, List<WebSocketChannel>> activeChannels = {};

  bool isTestingForWorkplace(String workplaceId) {
    return testingState[workplaceId] ?? false;
  }

  Future<void> toggleTesting(BuildContext context, String workplaceId, DatabaseHelper databaseHelper, VoidCallback updateUI) async {
    if (!isTestingForWorkplace(workplaceId)) {
      await startTesting(context, workplaceId, databaseHelper);
    } else {
      await stopTesting(context, workplaceId);
    }
    testingState[workplaceId] = !isTestingForWorkplace(workplaceId);
    updateUI();
  }

  Future<void> startTesting(BuildContext context, String workplaceId, DatabaseHelper databaseHelper) async {
    try {
      final masterIPs = await databaseHelper.getMasterIPsForWorkplace(workplaceId);
      if (masterIPs.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No Master IPs found for this workplace')));
        }
        return;
      }

      final data = {
        "data": [
          [0],
          [99,0,0]
        ]
      };

      activeChannels[workplaceId] = [];

      for (var masterIP in masterIPs) {
        try {
          final uri = Uri.parse('ws://${masterIP['master_ip']}:81');
          if (!isValidIpAddress(masterIP['master_ip'])) {
            throw FormatException('Invalid IP address format');
          }

          WebSocket socket = await WebSocket.connect(uri.toString())
              .timeout(Duration(seconds: 5));
          final channel = IOWebSocketChannel(socket);
          activeChannels[workplaceId]!.add(channel);

          channel.sink.add(json.encode(data));

          channel.stream.listen(
                (message) {
         //     print('Received message from ${masterIP['master_ip']}: $message');
              // No processing of received data
            },
            onDone: () {
              print('WebSocket closed for ${masterIP['master_ip']}');
            },
            onError: (error) {
              print('WebSocket error for ${masterIP['master_ip']}: $error');
            },
          );
        } catch (e) {
          print('Error connecting to WebSocket for ${masterIP['master_ip']}: $e');
        }
      }
    } catch (e) {
      print('Unhandled error in startTesting: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('An unexpected error occurred: $e')));
      }

    }
  }

  Future<void> stopTesting(BuildContext context, String workplaceId) async {
    if (activeChannels.containsKey(workplaceId)) {
      final stopData = {
        "data": [
          [0,2,3],
          [0,0,0]
        ]
      };

      for (var channel in activeChannels[workplaceId]!) {
        try {
          channel.sink.add(json.encode(stopData));
          await Future.delayed(Duration(milliseconds: 100)); // Daj čas na odoslanie správy
          await channel.sink.close();
        } catch (e) {
          print('Error sending stop signal or closing channel: $e');
        }
      }
      // Po uzavretí všetkých kanálov vymaž všetky záznamy pre dané workplaceId
      activeChannels.remove(workplaceId);
    } else {
      print('No active channels found for $workplaceId to stop.');
    }
  }


}
bool isValidIpAddress(String ipAddress) {
  try {
    return InternetAddress.tryParse(ipAddress) != null;
  } catch (e) {
    return false;
  }
}