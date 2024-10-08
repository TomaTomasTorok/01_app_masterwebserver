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