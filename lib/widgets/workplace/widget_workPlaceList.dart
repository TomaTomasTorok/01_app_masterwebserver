import 'package:flutter/material.dart';
import 'package:masterwebserver/widgets/workplace/workplace_learning.dart';
import 'package:masterwebserver/widgets/workplace/workplace_testing.dart';
import '../../JsonServ/task_services.dart';
import '../../Log/log_view_screan.dart';
import '../../Log/logger.dart';
import '../../SQLite/database_helper.dart';
import '../../main.dart';
import '../MasterIPList.dart';
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
  List<Map<String, dynamic>> workplaces = [];
  final TestingManager _testingManager = TestingManager();
  Map<String, Function> _learningCallbacks = {};
  late final TaskService _taskService;

  @override
  void initState() {
    super.initState();
    _taskService = TaskService(_databaseHelper);
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
          ElevatedButton(
            onPressed: () async {
              print("kocúrik");
              await _taskService.synchronizeJsonWithDatabase();
              await _taskService.processNewTasks();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Tasks synchronized and processed')),
              );
            },
            child: Text("Sync & Process"),
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

class AlternatingColorListTile extends StatefulWidget {
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

class TestingManager {
  Map<String, bool> testingState = {};
  Map<String, List<WebSocketChannel>> activeChannels = {};

  bool isTestingForWorkplace(String workplaceId) {
    return testingState[workplaceId] ?? false;
  }

  Future<void> toggleTesting(BuildContext context, String workplaceId, DatabaseHelper databaseHelper, VoidCallback updateUI) async {
    if (!isTestingForWorkplace(workplaceId)) {
      await startTesting(context, workplaceId, databaseHelper);
    } else {
      await stopTesting(context, workplaceId);
    }
    testingState[workplaceId] = !isTestingForWorkplace(workplaceId);
    updateUI();
  }

  Future<void> startTesting(BuildContext context, String workplaceId, DatabaseHelper databaseHelper) async {
    try {
      final masterIPs = await databaseHelper.getMasterIPsForWorkplace(workplaceId);
      if (masterIPs.isEmpty) {
        throw Exception('No Master IPs found for this workplace');
      }

      final data = {
        "data": [
          [0],
          [99,0,0]
        ]
      };

      activeChannels[workplaceId] = [];

      for (var masterIP in masterIPs) {
        try {
          final uri = Uri.parse('ws://${masterIP['master_ip']}:81');
          if (!isValidIpAddress(masterIP['master_ip'])) {
            throw FormatException('Invalid IP address format');
          }

          WebSocket socket = await WebSocket.connect(uri.toString())
              .timeout(Duration(seconds: 5));
          final channel = IOWebSocketChannel(socket);

          activeChannels[workplaceId]!.add(channel);

          channel.sink.add(json.encode(data));

          channel.stream.listen(
                (message) {
              print('Received message from ${masterIP['master_ip']}: $message');
            },
            onDone: () {
              print('WebSocket closed for ${masterIP['master_ip']}');
            },
            onError: (error) {
              print('WebSocket error for ${masterIP['master_ip']}: $error');
            },
          );
        } catch (e) {
          print('Error connecting to WebSocket for ${masterIP['master_ip']}: $e');
        }
      }

      if (activeChannels[workplaceId]!.isEmpty) {
        throw Exception('Failed to connect to any WebSocket');
      }
    } catch (e) {
      print('Unhandled error in startTesting: $e');
      throw e;  // Re-throw the exception to be caught in the UI
    }
  }

  Future<void> stopTesting(BuildContext context, String workplaceId) async {
    if (activeChannels.containsKey(workplaceId)) {
      final stopData = {
        "data": [
          [0],
          [0,0,0]
        ]
      };

      for (var channel in activeChannels[workplaceId]!) {
        try {
          channel.sink.add(json.encode(stopData));
          await Future.delayed(Duration(milliseconds: 100));
          await channel.sink.close();
        } catch (e) {
          print('Error sending stop signal or closing channel: $e');
        }
      }
      activeChannels[workplaceId]!.clear();
    }
  }

  bool isValidIpAddress(String ipAddress) {
    try {
      return InternetAddress.tryParse(ipAddress) != null;
    } catch (e) {
      return false;
    }
  }
}