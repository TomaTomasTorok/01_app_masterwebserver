
import 'package:flutter/material.dart';
import '../../SQLite/database_helper.dart';

void showAddWorkplaceDialog(BuildContext context, DatabaseHelper databaseHelper, Function refreshCallback) {
  final TextEditingController workplaceController = TextEditingController();
  final TextEditingController masterIPController = TextEditingController();

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Add Workplace'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: workplaceController,
              decoration: InputDecoration(hintText: "Enter workplace name"),
            ),
            SizedBox(height: 10),
            TextField(
              controller: masterIPController,
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
              if (workplaceController.text.isNotEmpty && masterIPController.text.isNotEmpty) {
                try {
                  await databaseHelper.insertWorkplaceWithMasterIP(
                      workplaceController.text,
                      masterIPController.text
                  );
                  Navigator.of(context).pop();
                  refreshCallback();
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