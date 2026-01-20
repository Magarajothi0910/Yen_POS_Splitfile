import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Server_Client/sendDataToClients.dart';

Future<void> updateTopPrioritiesAndBroadcast() async {
  double parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  try {
    final box = Hive.isBoxOpen('connectedDevices')
        ? Hive.box('connectedDevices')
        : await Hive.openBox('connectedDevices');

    List<Map<String, dynamic>> allDevices = [];

    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw is! Map) continue;

      final Map<String, dynamic> data = Map<String, dynamic>.from(raw);

      allDevices.add({
        ...data,
        'deviceType': data['deviceType'] ?? 'client',
      });
    }

    // Calculate score for ALL devices
    List<Map<String, dynamic>> scoredDevices = allDevices.map((device) {
      final double totalRam = parseDouble(device['totalRamGB']);
      final double totalStorage = parseDouble(device['totalStorageGB']);
      final int battery = parseInt(device['batteryLevel']);
      final int usageMinutes = parseInt(device['dailyAppUsageMinutes']);

      final double score =
          (totalRam * 0.4) +
          (totalStorage * 0.3) +
          (battery / 100 * 0.2) +
          ((usageMinutes > 0 ? 1440 - usageMinutes : 1440) / 1440 * 0.1);

      return {...device, 'score': double.parse(score.toStringAsFixed(3))};
    }).toList();

    // Separate server and clients with scores
    Map<String, dynamic>? scoredServer;
    List<Map<String, dynamic>> scoredClients = [];

    for (var device in scoredDevices) {
      if (device['deviceType'] == 'server') {
        scoredServer = device;
      } else {
        scoredClients.add(device);
      }
    }

    // Sort ALL clients by score descending
    scoredClients.sort(
      (a, b) => (b['score'] as double).compareTo(a['score'] as double),
    );

    // Assign priority: 1 to 5 for top 5, null for others
    for (int i = 0; i < scoredClients.length; i++) {
      scoredClients[i]['priority'] = i < 5 ? i + 1 : null;
    }

    // Build final list: Server first (if exists), then ALL clients sorted
    List<Map<String, dynamic>> broadcastList = [];

    if (scoredServer != null) {
      broadcastList.add({
        'deviceType': 'server',
        'clientIp': scoredServer['clientIp'],
        'model': scoredServer['model'],
        'manufacturer': scoredServer['manufacturer'],
        'osVersion': scoredServer['osVersion'],
        'batteryLevel': scoredServer['batteryLevel'],
        'batteryState': scoredServer['batteryState'],
        'totalRamGB': scoredServer['totalRamGB'],
        'freeRamGB': scoredServer['freeRamGB'],
        'totalStorageGB': scoredServer['totalStorageGB'],
        'freeStorageGB': scoredServer['freeStorageGB'],
        'dailyAppUsageMinutes': scoredServer['dailyAppUsageMinutes'],
        'score': scoredServer['score'],
        // No priority for server
      });
    }

    // Add ALL clients (top 5 with priority, others without)
    for (var client in scoredClients) {
      broadcastList.add({
        'deviceType': 'client',
        'clientIp': client['clientIp'],
        'model': client['model'],
        'manufacturer': client['manufacturer'],
        'osVersion': client['osVersion'],
        'batteryLevel': client['batteryLevel'],
        'batteryState': client['batteryState'],
        'totalRamGB': client['totalRamGB'],
        'freeRamGB': client['freeRamGB'],
        'totalStorageGB': client['totalStorageGB'],
        'freeStorageGB': client['freeStorageGB'],
        'dailyAppUsageMinutes': client['dailyAppUsageMinutes'],
        'priority': client['priority'], // 1–5 or null
        'score': client['score'],
      });
    }

    // Save full list to Hive under a better key name
    final priorityBox = Hive.isBoxOpen('deviceInfoData')
        ? Hive.box('deviceInfoData')
        : await Hive.openBox('deviceInfoData');

    await priorityBox.put('allConnectedDevices', broadcastList);

    // Broadcast the full updated list
    final broadcastPayload = {
      'action': 'priorityUpdate',
      'allDevices': broadcastList, // Clearer name than 'topDevices'
    };

    sendDataToClients(broadcastPayload , clients);

    // channel.sink.add(jsonEncode(broadcastPayload));

    debugPrint(
      "Priority updated & broadcasted: "
      "Server: ${scoredServer != null ? 'Yes' : 'No'}, "
      "Total Clients: ${scoredClients.length}, "
      "Top 5 Prioritized: ${scoredClients.length >= 5 ? 5 : scoredClients.length}",
    );
  } catch (e, st) {
    debugPrint("Error updating priorities: $e");
    debugPrint(st.toString());
  }
}
