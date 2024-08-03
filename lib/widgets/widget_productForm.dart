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
  List<String> _masterIps = [];

  @override
  void initState() {
    super.initState();
    _loadProductData();
    _loadMasterIps();
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

  Future<void> _loadMasterIps() async {
    final ips = await _databaseHelper.getMasterIPsForWorkplace(widget.workplace);
    setState(() {
      _masterIps = ips.map((ip) => ip['master_ip'] as String).toList();
    });
  }

  void _showAddOrEditItemDialog({Map<String, dynamic>? item}) {
    final TextEditingController slaveController = TextEditingController(text: item?['slave']?.toString() ?? '');
    final TextEditingController sequenceController = TextEditingController(text: item?['sequence']?.toString() ?? '');
    final TextEditingController sensorController = TextEditingController(text: item?['sensor']?.toString() ?? '');
    final TextEditingController sensorTypeController = TextEditingController(text: item?['sensor_type']?.toString() ?? '');
    final TextEditingController sensorValueController = TextEditingController(text: item?['sensor_value']?.toString() ?? '');
    String selectedMasterIp = item?['master_ip'] ?? _masterIps.first;

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
                      DropdownButtonFormField<String>(
                        value: selectedMasterIp,
                        items: _masterIps.map((String ip) {
                          return DropdownMenuItem<String>(
                            value: ip,
                            child: Text(ip),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            selectedMasterIp = newValue!;
                          });
                        },
                        decoration: InputDecoration(labelText: "Master IP"),
                      ),
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
                        'master_ip': selectedMasterIp,
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
                      _loadProductData(); // Obnovenie dát po úprave
                    },
                    child: Text(item == null ? "Add" : "Save"),
                  ),
                ],
              );
            }
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