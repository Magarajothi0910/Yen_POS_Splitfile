// import 'dart:async';
// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:network_info_plus/network_info_plus.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:yen_pos/Global/globals_data.dart';
// import 'package:yen_pos/kotpreinvoice/providers/order_provider.dart';

// enum AppMode { server, client }

// class WifiChangeManager {
//   WifiChangeManager._();
//   static final WifiChangeManager instance = WifiChangeManager._();

//   Future<void> Function()? onServerWifiChanged;

//   StreamSubscription? _sub;
//   String? _currentWifi;
//   String? _serverWifi;

//   AppMode? _mode;
//   GlobalKey<NavigatorState>? _navKey;

//   void init({
//     required AppMode mode,
//     required GlobalKey<NavigatorState> navigatorKey,
//   }) {
//     debugPrint("🚀 WifiChangeManager.init called");
//     debugPrint("➡️ Mode: $mode");

//     _mode = mode;
//     _navKey = navigatorKey;

//     _startListening();
//   }

//   void updateServerWifi(String wifiName) {
//     debugPrint("💾 Server Wi-Fi saved: $wifiName");
//     _serverWifi = wifiName;
//   }

//   Timer? _pollTimer;
//   String? _lastWifi;

//   void _startListening() {
//     debugPrint("🎧 WifiChangeManager started");

//     // connectivity listener
//     _sub ??= Connectivity().onConnectivityChanged.listen((_) {
//       _checkWifi(force: true);
//       _onWifiChanged();
//     });

//     // periodic polling (MANDATORY)
//     _pollTimer ??= Timer.periodic(
//       const Duration(seconds: 4),
//       (_) => _checkWifi(),
//     );
//   }

//   Future<void> _checkWifi({bool force = false}) async {
//     final wifi = await NetworkInfo().getWifiName();

//     if (wifi == null || wifi.isEmpty) return;

//     if (!force && wifi == _lastWifi) return;

//     debugPrint("📶 Wi-Fi changed: $_lastWifi → $wifi");

//     _lastWifi = wifi;

//     if (_mode == AppMode.server) {
//       _handleServerWifiChange(wifi);
//     } else {
//       _handleClientWifiChange(wifi);
//     }
//   }

//   Future<String?> _getWifiWithRetry() async {
//     debugPrint("🔁 Trying to fetch Wi-Fi SSID");

//     for (int i = 0; i < 6; i++) {
//       final wifi = await NetworkInfo().getWifiName();
//       debugPrint("🔍 Attempt ${i + 1}: SSID = $wifi");

//       if (wifi != null && wifi.isNotEmpty) {
//         debugPrint("✅ Wi-Fi SSID obtained: $wifi");
//         return wifi;
//       }

//       await Future.delayed(const Duration(seconds: 1));
//     }

//     debugPrint("❌ Failed to get Wi-Fi SSID after retries");
//     return null;
//   }

//   Future<void> _onWifiChanged() async {
//     debugPrint("⚡ _onWifiChanged triggered");

//     final wifi = await _getWifiWithRetry();

//     if (wifi == null) {
//       debugPrint(
//         "⚠️ Wi-Fi name still null → Location OFF or permission missing",
//       );
//       return;
//     }

//     if (wifi == _currentWifi) {
//       final context = navigatorKey.currentContext;

//       final orderProv = Provider.of<OrderProvider>(context!, listen: false);
//       orderProv.initializeHive();
//       orderProv.requestDataFromServer();
//       debugPrint("🔁 Same Wi-Fi as before ($wifi), ignoring");
//       return;
//     }

//     debugPrint("🔄 Wi-Fi changed from $_currentWifi → $wifi");
//     _currentWifi = wifi;

//     if (_mode == AppMode.server) {
//       debugPrint("🟢 App running as SERVER");
//       _handleServerWifiChange(wifi);
//     } else {
//       debugPrint("🔵 App running as CLIENT");
//       _handleClientWifiChange(wifi);
//     }
//   }

//   void _handleClientWifiChange(String wifi) {
//     debugPrint("👤 Client Wi-Fi change detected: $wifi");
//     debugPrint("📦 Expected server Wi-Fi: $_serverWifi");
//     final context = navigatorKey.currentContext;
// final orderProv = Provider.of<OrderProvider>(context!, listen: false);
// orderProv.initializeHive();
// orderProv.requestDataFromServer();

