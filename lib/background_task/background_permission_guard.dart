// lib/background/background_permission_guard.dart
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'dart:io';

class BackgroundPermissionGuard {
  static const _askedKey = 'asked_bg_permissions_once';
  static bool _dialogShowing = false; // ⚡ new in-memory flag

  static Future<void> askIfNeeded(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyAsked = prefs.getBool(_askedKey) ?? false;
    if (alreadyAsked || _dialogShowing) return; // ✅ check in-memory flag too

    _dialogShowing = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showDialog(context);
    });
  }

  static Future<void> _showDialog(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        final theme = Theme.of(context);
        final screenWidth = MediaQuery.of(context).size.width;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: theme.colorScheme.surface,
          elevation: 12,
          insetPadding: EdgeInsets.symmetric(horizontal: screenWidth * 0.18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.battery_saver_rounded, color: Colors.blue, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Keep YenPOS running in background',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'To make sure your server/client stays alive (WebSocket/UDP), please allow:\n\n'
                  '1) Ignore battery optimizations\n'
                  '2) Auto start on boot',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[300],
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 4,
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    onPressed: () async {
                      try {
                        // 1. Ask notification permission first
                        await _requestNotificationPermission();

                        // 2. Try to disable battery optimization automatically
                        final batteryOk =
                            await _requestIgnoreBatteryOptimizations();

                        // 3. If battery optimization still ON, then open intent manually
                        if (!batteryOk) {
                          await _openBatteryOptimizationSettings();
                        } else {}

                        // 4. Finally, open auto-start settings (OEM specific only)
                        await _openAutoStartSettingsIfPossible();

                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool(_askedKey, true);
                        Navigator.pop(context);
                      } catch (e) {}
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<bool> _requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) {
      return true; // treat as allowed
    }

    try {
      final ignoring =
          await FlutterForegroundTask.isIgnoringBatteryOptimizations;
      if (ignoring) {
        return true;
      }

      await FlutterForegroundTask.requestIgnoreBatteryOptimization();

      // Re-check after request
      final updatedIgnoring =
          await FlutterForegroundTask.isIgnoringBatteryOptimizations;
      if (updatedIgnoring) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Request notification permission for Android 13+
  static Future<void> _requestNotificationPermission() async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      final status = await Permission.notification.status;
      if (status.isDenied || status.isPermanentlyDenied) {
        final result = await Permission.notification.request();
        if (result.isGranted) {
        } else if (result.isPermanentlyDenied) {
          await openAppSettings();
        } else {}
      } else {}
    } catch (e) {}
  }

  static Future<void> _openBatteryOptimizationSettings() async {
    try {
      const intent = AndroidIntent(
        action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
        data: 'package:com.example.sampleprj',
      );
      await intent.launch();
    } catch (e) {
      try {
        const fallbackIntent = AndroidIntent(
          action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
        );
        await fallbackIntent.launch();
      } catch (e) {}
    }
  }

  /// Open manufacturer-specific auto-start settings
  static Future<void> _openAutoStartSettingsIfPossible() async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      final manufacturer = (await _getManufacturer()).toLowerCase();

      final Map<String, List<AndroidIntent>> oemIntents = {
        'xiaomi': [
          const AndroidIntent(
            action: 'android.intent.action.MAIN',
            componentName:
                'com.miui.securitycenter/com.miui.permcenter.autostart.AutoStartManagementActivity',
          ),
        ],
        'oppo': [
          const AndroidIntent(
            action: 'android.intent.action.MAIN',
            componentName:
                'com.coloros.safecenter/com.coloros.safecenter.permission.startup.StartupAppListActivity',
          ),
        ],
        'vivo': [
          const AndroidIntent(
            action: 'android.intent.action.MAIN',
            componentName:
                'com.vivo.permissionmanager/com.vivo.permissionmanager.activity.BgStartUpManagerActivity',
          ),
        ],
        'huawei': [
          const AndroidIntent(
            action: 'android.intent.action.MAIN',
            componentName:
                'com.huawei.systemmanager/.startupmgr.ui.StartupNormalAppListActivity',
          ),
        ],
        'honor': [
          const AndroidIntent(
            action: 'android.intent.action.MAIN',
            componentName:
                'com.huawei.systemmanager/com.huawei.systemmanager.optimize.process.ProtectActivity',
          ),
        ],
        'samsung': [
          const AndroidIntent(
            action: 'android.intent.action.MAIN',
            componentName:
                'com.samsung.android.lool/com.samsung.android.sm.ui.battery.BatteryActivity',
          ),
          const AndroidIntent(
            action: 'android.intent.action.MAIN',
            componentName:
                'com.samsung.android.sm/com.samsung.android.sm.ui.battery.BatteryActivity',
          ),
        ],
        'realme': [
          const AndroidIntent(
            action: 'android.intent.action.MAIN',
            componentName:
                'com.coloros.safecenter/com.coloros.safecenter.startupapp.StartupAppListActivity',
          ),
        ],
        'oneplus': [
          const AndroidIntent(
            action: 'android.intent.action.MAIN',
            componentName:
                'com.oneplus.security/com.oneplus.security.chainlaunch.ChainLaunchAppListActivity',
          ),
        ],
        'asus': [
          const AndroidIntent(
            action: 'android.intent.action.MAIN',
            componentName:
                'com.asus.mobilemanager/com.asus.mobilemanager.autostart.AutoStartActivity',
          ),
        ],
        'letv': [
          const AndroidIntent(
            action: 'android.intent.action.MAIN',
            componentName:
                'com.letv.android.letvsafe/com.letv.android.letvsafe.AutobootManageActivity',
          ),
        ],
      };

      final intents = oemIntents[manufacturer] ?? [];
      if (intents.isEmpty) {
        return;
      }

      for (final intent in intents) {
        try {
          await intent.launch();
          return;
        } catch (e) {}
      }
    } catch (e) {}
  }

  /// Get device manufacturer
  static Future<String> _getManufacturer() async {
    try {
      final process = await Process.run('getprop', ['ro.product.manufacturer']);
      final manufacturer = (process.stdout as String).trim();
      return manufacturer.isEmpty ? 'unknown' : manufacturer;
    } catch (e) {
      return 'unknown';
    }
  }
}
