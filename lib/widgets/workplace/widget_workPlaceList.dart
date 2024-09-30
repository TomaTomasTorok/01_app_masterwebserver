import 'package:flutter/material.dart';
import 'package:masterwebserver/widgets/workplace/workplace_learning.dart';
import 'package:masterwebserver/widgets/workplace/workplace_testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../Log/log_view_screan.dart';
import '../../Log/logger.dart';
import '../../SQLite/database_helper.dart';
import '../../Services/jsonTaskService.dart';
import '../../Services/path_change.dart';
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
  Map<String, bool> _syncLoopRunning = {};
  String? _currentProduct;

  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    jsonTaskSynchronizer = JsonTaskSynchronizer(_databaseHelper);
    _taskService = TaskService(_databaseHelper);
    _loadWorkplaces();
    _loadCheckedWorkplaces();
    //Timer pre pravidelné aktualizácie informácií o aktuálnom produkte
    _updateTimer = Timer.periodic(Duration(seconds: 1), (timer) {
     // widget.onRefresh();
      setState(() {
        _currentProduct = _taskService.currentProduct;

      });
    });
  }

  void _startSyncLoops() {
    List<String> checkedWorkplaceIds = getCheckedWorkplaceIds();
    print('Starting sync loops for workplaces: $checkedWorkplaceIds');

    for (String workplaceId in checkedWorkplaceIds) {
      if (!_syncLoopRunning.containsKey(workplaceId) || !_syncLoopRunning[workplaceId]!) {
        print('Starting sync loop for workplace: $workplaceId');
        _startSyncLoopForWorkplace(workplaceId);
      }
    }

    // Stop sync loops for unchecked workplaces
    _syncLoopRunning.keys.where((id) => !checkedWorkplaceIds.contains(id)).forEach((id) {
      print('Stopping sync loop for workplace: $id');
      _syncLoopRunning[id] = false;
    });
  }
//




  Future<void> _startSyncLoopForWorkplace(String workplaceId) async {
    _syncLoopRunning[workplaceId] = true;
    while (_syncLoopRunning[workplaceId]! && mounted) {
      await jsonTaskSynchronizer.synchronizeJsonWithDatabase(workplaceId);
      if(!_taskService.isBlocked!){ _taskService.processNewTasks(workplaceId);


      }

      await Future.delayed(Duration(seconds: 1));
    }
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
    _startSyncLoops();
  }
// Možnosť pracovania súčasne s viacerími checkbox
  // Future<void> _saveCheckedWorkplace(String workplaceId, bool isChecked) async {
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.setBool(workplaceId, isChecked);
  //   _startSyncLoops();
  // }


  // iba jeden aktívny chackbox
  Future<void> _saveCheckedWorkplace(String workplaceId, bool isChecked) async {
    final prefs = await SharedPreferences.getInstance();
    if (isChecked) {
      // Ak je nový checkbox zaškrtnutý, odškrtneme všetky ostatné
      _checkedWorkplaces.forEach((key, value) {
        if (key != workplaceId) {
          _checkedWorkplaces[key] = false;
          prefs.setBool(key, false);
        }
      });
    }
    await prefs.setBool(workplaceId, isChecked);
    _startSyncLoops();
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
        // title: Text("Workplace List"),
     title:   Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Workplace List",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            if (_currentProduct != null )
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: "Task in Progress: ", // Normálny text
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    TextSpan(
                      text: "$_currentProduct", // Tučný text pre produkt
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

          ],
        ),
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
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () => showSettingsDialog(context),
          ),
          if (_currentProduct != null )
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

            child: Text("Finish"),
          ),

          Container(width: 180),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF60C871), // Nastavenie farby pozadia na zelenú
              foregroundColor: Colors.white, // Nastavenie farby textu na bielu
            ),
            onPressed: () async {
              List<String> checkedWorkplaceIds = getCheckedWorkplaceIds();
              if (checkedWorkplaceIds.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please select at least one workplace')),
                );
                return;
              }

              // for (String workplaceId in checkedWorkplaceIds) {
              //   await jsonTaskSynchronizer.synchronizeJsonWithDatabase(workplaceId);
              //   await _taskService.processNewTasks(workplaceId);
              // }

              // ScaffoldMessenger.of(context).showSnackBar(
              //   SnackBar(content: Text('Tasks synchronized and processed for selected workplaces')),
              // );
            },
            child: Text("Online - Sync & Process"),
          ),
          Container(width: 500,),
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
          Container(width: 10,),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity, // Zaberie celú šírku rodiča
            height: 5.0, // Hrúbka čiary
            color: Colors.grey, // Farba čiary
          ),
          Container(height: 10,),
          Expanded(
            child: ListView.builder(
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
                   processNewTasks: _taskService.processNewTasks,
                );
              },
            ),
          ),
        ],
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
    _syncLoopRunning.forEach((key, value) => _syncLoopRunning[key] = false);
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
  final Function(String) processNewTasks;


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
    required this.processNewTasks,
  }) : super(key: key);

  @override
  _AlternatingColorListTileState createState() => _AlternatingColorListTileState();
}

class _AlternatingColorListTileState extends State<AlternatingColorListTile> {
  bool isTestingInProgress = false;
  void _showLoadingDialog(BuildContext context, String action) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text('$action in progress...'),
              ],
            ),
          ),
        );
      },
    );

    // Automaticky zatvoriť dialog po 3 sekundách
    Future.delayed(Duration(seconds: 3), () {
      Navigator.of(context).pop();
    });
  }
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

                    ),
                  ),
                );
              },
            ),
            SizedBox(width: 8),
            ElevatedButton(
              child: Text('Learning'),
             // onPressed: widget.onLearningStart,
              onPressed: () {

                widget.onLearningStart();
              },
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
                _showLoadingDialog(context, 'Testing');

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
            SizedBox(width: 8),
            ElevatedButton(
              child: Text('Delete'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text('Delete Workplace'),
                      content: Text('Are you sure you want to delete this workplace?'),
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
                            widget.databaseHelper.deleteWorkplace(widget.workplace['workplace_id']).then((_) {
                              widget.onRefresh();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Workplace deleted successfully')),
                              );
                            }).catchError((error) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to delete workplace: $error')),
                              );
                            });
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),



            SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(left: 35.0),
              child: ElevatedButton(
                child: Text('Products'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProductList(
                        workplaceId: widget.workplace['workplace_id'],

                        databaseHelper: widget.databaseHelper,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}