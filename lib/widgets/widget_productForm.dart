import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    String? selectedMasterIP = item?['master_ip'] ?? widget.masterIp;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(item == null ? "Add Sensor" : "Edit Sensor"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _databaseHelper.getMasterIPsForWorkplace(widget.workplace),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return CircularProgressIndicator();
                        } else if (snapshot.hasError) {
                          return Text("Error: ${snapshot.error}");
                        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Text("No Master IPs available");
                        } else {
                          List<String> masterIPs = snapshot.data!.map((ip) => ip['master_ip'] as String).toList();
                          if (!masterIPs.contains(selectedMasterIP)) {
                            selectedMasterIP = masterIPs.first;
                          }
                          return DropdownButtonFormField<String>(
                            value: selectedMasterIP,
                            decoration: InputDecoration(labelText: "Master IP"),
                            items: masterIPs.map((String ip) {
                              return DropdownMenuItem<String>(
                                value: ip,
                                child: Text(ip),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedMasterIP = newValue;
                              });
                            },
                          );
                        }
                      },
                    ),
                    TextField(
                      controller: slaveController,
                      decoration: InputDecoration(labelText: "Slave"),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    TextField(
                      controller: sequenceController,
                      decoration: InputDecoration(labelText: "Sequence"),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly]
                    ),
                    TextField(
                      controller: sensorController,
                      decoration: InputDecoration(labelText: "Sensor"),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly]
                    ),
                    TextField(
                      controller: sensorTypeController,
                      decoration: InputDecoration(labelText: "Sensor Type"),
                    ),
                    TextField(
                      controller: sensorValueController,
                      decoration: InputDecoration(labelText: "Sensor Value"),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly]
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
                    if (slaveController.text.isEmpty || sequenceController.text.isEmpty || sensorController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Slave, Sequence, and Sensor fields must be filled out.')),
                      );
                      return;
                    }

                    final newItem = {
                      'workplace_id': widget.workplace,
                      'product': widget.product['product'],
                      'master_ip': selectedMasterIP,
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
                      _loadProductData(); // Reload data after adding/editing
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
          return
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${index + 1}', // Index záznamu, pripočíta sa 1, pretože index začína od 0
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.black54,
                      ),
                    ),
                    SizedBox(width: 8), // Medzera medzi číslom a ikonou
                    Icon(Icons.sensors, color: Colors.greenAccent),
                  ],
                ),
                title: Text(
                  'Slave: ${item['slave']}, Sensor: ${item['sensor']}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Sequence: ${item['sequence']}, Type: ${item['sensor_type']}, Value: ${item['sensor_value']}'),
                onTap: () => _showAddOrEditItemDialog(item: item),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      SizedBox(width: 28),
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
                        onPressed: () => {

                            _showDeleteConfirmation(item['id'].toInt())}
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