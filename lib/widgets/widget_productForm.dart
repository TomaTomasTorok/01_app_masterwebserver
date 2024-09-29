import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:masterwebserver/widgets/widget_productForm_popUp.dart';
import 'package:masterwebserver/widgets/workplace/workplace_learning.dart';
import '../../SQLite/database_helper.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

import '../Services/sensors_operation.dart';

class ProductForm extends StatefulWidget {
  final String workplace;
  final String masterIp;
  final Map<String, dynamic> product;
  final bool isLearningMode;
  final Function? onFinishLearning;

  ProductForm({
    required this.workplace,
    required this.masterIp,
    required this.product,
    this.isLearningMode = false,
    this.onFinishLearning,
  });

  @override
  _ProductFormState createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductForm> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  List<Map<String, dynamic>> _items = [];
  bool _showFinishLearnButton = true;
  late SensorRenamer _sensorRenamer;
  WebSocketChannel? _channel;
  late CallPositionService _callPositionService;
  bool _isRemapping = false;
  Map<int, bool> _callPositionStates = {};

  @override
  void initState() {
    super.initState();
    _sensorRenamer = SensorRenamer(context, _databaseHelper);
    _loadProductData();
    NotificationService.addListener(_onNewSensorAdded);
    _callPositionService = CallPositionService();
  }

  @override
  void dispose() {
    NotificationService.removeListener(_onNewSensorAdded);
    super.dispose();
  }
  Future<void> _toggleCallPosition(Map<String, dynamic> item) async {
    int itemId = item['id'];
    bool wasActive = _callPositionStates[itemId] ?? false;
    // Deaktivujeme všetky tlačidlá
    _callPositionStates.updateAll((key, value) => false);
    // Ak tlačidlo nebolo aktívne, aktivujeme ho. Ak bolo aktívne, zostane deaktivované.
    if (!wasActive) {
      _callPositionStates[itemId] = true;
    }
    setState(() {});
    // Odošleme príslušný stav
    int state = _callPositionStates[itemId]! ? 1 : 0;
     _callPositionService.callPosition(item['master_ip'], item['slave'], item['sensor'], state);
    // Vizuálna spätná väzba - krátke bliknutie
    if (mounted) {
      setState(() {
        _callPositionStates[itemId] = false;
      });
      await Future.delayed(Duration(milliseconds: 200));
      if (mounted) {
        setState(() {
          _callPositionStates[itemId] = state == 1;
        });
      }
    }
  }

  void _onNewSensorAdded(String message) {
    if (message == 'new_sensor_added') {
      _loadProductData();
    }
  }

