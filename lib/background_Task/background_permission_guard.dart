// lib/background/background_permission_guard.dart
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'dart:io';

class BackgroundPermissionGuard {
  static const _askedKey = 'asked_bg_permissions_once';

  static Future<void> askIfNeeded(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyAsked = prefs.getBool(_askedKey) ?? false;
    if (alreadyAsked) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showDialog(context);
    });
  }

  static Future<void> _showDialog(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
            title: const Text('Keep YenPOS running in background'),
            content: const Text(
              'To make sure your server/client stays alive (WebSocket/UDP), please allow:\n'
              '1) Ignore battery optimizations\n'
              '2) Auto start on boot',
            ),
            actions: [
              TextButton(
                child: const Text('Later'),
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool(_askedKey, true);
                  Navigator.pop(context);
                },
              ),
              TextButton(
                child: const Text('Allow now'),
                onPressed: () async {
                  await _requestIgnoreBatteryOptimizations();
                  await _openAutoStartSettingsIfPossible();
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool(_askedKey, true);
                  Navigator.pop(context);
                },
              ),
            ]);
      },
    );
  }

  static Future<void> _requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return;

    final ignoring = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    if (!ignoring) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
  }

  /// Most OEMs hide this deep in settings. This intent may or may not work
  /// depending on the device. You can extend with manufacturer checks if needed.
  static Future<void> _openAutoStartSettingsIfPossible() async {
    if (!Platform.isAndroid) return;
    try {
      const intent = AndroidIntent(
        action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
      );
      await intent.launch();
    } catch (_) {
      // silently ignore
    }
  }
}
