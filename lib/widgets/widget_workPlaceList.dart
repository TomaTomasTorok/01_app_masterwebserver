import 'package:flutter/material.dart';
import 'package:masterwebserver/widgets/widget_productList.dart';
import 'package:masterwebserver/widgets/widget_workPlace_form.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../model/wokrplace.dart';



class WorkplaceList extends StatefulWidget {
  @override
  _WorkplaceListState createState() => _WorkplaceListState();
}

class _WorkplaceListState extends State<WorkplaceList> {
  List<Workplace> workplaces = [];

  @override
  void initState() {
    super.initState();
    _loadWorkplaces();
  }

  Future<void> _loadWorkplaces() async {
    final prefs = await SharedPreferences.getInstance();
    String? workplacesData = prefs.getString('workplaces');
    if (workplacesData != null) {
      List<dynamic> decoded = json.decode(workplacesData);
      workplaces = decoded.map((workplace) => Workplace.fromMap(workplace)).toList();
    }
    setState(() {});
  }

  void _addOrUpdateWorkplace(Workplace workplace, [int? index]) {
    if (index == null) {
      // Adding new workplace
      workplaces.add(workplace);
    } else {
      // Updating existing workplace
      workplaces[index] = workplace;
    }
    _saveWorkplaces();
  }

  Future<void> _saveWorkplaces() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('workplaces', json.encode(workplaces.map((workplace) => workplace.toMap()).toList()));
    setState(() {});
  }

  void _deleteWorkplace(int index) {
    workplaces.removeAt(index);
    _saveWorkplaces();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Workplace List"),
      ),
      body: ListView.builder(
        itemCount: workplaces.length,
        itemBuilder: (context, index) {
          final workplace = workplaces[index];
          return Card(
            child: ListTile(
              title: Text(workplace.name),
              subtitle: Text("IP Address: ${workplace.ipAddress}"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProductList(workplace: workplace)),
                );
              },
              trailing: IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteWorkplace(index),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // This should open a form to add or edit a workplace
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => WorkplaceForm(onSubmit: _addOrUpdateWorkplace)),
          );
        },
        child: Icon(Icons.add),
        tooltip: "Add Workplace",
      ),
    );
  }
}
