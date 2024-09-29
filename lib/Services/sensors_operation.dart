import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class CallPositionService {
  WebSocketChannel? _channel;

  Future<void> callPosition(String masterIp, int slave, int sensor, int selected) async {
    try {

      await _initializeWebSocket(masterIp);
       Map<String, dynamic> callData;
      if (selected == 1) {
        print("object");
        callData = {
          "data": [
            [0],
            [slave, 1, sensor]
          ]
        };
      } else {
        print("objectOff");
        callData = {
          "data": [
            [0],[0,0,0]
          ]
        };
      }
     
      _channel?.sink.add(json.encode(callData));
      await Future.delayed(Duration(milliseconds: 1000));
      await _channel!.sink.close();
      _channel = null;
      print('Call position sent for Slave: ');


      // Počkáme na odpoveď a potom zatvoríme spojenie
   //   await _channel?.stream.first;
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