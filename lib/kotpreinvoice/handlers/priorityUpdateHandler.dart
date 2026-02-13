import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:yen_pos/kotpreinvoice/services/serverreachable.dart';

// Future<void> handlePriorityUpdate(Map<String, dynamic> data) async {
//     try {
//       final List<dynamic> allDevicesDynamic = data['allDevices'] ?? [];

//       if (allDevicesDynamic.isEmpty) {
//         debugPrint("Warning: Received empty device list");
//         return;
//       }

//       final List<Map<String, dynamic>> allDevices = allDevicesDynamic.cast<Map<String, dynamic>>();

//       // Use the SAME box name as server: 'serverData'
//       final box = Hive.isBoxOpen('serverData') ? Hive.box('serverData') : await Hive.openBox('serverData');

//       final String myIp = box.get('clientIp') ?? Hive.box('deviceInfoData').get('clientIp') ?? '';

//       int myPriority = 0;
//       double myScore = 0.0;
//       String myRankInfo = 'Not ranked';

//       for (final device in allDevices) {
//         if (device['clientIp'] == myIp) {
//           myScore = (device['score'] as num).toDouble();

//           if (device['deviceType'] == 'server') {
//             myRankInfo = 'You are the Server';
//             break;
//           }

//           final priority = device['priority'];
//           if (priority is int && priority > 0) {
//             myPriority = priority;
//             myRankInfo = "Priority #$myPriority (Score: ${myScore.toStringAsFixed(2)})";
//           } else {
//             myRankInfo = "Not in Top 5 (Score: ${myScore.toStringAsFixed(2)})";
//           }
//           break;
//         }
//       }

//       // Save everything in the same box as server
//       await box.put('allConnectedDevices', allDevices);
//       await box.put('myPriority', myPriority);
//       await box.put('myRankInfo', myRankInfo);
//       await box.put('myScore', myScore);

//       debugPrint("Client: Priority update saved. My rank: $myRankInfo");
//     } catch (e, st) {
//       debugPrint("Error in _handlePriorityUpdate: $e\n$st");
//     }
//   }

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
