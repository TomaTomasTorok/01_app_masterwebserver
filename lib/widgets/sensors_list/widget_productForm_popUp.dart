import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../SQLite/database_helper.dart';

class ProductFormPopup extends StatefulWidget {
  final Map<String, dynamic>? item;
  final String workplace;
  final String masterIp;
  final Function(Map<String, dynamic>) onSave;
  final String product;
  ProductFormPopup({
    this.item,
    required this.workplace,
    required this.masterIp,
    required this.onSave,
    required this.product,
  });

  @override
  _ProductFormPopupState createState() => _ProductFormPopupState();
}

class _ProductFormPopupState extends State<ProductFormPopup> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final TextEditingController slaveController = TextEditingController();
  final TextEditingController sequenceController = TextEditingController();
  final TextEditingController sensorController = TextEditingController();
  final TextEditingController sensorTypeController = TextEditingController();
  final TextEditingController sensorValueController = TextEditingController();
  String? selectedMasterIP;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      slaveController.text = widget.item!['slave']?.toString() ?? '';
      sequenceController.text = widget.item!['sequence']?.toString() ?? '';
      sensorController.text = widget.item!['sensor']?.toString() ?? '';
      sensorTypeController.text = widget.item!['sensor_type']?.toString() ?? '';
      sensorValueController.text = widget.item!['sensor_value']?.toString() ?? '';
    }
    selectedMasterIP = widget.item?['master_ip'] ?? widget.masterIp;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? "Add Sensor" : "Edit Sensor"),
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
              decoration: InputDecoration(labelText: "Name"),
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
          onPressed: () {
            if (slaveController.text.isEmpty || sequenceController.text.isEmpty || sensorController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Slave, Sequence, and Sensor fields must be filled out.')),
              );
              return;
            }

            final newItem = {
              'workplace_id': widget.workplace,
              'master_ip': selectedMasterIP,
              'product':widget.product,
              'slave': int.tryParse(slaveController.text) ?? 0,
              'sequence': int.tryParse(sequenceController.text) ?? 0,
              'sensor': int.tryParse(sensorController.text) ?? 0,
              'sensor_type': sensorTypeController.text,
              'sensor_value': int.tryParse(sensorValueController.text) ?? 10,
            };

            widget.onSave(newItem);
            Navigator.of(context).pop();
          },
          child: Text(widget.item == null ? "Add" : "Save"),
        ),
      ],
    );
  }
}


class SensorRecolor {
  final DatabaseHelper databaseHelper;
  final BuildContext context;

  SensorRecolor(this.context, this.databaseHelper);

  Future<int?> updateSensorValue(Map<String, dynamic> item, String workplace, String product, {bool isMode = false}) async {
    if (isMode) {
      return _updateMode(item, workplace, product);
    } else {
      return _updateColor(item, workplace, product);
    }
  }