//     if (_serverWifi != null && wifi != _serverWifi) {
//       debugPrint("⚠️ Client connected to wrong Wi-Fi");

//       _showDialog(
//         title: "Wi-Fi Changed",
//         message: "Please connect to the server Wi-Fi:\n\n$_serverWifi",
//       );
//     }
//   }

//   Future<void> _handleServerWifiChange(String wifi) async {
//     debugPrint("🖥️ Server Wi-Fi changed to: $wifi");

//     if (onServerWifiChanged != null) {
//       debugPrint("🔄 Restarting server due to Wi-Fi change");
//       await onServerWifiChanged!();
//     } else {
//       debugPrint("⚠️ onServerWifiChanged callback is NULL");
//     }

//     _showDialog(
//       title: "Server Wi-Fi Changed",
//       message:
//           "Server is now connected to:\n\n$wifi\n\nClients must reconnect.",
//     );
//   }

//   void _showDialog({required String title, required String message}) {
//     debugPrint("🪟 Attempting to show dialog: $title");

//     try {
//       final context = _navKey?.currentState?.overlay?.context;

//       if (context == null) {
//         debugPrint("❌ Cannot show dialog → context is NULL");
//         return;
//       }

//       showDialog(
//         context: context,
//         barrierDismissible: false,
//         builder: (_) => AlertDialog(
//           title: Text(title),
//           content: Text(message, textAlign: TextAlign.center),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 debugPrint("✅ Dialog dismissed");

//                 if (_navKey?.currentState?.canPop() ?? false) {
//                   Navigator.pop(context);
//                 }
//               },
//               child: const Text("OK"),
//             ),
//           ],
//         ),
//       );
//     } catch (e) {
//       debugPrint("❌ Error showing dialog: $e");
//     }
//   }

//   void dispose() {
//     _sub?.cancel();
//     _pollTimer?.cancel();
//     _sub = null;
//     _pollTimer = null;
//   }
// }

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yen_pos/Global/globals_data.dart';
import 'package:yen_pos/kotpreinvoice/providers/order_provider.dart';

enum AppMode { server, client }

class WifiChangeManager {
  WifiChangeManager._();
  static final WifiChangeManager instance = WifiChangeManager._();

  /// 🔁 Injected from LoginScreen
  Future<void> Function()? onServerWifiChanged;
  Future<void> Function()? onDiscoverServer; // <- discoverServerAndHandle

  StreamSubscription? _sub;
  Timer? _pollTimer;

  String? _currentWifi;
  String? _previousWifi;
  String? _serverWifi;
  bool _initializedWifi = false;

  bool _dialogVisible = false;
  bool _handlingWifiChange = false;

  // String? _previousWifi;

  AppMode? _mode;
  GlobalKey<NavigatorState>? _navKey;

  // ─────────────────────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────────────────────
  void init({
    required AppMode mode,
    required GlobalKey<NavigatorState> navigatorKey,
  }) {
    debugPrint("🚀 WifiChangeManager.init → $mode");
    _mode = mode;
    _navKey = navigatorKey;
    _startListening();
  }

  Future<String?> _getLocalIpSafe() async {
    final info = NetworkInfo();

    for (int i = 0; i < 3; i++) {
      final ip = await info.getWifiIP();
      if (ip != null && ip.isNotEmpty) {
        return ip;
      }
      await Future.delayed(const Duration(milliseconds: 700));
    }

    return null;
  }

  String? _getSubnet(String? ip) {
    if (ip == null || ip.isEmpty) return null;
    final parts = ip.split('.');
    if (parts.length < 3) return null;
    return "${parts[0]}.${parts[1]}.${parts[2]}";
  }

  bool _isSameSubnet(String? ip1, String? ip2) {
    return _getSubnet(ip1) == _getSubnet(ip2);
  }

  void updateServerWifi(String wifi) {
    debugPrint("💾 Server Wi-Fi saved: $wifi");
    _serverWifi = wifi;
  }

  // ─────────────────────────────────────────────────────────────
  // LISTENERS
  // ─────────────────────────────────────────────────────────────
  void _startListening() {
    _sub ??= Connectivity().onConnectivityChanged.listen((_) {
      _checkWifi(force: true);
    });

    _pollTimer ??= Timer.periodic(
      const Duration(seconds: 4),
      (_) => _checkWifi(),
    );
  }

