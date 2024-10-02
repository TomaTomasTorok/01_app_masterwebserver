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
              'sensor_value': double.tryParse(sensorValueController.text) ?? 0.0,
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

  Future<double?> updateSensorValue(Map<String, dynamic> item, String workplace, String product) async {
    final Map<String, Color> colors = {
      '1': Colors.green,    // zelena
      '2': Colors.blue,    // Modrá
      '3': Colors.red,     // Červená
      '4': Colors.purple,  // Fialová
      '5': Colors.yellow,  // Žltá
      '6': Colors.brown,   // Hnedá
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
                  ),
                );
              },
            ),
          ),
        );
      },
    );

    if (selectedColorValue != null) {
      try {
        double currentValue = item['sensor_value'] as double;
        double newSensorValue = _calculateNewSensorValue(currentValue, selectedColorValue.toDouble());

        await databaseHelper.updateSensorValue(
          item['workplace_id'],
          item['product'],
          item['master_ip'],
          item['sequence'],
          newSensorValue,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sensor color updated successfully')),
        );
        return newSensorValue;
      } catch (e) {
        print('Error updating sensor color: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update sensor color')),
        );
        return null;
      }
    }
    return null;
  }

  Future<double?> updateSensorValueForProduct(String workplace, String product, double newValue) async {
    double? updatedValue = await showDialog<double>(
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
              onPressed: () => Navigator.of(context).pop(double.tryParse(controller.text)),
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

  // double _calculateNewSensorValue(double currentValue, double newValue) {
  //   String currentStr = currentValue.toStringAsFixed(2);
  //   String newStr = newValue.toStringAsFixed(0);
  //
  //   if (currentStr.length >= 4) {  // xx.xx
  //     return double.parse('${currentStr.substring(0,1)}${newStr}${currentStr.substring(3)}');
  //   } else if (currentStr.length == 3) {  // x.x
  //     return double.parse('${newStr}${currentStr.substring(2)}');
  //   } else {  // x
  //     return double.parse('${newStr}.${currentStr.substring(0,1)}');
  //   }
  // }
  double _calculateNewSensorValue(double currentValue, double newValue) {

    String currentStr = currentValue.toInt().toString();
    String newStr = newValue.toInt().toString();

    if (currentStr.length == 3) {
      // Ak je aktuálna hodnota trojmiestna, nahradíme druhú číslicu
      return double.parse('${currentStr[0]}${newStr}${currentStr[2]}');
    } else if (currentStr.length == 2) {
      // Ak je aktuálna hodnota dvojmiestna, nahradíme prvú číslicu
      return double.parse('${newStr}${currentStr[1]}');
    } else if (currentStr.length == 1) {
      // Ak je aktuálna hodnota jednomiestna, vytvoríme nové dvojmiestne číslo
      return double.parse('${newStr}${currentStr}');
    } else {
      // Pre prípad, že by hodnota mala viac ako 3 číslice, vrátime pôvodnú novú hodnotu
      return newValue;
    }
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