

import 'dart:io';
import 'package:flutter/foundation.dart';

class POSDetector {
  static Future<bool> get isPOSDevice async {
    // Check for Android first
    if (Platform.isAndroid) {
      return _checkAndroidPOS();
    }
    // Fall back to Linux/Windows checks
    else if (Platform.isLinux || Platform.isWindows) {
      return _hasBarcodeScanner() || _isUSBCameraConnected();
    }

    return false;
  }

  static Future<bool> _checkAndroidPOS() async {
    try {
      // Android POS devices often have specific hardware or manufacturer info
      // Check 1: Look for common POS manufacturer strings
      final manufacturer =
          await _getAndroidSystemProperty('ro.product.manufacturer');
      final model = await _getAndroidSystemProperty('ro.product.model');
      final brand = await _getAndroidSystemProperty('ro.product.brand');

      final manufacturerLower = manufacturer?.toLowerCase() ?? '';
      final modelLower = model?.toLowerCase() ?? '';
      final brandLower = brand?.toLowerCase() ?? '';

      // Common POS manufacturers and keywords
      const posKeywords = [
        'pos',
        'ingenico',
        'verifone',
        'pax',
        'newland',
        'sunmi',
        'landi',
        'castles',
        'bitel',
        'wiseasy',
        'mswipe'
      ];

      for (final keyword in posKeywords) {
        if (manufacturerLower.contains(keyword) ||
            modelLower.contains(keyword) ||
            brandLower.contains(keyword)) {
          return true;
        }
      }

      // Check 2: Look for USB peripherals (common in Android POS)
      final usbDevices = await _getUSBPermissions();
      if (usbDevices.isNotEmpty) {
        return true;
      }

      // Check 3: Look for specific POS features
      final hasPrinter = await _checkAndroidFeature('android.hardware.printer');
      final hasPosApi = await _checkAndroidFeature('android.hardware.pos');

      return hasPrinter || hasPosApi;
    } catch (e) {
    
      return false;
    }
  }

  static Future<String?> _getAndroidSystemProperty(String prop) async {
    try {
      final result = await Process.run('getprop', [prop]);
      if (result.exitCode == 0) {
        return result.stdout.toString().trim();
      }
    } catch (e) {
     
    }
    return null;
  }

  static Future<List<String>> _getUSBPermissions() async {
    try {
      // Check USB devices that have permissions granted
      final result = await Process.run('ls', ['/dev/bus/usb']);
      if (result.exitCode == 0) {
        return result.stdout
            .toString()
            .split('\n')
            .where((s) => s.isNotEmpty)
            .toList();
      }
    } catch (e) {
      
    }
    return [];
  }

  static Future<bool> _checkAndroidFeature(String feature) async {
    try {
      final result = await Process.run('pm', ['list', 'features', feature]);
      return result.exitCode == 0 && result.stdout.toString().contains(feature);
    } catch (e) {
      
      return false;
    }
  }

  static bool _hasBarcodeScanner() {
    if (!Platform.isLinux) return false;

    try {
      final inputDir = Directory('/dev/input');
      if (!inputDir.existsSync()) return false;

      final devices = inputDir.listSync().where((entity) {
        return entity.path.startsWith('/dev/input/event');
      }).toList();

      return devices.length > 2;
    } catch (e) {
     
      return false;
    }
  }

  static bool _isUSBCameraConnected() {
    try {
      if (Platform.isLinux) {
        final videoDevices = Directory('/dev').listSync().where((entity) {
          return entity.path.startsWith('/dev/video');
        }).toList();
        return videoDevices.isNotEmpty;
      } else if (Platform.isWindows) {
        return _checkWindowsCamera();
      }
      return false;
    } catch (e) {
     
      return false;
    }
  }

  static bool _checkWindowsCamera() {
    try {
      final result =
          Process.runSync('wmic', ['path', 'Win32_PnPEntity', 'get', 'Name']);
      if (result.exitCode == 0) {
        final output = result.stdout.toString().toLowerCase();
        return output.contains('camera') ||
            output.contains('webcam') ||
            output.contains('imaging');
      }
    } catch (e) {
     
    }
    return false;
  }
}