  Future<int?> _updateMode(Map<String, dynamic> item, String workplace, String product) async {
    int currentValue = item['sensor_value'] as int;
    bool isCurrentlyMultiCheck = currentValue % 10 == 0;

    bool? isMultiCheck = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select Mode'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                title: Text('MultiCheck'),
                value: isCurrentlyMultiCheck,
                onChanged: (bool? value) {
                  Navigator.of(context).pop(value);
                },
              ),
              CheckboxListTile(
                title: Text('SingleCheck'),
                value: !isCurrentlyMultiCheck,
                onChanged: (bool? value) {
                  Navigator.of(context).pop(value == false);
                },
              ),
            ],
          ),
        );
      },
    );

    if (isMultiCheck != null) {
      int newValue = isMultiCheck ? 0 : 1;
      return _updateSensorValue(item, workplace, product, newValue, isMode: true);
    }
    return null;
  }

  Future<int?> _updateColor(Map<String, dynamic> item, String workplace, String product) async {
    final Map<String, Color> colors = {
      '1': Colors.green,
      '2': Colors.blue,
      '3': Colors.red,
      '4': Colors.purple,
      '5': Colors.yellow,
      '6': Colors.brown,
    };

    int? selectedColorValue = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select Color'),
          content: Container(
            width: 400,
            child: GridView.builder(
              shrinkWrap: true,
              itemCount: colors.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                childAspectRatio: 1.0,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemBuilder: (context, index) {
                String colorKey = colors.keys.elementAt(index);
                Color color = colors[colorKey]!;
                return InkWell(
                  onTap: () => Navigator.of(context).pop(int.parse(colorKey)),
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        colorKey,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );

    if (selectedColorValue != null) {
      return _updateSensorValue(item, workplace, product, selectedColorValue);
    }
    return null;
  }

  Future<int?> _updateSensorValue(Map<String, dynamic> item, String workplace, String product, int newValue, {bool isMode = false}) async {
    try {
      int currentValue = item['sensor_value'] as int;
      int updatedValue = isMode
          ? _calculateNewModeValue(currentValue, newValue)
          : _calculateNewSensorValue(currentValue, newValue);

      await databaseHelper.updateSensorValue(
        item['workplace_id'],
        item['product'],
        item['master_ip'],
        item['sequence'],
        updatedValue,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isMode ? 'Sensor mode updated successfully' : 'Sensor color updated successfully')),
      );
      return updatedValue;
    } catch (e) {
      print('Error updating sensor ${isMode ? "mode" : "color"}: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update sensor ${isMode ? "mode" : "color"}')),
      );
      return null;
    }
  }

  int _calculateNewSensorValue(int currentValue, int newValue) {
    String currentStr = currentValue.toString();
    String newStr = newValue.toString();

    if (currentStr.length == 3) {
      return int.parse('${currentStr[0]}${newStr}${currentStr[2]}');
    } else if (currentStr.length == 2) {
      return int.parse('${newStr}${currentStr[1]}');
    } else if (currentStr.length == 1) {
      return int.parse('${newStr}${currentStr}');
    } else {
      return newValue;
    }
  }

  int _calculateNewModeValue(int currentValue, int newValue) {
    String currentStr = currentValue.toString();
    return int.parse('${currentStr.substring(0, currentStr.length - 1)}$newValue');
  }

  Future<int?> updateSensorValueForProduct(String workplace, String product, int newValue) async {
    int? updatedValue = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController controller = TextEditingController(text: newValue.toString());
        return AlertDialog(
          title: Text('Update Sensor Value for Product'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(hintText: "Enter new value"),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Update'),
              onPressed: () => Navigator.of(context).pop(int.tryParse(controller.text)),
            ),
          ],
        );
      },
    );

    if (updatedValue != null) {
      try {
        await databaseHelper.updateSensorValueForProduct(
          workplace,
          product,
          updatedValue,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sensor values updated for all sensors in the product')),
        );
        return updatedValue;
      } catch (e) {
        print('Error updating sensor values for product: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update sensor values for product')),
        );
        return null;
      }
    }
    return null;
  }
}
class SensorRenamer {
  final DatabaseHelper databaseHelper;
  final BuildContext context;

  SensorRenamer(this.context, this.databaseHelper);

  Future<String?> renameSensor(Map<String, dynamic> item, String workplace, String product) async {
    String? newName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController controller = TextEditingController(text: item['sensor_type']);
        return AlertDialog(
          title: Text('Rename Sensor'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: "Enter new name"),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Rename'),
              onPressed: () => Navigator.of(context).pop(controller.text),
            ),
          ],
        );
      },
    );

    if (newName != null && newName.isNotEmpty) {
      try {
        await databaseHelper.renameSensorType(
          workplace,
          product,
          item['master_ip'],
          item['slave'],
          item['sensor'],
          newName,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sensor renamed successfully')),
        );
        return newName; // Return the new name if rename was successful
      } catch (e) {
        print('Error renaming sensor: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to rename sensor')),
        );
        return null; // Return null if rename failed
      }
    }
    return null; // Return null if user cancelled or entered empty name
  }
  Future<String?> renameSensorInWorkplace(Map<String, dynamic> item, String workplace) async {
    String? newName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController controller = TextEditingController(text: item['sensor_type']);
        return AlertDialog(
          title: Text('Rename Sensor'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: "Enter new name"),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Rename'),
              onPressed: () => Navigator.of(context).pop(controller.text),
            ),
          ],
        );
      },
    );

    if (newName != null && newName.isNotEmpty) {
      try {
        await databaseHelper.renameSensorTypeWorkplace(
          workplace,

          item['master_ip'],
          item['slave'],
          item['sensor'],
          newName,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sensor renamed successfully')),
        );
        return newName; // Return the new name if rename was successful
      } catch (e) {
        print('Error renaming sensor: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to rename sensor')),
        );
        return null; // Return null if rename failed
      }
    }
    return null; // Return null if user cancelled or entered empty name
  }

}