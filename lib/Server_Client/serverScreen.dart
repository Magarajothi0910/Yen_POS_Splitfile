import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import 'package:provider/provider.dart';
import 'package:udp/udp.dart';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yenpos/Global/Provider/branchwise_item_fetch.dart';

import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Global/globals_data.dart' as globals;
import 'package:yenpos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yenpos/Mode_page/choose_mode_screen.dart';

import 'package:yenpos/Server_Client/handlers/websocket_handler.dart';

import 'package:yenpos/Server_Client/makethisdeviceas%20server_Dialog.dart';
import 'package:yenpos/Server_Client/sendDataToClients.dart';
import 'package:yenpos/Server_Client/serverreachable.dart';
import 'package:yenpos/Server_Client/startServers.dart';

import 'package:yenpos/Server_Client/sync_service.dart';
import 'package:yenpos/background_task/background_permission_guard.dart';
import 'package:yenpos/background_task/flutter_foreground_task.dart';
import 'package:yenpos/kotpreinvoice/providers/order_provider.dart';
import 'package:yenpos/kotpreinvoice/providers/product_provider.dart';

import 'package:yenpos/loginPage/provider/loginPageProvider.dart';
import 'package:yenpos/shift_managment_page/openshift/open_shift.dart';

import 'package:web_socket_channel/io.dart'; // 👈 this one adds fromSocket()

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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
    super.initState();
    // HiveManager().invoices.then((_) => _loadInvoices());
    // HiveManager().posInvoiceBox; // Just to ensure it's initialized
    HiveManager.initialize(); // Just to ensure it's initialized

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

    checkIfServerWasPreviouslyStored();
    // discoverServerAndHandle();
  }

  Future<void> checkIfServerWasPreviouslyStored() async {
    print("🔍 [checkIfServerWasPreviouslyStored] Starting check...");

    try {
      print("📦 Opening Hive boxes: configBox & serverBox");
      final configBox = Hive.box('configBox');
      final serverBox = Hive.box('serverBox');

      final savedIp = serverBox.get('serverIp')?.toString() ?? '';
      final savedPort = serverBox.get('serverPort')?.toString() ?? '';

      print("📡 Saved Server IP: '$savedIp', Port: '$savedPort'");

      if (savedIp.isEmpty || savedPort.isEmpty) {
        print("⚠️ No previously stored server info found — exiting check.");
        return;
      }

      print("🌐 Fetching local device IP...");
      final localIp = await getLocalIp();
      print("💻 Local IP Detected: $localIp");

      serverip = savedIp;
      serverPort = savedPort;

      // 🧠 Check if this device was the server
      if (localIp == savedIp) {
        print("🖥 Detected local server setup (localIp == savedIp).");
        print("🔎 Checking if local server port $savedPort is open...");

        final isLocalServerRunning = await isPortOpen(
          localIp!,
          int.parse(savedPort),
        );

        print("✅ Local server running status: $isLocalServerRunning");

        if (isLocalServerRunning) {
          print("🚀 Starting in SERVER mode...");
          appType = 'server';
          await configBox.put('appType', 'server');

          print("⚙️ Launching Foreground service for SERVER...");
          await ForegroundHelper.startIfNotRunning(appType: 'server');
          print("🟢 Foreground service (server) started successfully.");
          await Provider.of<ProductProvider>(
            context,
            listen: false,
          ).fetchAllData(context);
        } else {
          print("❌ Local server not running on $localIp:$savedPort.");
        }
      } else {
        // 🌐 Client Mode
        print("📲 Detected as CLIENT device (savedIp != localIp).");
        print(
          "🔎 Checking if remote server $savedIp:$savedPort is reachable...",
        );

        final reachable = await isServerReachable(
          savedIp,
          int.parse(savedPort),
        );

        print("🌍 Server reachability: $reachable");

        if (reachable) {
          print("🚀 Starting in CLIENT mode...");
          appType = 'client';
          await configBox.put('appType', 'client');

          try {
            print("⚙️ Launching Foreground service for CLIENT...");
            await ForegroundHelper.startIfNotRunning(appType: 'client');
            print("🟢 Foreground service (client) started successfully.");
          } catch (e) {
            print("🔥 Error while starting foreground service (client): $e");
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('WebSocket error: $e')));
            }
          }
        } else {
          print("❌ Saved server not reachable at $savedIp:$savedPort.");
        }
      }

      // ✅ Finalize
      if (mounted) {
        print(
          "✅ Server check complete — updating serverFoundNotifier to true.",
        );
        serverFoundNotifier.value = true;
      }
    } catch (e, stack) {
      print("🔥 Exception caught in checkIfServerWasPreviouslyStored: $e");
      print(stack);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error checking server: $e')));
      }
    }

    print("🔚 [checkIfServerWasPreviouslyStored] Finished execution.\n");
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

  // Future<void> startServer(Set<WebSocketChannel> clients, Function(Map<String, dynamic>, WebSocketChannel) onDataReceived) async {
  //   try {
  //     final server = await HttpServer.bind(InternetAddress.anyIPv4, 8181);
  //     print("✅ [SERVER] Started on port 8181");
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

  Future<void> startServer(
    Set<WebSocketChannel> clients,
    Function(Map<String, dynamic>, WebSocketChannel) onDataReceived,
  ) async {
    if (_wsServer != null) {
      print("ℹ️ Server already running.");
      return;
    }
    try {
      _wsServer = await HttpServer.bind(
        InternetAddress.anyIPv4,
        port,
        shared: true,
      );
      _wsServer!.transform(WebSocketTransformer()).listen((WebSocket socket) {
        final channel = IOWebSocketChannel(socket);
        handleWebSocket(channel, clients, (data) {
          onDataReceived(data, channel);
        });
      });
      print("✅ WebSocket server started on port $port");
    } catch (e) {
      print("❌ Failed to start server: $e");
      if (mounted) {
        debugPrint('Failed to start server: $e');
        // CustomSnackBar.show(
        //   context,
        //   'Failed to start server: $e',
        //   type: SnackType.error,
        // );
      }
    }
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

  Future<void> proceedToDashboard(BuildContext context) async {
    print("➡️ Proceeding to dashboard initialization...");

    if (!context.mounted) {
      print("⚠️ Context not mounted, aborting dashboard navigation.");
      return;
    }

    if (globals.aliasname == null || globals.aliasname!.trim().isEmpty) {
      print("⚠️ Alias name is empty or null.");
      return;
    }

    print("🏷 Alias name: ${globals.aliasname}");

    final itemProvider = Provider.of<ItemProvider>(context, listen: false);
    final branchInfo = await itemProvider.getBranchInfoFromAlias(
      globals.aliasname!,
    );

    if (branchInfo == null) {
      print("❌ Branch info not found for alias: ${globals.aliasname}");
      return;
    }

    // Set globals safely
    globals.branchName = branchInfo['branchName'] ?? 'Branch Not Found';
    globals.branchAddress = branchInfo['address'] ?? 'Address Not Available';
    globals.branchPhoneno = branchInfo['phone'] ?? 'Phone Not Available';

    print("✅ Global branch info set:");
    print("🏢 Name: ${globals.branchName}");
    print("📍 Address: ${globals.branchAddress}");
    print("📞 Phone: ${globals.branchPhoneno}");

    // ✅ Use globals.branchName safely
    if (!context.mounted) return;

    if (globals.branchName == null ||
        globals.branchName == 'Branch Not Found') {
      print("❌ Branch not found for alias: ${globals.aliasname}");
      return;
    }

    final url = Uri.parse(
      'https://yenerp.com/fastapi/shifts/check-open-shift?branch_name=${globals.branchName}',
    );

    print("🌐 Sending request to check open shift: $url");

    final client = http.Client();

    try {
      final response = await client.get(url);
      print("📩 Shift check response status: ${response.statusCode}");
      print("📦 Response body: ${response.body}");

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        print("✅ Decoded shift data: $data");

        globals.shiftId.value = data['shiftId']?.toString() ?? '0';
        globals.shiftNumber.value = data['shiftNumber']?.toString() ?? '0';

        print("🆔 Shift ID: ${globals.shiftId.value}");
        print("🔢 Shift Number: ${globals.shiftNumber.value}");

        int shiftNumberInt = int.tryParse(globals.shiftNumber.value) ?? 0;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;

          if (shiftNumberInt != 0) {
            print("✅ Active shift found — navigating to ChooseModePage...");
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => ChooseModePage()),
            );
          } else {
            print("⚠️ No open shift found — navigating to OpenShift page...");
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No open shift found for today.'),
                backgroundColor: Colors.orange,
              ),
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => OpenShift()),
            );
          }
        });
      } else {
        print("❌ Failed to fetch shift data or response empty.");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to fetch shift data.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e, stack) {
      print("🔥 Error in proceedToDashboard: $e");
      print(stack);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      client.close();
      print("🔚 HTTP client closed.");
    }
  }

  /// 📡 Discover server or create one if not found
  Future<void> discoverServerAndHandle() async {
    print("🔍 Starting server discovery via UDP...");

    final udp = await UDP.bind(Endpoint.any());
    udp.send(
      utf8.encode('WHO_IS_SERVER'),
      Endpoint.broadcast(port: const Port(56789)),
    );

    print("📤 Broadcasted WHO_IS_SERVER on port 56789.");

    final serverBox = await Hive.openBox('serverBox');
    bool found = false;

    try {
      await for (final datagram in udp.asStream(
        timeout: const Duration(seconds: 2),
      )) {
        if (datagram != null) {
          final message = utf8.decode(datagram.data);
          print("📨 Received UDP message: $message");

          if (message.startsWith('SERVER:')) {
            final parts = message.split(':');
            final ip = parts[1];
            final port = parts[2];

            print("✅ Server discovered at $ip:$port");

            await serverBox.put('serverIp', ip);
            await serverBox.put('serverPort', port);
            serverip = ip;

            setState(() {
              serverFound = true;
            });

            found = true;
            udp.close();
            print("🧩 UDP listener closed after finding server.");

            await ForegroundHelper.startIfNotRunning(appType: 'client');

            print("🚀 Foreground service started as client.");
            await proceedToDashboard(context);
            break;
          }
        }
      }
    } catch (e) {
      print("❌ Error during server discovery: $e");
    }

    if (!found && mounted) {
      print("⚠️ No server found — prompting user to create one.");

      udp.close();

      showDialog(
        context: context,
        builder: (_) => NoServerDialog(
          onMakeServer: () async {
            print("🛠 User chose to make this device the server.");

            final ip = await getLocalIp();
            if (ip != null) {
              print("✅ Setting up server on local IP: $ip");

              final box = await Hive.openBox('serverBox');
              await box.put('serverIp', ip);
              await box.put('serverPort', port);

              final configBox = HiveManager().configBox;
              appType = 'server';
              await configBox.put('appType', 'server');

              Provider.of<ItemProvider>(
                context,
                listen: false,
              ).fetchDataIfNeeded(branchAlias: globals.aliasname);

              serverip = ip;

              setState(() {
                serverFound = true;
              });

              await ForegroundHelper.startIfNotRunning(appType: 'server');
              print("⚙️ Foreground service started as server.");

              startUdpResponder(ip, udpPort);
              print("📡 UDP responder started on port $udpPort.");

              startServer(clients, onDataReceived);
              print("🧠 Local server started successfully.");
              await Provider.of<ProductProvider>(
                context,
                listen: false,
              ).fetchAllData(context);
              await Provider.of<OrderProvider>(
                context,
                listen: false,
              ).requestDataFromServer();
              proceedToDashboard(context);
            } else {
              print("❌ Failed to get local IP — cannot start server.");
            }
          },
        ),
      );
    }
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
                                            print("🔹 Login button clicked.");

                                            // 🧠 Remove focus from all TextFields (hide keyboard)
                                            FocusScope.of(context).unfocus();

                                            bool loginSuccess =
                                                await loginProvider.loginUser(
                                                  context,
                                                );
                                            print(
                                              "✅ Login success: $loginSuccess",
                                            );

                                            if (loginSuccess) {
                                              print(
                                                "🔍 Checking if server is already found...",
                                              );
                                              if (serverFound) {
                                                print(
                                                  "✅ Server previously found: $serverip",
                                                );
                                                bool isAlive =
                                                    await isServerReachable(
                                                      serverip,
                                                      8181,
                                                    );
                                                print(
                                                  "🌐 Server reachable: $isAlive",
                                                );

                                                if (isAlive) {
                                                  print(
                                                    "🚀 Proceeding to dashboard...",
                                                  );
                                                  await proceedToDashboard(
                                                    context,
                                                  );
                                                } else {
                                                  print(
                                                    "⚠️ Server not reachable — discovering again...",
                                                  );
                                                  await discoverServerAndHandle();
                                                }
                                              } else {
                                                print(
                                                  "🔎 No existing server found — starting discovery...",
                                                );
                                                await discoverServerAndHandle();
                                              }
                                            } else {
                                              print(
                                                "❌ Login failed — staying on login screen.",
                                              );
                                            }
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

  @override
  void dispose() {
    _syncTimer?.cancel();
    _patchCheckTimer?.cancel();
    _approvalCheckTimer?.cancel();
    _advanceController.dispose();
    serverFoundNotifier.dispose();
    super.dispose();
  }
}