  Future<void> _loadProductData() async {
    try {
      final data = await _databaseHelper.getProductDataWithMasterIP(
          widget.product['product'],
          widget.workplace
      );
      setState(() {
        _items = data;
      });
    } catch (e) {
      print('Error loading product data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load product data')),
      );
    }
  }

  Future<void> _remapSensor(Map<String, dynamic> item) async {
    if (_isRemapping) return; // Prevent multiple remapping processes
    _isRemapping = true;

    print('Starting remapping process for sensor: ${item['id']}');
    try {
      final remapData = {
        "data": [
          [0],
          [99, 2, item['sensor']]
        ]
      };

      print('Initializing WebSocket connection to ${item['master_ip']}');
      _channel = await _initializeWebSocket(item['master_ip']);

      print('Sending remap data: $remapData');
      _channel?.sink.add(json.encode(remapData));

      if (!mounted) return;

      print('Showing remapping progress dialog');
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

      print('Waiting for WebSocket response...');
      await _channel?.stream.listen((message) {
        print('Received WebSocket message: $message');

        if (!mounted) return;

        try {
          final parts = message.toString().split(':');
          if (parts.length == 3) {
            final newSlave = int.parse(parts[0]);
            final newSensor = int.parse(parts[2]);

            print('New Slave: $newSlave, New Sensor: $newSensor');

            final newPosition = {
              'slave': newSlave,
              'sensor': newSensor,
            };

            print('Updating sensor position for sensor ID: ${item['id']}');
            _updateSensorPosition(item['id'], newPosition);

            print('Closing remapping progress dialog');
            Navigator.of(context).pop();

            print('Remapping process completed successfully');

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Sensor remapped successfully to Slave: $newSlave, Sensor: $newSensor')),
            );

            // Send closing data and close the WebSocket connection
            _sendClosingDataAndCloseWebSocket();
          } else {
            throw FormatException('Unexpected message format');
          }
        } catch (e) {
          print('Error processing WebSocket message: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error processing remapping response')),
            );
          }
        } finally {
          _isRemapping = false;
        }
      }).asFuture();

    } catch (e) {
      print('Error during remapping: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred during remapping')),
        );
      }
    } finally {
      _isRemapping = false;
      // Ensure closing data is sent and WebSocket is closed even if an error occurred
      _sendClosingDataAndCloseWebSocket();
    }
  }

  void _sendClosingDataAndCloseWebSocket() async {
    if (_channel != null) {
      print('Sending closing data before closing WebSocket connection');
      final closingData = {
        "data": [
          [0],[0,0,0]

        ]
      };
      _channel!.sink.add(json.encode(closingData));

      // Wait a short time to ensure the data is sent before closing
      await Future.delayed(Duration(milliseconds: 100));

      print('Closing WebSocket connection');
      await _channel!.sink.close();
      _channel = null;
    }
  }

  Future<WebSocketChannel> _initializeWebSocket(String masterIp) async {
    final channel = WebSocketChannel.connect(Uri.parse('ws://$masterIp:81'));
    await channel.ready;
    return channel;
  }

  Future<void> _updateSensorPosition(int sensorId, Map<String, dynamic> newPosition) async {
    try {
      await _databaseHelper.updateProductData(sensorId, newPosition);
      _loadProductData(); // Aktualizujeme zoznam po zmene
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sensor remapped successfully')),
      );
    } catch (e) {
      print('Error updating sensor position: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update sensor position')),
      );
    }
  }

  Future<void> _deleteProduct(int sensorId) async {
    await _databaseHelper.deleteSensor(sensorId, );
    _loadProductData();
  }
  void _showDeleteConfirmation(int sensorId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Sensor'),
          content: Text('Are you sure you want to delete Sensor?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Delete'),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteProduct(sensorId);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _renameSensorInWorkplace(Map<String, dynamic> item) async {
    String? newName = await _sensorRenamer.renameSensorInWorkplace(item, widget.workplace);
    if (newName != null) {
      _loadProductData(); // Reload data after renaming
    }
  }


  Future<void> _renameSensor(Map<String, dynamic> item) async {
    String? newName = await _sensorRenamer.renameSensor(item, widget.workplace, widget.product['product']);
    if (newName != null) {
      _loadProductData(); // Reload data after renaming
    }
  }


  Future<void> stopTesting() async {
    if (_channel != null) {
      final stopData = {
        "data": [
          [0],
          [0,0,0]
        ]
      };

      try {
        _channel!.sink.add(json.encode(stopData));
        await Future.delayed(Duration(milliseconds: 100)); // Give some time for the message to be sent
        await _channel!.sink.close();
        _channel = null;
      } catch (e) {
        print('Error sending stop signal or closing channel: $e');
      }
    }
  }

  Future<void> _finishLearn() async {
    try {
      await stopTesting();
      widget.onFinishLearning?.call();

      await showDialog(
        context: context,
        builder: (BuildContext context) {
          Future.delayed(Duration(seconds: 2), () {
            Navigator.of(context).pop(true);
          });
          return AlertDialog(
            title: Text('Learning Process Finished'),
            content: Text('The learning process has been completed successfully.'),
          );
        },
      );

      setState(() {
        _showFinishLearnButton = false;
      });
    } catch (e) {
      print('Error in finish learn process: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred while finishing the learning process')),
      );
    }
  }

  void _showAddOrEditItemDialog({Map<String, dynamic>? item}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ProductFormPopup(
          item: item,
          workplace: widget.workplace,
          masterIp: widget.masterIp,
          product: widget.product['product'],
          onSave: (Map<String, dynamic> newItem) async {
            try {
              if (item == null) {
                final id = await _databaseHelper.insertProductData(newItem);
                setState(() {
                  _items = [..._items, {...newItem, 'id': id}];
                });
              } else {
                await _databaseHelper.updateProductData(item['id'], newItem);
                setState(() {
                  _items = _items.map((i) => i['id'] == item['id'] ? {...newItem, 'id': item['id']} : i).toList();
                });
              }
              _loadProductData(); // Reload data after adding/editing
            } catch (e) {
              print('Error saving sensor data: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to save sensor data')),
              );
            }
          },
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
        icon: Icon(Icons.arrow_back),
    onPressed: ()  async {
      if (widget.isLearningMode && _showFinishLearnButton){
       await   _finishLearn();
       Navigator.of(context).pop();}
  else{  Navigator.of(context).pop();}
    },),

        title: Text("Sensors for ${widget.product['product']} in ${widget.workplace}"),
        actions: [
          if (widget.isLearningMode && _showFinishLearnButton)
            IconButton(
              icon: Icon(Icons.check),
              onPressed: _finishLearn,
              tooltip: 'Finish Learn',
            ),
        ],
      ),
      body: _items.isEmpty
          ? Center(child: Text('Learning in progress... Waiting for sensors.'))
          : ListView.builder(
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          bool isCallPositionActive = _callPositionStates[item['id']] ?? false;
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListTile(
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black54,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.sensors, color: Colors.greenAccent),
                ],
              ),
              title: Text(
                '${item['sensor_type']},   Sequence: ${item['sequence']}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('Slave: ${item['slave']},   Sensor: ${item['sensor']}'),
              onTap: () => _showAddOrEditItemDialog(item: item),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [   ElevatedButton(
                  child: Text('Rename'),
                  onPressed: () => _renameSensor(item),
                ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    child: Text('Rename in workplace'),
                    onPressed: () => _renameSensorInWorkplace(item),
                  ),
                  SizedBox(width: 80),
                  ElevatedButton(
                    child: Text('Call Position'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCallPositionActive ? Colors.green : null,
                      foregroundColor: isCallPositionActive ? Colors.white : null,
                    ),
                    onPressed: () => _toggleCallPosition(item),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    child: Text('ReMap'),
                    onPressed: () => _remapSensor(item),
                  ),
                  SizedBox(width: 50),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      elevation: 4,
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      shadowColor: Colors.black.withOpacity(0.95),
                    ),
                    child: Text(
                      'Delete',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () => _showDeleteConfirmation(item['id'].toInt()),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOrEditItemDialog(),
        child: Icon(Icons.add),
        tooltip: "Add Sensor",
      ),
    );
  }
}