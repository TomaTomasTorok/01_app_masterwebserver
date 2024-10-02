import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../SQLite/database_helper.dart';
import '../../Services/sensors_operation.dart';
import '../workplace/workplace_learning.dart';
import 'widget_productForm_popUp.dart';


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
  late SensorOperations _sensorOperations;
  late CallPositionService _callPositionService;
  List<Map<String, dynamic>> _items = [];
  bool _showFinishLearnButton = true;
  late SensorRenamer _sensorRenamer;
  late SensorRecolor _sensorRecolor;
  bool _isRemapping = false;
  Map<int, bool> _callPositionStates = {};

  @override
  void initState() {
    super.initState();
    _sensorOperations = SensorOperations(context, _databaseHelper);
    _callPositionService = CallPositionService();
    _sensorRenamer = SensorRenamer(context, _databaseHelper);
    _sensorRecolor = SensorRecolor(context, _databaseHelper);
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
    try {
      final data = await _databaseHelper.getProductDataWithMasterIP(
          widget.product['product'],
          widget.workplace
      );
      setState(() {
        // Vytvorenie hlbokej kópie dát
        _items = List<Map<String, dynamic>>.from(
            data.map((item) => Map<String, dynamic>.from(item))
        );
        _items.sort((a, b) => a['sequence'].compareTo(b['sequence']));
      });
    } catch (e) {
      print('Error loading product data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load product data')),
      );
    }


  }

  Future<void> _toggleCallPosition(Map<String, dynamic> item) async {
    int itemId = item['id'];
    bool wasActive = _callPositionStates[itemId] ?? false;
    _callPositionStates.updateAll((key, value) => false);
    if (!wasActive) {
      _callPositionStates[itemId] = true;
    }
    setState(() {});
    int state = _callPositionStates[itemId]! ? 1 : 0;
    await _callPositionService.callPosition(item['master_ip'], item['slave'], item['sensor'], state);
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

  Future<void> _remapSensor(Map<String, dynamic> item) async {
    if (_isRemapping) return;
    _isRemapping = true;
    try {
      await _sensorOperations.remapSensor(item);
      _loadProductData();
    } catch (e) {
      print('Error during remapping: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred during remapping')),
      );
    } finally {
      _isRemapping = false;
    }
  }

  Future<void> _deleteProduct(int sensorId) async {
    await _databaseHelper.deleteSensor(sensorId);
    _loadProductData();
  }

  void _showDeleteConfirmation(int sensorId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Sensor'),
          content: Text('Are you sure you want to delete this Sensor?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
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

  Future<void> _renameSensor(Map<String, dynamic> item) async {
    String? newName = await _sensorRenamer.renameSensor(item, widget.workplace, widget.product['product']);
    if (newName != null) {
      _loadProductData();
    }
  }

  Color _getSensorColor(double sensorValue) {
    String valueStr = sensorValue.toStringAsFixed(2);
    if (valueStr.length >= 2) {
      switch (valueStr[0]) {
        case '1': return Colors.green;
        case '2': return Colors.blue;
        case '3': return Colors.red;
        case '4': return Colors.purple;
        case '5': return Colors.yellow;
        case '6': return Colors.brown;
        default: return Colors.greenAccent;
      }
    }
    return Colors.greenAccent; // Default farba
  }

  Future<void> _recolorSensor(Map<String, dynamic> item) async {
    double? newSensorValue = await _sensorRecolor.updateSensorValue(
        item,
        widget.workplace,
        widget.product['product']
    );
    if (newSensorValue != null) {
      setState(() {
        int itemIndex = _items.indexWhere((i) => i['id'] == item['id']);
        if (itemIndex != -1) {
          _items[itemIndex]['sensor_value'] = newSensorValue;
        }
      });
    }
    _loadProductData();
  }

  Future<void> _renameSensorInWorkplace(Map<String, dynamic> item) async {
    String? newName = await _sensorRenamer.renameSensorInWorkplace(item, widget.workplace);
    if (newName != null) {
      _loadProductData();
    }
  }

  Future<void> _finishLearn() async {
    try {
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
              _loadProductData();
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
          onPressed: () async {
            if (widget.isLearningMode && _showFinishLearnButton) {
              await _finishLearn();
            }
            Navigator.of(context).pop();
          },
        ),
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
          : ReorderableListView.builder(
        buildDefaultDragHandles: false,
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          bool isCallPositionActive = _callPositionStates[item['id']] ?? false;
          return Card(
            key: ValueKey(item['id']),
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
                  Icon(Icons.sensors, color: _getSensorColor(item['sensor_value'].toDouble())),
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
                children: [
                  ElevatedButton(
                    child: Text('Rename'),
                    onPressed: () => _renameSensor(item),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    child: Text('ReColor'),
                    onPressed: () => _recolorSensor(item),
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
                  SizedBox(width: 50),

                    ReorderableDragStartListener(
                      index: index,
                      child: Container(width: 65,color: Color(0xF6EFF8FF),
                        child: Column(
                          children: [
                            Icon(Icons.touch_app, color: Colors.grey, size: 30,),
                            Text("ReOrder")
                          ],
                        ),
                      ),
                    ),

                ],
              ),
            ),
          );
        },
        onReorder: (oldIndex, newIndex) {
          setState(()  {
            if (oldIndex < newIndex) {
              newIndex -= 1;
            }
            final item = _items.removeAt(oldIndex);
            _items.insert(newIndex, item);
            _updateSequences(oldIndex, newIndex).then((_) {
              // Po dokončení aktualizácie sekvencií znovu nastavíme stav pre obnovenie UI
              _loadProductData();
            });
          });
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOrEditItemDialog(),
        child: Icon(Icons.add),
        tooltip: "Add Sensor",
      ),
    );
  }

  Future<void> _updateSequences(int oldIndex, int newIndex) async {
    final movedItem = _items[newIndex];
     int newSequence;

    if (newIndex > 0) {
      // Získame sequence hodnotu predchádzajúcej položky
      newSequence = _items[newIndex - 1]['sequence']+1;
    } else {
      // Ak je presunutá na začiatok, použijeme hodnotu 0
      newSequence = 1;
    }

    // Aktualizujeme sequence presunutej položky
    await _databaseHelper.updateSequence(movedItem['id'], newSequence);


    // Aktualizujeme ovplyvnené položky
    if (oldIndex < newIndex) {
     // Položka bola presunutá nadol
      final lastIndex = _items.length - 1;
      for (int i = newIndex; i <= lastIndex; i++) {
        if (i == newIndex) continue; // Preskočíme presunutú položku
        final currentItem = _items[i];
        final currentSequence = await _databaseHelper.getSequence(currentItem['id']);
        await _databaseHelper.updateSequence(currentItem['id'], currentSequence + 1);

      }
    } else if (oldIndex > newIndex) {
      // Položka bola presunutá nahor
      final lastIndex = _items.length - 1;
      for (int i = newIndex + 1; i <= lastIndex; i++) {
        final currentItem = _items[i];
        final currentSequence = await _databaseHelper.getSequence(currentItem['id']);
        await _databaseHelper.updateSequence(currentItem['id'], currentSequence + 1);

      }
    }

    // Znovu zoradíme lokálny zoznam podľa aktualizovaných sequence hodnôt
    _items.sort((a, b) => a['sequence'].compareTo(b['sequence']));

  }


}