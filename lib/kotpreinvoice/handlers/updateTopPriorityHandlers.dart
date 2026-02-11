import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:yen_pos/Global/globals_data.dart' as globals;
import 'package:yen_pos/Server_Client/sendDataToClients.dart';
import 'package:yen_pos/kotpreinvoice/services/serverreachable.dart';

double clamp01(double value) {
  return value.clamp(0.0, 1.0);
}

double calculateOsScore(String osVersion) {
  final sdkMatch = RegExp(r'SDK (\d+)').firstMatch(osVersion);
  final int sdk = sdkMatch != null ? int.parse(sdkMatch.group(1)!) : 21;

  // Android SDK reference
  // 21 → very old, 34 → latest
  return clamp01((sdk - 21) / (34 - 21)) * 20;
}

double calculateRamScore(double totalRamGB, double freeRamGB) {
  final double totalScore = clamp01(totalRamGB / 12) * 15; // 12GB = max
  final double freeScore = clamp01(freeRamGB / totalRamGB) * 10;
  return totalScore + freeScore;
}

double calculateStorageScore(double totalGB, double freeGB) {
  final double totalScore = clamp01(totalGB / 256) * 15; // 256GB = max
  final double freeScore = clamp01(freeGB / totalGB) * 10;
  return totalScore + freeScore;
}

double calculateBatteryScore(int level, String state) {
  double score = clamp01(level / 100) * 10;

  if (state == 'charging') score += 3;
  if (state == 'full') score += 5;

  return clamp01(score / 15) * 15;
}

double calculateUsageScore(int minutes) {
  if (minutes <= 30) return 15;
  if (minutes <= 120) return 10;
  if (minutes <= 300) return 5;
  return 2;
}

int calculateDeviceScore(Map<String, dynamic> info) {
  double score = 0;

  score += calculateOsScore(info['osVersion']);
  score += calculateRamScore(
    double.parse(info['totalRamGB']),
    double.parse(info['freeRamGB']),
  );
  score += calculateStorageScore(
    double.parse(info['totalStorageGB']),
    double.parse(info['freeStorageGB']),
  );
  score += calculateBatteryScore(info['batteryLevel'], info['batteryState']);
  score += calculateUsageScore(info['dailyAppUsageMinutes']);

  return score.round().clamp(0, 100);
}

int getAppRank(String? app) {
  switch (app) {
    case 'POS':
      return 1;
    case 'OM':
      return 2;
    case 'KOT':
      return 3;
    default:
      return 4;
  }
}

Future<void> updateTopPrioritiesAndBroadcast() async {
  try {
    debugPrint('🟢 updateTopPrioritiesAndBroadcast() START');

    final box = Hive.isBoxOpen('connectedDevices')
        ? Hive.box('connectedDevices')
        : await Hive.openBox('connectedDevices');

    Map<String, dynamic>? server;
    final List<Map<String, dynamic>> clients = [];

    final now = DateTime.now();

    // 1️⃣ Extract devices WITHOUT trusting Hive order
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw is! Map) continue;

      final device = raw.map((k, v) => MapEntry(k.toString(), v));

      final last = DateTime.tryParse(device['lastUpdated'] ?? '');
      if (last == null || now.difference(last).inMinutes > 5) {
        debugPrint('⏭️ Skipping stale device: ${device['clientIp']}');
        continue;
      }

      device['score'] = calculateDeviceScore(device);

      if (device['deviceType'] == 'server') {
        server = device;
      } else {
        clients.add(device);
      }
    }

    if (server == null) {
      debugPrint('❌ No server found — abort broadcast');
      return;
    }

    clients.sort((a, b) {
      final ai = a['orderIndex'] ?? 9999;
      final bi = b['orderIndex'] ?? 9999;
      return ai.compareTo(bi);
    });

    // 2️⃣ CANONICAL ORDER: server first, then clients
    final List<Map<String, dynamic>> orderedDevices = [server, ...clients];

    debugPrint('📦 Canonical device order:');
    for (int i = 0; i < orderedDevices.length; i++) {
      debugPrint(
        '   [$i] ${orderedDevices[i]['clientIp']} '
        '(${orderedDevices[i]['deviceType']})',
      );
    }

    // 3️⃣ Build broadcast list
    final List<Map<String, dynamic>> broadcastList = [];

    // Server (index 0)
    broadcastList.add({...server, 'deviceType': 'server'});

    // Clients with priority
    for (int i = 1; i < orderedDevices.length; i++) {
      final client = orderedDevices[i];
      broadcastList.add({...client, 'deviceType': 'client', 'priority': i});
    }

    // 4️⃣ Save
    final priorityBox = Hive.isBoxOpen('deviceInfoData')
        ? Hive.box('deviceInfoData')
        : await Hive.openBox('deviceInfoData');

    await priorityBox.put('allConnectedDevices', broadcastList);

    // 5️⃣ Broadcast
    debugPrint('📡 Broadcasting priorityUpdate');
    sendDataToClients({
      'action': 'priorityUpdate',
      'allDevices': broadcastList,
    }, globals.clients);

    debugPrint(
      '✅ Priority update COMPLETE '
      '(Server=true, Clients=${clients.length})',
    );
  } catch (e, st) {
    debugPrint('❌ Priority update failed: $e');
    debugPrint(st.toString());
  }
}

