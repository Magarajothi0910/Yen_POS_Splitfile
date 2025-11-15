import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class BackgroundPermissionGuard {
  static const _askedKey = 'asked_bg_permissions_once';

  /// Check if permissions are needed and prompt the user if not already asked
  static Future<void> askIfNeeded(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyAsked = prefs.getBool(_askedKey) ?? false;

      if (alreadyAsked) {
        print('⚙️ Background permissions already requested. Skipping dialog...');
        return;
      }

      print('🔔 Scheduling background permission dialog...');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showDialog(context);
      });
    } catch (e) {
      print('❌ Error in askIfNeeded: $e');
    }
  }

  /// Show dialog to prompt user for background permissions
  static Future<void> _showDialog(BuildContext context) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false, // Prevent closing when tapped outside
        builder: (_) {
          return AlertDialog(
            backgroundColor: Colors.blue.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'Enable Background Running',
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            content: const Text(
              'To keep YenKOT running in the background (WebSocket/UDP), please allow:\n\n'
              '1) Disable battery optimizations\n'
              '2) Enable auto-start on boot\n'
              '3) Allow notifications',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 16,
                height: 1.4,
              ),
            ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Allow Now'),
                onPressed: () async {
                  try {
                    // 1. Ask notification permission first
                    await _requestNotificationPermission();

                    // 2. Try to disable battery optimization automatically
                    final batteryOk = await _requestIgnoreBatteryOptimizations();

                    // 3. If still ON, open settings manually
                    if (!batteryOk) {
                      await _openBatteryOptimizationSettings();
                    } else {
                      print("✅ Battery optimization already disabled. Skipping settings.");
                    }

                    // 4. Open OEM-specific auto-start settings
                    await _openAutoStartSettingsIfPossible();

                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool(_askedKey, true);

                    Navigator.pop(context);
                    print('✅ User granted background permissions.');
                  } catch (e) {
                    print('❌ Error requesting background permissions: $e');
                  }
                },
              ),
            ],
          );
        },
      );
      print('🔔 Background permission dialog displayed.');
    } catch (e) {
      print('❌ Error showing dialog: $e');
    }
  }

  /// Request to ignore battery optimizations if not already granted
  static Future<bool> _requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) {
      print('⚠️ Not Android. Skipping battery optimization request.');
      return true; // treat as allowed
    }

    try {
      final ignoring = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
      if (ignoring) {
        print('⚙️ Battery optimizations already ignored.');
        return true;
      }

      print('🔋 Requesting to ignore battery optimizations automatically...');
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();

      // Re-check after request
      final updatedIgnoring = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
      if (updatedIgnoring) {
        print('✅ Battery optimizations successfully ignored.');
        return true;
      } else {
        print('⚠️ Battery optimization still enabled, need manual action.');
        return false;
      }
    } catch (e) {
      print('❌ Error requesting battery optimizations: $e');
      return false;
    }
  }

  /// Request notification permission for Android 13+
  static Future<void> _requestNotificationPermission() async {
    if (!Platform.isAndroid) {
      print('⚠️ Not Android. Skipping notification permission request.');
      return;
    }

    try {
      final status = await Permission.notification.status;
      if (status.isDenied || status.isPermanentlyDenied) {
        print('🔔 Requesting notification permission...');
        final result = await Permission.notification.request();
        if (result.isGranted) {
          print('✅ Notification permission granted.');
        } else if (result.isPermanentlyDenied) {
          print('⚠️ Notification permission permanently denied. Opening app settings...');
          await openAppSettings();
        } else {
          print('⚠️ Notification permission denied.');
        }
      } else {
        print('⚙️ Notification permission already granted.');
      }
    } catch (e) {
      print('❌ Error requesting notification permission: $e');
    }
  }

  static Future<void> _openBatteryOptimizationSettings() async {
    try {
      const intent = AndroidIntent(
        action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
        data: 'package:com.example.sampleprj',
      );
      await intent.launch();
      print('✅ Opened battery optimization settings for manual action.');
    } catch (e) {
      print('⚠️ Failed to open specific battery settings: $e');
      try {
        const fallbackIntent = AndroidIntent(
          action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
        );
        await fallbackIntent.launch();
        print('✅ Opened general battery optimization settings as fallback.');
      } catch (e) {
        print('❌ Failed to open general settings: $e');
      }
    }
  }

  /// Open manufacturer-specific auto-start settings
  static Future<void> _openAutoStartSettingsIfPossible() async {
    if (!Platform.isAndroid) {
      print('⚠️ Not Android. Skipping auto-start settings.');
      return;
    }

    try {
      final manufacturer = (await _getManufacturer()).toLowerCase();
      print('📱 Device manufacturer: $manufacturer');

      final Map<String, List<AndroidIntent>> oemIntents = {
        'xiaomi': [
          const AndroidIntent(
            action: 'android.intent.action.MAIN',
            componentName: 'com.miui.securitycenter/com.miui.permcenter.autostart.AutoStartManagementActivity',
          ),
        ],
        'oppo': [
          const AndroidIntent(
            action: 'android.intent.action.MAIN',
            componentName: 'com.coloros.safecenter/com.coloros.safecenter.permission.startup.StartupAppListActivity',
          ),
        ],
        'vivo': [
          const AndroidIntent(
            action: 'android.intent.action.MAIN',
            componentName: 'com.vivo.permissionmanager/com.vivo.permissionmanager.activity.BgStartUpManagerActivity',
          ),
        ],
        'huawei': [
          const AndroidIntent(
            action: 'android.intent.action.MAIN',
            componentName: 'com.huawei.systemmanager/.startupmgr.ui.StartupNormalAppListActivity',
          ),
        ],
        'honor': [
          const AndroidIntent(
            action: 'android.intent.action.MAIN',
            componentName: 'com.huawei.systemmanager/com.huawei.systemmanager.optimize.process.ProtectActivity',
          ),
        ],
        'samsung': [
          const AndroidIntent(
            action: 'android.intent.action.MAIN',
            componentName: 'com.samsung.android.lool/com.samsung.android.sm.ui.battery.BatteryActivity',
          ),
          const AndroidIntent(
            action: 'android.intent.action.MAIN',
            componentName: 'com.samsung.android.sm/com.samsung.android.sm.ui.battery.BatteryActivity',
          ),
        ],
        'realme': [
          const AndroidIntent(
            action: 'android.intent.action.MAIN',
            componentName: 'com.coloros.safecenter/com.coloros.safecenter.startupapp.StartupAppListActivity',
          ),
        ],
        'oneplus': [
          const AndroidIntent(
            action: 'android.intent.action.MAIN',
            componentName: 'com.oneplus.security/com.oneplus.security.chainlaunch.ChainLaunchAppListActivity',
          ),
        ],
        'asus': [
          const AndroidIntent(
            action: 'android.intent.action.MAIN',
            componentName: 'com.asus.mobilemanager/com.asus.mobilemanager.autostart.AutoStartActivity',
          ),
        ],
        'letv': [
          const AndroidIntent(
            action: 'android.intent.action.MAIN',
            componentName: 'com.letv.android.letvsafe/com.letv.android.letvsafe.AutobootManageActivity',
          ),
        ],
      };

      final intents = oemIntents[manufacturer] ?? [];
      if (intents.isEmpty) {
        print('⚠️ No specific auto-start intents for $manufacturer. Skipping auto-start settings.');
        return;
      }

      for (final intent in intents) {
        try {
          print('⚙️ Attempting to open auto-start settings for $manufacturer...');
          await intent.launch();
          print('✅ Successfully opened auto-start settings for $manufacturer.');
          return;
        } catch (e) {
          print('⚠️ Failed to open auto-start settings for $manufacturer: $e');
        }
      }

      print("⚠️ Could not open auto-start settings for $manufacturer. User may need to allow manually.");
    } catch (e) {
      print('❌ Error in _openAutoStartSettingsIfPossible: $e');
    }
  }

  /// Get device manufacturer
  static Future<String> _getManufacturer() async {
    try {
      final process = await Process.run('getprop', ['ro.product.manufacturer']);
      final manufacturer = (process.stdout as String).trim();
      print('📱 Retrieved manufacturer: $manufacturer');
      return manufacturer.isEmpty ? 'unknown' : manufacturer;
    } catch (e) {
      print('⚠️ Failed to retrieve manufacturer: $e');
      return 'unknown';
    }
  }
}
