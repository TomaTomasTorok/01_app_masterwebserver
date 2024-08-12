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
                return ListTile(
                  title: Text('Master IP: ${masterIP['master_ip']}'),
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