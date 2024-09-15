import 'package:flutter/material.dart';
import '../SQLite/database_helper.dart';

class MasterIPList extends StatefulWidget {
  final String workplaceId;

  MasterIPList({required this.workplaceId});

  @override
  _MasterIPListState createState() => _MasterIPListState();
}

class _MasterIPListState extends State<MasterIPList> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  List<Map<String, dynamic>> masterIPs = [];
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMasterIPs();
  }

  Future<void> _loadMasterIPs() async {
    final results = await _databaseHelper.getMasterIPsForWorkplace(widget.workplaceId);
    setState(() {
      masterIPs = results;
    });
  }

  void _addMasterIP() async {
    if (_controller.text.isNotEmpty) {
      await _databaseHelper.insertMasterIP(widget.workplaceId, _controller.text);
      _controller.clear();
      _loadMasterIPs();
    }
  }

  Future<void> _deleteMasterIP(String masterIP) async {
    try {
      await _databaseHelper.deleteMasterIP(widget.workplaceId, masterIP);
      await _loadMasterIPs();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Master IP deleted successfully')),
      );
    } catch (e) {
      print('Error deleting Master IP: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete Master IP')),
      );
    }
  }

  void _showDeleteConfirmation(String masterIP) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Master IP'),
          content: Text('Are you sure you want to delete this Master IP?'),
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
                _deleteMasterIP(masterIP);
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
        title: Text("Master IP List for ${widget.workplaceId}"),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8.0)),
                  borderSide: BorderSide(color: Colors.blue, width: 2.0),
                ),
                labelText: "Enter Master IP",
                suffixIcon: IconButton(
                  icon: Icon(Icons.add),
                  onPressed: _addMasterIP,
                ),
              ),
              onSubmitted: (value) => _addMasterIP(),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: masterIPs.length,
              itemBuilder: (context, index) {
                final masterIP = masterIPs[index];
                return Card(
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
                      ],
                    ),
                    title: Text(
                      'Master IP: ${masterIP['master_ip']}',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Details: ${masterIP['details'] ?? 'No details available'}',
                      style: TextStyle(color: Colors.black54),
                    ),
                    trailing: ElevatedButton(
                      child: Text('Delete'),
                      style: ElevatedButton.styleFrom(
                        primary: Colors.red,
                        onPrimary: Colors.white,
                      ),
                      onPressed: () => _showDeleteConfirmation(masterIP['master_ip']),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}