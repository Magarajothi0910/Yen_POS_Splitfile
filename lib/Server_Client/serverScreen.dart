import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import 'package:provider/provider.dart';
import 'package:udp/udp.dart';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yenpos/Global/Provider/branchwise_item_fetch.dart';
import 'package:yenpos/Global/get_device_info.dart';

import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Global/globals_data.dart' as globals;
import 'package:yenpos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yenpos/Mode_page/choose_mode_screen.dart';
import 'package:yenpos/Sale_order/Widgets/Send_data_to_server.dart';

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
import 'package:yenpos/more_page/providers/cash_management_provider.dart';
import 'package:yenpos/shift_managment_page/openshift/open_shift.dart';
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

    HiveManager.initialize(); // Just to ensure it's initialized

    checkIfServerWasPreviouslyStored();
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
          appType = 'server';
          await configBox.put('appType', 'server');

          await ForegroundHelper.startIfNotRunning(appType: 'server');
          await Provider.of<ProductProvider>(
            context,
            listen: false,
          ).fetchAllData(context);

          await collectAndSendDeviceInfo('server', localIp ?? '0.0.0.0');
        } else {}
      } else {
        // 🌐 Client Mode

        final reachable = await isServerReachable(
          savedIp,
          int.parse(savedPort),
        );
        if (reachable) {
          appType = 'client';
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

  Future<void> startServer(
    Set<WebSocketChannel> clients,
    Function(Map<String, dynamic>, WebSocketChannel) onDataReceived,
  ) async {
    if (_wsServer != null) {
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
    } catch (e) {
      if (mounted) {
      
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
                const CircularProgressIndicator(),
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

  Future<void> proceedToDashboard(BuildContext context) async {
    final data = jsonEncode({'type': 'handshake'});
    sendataToServer(jsonDecode(data));
    // if (!context.mounted) {
    //   return;
    // }

    if (!context.mounted) {
      return;
    }

    // 🔄 SHOW LOADING (Shift check start)
    showLoadingDialog(context, message: "Checking shift status...");

    try {
      // Step 1: Alias check
      if (globals.aliasname == null || globals.aliasname!.trim().isEmpty) {
        hideLoadingDialog(context);
        return;
      }

      // Step 2: Branch info
      final itemProvider = Provider.of<ItemProvider>(context, listen: false);
      final branchInfo = await itemProvider.getBranchInfoFromAlias(
        globals.aliasname!,
      );

      if (branchInfo == null) {
        hideLoadingDialog(context);
        return;
      }

      globals.branchName = branchInfo['branchName'] ?? "";
      globals.branchAddress = branchInfo['address'] ?? "";
      globals.branchPhoneno = branchInfo['phone'] ?? "";

      if (!context.mounted) {
        return;
      }

      if (globals.branchName == null ||
          globals.branchName == 'Branch Not Found') {
        return;
      }
      // Step 3: Shift API
      final url = Uri.parse(
        'https://yenerp.com/fluttertestapi/dayendvalidations/status'
        '?empId=$userName&branchName=${globals.branchName}',
      );
      final client = http.Client();

      final response = await client.get(url);

      hideLoadingDialog(context); // ✅ HIDE LOADING AFTER API

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        globals.shiftOpenStatus.value =
            data['shiftStatus']?.toString() ?? 'close';

        globals.shiftId.value = data['shiftId']?.toString() ?? '0';
        globals.shiftNumber.value = data['shiftNumber']?.toString() ?? '0';

        int shiftNumberInt = int.tryParse(globals.shiftNumber.value) ?? 0;

        if (!context.mounted) return;

        if (shiftOpenStatus.value == 'open') {
          hideLoadingDialog(context);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => ChooseModePage()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No open shift found for today'),
              backgroundColor: Colors.orange,
            ),
          );
          hideLoadingDialog(context);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => OpenShift()),
          );
        }
      } else {
        hideLoadingDialog(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to fetch shift data'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e, stack) {
      hideLoadingDialog(context);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// 📡 Discover server or create one if not found
  Future<void> discoverServerAndHandle() async {
    final udp = await UDP.bind(Endpoint.any());
    udp.send(
      utf8.encode('WHO_IS_SERVER'),
      Endpoint.broadcast(port: Port(udpPort)),
    );

    final serverBox = await Hive.openBox('serverBox');
    bool found = false;

    try {
      await for (final datagram in udp.asStream(
        timeout: const Duration(seconds: 2),
      )) {
        if (datagram != null) {
          final message = utf8.decode(datagram.data);

          if (message.startsWith('SERVER:')) {
            final parts = message.split(':');
            final ip = parts[1];
            final port = parts[2];

            await serverBox.put('serverIp', ip);
            await serverBox.put('serverPort', port);
            serverip = ip;

            setState(() {
              serverFound = true;
            });

            found = true;
            udp.close();

            await ForegroundHelper.startIfNotRunning(appType: 'client');

            /// ❌ DO NOT HIDE LOADING HERE
            await proceedToDashboard(context);
            return;
          }
        }
      }
    } catch (e) {}

    /// 🟥 No server found → show dialog
    if (!found && mounted) {
      udp.close();

      hideLoadingDialog(context); // ❗ hide before dialog

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => NoServerDialog(
          onMakeServer: () async {
            if (!mounted) return;

            /// 🔄 SHOW LOADING AGAIN
            showLoadingDialog(context, message: "Creating server...");

            final ip = await getLocalIp();
            if (ip == null) {
              hideLoadingDialog(context);
              return;
            }

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

            startUdpResponder(ip, udpPort);
            startServer(clients, onDataReceived);

            await Provider.of<ProductProvider>(
              context,
              listen: false,
            ).fetchAllData(context);

            collectAndSendDeviceInfo('server', ip ?? '0.0.0.0');

            // await Provider.of<OrderProvider>(
            //   context,
            //   listen: false,
            // ).requestDataFromServer();

            await Provider.of<ItemProvider>(
              context,
              listen: false,
            ).fetchAndSaveSalesOrders(branchAlias: globals.aliasname);

            await Provider.of<ItemProvider>(
              context,
              listen: false,
            ).fetchAndStoreAdvancePercent(branchAlias: globals.aliasname);

            /// 🚀 NOW GO TO DASHBOARD
            await proceedToDashboard(context);
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

                                            if (loginSuccess) {
                                              if (serverFound) {
                                                bool isAlive =
                                                    await isServerReachable(
                                                      serverip,
                                                      port,
                                                    );

                                                if (isAlive) {
                                                  await proceedToDashboard(
                                                    context,
                                                  );
                                                } else {
                                                  await discoverServerAndHandle();
                                                }
                                              } else {
                                                await discoverServerAndHandle();
                                              }
                                            } else {}
                                            loginProvider.userNameController
                                                .clear();
                                            loginProvider.passwordController
                                                .clear();
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
                                                        "branchName":
                                                            branchName,
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
