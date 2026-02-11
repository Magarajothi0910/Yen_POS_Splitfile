import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

Future<void> handlePriorityUpdate(Map<String, dynamic> data) async {
    try {
      final List<dynamic> allDevicesDynamic = data['allDevices'] ?? [];
 
      if (allDevicesDynamic.isEmpty) {
        debugPrint("Warning: Received empty device list");
        return;
      }
 
      final List<Map<String, dynamic>> allDevices = allDevicesDynamic.cast<Map<String, dynamic>>();
 
      // Use the SAME box name as server: 'serverData'
      final box = Hive.isBoxOpen('serverData') ? Hive.box('serverData') : await Hive.openBox('serverData');
 
      final String myIp = box.get('clientIp') ?? Hive.box('deviceInfoData').get('clientIp') ?? '';
 
      int myPriority = 0;
      double myScore = 0.0;
      String myRankInfo = 'Not ranked';
 
      for (final device in allDevices) {
        if (device['clientIp'] == myIp) {
          myScore = (device['score'] as num).toDouble();
 
          if (device['deviceType'] == 'server') {
            myRankInfo = 'You are the Server';
            break;
          }
 
          final priority = device['priority'];
          if (priority is int && priority > 0) {
            myPriority = priority;
            myRankInfo = "Priority #$myPriority (Score: ${myScore.toStringAsFixed(2)})";
          } else {
            myRankInfo = "Not in Top 5 (Score: ${myScore.toStringAsFixed(2)})";
          }
          break;
        }
      }
 
      // Save everything in the same box as server
      await box.put('allConnectedDevices', allDevices);
      await box.put('myPriority', myPriority);
      await box.put('myRankInfo', myRankInfo);
      await box.put('myScore', myScore);
 
      debugPrint("Client: Priority update saved. My rank: $myRankInfo");
    } catch (e, st) {
      debugPrint("Error in _handlePriorityUpdate: $e\n$st");
    }
  }
 