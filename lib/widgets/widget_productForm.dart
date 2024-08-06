import 'package:flutter/material.dart';
import 'package:masterwebserver/widgets/workplace/workplace_learning.dart';
import '../../SQLite/database_helper.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

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
  WebSocketChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadProductData();
    NotificationService.addListener(_onNewSensorAdded);
    if (widget.isLearningMode) {
      _initializeWebSocket();
    }
  }

  @override
  void dispose() {
    NotificationService.removeListener(_onNewSensorAdded);
    _closeWebSocket();
    super.dispose();
  }

  void _initializeWebSocket() {
    _channel = WebSocketChannel.connect(Uri.parse('ws://${widget.masterIp}:81'));
  }

  void _closeWebSocket() {
    _channel?.sink.close();
    _channel = null;
  }

  Future<void> stopTesting() async {
    if (_channel != null) {
      final stopData = {
        "data": [
          [1,2,3,4,5,6,7,8,9,10],
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
    final TextEditingController slaveController = TextEditingController(text: item?['slave']?.toString() ?? '');
    final TextEditingController sequenceController = TextEditingController(text: item?['sequence']?.toString() ?? '');
    final TextEditingController sensorController = TextEditingController(text: item?['sensor']?.toString() ?? '');
    final TextEditingController sensorTypeController = TextEditingController(text: item?['sensor_type']?.toString() ?? '');
    final TextEditingController sensorValueController = TextEditingController(text: item?['sensor_value']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(item == null ? "Add Sensor" : "Edit Sensor"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: slaveController,
                  decoration: InputDecoration(labelText: "Slave"),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: sequenceController,
                  decoration: InputDecoration(labelText: "Sequence"),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: sensorController,
                  decoration: InputDecoration(labelText: "Sensor"),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: sensorTypeController,
                  decoration: InputDecoration(labelText: "Sensor Type"),
                ),
                TextField(
                  controller: sensorValueController,
                  decoration: InputDecoration(labelText: "Sensor Value"),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                final newItem = {
                  'workplace_id': widget.workplace,
                  'product': widget.product['product'],
                  'master_ip': item?['master_ip'] ?? widget.masterIp,
                  'slave': int.tryParse(slaveController.text) ?? 0,
                  'sequence': int.tryParse(sequenceController.text) ?? 0,
                  'sensor': int.tryParse(sensorController.text) ?? 0,
                  'sensor_type': sensorTypeController.text,
                  'sensor_value': double.tryParse(sensorValueController.text) ?? 0.0,
                };

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
                  Navigator.of(context).pop();
                } catch (e) {
                  print('Error saving sensor data: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to save sensor data')),
                  );
                }
              },
              child: Text(item == null ? "Add" : "Save"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
          return ListTile(
            title: Text('Slave: ${item['slave']}, Sensor: ${item['sensor']}'),
            subtitle: Text('Sequence: ${item['sequence']}, Type: ${item['sensor_type']}, Value: ${item['sensor_value']}'),
            onTap: () => _showAddOrEditItemDialog(item: item),
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