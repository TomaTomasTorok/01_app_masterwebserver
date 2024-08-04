import 'package:flutter/material.dart';
import 'package:masterwebserver/widgets/widget_productList.dart';
import '../MasterIPList.dart';

class WorkplaceMenu extends StatelessWidget {
  final String workplaceId;
  final String workplaceName;

  WorkplaceMenu({required this.workplaceId, required this.workplaceName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Menu for $workplaceName'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              child: Text('Master IP List'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MasterIPList(workplaceId: workplaceId, workplaceName: workplaceName),
                  ),
                );
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              child: Text('Product List'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductList(workplaceId: workplaceId, workplaceName: workplaceName),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}