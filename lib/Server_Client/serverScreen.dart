import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';

import 'package:provider/provider.dart';
import 'package:udp/udp.dart';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yen_pos/Global/Provider/branchwise_item_fetch.dart';
import 'package:yen_pos/Global/get_device_info.dart';

import 'package:yen_pos/Global/globals_data.dart';
import 'package:yen_pos/Global/globals_data.dart' as globals;
import 'package:yen_pos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yen_pos/Mode_page/choose_mode_screen.dart';
import 'package:yen_pos/Sale_order/Widgets/Send_data_to_server.dart';

import 'package:yen_pos/Server_Client/handlers/websocket_handler.dart';

import 'package:yen_pos/Server_Client/makethisdeviceas%20server_Dialog.dart';
import 'package:yen_pos/Server_Client/sendDataToClients.dart';
import 'package:yen_pos/Server_Client/serverreachable.dart';
import 'package:yen_pos/Server_Client/startServers.dart';

import 'package:yen_pos/Server_Client/sync_service.dart';
import 'package:yen_pos/Server_Client/websocketService.dart';
import 'package:yen_pos/Server_Client/wifi_change_manager.dart';
import 'package:yen_pos/background_task/background_permission_guard.dart';
import 'package:yen_pos/background_task/flutter_foreground_task.dart';
import 'package:yen_pos/kotpreinvoice/providers/order_provider.dart';
import 'package:yen_pos/kotpreinvoice/providers/product_provider.dart';
import 'package:yen_pos/loginPage/provider/loginPageProvider.dart';
import 'package:yen_pos/more_page/providers/cash_management_provider.dart';
import 'package:yen_pos/shift_managment_page/openshift/open_shift.dart';
import 'package:web_socket_channel/io.dart'; // 👈 this one adds fromSocket()

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  //Day End
  final ValueNotifier<bool> isShiftOpened = ValueNotifier(false);
  final ValueNotifier<ConnectivityResult> _connectivityResult = ValueNotifier(
    ConnectivityResult.none,
  );
  //
  List<Map<String, dynamic>> orders = [];
  HttpServer? _wsServer;
  Set<String> sentPatchOrders = {};
  final SyncService _syncService = SyncService();
  Timer? _syncTimer;
  Timer? _patchCheckTimer;
  List<String> logs = [];
  String serverPort = "Unknown";
  late Box box;
  bool serverFound = false;
  bool proceedToDashboardCalled = false;
  String status = 'Searching for server...';
  //saleorders

  Timer? _approvalCheckTimer;
  Map<String, dynamic>? paymentDetails;
  int _sendDataToClientsCount = 0;
  final TextEditingController _advanceController = TextEditingController();
  bool placeOrderCliked = false;
  bool showPaymentScreen = false;
  final ValueNotifier<bool> serverFoundNotifier = ValueNotifier(false);

  //saleorder
  @override
  initState() {
    //Day End
    super.initState();
    _checkConnectivity();
    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen((result) {
      _connectivityResult.value =
          result.first; // Handle Stream<List<ConnectivityResult>>
    });
    //

    HiveManager.initialize(); // Just to ensure it's initialized

    // checkIfServerWasPreviouslyStored();
    WifiChangeManager.instance.onDiscoverServer = () async {
      serverip = '';
      await stopServer();
      await stopUdpResponder();
      await handleServerConnection();
      ();
    };
    // WebSocketService.instance.onDiscoverServer = () async {
    //    serverip = '';
    //   await stopServer();
    //   await stopUdpResponder();
    //   await handleServerConnection();
    //   ();
    // };
    // discoverServerAndHandle();
  }

  //Day End
  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _connectivityResult.value = result.first;
  }
  //

  Future<void> checkIfServerWasPreviouslyStored() async {
    try {
      final configBox = Hive.box('configBox');
      final serverBox = Hive.box('serverBox');

      final savedIp = serverBox.get('serverIp')?.toString() ?? '';
      final savedPort = serverBox.get('serverPort')?.toString() ?? '';

      if (savedIp.isEmpty || savedPort.isEmpty) {
        return;
      }

      final localIp = await getLocalIp();

      serverip = savedIp;
      serverPort = savedPort;

      // 🧠 Check if this device was the server
      if (localIp == savedIp) {
        final isLocalServerRunning = await isPortOpen(
          localIp!,
          int.parse(savedPort),
        );

        if (isLocalServerRunning) {
          appTypeNotifier.value = APP_SERVER;
          await configBox.put('appType', 'server');

          await ForegroundHelper.startIfNotRunning(appType: 'server');
          await Provider.of<ProductProvider>(
            navigatorKey.currentContext!,
            listen: false,
          ).fetchAllData(navigatorKey.currentContext!);

          await collectAndSendDeviceInfo('server', localIp ?? '0.0.0.0');
        } else {}
      } else {
        // 🌐 Client Mode

        final reachable = await isServerReachable(
          savedIp,
          int.parse(savedPort),
        );
        if (reachable) {
          appTypeNotifier.value = APP_CLIENT;
          await configBox.put('appType', 'client');
          await Provider.of<ProductProvider>(
            context,
            listen: false,
          ).fetchAllData(context);
          await collectAndSendDeviceInfo('client', localIp ?? '0.0.0.0');
          try {
            await ForegroundHelper.startIfNotRunning(appType: 'client');
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('WebSocket error: $e')));
            }
          }
        } else {}
      }

      // ✅ Finalize
      if (mounted) {
        serverFoundNotifier.value = true;
      }
    } catch (e, stack) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error checking server: $e')));
      }
    }
  }

  Future<bool> isPortOpen(String ip, int port) async {
    try {
      final socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(milliseconds: 500),
      );
      socket.destroy();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> stopServer() async {
    try {
      // await _wsServer?.close(force: true);
      _wsServer = null;
      debugPrint("🛑 WebSocket server stopped");
    } catch (e) {
      debugPrint("Error stopping server: $e");
    }
  }

  Future<void> onServerWifiChanged() async {
    debugPrint("📶 Server Wi-Fi changed → restarting server");

    // await stopServer();
    await discoverServerAndHandle();
  }

  Future<void> onDataReceived(
    Map<String, dynamic> data,
    WebSocketChannel channel,
  ) async {
    if (data != null) {
      if (data['action'] == 'seat_tapped' ||
          data['action'] == 'seat_returned') {
        sendDataToClients(data, clients);
      }

      if (mounted) {
        setState(() {
          receivedData.add(data);
        });
      }

      if (data['action'] == 'updatePrinterItems') {
        sendDataToClients({
          'action': 'updatePrinterItems',
          'printer': data['printer'],
        }, clients);
      }

      if (data['action'] == 'removePrinter') {
        handleRemovePrinter(data, clients);
      }
    }
  }

  void showLoadingDialog(
    BuildContext context, {
    String message = "Please wait...",
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Colors.blue),
                const SizedBox(width: 16),
                Text(message, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void hideLoadingDialog(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> proceedToDashboard() async {
    print("🚀 [proceedToDashboard] Function called");
    print("🚀 [proceedToDashboard] Function called");
    final data = jsonEncode({'type': 'handshake'});
    sendataToServer(jsonDecode(data));
    // if (!context.mounted) {
    //   return;
    // }

    if (!context.mounted) {
      print("⚠️ Context not mounted. Returning.");
      return;
    }

    // 🔄 SHOW LOADING (Shift check start)
    showLoadingDialog(context, message: "Checking shift status...");

    try {
      // Step 1: Alias check
      if (globals.locationId == null || globals.locationId!.trim().isEmpty) {
        print("⚠️ Alias name is null or empty");
        hideLoadingDialog(context);
        return;
      }
      print("✅ Alias name: ${globals.locationId}");

      // Step 2: Branch info
      final itemProvider = Provider.of<ItemProvider>(context, listen: false);
      print("🔄 Fetching branch info...");
      final branchInfo = await itemProvider.getBranchInfoFromAlias(
        globals.locationId,
      );

      await Provider.of<ProductProvider>(
        context,
        listen: false,
      ).fetchAllData(context);
      debugPrint('📥 [DATA] Products fetched (client)');

      await Provider.of<OrderProvider>(
        context,
        listen: false,
      ).requestDataFromServer();

      Provider.of<ItemProvider>(
        context,
        listen: false,
      ).fetchDataIfNeeded(branchAlias: globals.locationId);
      await Provider.of<ItemProvider>(
        context,
        listen: false,
      ).fetchAndStoreAdvancePercent(locationId: globals.locationId);

      if (branchInfo == null) {
        print("❌ Branch info not found");
        hideLoadingDialog(context);
        return;
      }

      globals.branchName = branchInfo['branchName'] ?? "";
      globals.branchAddress = branchInfo['address'] ?? "";
      globals.branchPhoneno = branchInfo['phone'] ?? "";
      globals.aliasname = branchInfo['aliasName'] ?? "";

      print("📌 Branch set: ${globals.branchName}");

      if (!context.mounted) {
        print(
          "⚠️ [Step 4] Context not mounted after setting globals. Returning.",
        );
        return;
      }

      if (globals.branchName == null ||
          globals.branchName == 'Branch Not Found') {
        print(
          "⚠️ [Step 4] Invalid branch name: ${globals.branchName}. Returning.",
        );
        return;
      }
      // Step 3: Shift API
      final url = Uri.parse(
        'https://yenerp.com/fluttertestapi/shifts/check-open-shifts?empId=$userName&locationId=${globals.locationId}&deviceId=${globals.deviceId}',
      );
      final client = http.Client();

      print("🌐 API URL: $url");

      final response = await client.get(url);

      print("📡 Response: ${response.statusCode} | ${response.body}");

      hideLoadingDialog(context); // ✅ HIDE LOADING AFTER API

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        print("✅ [Step 6] Shift data parsed: $data");
        globals.shiftOpenStatus.value = data['status'].toString();
        globals.shiftId.value = data['id']?.toString() ?? '0';
        globals.shiftNumber.value = data['shiftNumber']?.toString() ?? '0';

        print(
          "📌 ShiftId: ${globals.shiftId.value}, ShiftStatus: ${globals.shiftOpenStatus.value}",
        );

        print(
          "📌 [Step 6] Globals shiftId: ${globals.shiftId.value}, shiftNumber: ${globals.shiftNumber.value}",
        );

        int shiftNumberInt = int.tryParse(globals.shiftNumber.value) ?? 0;

        if (!context.mounted) return;

        if (shiftOpenStatus.value == 'open') {
          print("✅ Open shift found → ChooseModePage");
          hideLoadingDialog(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Already shift is opened for this employee'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => ChooseModePage()),
          );
        } else {
          print("⚠️ No open shift → OpenShift");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No open shift found for today'),
              backgroundColor: Colors.orange,
            ),
          );
          hideLoadingDialog(context);
          showKOTConfirmationDialog();
        }
      } else {
        hideLoadingDialog(context);
        print("❌ Failed to fetch shift data");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to fetch shift data'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e, stack) {
      hideLoadingDialog(context);
      print("❌ Exception: $e");
      print("📄 StackTrace: $stack");

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> showKOTConfirmationDialog() async {
    final configBox = Hive.box('configBox'); // or HiveManager().configBox

    // Check if user has already answered the KOT question
    final bool? hasAnsweredDineIn = configBox.get('hasAnsweredDineIn');

    if (hasAnsweredDineIn == true) {
      // Already answered → skip dialog, go straight to OpenShift
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => OpenShift()),
      );
      return;
    }
    if (!mounted) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "YEN POS",
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, _, __) => const SizedBox.shrink(),
      transitionBuilder: (context, anim, secondary, child) {
        final curved = Curves.easeOutBack.transform(anim.value);
        return Transform.scale(
          scale: curved,
          child: Opacity(
            opacity: anim.value,
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white.withOpacity(0.97),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // const Icon(
                    //   Icons.exit_to_app_rounded,
                    //   size: 48,
                    //   color: Colors.deepOrange,
                    // ),
                    const SizedBox(height: 16),
                    const Text(
                      'DID YOU WANT TO ENABLE KOT?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Enabling KOT will allow you to manage kitchen orders effectively. Do you wish to proceed?',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54, fontSize: 14),
                    ),
                    const SizedBox(height: 26),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        OutlinedButton(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await configBox.put('hasAnsweredDineIn', true);
                            globals.isDineInEnabled.value = false;
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => OpenShift()),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.grey),
                            foregroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 12,
                            ),
                          ),
                          child: const Text("No"),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            sendataToServer({
                              'type': 'DineInStatus',
                              'deviceCodeId': globals.deviceCodeId,
                              'locationId': locationId,
                            });
                            await configBox.put('hasAnsweredDineIn', true);
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => OpenShift()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 12,
                            ),
                            elevation: 3,
                          ),
                          child: const Text(
                            "Yes",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> handleServerConnection() async {
    debugPrint("🌐 [Network] Starting server connection flow...");
    // state.setCheckingNetwork(true);

    try {
      showLoadingDialog(
        navigatorKey.currentContext!,
        message: 'Searching server...',
      );
      final hasSavedServer = serverFound && serverip.trim().isNotEmpty;

      if (!hasSavedServer) {
        debugPrint(
          "📭 [Network] No valid saved server IP → Starting discovery",
        );
      } else {
        debugPrint(
          "📌 [Network] Saved server found → IP: $serverip, Port: $port",
        );

        debugPrint("🔍 [Network] Checking if saved server is reachable...");
        final isAlive = await isServerReachable(serverip, port);

        debugPrint("📡 [Network] Saved server reachability: $isAlive");

        if (isAlive) {
          debugPrint(
            "✅ [Network] Saved server is alive → Connecting as client...",
          );
          await _connectAsClient();
          debugPrint("🔗 [Network] Client connection established successfully");
          hideLoadingDialog(navigatorKey.currentContext!);
          return;
        } else {
          debugPrint(
            "⚠️ [Network] Saved server not reachable → Falling back to discovery",
          );
        }
      }
      hideLoadingDialog(navigatorKey.currentContext!);

      // 🔍 Discovery path
      debugPrint("🛰️ [Network] Discovering server on local network...");
      await discoverServerAndHandle();
      debugPrint("🏁 [Network] Server discovery flow completed");
    } catch (e, stack) {
      debugPrint("❌ [Network] Unexpected error during connection flow");
      debugPrint("❌ Error: $e");
      debugPrint("🧵 StackTrace:\n$stack");

      if (mounted) {
        // state.setErrorMessage('Network error: $e');
      }
    } finally {
      debugPrint("🧹 [Network] Connection flow finished");
      // state.setCheckingNetwork(false);
    }
  }

  Future<void> _connectAsClient() async {
    debugPrint("Client initiated");
    try {
      showLoadingDialog(
        navigatorKey.currentContext!,
        message: 'Going as Client',
      );
      final webSocketService = Provider.of<WebSocketService>(
        context,
        listen: false,
      );
      // final orderProvider = Provider.of<OrderProvider>(context, listen: false);

      final localIp = await getLocalIp();

      // Parallel execution
      await Future.wait([
        webSocketService.connect(),
        collectAndSendDeviceInfo('client', localIp ?? '0.0.0.0'),
        // orderProvider.requestDataFromServer(),
      ]);

      if (!proceedToDashboardCalled) {
        await proceedToDashboard();
      }
      hideLoadingDialog(navigatorKey.currentContext!);
    } catch (e) {
      debugPrint("❌ Client connection: $e");
      // Fallback to discovery
      await discoverServerAndHandle();
    }
  }

  Future<void> discoverServerAndHandle() async {
    debugPrint("🛰️ [Discovery] Starting server discovery...");
    // state.setCheckingNetwork(true);

    final localIp = await getLocalIp();
    if (localIp == null) {
      debugPrint("⚠️ [Discovery] No local IP found → aborting discovery");
      // state.setCheckingNetwork(false);
      return;
    }

    debugPrint("📍 [Discovery] Local IP: $localIp");

    final udp = await UDP.bind(Endpoint.any(port: Port(udpPort)));
    debugPrint("🟢 [Discovery] UDP socket bound on port $udpPort");

    try {
      // Send discovery packets in parallel
      debugPrint("📡 [Discovery] Sending WHO_IS_SERVER broadcast packets");

      await Future.wait([
        udp.send(
          utf8.encode('WHO_IS_SERVER'),
          Endpoint.broadcast(port: Port(udpPort)),
        ),
        // Future.delayed(
        //   const Duration(milliseconds: 100),
        //   () => udp.send(
        //     utf8.encode('WHO_IS_SERVER'),
        //     Endpoint.broadcast(port: Port(udpPort)),
        //   ),
        // ),
      ]);

      debugPrint("📤 [Discovery] Discovery packets sent");

      final serverBox = Hive.box('serverBox');
      bool found = false;

      // Fast timeout (1.5 seconds instead of 2)
      final timeout = const Duration(milliseconds: 3000);
      debugPrint(
        "⏱️ [Discovery] Listening for responses (timeout: ${timeout.inMilliseconds}ms)",
      );

      await for (final datagram in udp.asStream(timeout: timeout)) {
        try {
          if (datagram == null) continue;

          final message = utf8.decode(datagram.data);
          final fromIp = datagram.address.address;

          debugPrint(
            "📩 [Discovery] Datagram received from $fromIp → $message",
          );

          // Skip self and invalid messages
          if (fromIp == localIp) {
            debugPrint("⏭️ [Discovery] Ignored self response");
            continue;
          }

          if (!message.startsWith('SERVER:')) {
            debugPrint("⏭️ [Discovery] Ignored non-server message");
            continue;
          }

          final parts = message.split(':');
          if (parts.length < 3) {
            debugPrint("⚠️ [Discovery] Malformed SERVER message: $message");
            continue;
          }

          final ip = parts[1];
          final portStr = parts[2];
          debugPrint("🎯 [Discovery] Server found → $ip:$portStr");

          await serverBox.put('serverIp', ip);
          serverip = ip;
          serverFound = true;
          appTypeNotifier.value = APP_CLIENT;

          debugPrint("⚙️ [Discovery] Initializing client services in parallel");

          await Future.wait([
            ForegroundHelper.startIfNotRunning(
              appType: 'client',
              // serverIp: serverip,
              // serverPort: portStr,
            ),
            _connectToServerAndProceed(ip, localIp),
          ]);

          found = true;

          // ✅ SAVE SERVER WIFI FIRST
          final serverWifi = await NetworkInfo().getWifiName();
          if (serverWifi != null) {
            debugPrint("📦 [Discovery] Saving server Wi-Fi: $serverWifi");
            WifiChangeManager.instance.updateServerWifi(serverWifi);
          } else {
            debugPrint("⚠️ [Discovery] Unable to read Wi-Fi name");
          }

          // ✅ THEN INIT WIFI MANAGER
          debugPrint(
            "🚀 [Discovery] Initializing WifiChangeManager (client mode)",
          );
          WifiChangeManager.instance.init(
            mode: AppMode.client,
            navigatorKey: navigatorKey,
          );

          udp.close();
          debugPrint("🔴 [Discovery] UDP socket closed after server found");
          break;
        } catch (e) {
          debugPrint("⚠️ [Discovery] Datagram processing error: $e");
        }
      }

      if (!found) {
        debugPrint("❌ [Discovery] No server found within timeout");

        try {
          debugPrint("📢 [Discovery] Showing 'No Server Found' dialog");
          _showNoServerDialog();
        } catch (e, stack) {
          debugPrint("⚠️ [Discovery] Failed to show NoServer dialog");
          debugPrint("⚠️ Error: $e");
          debugPrint("🧵 StackTrace:\n$stack");
        }
      } else if (found) {
        debugPrint(
          "✅ [Discovery] Server successfully discovered and connected",
        );
      } else {
        // This means: not found AND widget not mounted
        debugPrint(
          "🚫 [Discovery] Server not found but widget unmounted → skipping dialog",
        );
      }
    } catch (e, stack) {
      debugPrint("❌ [Discovery] Discovery error: $e");
      debugPrint("🧵 [Discovery] StackTrace:\n$stack");

      if (mounted) {
        // state.setErrorMessage('Network error: $e');
      }
    } finally {
      udp.close();
      debugPrint("🧹 [Discovery] Discovery finished → UDP closed");
      // /state.setCheckingNetwork(false);
    }
  }

  Future<void> _connectToServerAndProceed(String ip, String localIp) async {
    try {
      final data = jsonEncode({'type': 'handshake'});
      sendataToServer(jsonDecode(data));
      final contexts = navigatorKey.currentContext!;
      final webSocketService = Provider.of<WebSocketService>(
        contexts,
        listen: false,
      );
      final orderProvider = Provider.of<OrderProvider>(contexts, listen: false);
      final productProvider = Provider.of<ProductProvider>(
        contexts,
        listen: false,
      );

      // Fast parallel connection and data fetch
      await webSocketService.connect();
      await productProvider.fetchAllData(contexts);

      if (!webSocketService.isConnected) {
        throw Exception("Connection failed");
      }

      // Send device info
      final deviceBox = Hive.box('deviceData');
      final deviceCode = deviceBox.get('deviceCode')?.toString() ?? '';
      // webSocketService.sendDeviceCodeToServer(deviceCode);
      await collectAndSendDeviceInfo('client', localIp);

      // Request data
      await orderProvider.requestDataFromServer();

      // Proceed to dashboard
      if (!proceedToDashboardCalled) {
        await proceedToDashboard();
      }
    } catch (e) {
      debugPrint("❌ Connection failed: $e");
      if (mounted) {
        // state.setErrorMessage('Cannot connect to server');
      }
    }
  }

  void _showNoServerDialog() {
    final ctx = navigatorKey.currentContext;

    if (ctx == null) {
      debugPrint("❌ No navigator context available");
      return;
    }
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => NoServerDialog(
        onMakeServer: () async {
          // Navigator.of(ctx).pop();

          // 🔄 Show loading
          showLoadingDialog(
            navigatorKey.currentContext!,
            message: "Starting server...",
          );

          try {
            // 1️⃣ Get IP
            final ip = await getLocalIp();
            if (ip == null) {
              throw Exception("No network connection found");
            }

            // 2️⃣ Save config
            final serverBox = Hive.box('serverBox');
            final configBox = Hive.box('configBox');

            await Future.wait([
              serverBox.put('serverIp', ip),
              serverBox.put('port', port.toString()),
              configBox.put('appType', 'server'),
            ]);

            serverip = ip;
            appTypeNotifier.value = APP_SERVER;
            serverFound = true;
            serverFoundNotifier.value = true;

            // 3️⃣ Start services
            await ForegroundHelper.startIfNotRunning(appType: 'server');
            await startUdpResponder(serverip, udpPort);
            await startServer(clients);

            await collectAndSendDeviceInfo('server', ip);

            if (!proceedToDashboardCalled) {
              debugPrint('fetchAllData');
              Provider.of<ProductProvider>(
                context,
                listen: false,
              ).fetchAllData(context);
              Provider.of<ItemProvider>(
                context,
                listen: false,
              ).fetchDataIfNeeded(branchAlias: globals.locationId);
              await Provider.of<ItemProvider>(
                context,
                listen: false,
              ).fetchAndSaveSalesOrders(branchAlias: globals.locationId);

              await Provider.of<ItemProvider>(
                context,
                listen: false,
              ).fetchAndStoreAdvancePercent(locationId: globals.locationId);
            }

            sendDataToClients({'action': 'DineInShift'}, clients);

            // 4️⃣ Init WiFi manager
            WifiChangeManager.instance.init(
              mode: AppMode.server,
              navigatorKey: navigatorKey,
            );
            // WifiChangeManager.instance.onServerWifiChanged =
            //     onServerWifiChanged;

            // 5️⃣ Verify server
            final isServerAlive = await isServerReachable(serverip, port);
            if (!isServerAlive) {
              throw Exception("Server started but not reachable");
            }

            // ✅ Success
            // showLoadingDialog.hide(navigatorKey.currentContext!);
            hideLoadingDialog(navigatorKey.currentContext!);

            if (!proceedToDashboardCalled) {
              debugPrint("proceedToDashboardCalled 1234");
              await proceedToDashboard();
              proceedToDashboardCalled = true;
            }
          } catch (e, stack) {
            // ProcessingLoader.hide(navigatorKey.currentContext!);
            hideLoadingDialog(navigatorKey.currentContext!);

            debugPrint("❌ Server creation failed: $e");
            debugPrint("🧵 StackTrace:\n$stack");

            // 🔔 User-visible error
            // CustomSnackBar.show(
            //   navigatorKey.currentContext!,
            //   e.toString().replaceFirst('Exception: ', ''),
            //   type: SnackType.error,
            // );

            // Optional: reset state
            serverFound = false;
            serverFoundNotifier.value = false;
            appTypeNotifier.value = '';
          }
        },
      ),
    );
  }

  Future<void> checkPendingApprovals(Box salesOrdersBox) async {
    salesOrdersBox.toMap().forEach((key, value) {});

    salesOrdersBox.toMap().forEach((key, value) {
      if (value is Map && value.containsKey('waitingForApprovalResult')) {
      } else {}
    });

    for (final entry in salesOrdersBox.toMap().entries) {
      final order = entry.value;
      final orderData = order['data'];

      if (order['waitingForApprovalResult'] == 'Yes' &&
          orderData is Map &&
          orderData.containsKey('saleOrderNo')) {
        final saleOrderNo = orderData['saleOrderNo'];

        // Check approvalStatus in approvalDetails list
        dynamic approvalStatus;
        if (orderData.containsKey('approvalDetails') &&
            orderData['approvalDetails'] is List &&
            orderData['approvalDetails'].isNotEmpty) {
          final approvalDetails = orderData['approvalDetails'];
          approvalStatus = approvalDetails.last['approvalStatus'];
        } else {}

        if (approvalStatus != null) {
          continue;
        }

        try {
          final apiResponse = await _syncService.fetchSalesOrderFromApi(
            saleOrderNo,
          );

          dynamic apiSalesOrder = apiResponse;

          // Check if API response has valid approvalDetails with approvalStatus
          dynamic apiApprovalStatus;
          if (apiSalesOrder != null &&
              apiSalesOrder is Map<String, dynamic> &&
              apiSalesOrder.containsKey('approvalDetails') &&
              apiSalesOrder['approvalDetails'] is List &&
              apiSalesOrder['approvalDetails'].isNotEmpty) {
            apiApprovalStatus =
                apiSalesOrder['approvalDetails'].last['approvalStatus'];
          }

          if (apiApprovalStatus != null) {
            final updatedOrder = Map<String, dynamic>.from(order);

            // Merge API data into existing 'data' field
            if (updatedOrder['data'] is Map) {
              updatedOrder['data'] = Map<String, dynamic>.from(
                updatedOrder['data'],
              )..addAll(apiSalesOrder);
            } else {
              updatedOrder['data'] = apiSalesOrder;
            }

            updatedOrder['waitingForApprovalResult'] = 'No';
            await salesOrdersBox.put(entry.key, updatedOrder);

            sendDataToClients({
              'action': 'patchsaleorderGenerated',
              'saleOrderNo': saleOrderNo,
              'patchSaleOrder': updatedOrder,
            }, clients);
          } else {
            continue; // Skip if approvalStatus is missing or null
          }
        } catch (e) {}
      } else {}
    }

    salesOrdersBox.toMap().forEach((key, value) {});
  }

  Future<void> chequePendingDiscountApproval(Box holdOrderBox) async {
    holdOrderBox.toMap().forEach((key, value) {});

    holdOrderBox.toMap().forEach((key, value) {
      if (value is Map && value.containsKey('waitingForApprovalResult')) {
      } else {}
    });

    for (final entry in holdOrderBox.toMap().entries) {
      final order = entry.value;
      final orderData = order['data'];

      if (order['waitingForApprovalResult'] == 'Yes' &&
          orderData is Map &&
          orderData.containsKey('saleOrderNo')) {
        final saleOrderNo = orderData['saleOrderNo'];

        // Check approvalStatus in approvalDetails list
        dynamic approvalStatus;
        if (orderData.containsKey('approvalDetails') &&
            orderData['approvalDetails'] is List &&
            orderData['approvalDetails'].isNotEmpty) {
          final approvalDetails = orderData['approvalDetails'];
          approvalStatus = approvalDetails.last['approvalStatus'];
        } else {}

        if (approvalStatus != null) {
          continue;
        }

        try {
          final apiResponse = await _syncService.fetchSalesOrderFromApi(
            saleOrderNo,
          );

          dynamic apiSalesOrder = apiResponse;

          // Check if API response has valid approvalDetails with approvalStatus
          dynamic apiApprovalStatus;
          if (apiSalesOrder != null &&
              apiSalesOrder is Map<String, dynamic> &&
              apiSalesOrder.containsKey('approvalDetails') &&
              apiSalesOrder['approvalDetails'] is List &&
              apiSalesOrder['approvalDetails'].isNotEmpty) {
            apiApprovalStatus =
                apiSalesOrder['approvalDetails'].last['approvalStatus'];
          }

          if (apiApprovalStatus != null) {
            final updatedOrder = Map<String, dynamic>.from(order);

            // Merge API data into existing 'data' field
            if (updatedOrder['data'] is Map) {
              updatedOrder['data'] = Map<String, dynamic>.from(
                updatedOrder['data'],
              )..addAll(apiSalesOrder);
            } else {
              updatedOrder['data'] = apiSalesOrder;
            }

            updatedOrder['waitingForApprovalResult'] = 'No';
            await holdOrderBox.put(entry.key, updatedOrder);

            sendDataToClients({
              'action': 'patchsaleorderGenerated',
              'saleOrderNo': saleOrderNo,
              'patchSaleOrder': updatedOrder,
            }, clients);
          } else {
            continue; // Skip if approvalStatus is missing or null
          }
        } catch (e) {}
      } else {}
    }

    holdOrderBox.toMap().forEach((key, value) {});
  }

  Future<bool> hasRealInternetConnection() async {
    // First, check basic connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      return false;
    }

    // Then, perform a real reachability check
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on TimeoutException {
      return false;
    } on SocketException {
      return false;
    } catch (e) {
      return false;
    }
  }

  bool isSameSubnet(String ip1, String ip2) {
    final p1 = ip1.split('.');
    final p2 = ip2.split('.');

    if (p1.length != 4 || p2.length != 4) return false;

    // Compare first 3 octets
    return p1[0] == p2[0] && p1[1] == p2[1] && p1[2] == p2[2];
  }

  void _showInfoDialog({
    required String title,
    required String message,
    required VoidCallback onOk,
  }) {
    final context = navigatorKey.currentState?.overlay?.context;
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

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 1) Ask the user to allow background
      await BackgroundPermissionGuard.askIfNeeded(context);

      // 2) Start your foreground service at the very first run (if you want)
      await ForegroundHelper.init();
      await ForegroundHelper.startIfNotRunning(appType: 'server');
    });
    final loginProvider = Provider.of<LoginProvider>(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 40.0,
              vertical: 60.0,
            ),
            child: Row(
              children: [
                // Left side: Text + Card
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 150),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // POS Title + Logo Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Bestmummy Logo
                            Image.asset(
                              'assets/bestmummy.png', // make sure this file exists in assets folder
                              height: 150,
                            ),
                            const SizedBox(width: 16),
                            // POS Title and Description
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'POS',
                                  style: TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Fast, simple POS for billing',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey.shade700,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Login Card
                        Card(
                          elevation: 8,
                          color: Colors.white,
                          shadowColor: Colors.black26,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(28.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Login',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 25),

                                // Username
                                TextFormField(
                                  controller: loginProvider
                                      .userNameController, // ← Added controller
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.grey.shade100,
                                    labelText: 'Username',
                                    labelStyle: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.black54,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.person,
                                      color: Colors.black54,
                                    ),
                                    errorText: loginProvider
                                        .userNameError, // ✅ show error
                                  ),
                                ),
                                const SizedBox(height: 18),

                                // Password
                                TextFormField(
                                  controller: loginProvider
                                      .passwordController, // ← Added controller
                                  obscureText: true,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.grey.shade100,
                                    labelText: 'Password',
                                    labelStyle: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.black54,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.lock,
                                      color: Colors.black54,
                                    ),
                                    errorText: loginProvider
                                        .passwordError, // ✅ show error
                                  ),
                                ),
                                const SizedBox(height: 25),

                                // 🧠 Login Button Widget
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: loginProvider.isSigningIn
                                        ? null
                                        : () async {
                                            // 🧠 Remove focus from all TextFields (hide keyboard)
                                            FocusScope.of(context).unfocus();

                                            bool loginSuccess =
                                                await loginProvider.loginUser(
                                                  context,
                                                );
                                            final ip = await getLocalIp();
                                            final allowed = isSameSubnet(
                                              locSubnetIp.value,
                                              ip!,
                                            );

                                            if (loginSuccess && allowed) {
                                              debugPrint(
                                                'Local: ${locSubnetIp.value} | Client: $ip',
                                              );

                                              await handleServerConnection();
                                            } else {
                                              if (!allowed) {
                                                _showInfoDialog(
                                                  message: 'Changed Network',
                                                  title: 'Changed Network',
                                                  onOk: () {},

                                                  // Navigator.pop(context),
                                                );
                                              }
                                            }
                                            loginProvider.userNameController
                                                .clear();
                                            loginProvider.passwordController
                                                .clear();
                                            proceedToDashboardCalled = false;
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade800,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 18,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 6,
                                      shadowColor: Colors.black26,
                                    ),
                                    child: const Text(
                                      'Log in',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 25),
                                ValueListenableBuilder<bool>(
                                  valueListenable: isShiftOpened,
                                  builder: (context, opened, child) {
                                    return Visibility(
                                      visible: !opened,
                                      child: OutlinedButton(
                                        onPressed: () async {
                                          final ValidationData = {
                                            "branchName": branchName,
                                            // Add other necessary fields
                                          };
                                          // await CashManagementProvider.postValidationData(
                                          //     ValidationData, context);
                                          await CashManagementProvider.fetchValidationDetails();
                                          await CashManagementProvider.fetchShiftDetails();
                                          await CashManagementProvider.fetchShiftOpenCheck();
                                          bool checkDayEnd =
                                              await CashManagementProvider.checkDayEnd(
                                                locationId,
                                              );

                                          final status = globals.status.value;
                                          final dayEndStatus =
                                              globals.dayEndStatus.value;
                                          final connectivity =
                                              _connectivityResult.value;
                                          final dispatch = dispatchStatus.value;
                                          final itemTransfer =
                                              itemTransferStatus.value;
                                          final soApproval =
                                              soApprovalStatus.value;
                                          final store = storeStatus.value;
                                          final soDelivery =
                                              soDeliveryStatus.value;

                                          final isConnected =
                                              connectivity !=
                                              ConnectivityResult.none;
                                          final isDayOpen = status == "open";
                                          final isDispatchApproved =
                                              dispatch.isEmpty ||
                                              dispatch == "success";
                                          final isItemTransferApproved =
                                              itemTransfer.isEmpty ||
                                              itemTransfer == "success";
                                          final isSoApprovalApproved =
                                              soApproval.isEmpty ||
                                              soApproval == "success";
                                          final isStoreApproved =
                                              store.isEmpty ||
                                              store == "success";
                                          final isSoDeliveryApproved =
                                              soDelivery.isEmpty ||
                                              soDelivery == "success";

                                          void showPremiumDialog({
                                            required BuildContext context,
                                            required String title,
                                            required Widget content,
                                            Color accentColor = Colors
                                                .blueAccent, // default accent
                                            IconData? icon, // optional icon
                                          }) {
                                            showDialog(
                                              context: context,
                                              barrierDismissible: true,
                                              builder: (context) => Dialog(
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                elevation: 10,
                                                backgroundColor:
                                                    Colors.transparent,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        Colors.white,
                                                        Colors.grey.shade100,
                                                      ],
                                                      begin: Alignment.topLeft,
                                                      end:
                                                          Alignment.bottomRight,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black26,
                                                        blurRadius: 15,
                                                        offset: Offset(0, 8),
                                                      ),
                                                    ],
                                                  ),
                                                  padding: EdgeInsets.all(20),
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      if (icon != null) ...[
                                                        Container(
                                                          padding:
                                                              EdgeInsets.all(
                                                                12,
                                                              ),
                                                          decoration:
                                                              BoxDecoration(
                                                                color: accentColor
                                                                    .withOpacity(
                                                                      0.1,
                                                                    ),
                                                                shape: BoxShape
                                                                    .circle,
                                                              ),
                                                          child: Icon(
                                                            icon,
                                                            color: accentColor,
                                                            size: 40,
                                                          ),
                                                        ),
                                                        SizedBox(height: 15),
                                                      ],
                                                      // Title
                                                      Text(
                                                        title,
                                                        style: TextStyle(
                                                          fontFamily: 'Poppins',
                                                          fontSize: 20,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.black87,
                                                          letterSpacing: 0.5,
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                      SizedBox(height: 10),
                                                      // Content
                                                      content,
                                                      SizedBox(height: 20),
                                                      // Action Button
                                                      SizedBox(
                                                        width: double.infinity,
                                                        child: ElevatedButton(
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor:
                                                                accentColor,
                                                            padding:
                                                                EdgeInsets.symmetric(
                                                                  vertical: 14,
                                                                ),
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                            ),
                                                            elevation: 5,
                                                          ),
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                context,
                                                              ),
                                                          child: Text(
                                                            'OK',
                                                            style: TextStyle(
                                                              fontFamily:
                                                                  'Poppins',
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color:
                                                                  Colors.white,
                                                              letterSpacing:
                                                                  0.5,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          }

                                          if (isDayOpen) {
                                            showPremiumDialog(
                                              context: context,
                                              title: 'Warning',
                                              content: const Text(
                                                'Shift is not closed yet.',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  color: Colors.black54,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              accentColor: Colors.orangeAccent,
                                              icon: Icons.warning_amber_rounded,
                                            );
                                            return;
                                          }

                                          final bool hasInternet =
                                              await hasRealInternetConnection();

                                          if (!hasInternet) {
                                            showPremiumDialog(
                                              context: context,
                                              title: 'Network Error',
                                              content: const Text(
                                                'No internet connection. Please check your network.',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  color: Colors.black54,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              accentColor: Colors.redAccent,
                                              icon: Icons.wifi_off_rounded,
                                            );
                                            return;
                                          }

                                          if (!checkDayEnd) {
                                            showPremiumDialog(
                                              context: context,
                                              title: 'Error',
                                              content: const Text(
                                                'Some shifts are not closed',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  color: Colors.black54,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              accentColor: Colors.redAccent,
                                              icon: Icons.error_outline,
                                            );
                                          }

                                          if (!isDispatchApproved &&
                                              dispatch.isNotEmpty) {
                                            showPremiumDialog(
                                              context: context,
                                              title: 'Error',
                                              content: const Text(
                                                'Some dispatches are not received yet.',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  color: Colors.black54,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              accentColor: Colors.redAccent,
                                              icon: Icons.error_outline,
                                            );
                                            return;
                                          }

                                          if (!isItemTransferApproved &&
                                              itemTransfer.isNotEmpty) {
                                            showPremiumDialog(
                                              context: context,
                                              title: 'Error',
                                              content: const Text(
                                                'Some item transfers are not received yet.',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  color: Colors.black54,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              accentColor: Colors.redAccent,
                                              icon: Icons.error_outline,
                                            );
                                            return;
                                          }

                                          if (!isSoApprovalApproved &&
                                              soApproval.isNotEmpty) {
                                            showPremiumDialog(
                                              context: context,
                                              title: 'Error',
                                              content: const Text(
                                                'Some Sale Order approvals are pending.',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  color: Colors.black54,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              accentColor: Colors.redAccent,
                                              icon: Icons.error_outline,
                                            );
                                            return;
                                          }

                                          if (!isStoreApproved &&
                                              store.isNotEmpty) {
                                            showPremiumDialog(
                                              context: context,
                                              title: 'Error',
                                              content: const Text(
                                                'Store Dispatch is not received.',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  color: Colors.black54,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              accentColor: Colors.redAccent,
                                              icon: Icons.error_outline,
                                            );
                                            return;
                                          }

                                          if (!isSoDeliveryApproved &&
                                              soDelivery.isNotEmpty) {
                                            showPremiumDialog(
                                              context: context,
                                              title: 'Error',
                                              content: const Text(
                                                'Some Sale Orders are not Delivered or pending.',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  color: Colors.black54,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              accentColor: Colors.redAccent,
                                              icon: Icons.error_outline,
                                            );
                                            return;
                                          }

                                          if (dayEndStatus.isEmpty ||
                                              dayEndStatus == "closed") {
                                            showPremiumDialog(
                                              context: context,
                                              title: 'Error',
                                              content: const Text(
                                                'Cannot end day: No open shift available',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  color: Colors.black54,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              accentColor: Colors.redAccent,
                                              icon: Icons.error_outline,
                                            );
                                            return;
                                          }

                                          // Show confirmation dialog
                                          showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              backgroundColor: Colors.white,
                                              title: const Center(
                                                child: Text('Confirm Day End'),
                                              ),
                                              content: const Text(
                                                'Are you sure you want to end the day?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                  child: const Text(
                                                    'Cancel',
                                                    style: TextStyle(
                                                      fontFamily: 'Poppins',
                                                      color: Colors.blue,
                                                    ),
                                                  ),
                                                ),
                                                TextButton(
                                                  onPressed: () async {
                                                    try {
                                                      CashManagementProvider.fetchShiftDetails();
                                                      final dayEndPost = {
                                                        "locationId":
                                                            locationId,
                                                        // Add other necessary fields
                                                      };
                                                      await CashManagementProvider.postDayEndData(
                                                        dayEndPost,
                                                        context,
                                                      );
                                                      await CashManagementProvider.fetchShiftDetails();

                                                      if (context.mounted) {
                                                        Navigator.pop(
                                                          context,
                                                        ); // close any loading dialogs

                                                        showPremiumDialog(
                                                          context: context,
                                                          title: 'Success',
                                                          content: const Text(
                                                            'Day End completed successfully.',
                                                            textAlign: TextAlign
                                                                .center,
                                                            style: TextStyle(
                                                              fontFamily:
                                                                  'Poppins',
                                                              color: Colors
                                                                  .black54,
                                                              fontSize: 16,
                                                            ),
                                                          ),
                                                          accentColor:
                                                              Colors.green,
                                                          icon: Icons
                                                              .check_circle_outline,
                                                        );
                                                      }
                                                    } catch (e) {
                                                      if (context.mounted) {
                                                        Navigator.pop(context);

                                                        showPremiumDialog(
                                                          context: context,
                                                          title: 'Error',
                                                          content: Text(
                                                            'Day End failed: $e',
                                                            textAlign: TextAlign
                                                                .center,
                                                            style: TextStyle(
                                                              fontFamily:
                                                                  'Poppins',
                                                              color: Colors
                                                                  .black54,
                                                              fontSize: 16,
                                                            ),
                                                          ),
                                                          accentColor:
                                                              Colors.redAccent,
                                                          icon: Icons
                                                              .error_outline,
                                                        );
                                                      }
                                                    }
                                                  },
                                                  child: const Text(
                                                    'Confirm',
                                                    style: TextStyle(
                                                      fontFamily: 'Poppins',
                                                      color: Colors.blue,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.black,
                                          backgroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 146,
                                            vertical: 15,
                                          ),
                                          textStyle: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          disabledForegroundColor: Colors.grey,
                                        ),
                                        child: const Text(
                                          "Day End",
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 20,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),

                                Divider(
                                  color: Colors.grey.shade300,
                                  thickness: 1,
                                ),
                                const SizedBox(height: 10),

                                // Server & App Type Info
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Server Type
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.cloud_outlined,
                                          color: Colors.blue.shade700,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Server: $serverip',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    // App Type
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.apps_rounded,
                                          color: Colors.blue.shade700,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'App Type: $appType',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Right side: Image
                Expanded(
                  flex: 1,
                  child: Image.asset(
                    'assets/posbilling.png',
                    height: 650,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // @override
  // void dispose() {
  //   _syncTimer?.cancel();
  //   _patchCheckTimer?.cancel();
  //   _approvalCheckTimer?.cancel();
  //   _advanceController.dispose();
  //   serverFoundNotifier.dispose();
  //   super.dispose();
  // }
}


//

 // / 📡 Discover server or create one if not found
  // Future<void> discoverServerAndHandle() async {
  //   print("🔍 [discoverServerAndHandle] called");

  //   final udp = await UDP.bind(Endpoint.any());
  //   udp.send(
  //     utf8.encode('WHO_IS_SERVER'),
  //     Endpoint.broadcast(port: Port(udpPort)),
  //   );

  //   final serverBox = await Hive.openBox('serverBox');
  //   bool found = false;

  //   try {
  //     await for (final datagram in udp.asStream(
  //       timeout: const Duration(seconds: 2),
  //     )) {
  //       if (datagram != null) {
  //         final message = utf8.decode(datagram.data);

  //         if (message.startsWith('SERVER:')) {
  //           print("✅ Server found via UDP");

  //           final parts = message.split(':');
  //           final ip = parts[1];
  //           final port = parts[2];

  //           await serverBox.put('serverIp', ip);
  //           await serverBox.put('serverPort', port);
  //           serverip = ip;

  //           setState(() {
  //             serverFound = true;
  //           });

  //           found = true;
  //           udp.close();

  //           await ForegroundHelper.startIfNotRunning(appType: 'client');

  //           /// ❌ DO NOT HIDE LOADING HERE
  //           await proceedToDashboard(context);
  //           return;
  //         }
  //       }
  //     }
  //   } catch (e) {
  //     print("❌ UDP discovery error: $e");
  //   }

  //   /// 🟥 No server found → show dialog
  //   if (!found && mounted) {
  //     udp.close();

  //     hideLoadingDialog(context); // ❗ hide before dialog

  //     showDialog(
  //       context: context,
  //       barrierDismissible: false,
  //       builder: (_) => NoServerDialog(
  //         onMakeServer: () async {
  //           if (!mounted) return;

  //           /// 🔄 SHOW LOADING AGAIN
  //           showLoadingDialog(context, message: "Creating server...");

  //           final ip = await getLocalIp();
  //           if (ip == null) {
  //             hideLoadingDialog(context);
  //             return;
  //           }

  //           print("🖥️ Creating server on IP: $ip");

  //           final box = await Hive.openBox('serverBox');
  //           await box.put('serverIp', ip);
  //           await box.put('serverPort', port);

  //           final configBox = HiveManager().configBox;
  //           appType = 'server';
  //           await configBox.put('appType', 'server');

  //           Provider.of<ItemProvider>(
  //             context,
  //             listen: false,
  //           ).fetchDataIfNeeded(branchAlias: globals.aliasname);

  //           serverip = ip;

  //           setState(() {
  //             serverFound = true;
  //           });

  //           await ForegroundHelper.startIfNotRunning(appType: 'server');

  //           startUdpResponder(ip, udpPort);
  //           startServer(clients, onDataReceived);

  //           print("📦 Fetching initial data...");

  //           await Provider.of<ProductProvider>(
  //             context,
  //             listen: false,
  //           ).fetchAllData(context);

  //           collectAndSendDeviceInfo('server', ip ?? '0.0.0.0');

  //           // await Provider.of<OrderProvider>(
  //           //   context,
  //           //   listen: false,
  //           // ).requestDataFromServer();

  //           await Provider.of<ItemProvider>(
  //             context,
  //             listen: false,
  //           ).fetchAndSaveSalesOrders(branchAlias: globals.aliasname);

  //           await Provider.of<ItemProvider>(
  //             context,
  //             listen: false,
  //           ).fetchAndStoreAdvancePercent(branchAlias: globals.aliasname);

  //           print("✅ Server setup complete");

  //           /// 🚀 NOW GO TO DASHBOARD
  //           await proceedToDashboard(context);
  //         },
  //       ),
  //     );
  //   }
  // }

  //   Future<void> startServer(
//   Set<WebSocketChannel> clients,
//   Function(Map<String, dynamic>, WebSocketChannel) onDataReceived,
// ) async {
//   // 1️⃣ Local check
//   if (_wsServer != null) {
//     debugPrint("⚠️ Server already running locally");
//     return;
//   }

//   // 2️⃣ Network check
//   debugPrint("🔍 Rechecking network for existing server...");
//   final exists = await isAnotherServerOnNetwork();

//   if (exists) {
//     debugPrint("❌ Another server exists on network → abort start");
//     appTypeNotifier.value = APP_CLIENT;
//     _connectAsClient();
//     return;
//   }

//   // 3️⃣ Safe to start
//   try {
//     debugPrint("🚀 No server found → starting WebSocket server");

//     _wsServer = await HttpServer.bind(
//       InternetAddress.anyIPv4,
//       port,
//       shared: true,
//     );

//     _wsServer!
//         .transform(WebSocketTransformer())
//         .listen((WebSocket socket) {
//       final channel = IOWebSocketChannel(socket);
//       handleWebSocket(channel, clients, (data) {
//         onDataReceived(data, channel);
//       });
//     });

//     debugPrint("✅ Server started successfully");
//   } catch (e) {
//     _wsServer = null;
//     debugPrint("❌ Failed to start server: $e");
//   }
// }

 // Future<void> startServer(Set<WebSocketChannel> clients, Function(Map<String, dynamic>, WebSocketChannel) onDataReceived) async {
  //   try {
  //     final server = await HttpServer.bind(InternetAddress.anyIPv4, 8686);
  //     print("✅ [SERVER] Started on port 8686");
  //     print("===========================================");

  //     await for (HttpRequest request in server) {
  //       if (WebSocketTransformer.isUpgradeRequest(request)) {
  //         final socket = await WebSocketTransformer.upgrade(request);
  //         final channel = IOWebSocketChannel(socket);
  //         final clientId = DateTime.now().millisecondsSinceEpoch.toString();

  //         clients.add(channel);
  //         clientIds[channel] = clientId;

  //         print("🟢 [CLIENT CONNECTED] ID: $clientId");
  //         print("📡 [TOTAL CONNECTED CLIENTS]: ${clients.length}");
  //         print("-------------------------------------------");

  //         handleWebSocket(channel, clients, (data) {
  //           onDataReceived(data, channel);
  //         });
  //         channel.stream.listen(
  //           (data) => onDataReceived(jsonDecode(data), channel),
  //           onDone: () {
  //             print("🔴 [CLIENT DISCONNECTED]");
  //             clients.remove(channel);
  //             print("📉 Active clients: ${clients.length}");
  //           },
  //           onError: (err) {
  //             print("⚠️server WebSocket error: $err");
  //             clients.remove(channel);
  //           },
  //         );
  //       }
  //     }
  //   } catch (e, st) {
  //     print("🔥 [SERVER START ERROR]: $e");
  //   }
  // }

  //  Future<bool> isAnotherServerOnNetwork() async {
//   final localIp = await getLocalIp();
//   if (localIp == null) return false;

//   final udp = await UDP.bind(Endpoint.any(port: Port(udpPort)));

//   bool found = false;

//   await udp.send(
//     utf8.encode('WHO_IS_SERVER'),
//     Endpoint.broadcast(port: Port(udpPort)),
//   );

//   final timeout = const Duration(milliseconds: 1500);

//   try {
//     await for (final dg in udp.asStream(timeout: timeout)) {
//       if (dg == null) continue;

//       final msg = utf8.decode(dg.data);
//       final fromIp = dg.address.address;

//       if (fromIp == localIp) continue;
//       if (!msg.startsWith('SERVER:')) continue;

//       debugPrint("🚨 Another server detected at $fromIp");
//       found = true;
//       break;
//     }
//   } finally {
//     udp.close();
//   }

//   return found;
// }

   
   
 // _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
    //   SyncService();
    //   _syncService.syncUnsyncedSaleOrders();
    //   _syncService.syncUnsyncedHoldOrders();
    //   _syncService.syncUnsyncedInvoices();
    //   _syncService.syncPendingPatches();
    //   _syncService.syncUnsyncedHoldOrders();
    // });
    // // Provider.of<LoginProvider>(context, listen: false).fetchAndStoreLoginData();

    // _approvalCheckTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
    //   checkPendingApprovals(HiveManager.salesOrderBox);
    //   chequePendingDiscountApproval(HiveManager.holdOrderBox);
    // });

// HiveManager().invoices.then((_) => _loadInvoices());
    // HiveManager().posInvoiceBox; // Just to ensure it's initialized

     //  Future<void> handlePostLoginFlow() async {
  //   debugPrint("➡️ [handlePostLoginFlow] started");
  //   debugPrint("ℹ️ serverFound = $serverFound");

  //   if (!serverFound) {
  //     debugPrint("! serverFound = $serverFound → starting discovery");
  //     await discoverServerAndHandle();
  //     return;
  //   }

  //   // Wait a few seconds to let Wi-Fi settle
  //   await Future.delayed(const Duration(seconds: 2));

  //   bool alive = await isServerReachable(serverip, port);
  //   debugPrint("📡 Server reachable = $alive");

  //   if (alive) {
  //     //await proceedToDashboard(context);
  //     final udp = await UDP.bind(Endpoint.any());
  //     await ForegroundHelper.startIfNotRunning(appType: 'client');
  //     udp.close();
  //     final data = jsonEncode({'type': 'handshake'});
  //     debugPrint("handshake send");

  //     sendataToServer(jsonDecode(data));
  //     return;
  //   } else {
  //     debugPrint("❌ Server NOT reachable → starting discovery");
  //     await discoverServerAndHandle();
  //   }

  //   debugPrint("⬅️ [handlePostLoginFlow] finished");
  // }

    //   if (serverFound) {
                                              //     bool isAlive =
                                              //         await isServerReachable(
                                              //           serverip,
                                              //           port,
                                              //         );

                                              //     if (isAlive) {
                                              //       await proceedToDashboard(
                                              //         context,
                                              //       );
                                              //     } else {
                                              //       await discoverServerAndHandle();
                                              //     }
                                              //   } else {
                                              //     await discoverServerAndHandle();
                                              //   }
                                              // } else {}