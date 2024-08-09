// import 'dart:io';
// import 'package:flutter/foundation.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:intl/intl.dart';
//
// class Logger {
//   static const String logFilePrefix = 'app_logs_';
//   static const String logFileExtension = '.txt';
//   static Directory? _logDirectory;
//
//   static Future<void> initialize() async {
//     try {
//       final appDocDir = await getApplicationDocumentsDirectory();
//       _logDirectory = Directory('${appDocDir.path}/logs');
//       if (!await _logDirectory!.exists()) {
//         await _logDirectory!.create(recursive: true);
//       }
//       print('Log directory initialized: ${_logDirectory!.path}');
//     } catch (e) {
//       print('Error initializing logger: $e');
//     }
//   }
//
//   static Future<void> log(String message) async {
//     try {
//       if (_logDirectory == null) {
//         print('Logger not initialized. Call Logger.initialize() first.');
//         return;
//       }
//
//       final now = DateTime.now();
//       final formattedDate = DateFormat('yyyy-MM-dd').format(now);
//       final formattedTime = DateFormat('HH:mm:ss.SSS').format(now);
//       final logMessage = '$formattedTime: $message\n';
//
//       final file = File('${_logDirectory!.path}/$logFilePrefix$formattedDate$logFileExtension');
//       await file.writeAsString(logMessage, mode: FileMode.append);
//
//       print('Logged: $message');  // Always print for debugging purposes
//     } catch (e) {
//       print('Error logging message: $e');
//     }
//   }
//
//   static Future<List<String>> getLogFiles() async {
//     try {
//       if (_logDirectory == null) {
//         print('Logger not initialized. Call Logger.initialize() first.');
//         return [];
//       }
//
//       final files = _logDirectory!.listSync()
//           .where((file) => file.path.contains(logFilePrefix) && file.path.endsWith(logFileExtension))
//           .map((file) => file.path.split(Platform.pathSeparator).last)
//           .toList();
//
//       print('Found ${files.length} log files');
//       return files..sort((a, b) => b.compareTo(a));
//     } catch (e) {
//       print('Error getting log files: $e');
//       return [];
//     }
//   }
//
//   static Future<String> readLogFile(String fileName) async {
//     try {
//       if (_logDirectory == null) {
//         return 'Logger not initialized. Call Logger.initialize() first.';
//       }
//
//       final file = File('${_logDirectory!.path}${Platform.pathSeparator}$fileName');
//       if (await file.exists()) {
//         final content = await file.readAsString();
//         print('Read log file: $fileName, size: ${content.length} bytes');
//         return content;
//       }
//       print('Log file not found: ${file.path}');
//       return 'No logs available.';
//     } catch (e) {
//       print('Error reading log file: $e');
//       return 'Error reading log file: $e';
//     }
//   }
// }