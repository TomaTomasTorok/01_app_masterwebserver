import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../SQLite/database_helper.dart';

class CallPositionService {
  WebSocketChannel? _channel;

  Future<void> callPosition(String masterIp, int slave, int sensor, int selected) async {
    try {
      await _initializeWebSocket(masterIp);
      Map<String, dynamic> callData;
      if (selected == 1) {

        callData = {
          "data": [
            [0],
            [slave, 1, sensor]
          ]
        };
      } else {

        callData = {
          "data": [
            [0]
      //      ,[0,0,0]
          ]
        };
      }

      _channel?.sink.add(json.encode(callData));
      await Future.delayed(Duration(milliseconds: 1000));
      await _channel!.sink.close();
      _channel = null;
      print('Call position sent for Slave: $slave, Sensor: $sensor');

    } catch (e) {
      print('Error calling position: $e');
    } finally {
      _closeWebSocket();
    }
  }

  Future<void> _initializeWebSocket(String masterIp) async {
    _channel = WebSocketChannel.connect(Uri.parse('ws://$masterIp:81'));
    await _channel?.ready;
  }

  void _closeWebSocket() {
    _channel?.sink.close();
    _channel = null;
  }
}

class SensorOperations {
  final BuildContext context;
  final DatabaseHelper databaseHelper;

  SensorOperations(this.context, this.databaseHelper);

  Future<void> remapSensor(Map<String, dynamic> item) async {
    print('Starting remapping process for sensor: ${item['id']}');
    WebSocketChannel? channel;
    try {
      final remapData = {
        "data": [
          [0],
          [99, 2, item['sensor']]
        ]
      };

      channel = await initializeWebSocket(item['master_ip']);
      channel.sink.add(json.encode(remapData));

      // Show remapping progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Remapping in Progress'),
            content: Text('Please wait while the sensor is being remapped...'),
          );
        },
      );

      await for (var message in channel.stream) {
        final parts = message.toString().split(':');
        if (parts.length == 3) {
          final newSlave = int.parse(parts[0]);
          final newSensor = int.parse(parts[2]);
          final newPosition = {
            'slave': newSlave,
            'sensor': newSensor,
          };
          await updateSensorPosition(item['id'], newPosition);
          Navigator.of(context).pop(); // Close progress dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sensor remapped successfully to Slave: $newSlave, Sensor: $newSensor')),
          );
          break;
        }
      }
    } catch (e) {
      print('Error during remapping: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred during remapping: $e')),
      );
    } finally {
      sendClosingDataAndCloseWebSocket(channel);
    }
  }

  Future<void> updateSensorPosition(int sensorId, Map<String, dynamic> newPosition) async {
    try {
      await databaseHelper.updateProductData(sensorId, newPosition);
    } catch (e) {
      print('Error updating sensor position: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update sensor position: $e')),
      );
    }
  }

  Future<WebSocketChannel> initializeWebSocket(String masterIp) async {
    final channel = WebSocketChannel.connect(Uri.parse('ws://$masterIp:81'));
    await channel.ready;
    return channel;
  }

  void sendClosingDataAndCloseWebSocket(WebSocketChannel? channel) async {
    if (channel != null) {
      final closingData = {
        "data": [
          [0]
     //     ,[0,0,0]
        ]
      };
      channel.sink.add(json.encode(closingData));
      await Future.delayed(Duration(milliseconds: 100));
      await channel.sink.close();
    }
  }
}