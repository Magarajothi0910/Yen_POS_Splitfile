import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:hive/hive.dart';
// import 'package:server/services/send_data_to_server.dart';
import 'package:system_info2/system_info2.dart';
import 'package:app_usage/app_usage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:storage_info/storage_info.dart';
import 'package:yen_pos/Global/globals_data.dart';
import 'package:yen_pos/Sale_order/Widgets/Send_data_to_server.dart';

Future<Map<String, dynamic>> getDeviceInfo() async {
  final Map<String, dynamic> info = {};
  final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
  final Battery battery = Battery(); // For battery level and state
  final storageInfo = StorageInfo();

  try {
    // Common battery info (works on both Android & iOS)
    final int batteryLevel = await battery.batteryLevel;
    info['batteryLevel'] = batteryLevel;

    final BatteryState batteryState = await battery.batteryState;
    String batteryStateStr;
    switch (batteryState) {
      case BatteryState.charging:
        batteryStateStr = 'charging';
        break;
      case BatteryState.discharging:
        batteryStateStr = 'discharging';
        break;
      case BatteryState.full:
        batteryStateStr = 'full';
        break;
      default:
        batteryStateStr = 'unknown';
    }
    info['batteryState'] = batteryStateStr;

    if (Platform.isAndroid) {
      final AndroidDeviceInfo androidInfo = await deviceInfoPlugin.androidInfo;
      info['platform'] = 'android';
      info['model'] = androidInfo.model;
      info['manufacturer'] = androidInfo.manufacturer;
      info['osVersion'] =
          'Android ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})';

      // RAM
      final totalRamBytes = SysInfo.getTotalPhysicalMemory();
      final freeRamBytes = SysInfo.getFreePhysicalMemory();

      info['totalRamGB'] = (totalRamBytes / (1024 * 1024 * 1024))
          .toStringAsFixed(2);
      info['freeRamGB'] = (freeRamBytes / (1024 * 1024 * 1024)).toStringAsFixed(
        2,
      );

      // Storage
      final totalStorageBytes = await storageInfo.getStorageTotalSpace();
      final freeStorageBytes = await storageInfo.getStorageFreeSpace();

      info['totalStorageGB'] = (totalStorageBytes / (1024 * 1024 * 1024))
          .toStringAsFixed(2);

      info['freeStorageGB'] = (freeStorageBytes / (1024 * 1024 * 1024))
          .toStringAsFixed(2);

      // Daily app usage
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String packageName = packageInfo.packageName;

      final DateTime now = DateTime.now();
      final DateTime startOfDay = DateTime(now.year, now.month, now.day);

      final List<AppUsageInfo> usageList = await AppUsage().getAppUsage(
        startOfDay,
        now,
      );

      int usageMinutes = 0;
      for (final AppUsageInfo usageInfo in usageList) {
        if (usageInfo.packageName == packageName) {
          usageMinutes = usageInfo.usage.inMinutes;
          break;
        }
      }
      info['dailyAppUsageMinutes'] = usageMinutes;
    } else if (Platform.isIOS) {
      final IosDeviceInfo iosInfo = await deviceInfoPlugin.iosInfo;
      info['platform'] = 'ios';
      info['model'] = iosInfo.model;
      info['manufacturer'] = 'Apple';
      info['osVersion'] = '${iosInfo.systemName} ${iosInfo.systemVersion}';

      // RAM
      final totalRamBytes = SysInfo.getTotalPhysicalMemory();
      final freeRamBytes = SysInfo.getFreePhysicalMemory();

      info['totalRamGB'] = (totalRamBytes / (1024 * 1024 * 1024))
          .toStringAsFixed(2);
      info['freeRamGB'] = (freeRamBytes / (1024 * 1024 * 1024)).toStringAsFixed(
        2,
      );

      // Storage
      final totalStorageBytes = await storageInfo.getStorageTotalSpace();
      final freeStorageBytes = await storageInfo.getStorageFreeSpace();

      info['totalStorageGB'] = (totalStorageBytes / (1024 * 1024 * 1024))
          .toStringAsFixed(2);

      info['freeStorageGB'] = (freeStorageBytes / (1024 * 1024 * 1024))
          .toStringAsFixed(2);

      info['dailyAppUsageMinutes'] = 0;
      info['note'] =
          'Daily app usage time is not available on iOS due to platform restrictions.';
    }
  } catch (e) {
    info['error'] = e.toString();
    info['note'] = 'Some information could not be retrieved: $e';
  }

  return info;
}

Future<void> collectAndSendDeviceInfo(
  String deviceType,
  String clientIp,
) async {
  print('collectAndSendDeviceInfo');
  try {
    // 1. Get the device information using the function we created
    final Map<String, dynamic> deviceInfo = await getDeviceInfo();

    // if (!Hive.isBoxOpen('device_info')) {
    //   await Hive.openBox('device_info');
    // }

    // 2. Get existing deviceCode from Hive (or empty if not set)
    final deviceBox = Hive.isBoxOpen('deviceInfoData')
        ? Hive.box('deviceInfoData')
        : await Hive.openBox('deviceInfoData');
    // final deviceBox = Hive.box('deviceInfoData');
    final box = Hive.box('deviceData');
    String deviceCode = box.get('deviceCode')?.toString() ?? '';

    // 3. Add deviceCode to the data (useful for server to identify the device)
    deviceInfo['deviceCode'] = deviceCode;

    // Optional: Add timestamp
    deviceInfo['timestamp'] = DateTime.now().toIso8601String();
    deviceInfo['clientIp'] = clientIp;
    deviceInfo['deviceType'] = deviceType;
    deviceInfo['app'] = app;
    deviceInfo['deviceName'] = deviceName;

    // 4. Store the full device info locally in Hive (for offline access or future use)
    await deviceBox.put('lastDeviceInfo', deviceInfo);

    // 5. Prepare payload for server
    final Map<String, dynamic> payload = {
      'action': 'clientDeviceData',
      'data': deviceInfo, // This contains all device details + deviceCode
    };

    // 6. Send to server
    await sendataToServer(payload);

    // Optional: Print for debugging (remove in production)
    print('Device info collected and sent successfully');
    print('Device Code: $deviceCode');
    print(
      'Battery: ${deviceInfo['batteryLevel']}% (${deviceInfo['batteryState']})',
    );
    print('RAM: ${deviceInfo['freeRamGB']} / ${deviceInfo['totalRamGB']} GB');
  } catch (e) {
    // Handle errors gracefully (e.g., no internet, permission denied, etc.)
    print('Failed to collect or send device info: $e');

    // Still try to store locally what we could get
    final deviceBox = Hive.box('deviceInfoData');
    await deviceBox.put('lastDeviceInfoError', {
      'error': e.toString(),
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}
