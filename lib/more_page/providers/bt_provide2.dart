import 'dart:async';
import 'package:flutter/material.dart';
// import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class BluetoothProvider2 with ChangeNotifier {
  // BluetoothConnection? connection;
  double _weight = 0.0;
  bool isConnected = false;
  String buffer = '';
  String wsName = '';
  StreamSubscription? _connectionSubscription;

  double get weight => _weight;



  double? parseWeight(String data) {
    RegExp exp = RegExp(r'(\d{1,3}\.\d{3})');
    Iterable<Match> matches = exp.allMatches(data);

    if (matches.isNotEmpty) {
      try {
        String latestMatch = matches.last.group(0) ?? '0.000';
        return double.parse(latestMatch);
      } catch (e) {
      }
    }
    return null;
  }
}
