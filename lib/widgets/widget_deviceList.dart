import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class DeviceList extends StatefulWidget {
  @override
  _DeviceListState createState() => _DeviceListState();
}

class _DeviceListState extends State<DeviceList> {
  List<int> devices = [];
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadDevices();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  Future<void> _loadDevices() async {
    final prefs = await SharedPreferences.getInstance();
    String? devicesData = prefs.getString('devices');
    if (devicesData != null) {
      devices = List<int>.from(json.decode(devicesData));
      setState(() {});
    }
  }

  Future<void> _saveDevices() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('devices', json.encode(devices));
  }

  void _addDevice() {
    if (_controller.text.isNotEmpty) {
      final int deviceNumber = int.tryParse(_controller.text) ?? -1;
      if (deviceNumber != -1) {
        setState(() {
          devices.add(deviceNumber);
        });
        _saveDevices();
      }
      _controller.clear();
      FocusScope.of(context).requestFocus(_focusNode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Device List"),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              focusNode: _focusNode,
              controller: _controller,
              decoration: InputDecoration(
                labelText: "Enter device number",
                suffixIcon: IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _addDevice,
                ),
              ),
              keyboardType: TextInputType.number,
              onSubmitted: (value) => _addDevice(),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text('Device ${devices[index]}'),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        devices.removeAt(index);
                      });
                      _saveDevices();
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: _addDevice,
      //   child: Icon(Icons.add),
      //   tooltip: "Add Device",
      // ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
