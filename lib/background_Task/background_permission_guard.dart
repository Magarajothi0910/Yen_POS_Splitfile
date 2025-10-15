// lib/background/background_permission_guard.dart
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
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
          insetPadding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.18,
          ),
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
                      await _requestIgnoreBatteryOptimizations();
                      await _openAutoStartSettingsIfPossible();
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool(_askedKey, true);
                      _dialogShowing = false; // reset flag
                      Navigator.pop(context);
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

  static Future<void> _requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return;

    final ignoring = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    if (!ignoring) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
  }

  static Future<void> _openAutoStartSettingsIfPossible() async {
    if (!Platform.isAndroid) return;
    try {
      const intent = AndroidIntent(
        action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
      );
      await intent.launch();
    } catch (_) {}
  }
}
