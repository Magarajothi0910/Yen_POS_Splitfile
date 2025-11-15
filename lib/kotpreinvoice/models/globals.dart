// library globals;

// import 'package:flutter/material.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';

// String branchName = "";
// String branchId = "";
// int totalTables = 0;
// String aliasname = "AR";
// String ordertype = "Dine In";
// List<Map<String, dynamic>> tables = [
//   // {
//   //   "areaName": "AC",
//   //   "tables": [
//   //     {"tableNumber": "Table 1", "seats": 4},
//   //     {"tableNumber": "Table 2", "seats": 4},
//   //     {"tableNumber": "Table 3", "seats": 4},
//   //     {"tableNumber": "Table 4", "seats": 4},
//   //     {"tableNumber": "Table 5", "seats": 4},
//   //     {"tableNumber": "Table 6", "seats": 4},
//   //     {"tableNumber": "Table 7", "seats": 4},
//   //     {"tableNumber": "Table 8", "seats": 4},
//   //     {"tableNumber": "Table 9", "seats": 4},
//   //     {"tableNumber": "Table 10", "seats": 40},
//   //   ],
//   //   "tableCount": 10,
//   //   "status": "active",
//   // },
//   // {
//   //   "areaName": "HALL",
//   //   "tables": [
//   //     {"tableNumber": "Table 11", "seats": 4},
//   //     {"tableNumber": "Table 12", "seats": 4},
//   //     {"tableNumber": "Table 13", "seats": 4},
//   //     {"tableNumber": "Table 14", "seats": 4},
//   //     {"tableNumber": "Table 15", "seats": 4},
//   //     {"tableNumber": "Table 16", "seats": 4},
//   //     {"tableNumber": "Table 17", "seats": 4},
//   //     {"tableNumber": "Table 18", "seats": 4},
//   //     {"tableNumber": "Table 19", "seats": 4},
//   //     {"tableNumber": "Table 20", "seats": 4},
//   //   ],
//   //   "tableCount": 10,
//   //   "status": "active",
//   // },
//   // {
//   //   "areaName": "FIRST FLOOR",
//   //   "tables": [
//   //     {"tableNumber": "Table 21", "seats": 4},
//   //     {"tableNumber": "Table 22", "seats": 4},
//   //     {"tableNumber": "Table 23", "seats": 4},
//   //     {"tableNumber": "Table 24", "seats": 4},
//   //     {"tableNumber": "Table 25", "seats": 4},
//   //     {"tableNumber": "Table 26", "seats": 4},
//   //     {"tableNumber": "Table 27", "seats": 4},
//   //     {"tableNumber": "Table 28", "seats": 4},
//   //     {"tableNumber": "Table 29", "seats": 4},
//   //     {"tableNumber": "Table 30", "seats": 4},
//   //   ],
//   //   "tableCount": 10,
//   //   "status": "active",
//   // },
//   // {
//   //   "areaName": "BALCONY",
//   //   "tables": [
//   //     {"tableNumber": "Table 31", "seats": 4},
//   //     {"tableNumber": "Table 32", "seats": 4},
//   //     {"tableNumber": "Table 33", "seats": 4},
//   //     {"tableNumber": "Table 34", "seats": 4},
//   //     {"tableNumber": "Table 35", "seats": 4},
//   //     {"tableNumber": "Table 36", "seats": 4},
//   //     {"tableNumber": "Table 37", "seats": 4},
//   //     {"tableNumber": "Table 38", "seats": 4},
//   //     {"tableNumber": "Table 39", "seats": 4},
//   //     {"tableNumber": "Table 40", "seats": 4},
//   //     {"tableNumber": "Table 41", "seats": 4},
//   //     {"tableNumber": "Table 42", "seats": 4},
//   //     {"tableNumber": "Table 43", "seats": 4},
//   //     {"tableNumber": "Table 44", "seats": 4},
//   //     {"tableNumber": "Table 45", "seats": 4},
//   //     {"tableNumber": "Table 46", "seats": 40},
//   //     {"tableNumber": "Table 47", "seats": 4},
//   //     {"tableNumber": "Table 48", "seats": 4},
//   //     {"tableNumber": "Table 49", "seats": 4},
//   //     {"tableNumber": "Table 50", "seats": 4},
//   //   ],
//   //   "tableCount": 20,
//   //   "status": "active",
//   // },
// ];
// String serverip = '192.168.1.152';
// int port = 8090;
// int udpPort = 44556;
// String userName = "";
// String createdBy = "";
// String enteredWeight = '';
// int count = 0;
// int count2 = 0;
// int count3 = 0;
// int count4 = 0;
// bool hold = false;
// String appType = 'server';
// const int kMaxRemarkLength = 50;
// final List<Map<String, dynamic>> receivedData = [];
// final Set<WebSocketChannel> clients = {};
// final Map<String, WebSocketChannel> deviceClientMap =
//     {}; // Map deviceCode to WebSocketChannel
// List<String> areaNames = [];
// const int maxExtraSeatsPerTable = 3;
// Map<String, List<String>> extraTables = {};

// ValueNotifier<String> currentDate = ValueNotifier('');
// ValueNotifier<String> currentTime = ValueNotifier('');
