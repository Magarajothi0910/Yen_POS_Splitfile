import 'package:flutter/material.dart';

class Printer {
  String name;
  String ipAddress;
  String type;
  List<String> items;
  bool status; // Status field for soft delete

  Printer({
    required this.name,
    required this.ipAddress,
    required this.type,
    required this.items,
    this.status = true, // Default status is true (active)
  });

  // Make sure to include the status field in toJson
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'ipAddress': ipAddress,
      'type': type,
      'items': items,
      'status': status,
    };
  }

  // Make sure to include status in fromJson or a similar factory method
  factory Printer.fromJson(Map<String, dynamic> json) {
  try {
    final itemsRaw = json['items'] as List<dynamic>?;

    return Printer(
      name: json['name'] as String? ?? 'Unknown',
      ipAddress: json['ipAddress'] as String? ?? '',
      type: json['type'] as String? ?? '',
      items: itemsRaw != null 
          ? itemsRaw.map((e) => e.toString()).toList()
          : <String>[],
      status: json['status'] as bool? ?? true,
    );
  } catch (e) {
    debugPrint('Error parsing Printer from JSON: $e\nJSON: $json');
    rethrow; // Optional: rethrow so you can catch it outside
  }
}
}
