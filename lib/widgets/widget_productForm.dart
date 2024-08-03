import 'package:flutter/material.dart';
import '../SQLite/database_helper.dart';

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

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(item == null ? "Add Sensor" : "Edit Sensor"),
          content: Column(
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
            ],
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
                  'master_ip': widget.masterIp,
                  'slave': int.tryParse(slaveController.text) ?? 0,
                  'sequence': int.tryParse(sequenceController.text) ?? 0,
                  'sensor': int.tryParse(sensorController.text) ?? 0,
                  'sensor_value': 0.0,
                };

                if (item == null) {
                  // Pridanie nového záznamu
                  final id = await _databaseHelper.insertProductData(newItem);
                  newItem['id'] = id;
                  setState(() {
                    _items.add(newItem);
                  });
                } else {
                  // Aktualizácia existujúceho záznamu
                  await _databaseHelper.updateProductData(item['id'], newItem);
                  setState(() {
                    final index = _items.indexWhere((i) => i['id'] == item['id']);
                    if (index != -1) {
                      _items[index] = {...item, ...newItem};
                    }
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
          ? Center(child: Text('No sensors found for this product'))
          : ListView.builder(
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return ListTile(
            title: Text('Slave: ${item['slave']}, Sensor: ${item['sensor']}'),
            subtitle: Text('Sequence: ${item['sequence']}'),
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