  Future<void> _checkWifi({bool force = false}) async {
    final wifi = await NetworkInfo().getWifiName();
    if (wifi == null || wifi.isEmpty) return;

    // ✅ FIRST TIME: just cache Wi-Fi, DO NOTHING
    if (!_initializedWifi) {
      _initializedWifi = true;
      _currentWifi = wifi;
      _previousWifi = wifi;
      debugPrint("✅ Initial Wi-Fi set: $wifi (no action)");
      return;
    }

    // no change
    if (!force && wifi == _currentWifi) return;

    debugPrint("📶 Wi-Fi changed: $_currentWifi → $wifi");

    _previousWifi = _currentWifi;
    _currentWifi = wifi;

    if (_mode == AppMode.server) {
      _handleServerWifiChange(wifi);
    } else {
      _handleClientWifiChange(wifi);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // SERVER FLOW
  // ─────────────────────────────────────────────────────────────
  void _handleServerWifiChange(String wifi) async {
    if (_handlingWifiChange) return;
    _handlingWifiChange = true;

    final currentIp = await _getLocalIpSafe();
    final storedIp = locSubnetIp.value;

    if (currentIp == null || storedIp.isEmpty) {
      debugPrint("⏳ Server IP not ready, skipping");
      _handlingWifiChange = false;
      return;
    }

    final sameSubnet = _isSameSubnet(currentIp, storedIp);

    if (sameSubnet) {
      debugPrint("✅ Server subnet matched → restarting");
      await onServerWifiChanged?.call();
      await onDiscoverServer?.call();
      _handlingWifiChange = false;
      return;
    }

    if (!_dialogVisible) {
      _dialogVisible = true;

      _showInfoDialog(
        title: "Network Changed",
        message:
            "Old network:\n${_getSubnet(storedIp)}.x\n\n"
            "Current network:\n${_getSubnet(currentIp)}.x\n\n"
            "Reconnect to original Wi-Fi.",
        onOk: () {
          _dialogVisible = false;
        },
      );
    }

    _handlingWifiChange = false;
  }

  // ─────────────────────────────────────────────────────────────
  // CLIENT FLOW
  // ─────────────────────────────────────────────────────────────
  void _handleClientWifiChange(String wifi) async {
    if (_handlingWifiChange) return;
    _handlingWifiChange = true;

    final currentIp = await _getLocalIpSafe();
    final storedIp = locSubnetIp.value;

    debugPrint("📡 Current IP: $currentIp");
    debugPrint("💾 Stored Subnet IP: $storedIp");

    // 🚫 IP not ready yet → silently ignore
    if (currentIp == null || storedIp.isEmpty) {
      debugPrint("⏳ IP not ready, skipping check");
      _handlingWifiChange = false;
      return;
    }

    final sameSubnet = _isSameSubnet(currentIp, storedIp);

    if (sameSubnet) {
      debugPrint("✅ Subnet matched → discovering server");
      await onDiscoverServer?.call();
      _handlingWifiChange = false;
      return;
    }

    // ❌ Mismatch → INFO ONLY (ONCE)
    if (!_dialogVisible) {
      _dialogVisible = true;

      _showInfoDialog(
        title: "Network Mismatch",
        message:
            "Server network:\n${_getSubnet(storedIp)}.x\n\n"
            "Your network:\n${_getSubnet(currentIp)}.x\n\n"
            "Please connect to the server Wi-Fi.",
        onOk: () {
          _dialogVisible = false;
        },
      );
    }

    _handlingWifiChange = false;
  }

  // ─────────────────────────────────────────────────────────────
  // DIALOGS
  // ─────────────────────────────────────────────────────────────
  void _showDecisionDialog({
    required String title,
    required String message,
    required String primaryText,
    required String secondaryText,
    required VoidCallback onPrimary,
    required VoidCallback onSecondary,
  }) {
    final context = _navKey?.currentState?.overlay?.context;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.blue.shade800,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          TextButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(7),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              onSecondary();
            },
            child: const Text("Go Back", style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(7),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              onPrimary();
            },
            child: Text(primaryText, style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog({
    required String title,
    required String message,
    required VoidCallback onOk,
  }) {
    final context = _navKey?.currentState?.overlay?.context;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(7),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              onOk();
            },
            child: Text("OK", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CLEANUP
  // ─────────────────────────────────────────────────────────────
  void dispose() {
    _sub?.cancel();
    _pollTimer?.cancel();
    _sub = null;
    _pollTimer = null;
  }
}