Future<void> handleClientReorder(Map<String, dynamic> data) async {
  try {
    final String clientIp = data['clientIp'];
    final int targetOrderIndex = data['targetOrderIndex'];

    debugPrint(
      '🔁 Server reorder request: $clientIp → position $targetOrderIndex',
    );

    final box = Hive.isBoxOpen('connectedDevices')
        ? Hive.box('connectedDevices')
        : await Hive.openBox('connectedDevices');

    // 1️⃣ Build canonical ordered list using orderIndex
    Map<String, dynamic>? server;
    final List<Map<String, dynamic>> clients = [];

    for (final v in box.values) {
      if (v is! Map) continue;

      final device = Map<String, dynamic>.from(v);

      if (device['deviceType'] == 'server') {
        server = device;
      } else {
        clients.add(device);
      }
    }

    if (server == null) {
      debugPrint('❌ No server found — abort reorder');
      return;
    }

    clients.sort(
      (a, b) => (a['orderIndex'] ?? 0).compareTo(b['orderIndex'] ?? 0),
    );

    final currentIndex = clients.indexWhere((d) => d['clientIp'] == clientIp);

    if (currentIndex == -1) {
      debugPrint('❌ Client not found in server list');
      return;
    }

    // Clamp target
    final newIndex = targetOrderIndex.clamp(1, clients.length) - 1;

    // 2️⃣ Reorder
    final moved = clients.removeAt(currentIndex);
    clients.insert(newIndex, moved);

    // 3️⃣ Reassign orderIndex cleanly
    for (int i = 0; i < clients.length; i++) {
      clients[i]['orderIndex'] = i + 1;
    }

    // 4️⃣ Rewrite Hive (order-safe)
    await box.clear();

    await box.put('server', server);

    for (final c in clients) {
      await box.put('device_${c['clientIp']}', c);
    }

    debugPrint('📦 New canonical order:');
    for (final c in clients) {
      debugPrint('   ${c['clientIp']} → orderIndex=${c['orderIndex']}');
    }

    // 5️⃣ Broadcast
    await updateTopPrioritiesAndBroadcast();

    debugPrint('✅ Server reorder applied successfully');
  } catch (e, st) {
    debugPrint('❌ Error in _handleClientReorder: $e');
    debugPrint(st.toString());
  }
}

Future<void> handlePriorityUpdate(Map<String, dynamic> data) async {
  try {
    debugPrint('🟢 _handlePriorityUpdate RECEIVED');

    final List<dynamic> allDevicesDynamic = data['allDevices'] ?? [];

    if (allDevicesDynamic.isEmpty) {
      debugPrint('⚠️ Warning: Received empty device list');
      return;
    }

    debugPrint('📦 Devices received from server: ${allDevicesDynamic.length}');

    final List<Map<String, dynamic>> allDevices = allDevicesDynamic
        .cast<Map<String, dynamic>>();

    // Use the SAME box name as server
    final box = Hive.isBoxOpen('serverData')
        ? Hive.box('serverData')
        : await Hive.openBox('serverData');

    final String myIp = (await getLocalIp())?.trim() ?? '';

    debugPrint('📍 Local device IP: $myIp');

    int myPriority = 0;
    double myScore = 0.0;
    String myRankInfo = 'Not ranked';

    bool foundSelf = false;

    for (final device in allDevices) {
      debugPrint(
        '🔍 Checking device '
        '${device['clientIp']} '
        '(type=${device['deviceType']}, '
        'priority=${device['priority']}, '
        'score=${device['score']})',
      );

      if (device['clientIp'] == myIp) {
        foundSelf = true;

        myScore = (device['score'] as num).toDouble();

        if (device['deviceType'] == 'server') {
          myRankInfo = 'You are the Server';
          debugPrint('🖥️ This device is SERVER');
        } else {
          final int priority =
              int.tryParse(device['priority']?.toString() ?? '') ?? 0;

          myPriority = priority;

          if (priority > 0) {
            myRankInfo =
                'Priority #$myPriority (Score: ${myScore.toStringAsFixed(2)})';
            debugPrint('📱 This device is CLIENT → priority=$myPriority');
          } else {
            myRankInfo = 'Not in Top 5 (Score: ${myScore.toStringAsFixed(2)})';
            debugPrint('📱 This device is CLIENT but unranked');
          }
        }

        break;
      }
    }

    if (!foundSelf) {
      debugPrint('⚠️ Local device not found in allDevices list (IP mismatch?)');
    }

    // Save everything in the same box as server
    await box.put('allConnectedDevices', allDevices);
    await box.put('myPriority', myPriority);
    await box.put('myRankInfo', myRankInfo);
    await box.put('myScore', myScore);

    debugPrint(
      '💾 Priority data saved → '
      'priority=$myPriority, score=$myScore',
    );

    debugPrint('✅ Client: Priority update saved. My rank: $myRankInfo');
  } catch (e, st) {
    debugPrint('❌ Error in _handlePriorityUpdate: $e');
    debugPrint(st.toString());
  }
}
