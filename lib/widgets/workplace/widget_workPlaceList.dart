import 'package:flutter/material.dart';
import 'package:masterwebserver/widgets/workplace/workplace_learning.dart';
import 'package:masterwebserver/widgets/workplace/workplace_testing.dart';
import '../../SQLite/database_helper.dart';
import '../MasterIPList.dart';
import '../widget_productList.dart';
import 'workplace_dialog.dart';

class WorkplaceList extends StatefulWidget {
  @override
  _WorkplaceListState createState() => _WorkplaceListState();
}

class _WorkplaceListState extends State<WorkplaceList> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  List<Map<String, dynamic>> workplaces = [];
  final TestingManager _testingManager = TestingManager();
  Map<String, Function> _learningCallbacks = {};

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

  void _cleanupLearningCallbacks() {
    for (var callback in _learningCallbacks.values) {
      try {
        callback();
      } catch (e) {
        print('Error during callback cleanup: $e');
      }
    }
    _learningCallbacks.clear();
  }

  void _startLearning(String workplaceId) async {
    // Cleanup existing callback for this workplace if it exists
    if (_learningCallbacks.containsKey(workplaceId)) {
      try {
        _learningCallbacks[workplaceId]!();
      } catch (e) {
        print('Error cleaning up existing learning process: $e');
      }
      _learningCallbacks.remove(workplaceId);
    }

    void finishLearningCallback() {
      if (mounted && _learningCallbacks.containsKey(workplaceId)) {
        try {
          _learningCallbacks[workplaceId]!();
        } catch (e) {
          print('Error during learning callback: $e');
        } finally {
          _learningCallbacks.remove(workplaceId);
        }
        setState(() {});
      }
    }

    try {
      _learningCallbacks[workplaceId] = await handleLearning(
        context,
        workplaceId,
        _databaseHelper,
        finishLearningCallback,
      );
    } catch (e) {
      print('Error starting learning process: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start learning process')),
        );
      }
    }
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
          return AlternatingColorListTile(
            workplace: workplace,
            index: index,
            databaseHelper: _databaseHelper,
            testingManager: _testingManager,
            onRefresh: _loadWorkplaces,
            onTestingToggle: () => setState(() {}),
            onLearningStart: () => _startLearning(workplace['workplace_id']),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddWorkplaceDialog(context, _databaseHelper, _loadWorkplaces),
        child: Icon(Icons.add),
        tooltip: "Add Workplace",
      ),
    );
  }

  @override
  void dispose() {
    _cleanupLearningCallbacks();
    super.dispose();
  }
}

class AlternatingColorListTile extends StatelessWidget {
  final Map<String, dynamic> workplace;
  final int index;
  final DatabaseHelper databaseHelper;
  final TestingManager testingManager;
  final VoidCallback onRefresh;
  final VoidCallback onTestingToggle;
  final VoidCallback onLearningStart;

  const AlternatingColorListTile({
    Key? key,
    required this.workplace,
    required this.index,
    required this.databaseHelper,
    required this.testingManager,
    required this.onRefresh,
    required this.onTestingToggle,
    required this.onLearningStart,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Color color1 = colorScheme.surfaceVariant.withOpacity(0.5);
    final Color color2 = colorScheme.surface;

    return Container(
      color: index % 2 == 0 ? color1 : color2,
      child: ListTile(
        title: Text(
          workplace['workplace_id'],
          style: TextStyle(color: colorScheme.onSurface),
        ),
        subtitle: Text(
          'Master IP: ${workplace['master_ip']}',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
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
              onPressed: onLearningStart,
            ),
            SizedBox(width: 8),
            ElevatedButton(
              child: Text('Testing'),
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all(
                  testingManager.isTestingForWorkplace(workplace['workplace_id']) ? Colors.green : null,
                ),
              ),
              onPressed: () => testingManager.toggleTesting(
                context,
                workplace['workplace_id'],
                databaseHelper,
                onTestingToggle,
              ),
            ),
            SizedBox(width: 8),
            ElevatedButton(
              child: Text('Products'),
              onPressed: () {
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
            ),
          ],
        ),
      ),
    );
  }
}