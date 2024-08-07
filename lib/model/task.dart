import 'dart:convert';

class Task {
  int? id;
  final String product;
  final String workstationCreated;
  final DateTime timestampCreated;
  String? workstationProcessed;
  DateTime? timestampProcessed;
  String status;

  Task({
    this.id,
    required this.product,
    required this.workstationCreated,
    required this.timestampCreated,
    this.workstationProcessed,
    this.timestampProcessed,
    this.status = 'Ongoing',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product': product,
      'workstation_created': workstationCreated,
      'timestamp_created': timestampCreated.toIso8601String(),
      'workstation_processed': workstationProcessed,
      'timestamp_processed': timestampProcessed?.toIso8601String(),
      'status': status,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      product: map['product'] ?? '',
      workstationCreated: map['workstation_created'] ?? '',
      timestampCreated: map['timestamp_created'] != null
          ? DateTime.parse(map['timestamp_created'])
          : DateTime.now(),
      workstationProcessed: map['workstation_processed'],
      timestampProcessed: map['timestamp_processed'] != null
          ? DateTime.parse(map['timestamp_processed'])
          : null,
      status: map['status'] ?? 'Ongoing',
    );
  }

  String toJson() => json.encode(toMap());

  factory Task.fromJson(String source) => Task.fromMap(json.decode(source));
}