import 'package:flutter/material.dart';
import 'package:masterwebserver/widgets/workplace/workplace_learning.dart';
import 'package:masterwebserver/widgets/workplace/workplace_testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../Log/log_view_screan.dart';
import '../../Log/logger.dart';
import '../../SQLite/database_helper.dart';
import '../../Services/jsonTaskService.dart';
import '../../Services/task_services.dart';
import '../../main.dart';
import '../MasterIPList.dart';
import '../processProductData.dart';
import '../widget_productList.dart';
import 'workplace_dialog.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';

class WorkplaceList extends StatefulWidget {
  @override
  _WorkplaceListState createState() => _WorkplaceListState();
}

class _WorkplaceListState extends State<WorkplaceList> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  late JsonTaskSynchronizer jsonTaskSynchronizer;
  List<Map<String, dynamic>> workplaces = [];
  final TestingManager _testingManager = TestingManager();
  Map<String, Function> _learningCallbacks = {};
  late final TaskService _taskService;
  Map<String, bool> _checkedWorkplaces = {};

  @override
  void initState() {
    super.initState();
    jsonTaskSynchronizer = JsonTaskSynchronizer(_databaseHelper);
    _taskService = TaskService(_databaseHelper);
    _loadWorkplaces();
    _loadCheckedWorkplaces();
  }

  Future<void> _loadWorkplaces() async {
    final results = await _databaseHelper.getWorkplaces();
    setState(() {
      workplaces = results;
    });
    _loadCheckedWorkplaces();
  }

  Future<void> _loadCheckedWorkplaces() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      for (var workplace in workplaces) {
        String workplaceId = workplace['workplace_id'];
        _checkedWorkplaces[workplaceId] = prefs.getBool(workplaceId) ?? false;
      }
    });
  }

  Future<void> _saveCheckedWorkplace(String workplaceId, bool isChecked) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(workplaceId, isChecked);
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
        actions: [
          // ElevatedButton(
          //   onPressed: () async {
          //     await jsonTaskSynchronizer.synchronizeJsonWithDatabase();
          //     await _taskService.processNewTasks();
          //     ScaffoldMessenger.of(context).showSnackBar(
          //       SnackBar(content: Text('Tasks synchronized and processed')),
          //     );
          //   },
          //   child: Text("Online - Sync & Process"),
          // ),
          ElevatedButton(
            onPressed: () async {
              List<String> checkedWorkplaceIds = getCheckedWorkplaceIds();
              if (checkedWorkplaceIds.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please select at least one workplace')),
                );
                return;
              }

              for (String workplaceId in checkedWorkplaceIds) {
                await jsonTaskSynchronizer.synchronizeJsonWithDatabase(workplaceId);
                await _taskService.processNewTasks(workplaceId);
              }

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Tasks synchronized and processed for selected workplaces')),
              );
            },
            child: Text("Online - Sync & Process"),
          ),
          ElevatedButton(
            onPressed: () async {
              List<String> checkedWorkplaceIds = getCheckedWorkplaceIds();
              if (checkedWorkplaceIds.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please select at least one workplace')),
                );
                return;
              }

              for (String workplaceId in checkedWorkplaceIds) {
                _taskService.cancelProcessor(workplaceId);
              }

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Tasks stopped')),
              );
            },


            // onPressed: () async {
            //   _taskService.cancelProcessor();
            //   ScaffoldMessenger.of(context).showSnackBar(
            //     SnackBar(content: Text('Tasks stopped')),
            //   );
            // },
            child: Text("Finish"),
          ),
          IconButton(
            icon: Icon(Icons.assessment),
            onPressed: () async {
              final logFiles = await getLogFiles();
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text('Log Files'),
                    content: Container(
                      width: double.maxFinite,
                      child: ListView.builder(
                        itemCount: logFiles.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            title: Text(logFiles[index]),
                            onTap: () async {
                              final logContent = await readLogFile(logFiles[index]);
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => LogViewerScreen(
                                    fileName: logFiles[index],
                                    logContent: logContent,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    actions: [
                      TextButton(
                        child: Text('Close'),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
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
            isChecked: _checkedWorkplaces[workplace['workplace_id']] ?? false,
            onCheckboxChanged: (bool? value) {
              setState(() {
                _checkedWorkplaces[workplace['workplace_id']] = value ?? false;
                _saveCheckedWorkplace(workplace['workplace_id'], value ?? false);
              });
            },
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

  List<String> getCheckedWorkplaceIds() {
    return _checkedWorkplaces.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  @override
  void dispose() {
    _cleanupLearningCallbacks();
    super.dispose();
  }
}

class AlternatingColorListTile extends StatefulWidget {
  final Map<String, dynamic> workplace;
  final int index;
  final DatabaseHelper databaseHelper;
  final TestingManager testingManager;
  final VoidCallback onRefresh;
  final VoidCallback onTestingToggle;
  final VoidCallback onLearningStart;
  final bool isChecked;
  final ValueChanged<bool?> onCheckboxChanged;

  const AlternatingColorListTile({
    Key? key,
    required this.workplace,
    required this.index,
    required this.databaseHelper,
    required this.testingManager,
    required this.onRefresh,
    required this.onTestingToggle,
    required this.onLearningStart,
    required this.isChecked,
    required this.onCheckboxChanged,
  }) : super(key: key);

  @override
  _AlternatingColorListTileState createState() => _AlternatingColorListTileState();
}

class _AlternatingColorListTileState extends State<AlternatingColorListTile> {
  bool isTestingInProgress = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Color color1 = colorScheme.surfaceVariant.withOpacity(0.5);
    final Color color2 = colorScheme.surface;

    return Container(
      color: widget.index % 2 == 0 ? color1 : color2,
      child: ListTile(
        leading: Checkbox(
          value: widget.isChecked,
          onChanged: widget.onCheckboxChanged,
        ),
        title: Text(
          widget.workplace['workplace_id'],
          style: TextStyle(color: colorScheme.onSurface),
        ),
        subtitle: Text(
          'Master IP: ${widget.workplace['master_ip']}',
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
                      workplaceId: widget.workplace['workplace_id'],
                      workplaceName: widget.workplace['workplace_id'],
                    ),
                  ),
                );
              },
            ),
            SizedBox(width: 8),
            ElevatedButton(
              child: Text('Learning'),
              onPressed: widget.onLearningStart,
            ),
            SizedBox(width: 8),
            ElevatedButton(
              child: Text('Testing'),
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all(
                  isTestingInProgress || widget.testingManager.isTestingForWorkplace(widget.workplace['workplace_id']) ? Colors.green : null,
                ),
              ),
              onPressed: () async {
                setState(() {
                  isTestingInProgress = true;
                });
                try {
                  await widget.testingManager.toggleTesting(
                    context,
                    widget.workplace['workplace_id'],
                    widget.databaseHelper,
                    widget.onTestingToggle,
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error during testing: $e')),
                  );
                } finally {
                  setState(() {
                    isTestingInProgress = false;
                  });
                }
              },
            ),
            SizedBox(width: 8),
            ElevatedButton(
              child: Text('Products'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductList(
                      workplaceId: widget.workplace['workplace_id'],
                      workplaceName: widget.workplace['workplace_id'],
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