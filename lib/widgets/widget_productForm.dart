import 'package:flutter/material.dart';
import 'package:masterwebserver/widgets/workplace/workplace_learning.dart';
import '../../SQLite/database_helper.dart';


class ProductForm extends StatefulWidget {
  final String workplace;
  final String masterIp;
  final Map<String, dynamic> product;

  ProductForm({
    required this.workplace,
    required this.masterIp,
    required this.product,
  });

  @override
  _ProductFormState createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductForm> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _loadProductData();
    NotificationService.addListener(_onNewSensorAdded);
  }

  @override
  void dispose() {
    NotificationService.removeListener(_onNewSensorAdded);
    super.dispose();
  }

  void _onNewSensorAdded(String message) {
    if (message == 'new_sensor_added') {
      _loadProductData();
    }
  }

  Future<void> _loadProductData() async {
    final data = await _databaseHelper.getProductDataWithMasterIP(
        widget.product['product'],
        widget.workplace
    );
    setState(() {
      _items = data;
    });
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

                if (item == null) {
                  // Pridanie nového záznamu
                  final id = await _databaseHelper.insertProductData(newItem);
                  setState(() {
                    _items = [..._items, {...newItem, 'id': id}];
                  });
                } else {
                  // Aktualizácia existujúceho záznamu
                  await _databaseHelper.updateProductData(item['id'], newItem);
                  setState(() {
                    _items = _items.map((i) => i['id'] == item['id'] ? {...newItem, 'id': item['id']} : i).toList();
                  });
                }

                Navigator.of(context).pop();
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