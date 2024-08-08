
import 'package:flutter/material.dart';

class LogViewerScreen extends StatelessWidget {
  final String fileName;
  final String logContent;

  LogViewerScreen({required this.fileName, required this.logContent});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(fileName),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(logContent),
        ),
      ),
    );
  }
}