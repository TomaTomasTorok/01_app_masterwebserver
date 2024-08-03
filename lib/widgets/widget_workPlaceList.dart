import 'package:flutter/material.dart';
import '../SQLite/database_helper.dart';
import 'MasterIPList.dart';
import 'widget_productList.dart';

class WorkplaceList extends StatefulWidget {
  @override
  _WorkplaceListState createState() => _WorkplaceListState();
}

class _WorkplaceListState extends State<WorkplaceList> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  List<Map<String, dynamic>> workplaces = [];

  @override
  void initState() {
    super.initState();
    _loadWorkplaces();
  }

  Future<void> _loadWorkplaces() async {
    final results = await _databaseHelper.getWorkplaces();
    setState(() {
      workplaces = results;
    });
  }

  void _showAddWorkplaceDialog() {
    final TextEditingController _workplaceController = TextEditingController();
    final TextEditingController _masterIPController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add Workplace'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _workplaceController,
                decoration: InputDecoration(hintText: "Enter workplace name"),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _masterIPController,
                decoration: InputDecoration(hintText: "Enter Master IP"),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Add'),
              onPressed: () async {
                if (_workplaceController.text.isNotEmpty && _masterIPController.text.isNotEmpty) {
                  try {
                    await _databaseHelper.insertWorkplaceWithMasterIP(
                        _workplaceController.text,
                        _masterIPController.text
                    );
                    Navigator.of(context).pop();
                    _loadWorkplaces();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Workplace added successfully')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please enter both Workplace name and Master IP')),
                  );
                }
              },
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
        title: Text("Workplace List"),
      ),
      body: ListView.builder(
        itemCount: workplaces.length,
        itemBuilder: (context, index) {
          final workplace = workplaces[index];
          return ListTile(
            title: Text(workplace['workplace_id']),
            subtitle: Text('Master IP: ${workplace['master_ip']}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  child: Text('Master IP List'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MasterIPList(
                          workplaceId: workplace['workplace_id'],
                          workplaceName: workplace['workplace_id'],
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  child: Text('Learning'),
                  onPressed: () {
                    // Implementujte funkcionalitu učenia
                  },
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  child: Text('Test'),
                  onPressed: () {
                    // Implementujte funkcionalitu testu
                  },
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  child: Text('Change'),
                  onPressed: () {
                    // Implementujte funkcionalitu zmeny
                  },
                ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductList(
                    workplaceId: workplace['workplace_id'],
                    workplaceName: workplace['workplace_id'],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddWorkplaceDialog,
        child: Icon(Icons.add),
        tooltip: "Add Workplace",
      ),
    );
  }
}