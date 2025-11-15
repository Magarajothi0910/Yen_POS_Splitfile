// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:hive_flutter/hive_flutter.dart';
// import 'package:web_socket_channel/io.dart';
// import 'package:yenpos/Server_Client/handlers/websocket_handler.dart';
// import '../background_Task/flutter_foreground_task.dart';
// import '../../kotpreinvoice/providers/bottomNavprovider.dart';
// import '../screens/table_screen.dart';
// import 'package:udp/udp.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';
// import '../SaleOrder/hiveBoxInitializer.dart';
// import '../SaleOrder/soHandler/saleOrder_handlers.dart';
// import '../SaleOrder/soHandler/soApproveAndHoldOrders.dart';
// import '../UI/loginUI.dart';
// import '../models/fetchBranch.dart';
// import 'package:yenpos/Global/globals_data.dart';
// import '../providers/printer_provider.dart';
// import '../services/sendDataToClients.dart';
// import '../services/serverreachable.dart';
// import '../services/startServers.dart';
// import '../services/websocket_handlers.dart';
// import '../services/websocketService.dart';
// import '../widgets/makethisdeviceas server_Dialog.dart';
// import '../providers/order_provider.dart';
// import 'package:provider/provider.dart';
// import '../providers/product_provider.dart';
// import '../providers/login_provider.dart';

// // 🔔 ChangeNotifier to manage LoginScreen state
// class LoginScreenState extends ChangeNotifier {
//   bool serverFound = false;
//   String status = 'Searching for server...';
//   List<Map<String, dynamic>> receivedData = [];
//   String? errorMessage;
//   // 📌 Store error messages for UI display
//   // 🔔 Update server found status
//   void updateServerFound(bool found) {
//     serverFound = found;
//     print("📍 serverFound state updated: $found");
//     notifyListeners();
//   } // 🔔 Update status message

//   void updateStatus(String newStatus) {
//     status = newStatus;
//     print("📝 Status updated: $newStatus");
//     notifyListeners();
//   } // 🔔 Add received data

//   void addReceivedData(Map<String, dynamic> data) {
//     receivedData.add(data);
//     print("📥 Added received data: $data");
//     notifyListeners();
//   } // 🔔 Set error message

//   void setErrorMessage(String message) {
//     errorMessage = message;
//     print("❌ Error message set: $message");
//     notifyListeners();
//   }
// } // ignore: camel_case_types

// class LoginScreen extends StatefulWidget {
//   const LoginScreen({super.key});
//   @override // ignore: library_private_types_in_public_api
//   _LoginScreenState createState() => _LoginScreenState();
// }

// class _LoginScreenState extends State<LoginScreen> {
//   final TextEditingController _userNameController = TextEditingController();
//   final TextEditingController _passwordController = TextEditingController();
//   WebSocketServiceDine? webSocketService;
//   WebSocketChannel? channel;
//   HttpServer? _wsServer;
//   int sendDataToClientsCallCount = 0;
//   List<Map<String, dynamic>> orders = [];
//   List<String> logs = [];
//   String serverPort = "";
//   late Box box;
//   final ValueNotifier<bool> serverFoundNotifier = ValueNotifier(false);
//   late LoginScreenState state; // Sale orders
//   final saleOrderHandler = SaleOrderHandler();
//   final soApproveAndHoldHandler = soApproveAndHoldOrderHandler();
//   final hiveBoxManager = HiveBoxManager();
//   late Box saleOrderBox;
//   late Box holdOrderBox;
//   Map<String, dynamic>? paymentDetails;
//   bool placeOrderCliked = false;
//   bool showPaymentScreen = false;
//   @override
//   void initState() {
//     super.initState();
//     state = LoginScreenState(); // 🔔 Initialize ChangeNotifier
//     try {
//       print("🔍 Initializing LoginScreen...");
//       Provider.of<LoginProviderDine>(
//         context,
//         listen: false,
//       ).fetchAndStoreLoginData();
//       final printerService = Provider.of<PrinterProviderDine>(
//         context,
//         listen: false,
//       );
//       printerService.printerInitializeHive();
//       fetchAndStoreBranchData();
//       // checkIfServerWasPreviouslyStored();
//       final productProvider = Provider.of<ProductProvider>(
//         context,
//         listen: false,
//       );
//       productProvider.fetchTablesAndSaveInHive(context);
//       print("✅ LoginScreen initialization complete.");
//     } catch (e) {
//       print("❌ Error in initState: $e");
//       state.setErrorMessage("Initialization error: $e");
//     }
//   }

//   @override
//   void dispose() {
//     try {
//       _userNameController.dispose();
//       _passwordController.dispose();
//       serverFoundNotifier.dispose();
//       state.dispose(); // 🧹 Dispose ChangeNotifier
//       print("🛑 Disposed controllers, notifier, and state.");
//       super.dispose();
//     } catch (e) {
//       print("❌ Error in dispose: $e");
//     }
//   }

//   Future<void> checkIfServerWasPreviouslyStored() async {
//     print("🔍 Checking if server info was previously stored...");
//     try {
//       final box = Hive.box('ordersBox');
//       print("📦 OrdersBox length: ${box.length}");
//       final configBox = Hive.box('configBox');
//       final serverBox = Hive.box('serverBox');
//       final savedIp = serverBox.get('serverIp')?.toString() ?? '';
//       final savedPort = serverBox.get('serverPort')?.toString() ?? '';
//       print("🧠 Saved IP: $savedIp, Saved Port: $savedPort");
//       if (savedIp.isEmpty || savedPort.isEmpty) {
//         print("⚠️ No saved server info found.");
//         return;
//       }
//       final localIp = await getLocalIp();
//       print("🌐 Device Local IP: $localIp");
//       serverip = savedIp;
//       serverPort = savedPort;
//       if (localIp == savedIp) {
//         // Server mode
//         final isLocalServerRunning = await isPortOpen(
//           localIp!,
//           int.parse(savedPort),
//         );
//         if (isLocalServerRunning) {
//           appType = 'server';
//           await configBox.put('appType', 'server');
//           print("🖥️ Device confirmed as server"); // Start foreground service
//           await ForegroundHelper.startIfNotRunning(appType: 'server');
//           try {
//             await Provider.of<ProductProvider>(
//               context,
//               listen: false,
//             ).fetchAllData(context);
//             print("✅ Fetched data successfully in server mode");
//           } catch (e) {
//             print("❌ Error fetching server data: $e");
//             if (mounted) {
//               state.setErrorMessage('Server fetch error: $e');
//               ScaffoldMessenger.of(
//                 context,
//               ).showSnackBar(SnackBar(content: Text('Server fetch error: $e')));
//             }
//           }
//         } else {
//           print("⚠️ Server not running locally, discovery required.");
//         }
//       } else {
//         // Client mode
//         final reachable = await isServerReachable(
//           savedIp,
//           int.parse(savedPort),
//         );
//         if (reachable) {
//           appType = 'client';
//           await configBox.put('appType', 'client');
//           print("📱 Device running in client mode");
//           try {
//             final orderProvider = Provider.of<OrderProvider>(
//               context,
//               listen: false,
//             );
//             await orderProvider.initializeWebSocket();
//             print(
//               "✅ WebSocket initialized",
//             ); // Start foreground service for client
//             await ForegroundHelper.startIfNotRunning(
//               appType: 'client',
//               serverIp: serverip,
//               serverPort: serverPort,
//             );
//             orderProvider.channel.sink.add(
//               jsonEncode({'action': 'requestBranchwiseItemsForClient'}),
//             );
//             print("📤 Request sent to server for branchwise items");
//           } catch (e) {
//             print("❌ Error initializing WebSocket: $e");
//             if (mounted) {
//               state.setErrorMessage('WebSocket error: $e');
//               ScaffoldMessenger.of(
//                 context,
//               ).showSnackBar(SnackBar(content: Text('WebSocket error: $e')));
//             }
//           }
//         } else {
//           print("❌ Saved server unreachable, discovery required.");
//         }
//       }
//       if (mounted) {
//         state.updateServerFound(true);
//         serverFoundNotifier.value = true;
//       }
//     } catch (e, stack) {
//       print("❌ Error in checkIfServerWasPreviouslyStored: $e");
//       print("🐞 Stacktrace: $stack");
//       if (mounted) {
//         state.setErrorMessage('Error checking server: $e');
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(SnackBar(content: Text('Error checking server: $e')));
//       }
//     }
//   }

//   Future<void> discoverServerAndHandle() async {
//     state.updateStatus("Discovering server...");
//     final udp = await UDP.bind(Endpoint.any(port: const Port(44556)));
//     try {
//       udp.send(
//         utf8.encode('WHO_IS_SERVER'),
//         Endpoint.broadcast(port: const Port(44556)),
//       );
//       print("📡 Broadcast WHO_IS_SERVER sent");
//       final serverBox = Hive.box('serverBox');
//       bool found = false;
//       await for (final datagram in udp.asStream(
//         timeout: const Duration(seconds: 2),
//       )) {
//         try {
//           if (datagram != null) {
//             final message = utf8.decode(datagram.data);
//             print("📩 UDP message received: $message");
//             if (message.startsWith('SERVER:')) {
//               final parts = message.split(':');
//               final ip = parts[1];
//               final port = parts[2];
//               await serverBox.put('serverIp', ip);
//               await serverBox.put('serverPort', port);
//               serverip = ip;
//               serverPort = port;
//               state.updateServerFound(true);
//               print("✅ Server found at $ip:$port");
//               await ForegroundHelper.startIfNotRunning(
//                 appType: 'client',
//                 serverIp: serverip,
//                 serverPort: serverPort,
//               );
//               if (mounted) serverFoundNotifier.value = true;
//               found = true;
//               udp.close();
//               try {
//                 final webSocketService = Provider.of<WebSocketServiceDine>(
//                   context,
//                   listen: false,
//                 );
//                 webSocketService.connect();
//                 print("✅ WebSocket connected to ws://$serverip:$port");
//                 if (webSocketService.isConnected) {
//                   final box = Hive.box('deviceData');
//                   String deviceCode = box.get('deviceCode')?.toString() ?? '';
//                   webSocketService.sendDeviceCodeToServer(deviceCode);
//                   print("📤 Device code sent: $deviceCode");
//                   final orderProvider = Provider.of<OrderProvider>(
//                     context,
//                     listen: false,
//                   );
//                   await orderProvider.requestDataFromServer();
//                   print("📤 Requested data from server");
//                   await proceedToDashboard();
//                 } else {
//                   print("❌ WebSocket not connected after connect attempt");
//                   throw Exception("WebSocket connection failed");
//                 }
//               } catch (e) {
//                 print("❌ WebSocket connection error: $e");
//                 if (mounted) {
//                   state.setErrorMessage('WebSocket connection error: $e');
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(content: Text('WebSocket connection error: $e')),
//                   );
//                 }
//               }
//               break;
//             }
//           }
//         } catch (e) {
//           print("❌ Error processing UDP datagram: $e");
//         }
//       }
//       if (!found && mounted) {
//         print("❌ No server found, showing NoServerDialog...");

//         showDialog(
//           context: context,
//           builder: (_) => NoServerDialog(
//             onMakeServer: () async {
//               try {
//                 print("🚪 Closing dialog...");
//                 Navigator.of(context).pop();

//                 print("🌐 Fetching local IP...");
//                 final ip = await getLocalIp();
//                 if (ip == null) throw Exception("Unable to fetch local IP");
//                 print("📡 Local IP fetched: $ip");

//                 print("💾 Saving server IP and port to Hive...");
//                 await serverBox.put('serverIp', ip);
//                 await serverBox.put('serverPort', port);

//                 appType = 'server';
//                 print("⚙️ Setting appType to 'server' in configBox...");
//                 await Hive.box('configBox').put('appType', 'server');

//                 serverip = ip;
//                 print("🟢 Server IP set: $serverip");

//                 print("🔔 Updating UI state for server found...");
//                 state.updateServerFound(true);
//                 serverFoundNotifier.value = true;

//                 print("🛠️ Starting foreground service if not running...");
//                 await ForegroundHelper.startIfNotRunning(appType: 'server');

//                 print("📡 Starting UDP responder...");
//                 await startUdpResponder(serverip, udpPort);

//                 print("🖥️ Starting server...");
//                 await startServer(onDataReceived);

//                 print("⏳ Checking if server is reachable...");
//                 final isServerAlive = await isServerReachable(serverip, 8090);

//                 if (isServerAlive) {
//                   print("✅ Server running at $serverip:$port");

//                   print("📦 Fetching all product data...");
//                   await Provider.of<ProductProvider>(
//                     context,
//                     listen: false,
//                   ).fetchAllData(context);

//                   print("📤 Requesting order data from server...");
//                   await Provider.of<OrderProvider>(
//                     context,
//                     listen: false,
//                   ).requestDataFromServer();

//                   print("🚀 Proceeding to dashboard...");
//                   await proceedToDashboard();
//                 } else {
//                   print("❌ Failed to start server at $serverip:$port");
//                   if (mounted) {
//                     state.setErrorMessage(
//                       'Failed to start server. Please try again.',
//                     );
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       const SnackBar(
//                         content: Text(
//                           'Failed to start server. Please try again.',
//                         ),
//                       ),
//                     );
//                   }
//                 }
//               } catch (e, stack) {
//                 print("🔥 Error in onMakeServer callback: $e\n$stack");
//                 if (mounted) {
//                   state.setErrorMessage('Error starting server: $e');
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(content: Text('Error starting server: $e')),
//                   );
//                 }
//               }
//             },
//           ),
//         );
//       }
//     } catch (e, stack) {
//       print("❌ Error during server discovery: $e");
//       print("🐞 Stacktrace: $stack");
//       if (mounted) {
//         state.setErrorMessage('Server discovery error: $e');
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(SnackBar(content: Text('Server discovery error: $e')));
//       }
//     } finally {
//       udp.close();
//       print("🔌 UDP socket closed");
//     }
//   }

//   Future<bool> isPortOpen(String ip, int port) async {
//     try {
//       final socket = await Socket.connect(
//         ip,
//         port,
//         timeout: const Duration(milliseconds: 500),
//       );
//       socket.destroy();
//       print("✅ Port $port on $ip is open.");
//       return true;
//     } catch (e) {
//       print("⚠️ Port $port on $ip is closed or unreachable: $e");
//       return false;
//     }
//   }

//   Future<void> startServer(
//     Function(Map<String, dynamic>) onDataReceived,
//   ) async {
//     if (_wsServer != null) {
//       print("ℹ️ Server already running.");
//       return;
//     }
//     try {
//       _wsServer = await HttpServer.bind(
//         InternetAddress.anyIPv4,
//         8090,
//         shared: true,
//       );
//       _wsServer!.transform(WebSocketTransformer()).listen((WebSocket socket) {
//          final channel = IOWebSocketChannel(socket); // ✅ FIXED HERE
//                 clients.add(channel);
//         handleWebSocket(channel, clients,(data) {
//           state.addReceivedData(data);
//         });
//       });
//       print("✅ WebSocket server started on port $port");
//     } catch (e) {
//       print("❌ Failed to start server: $e");
//       if (mounted) {
//         state.setErrorMessage('Failed to start server: $e');
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(SnackBar(content: Text('Failed to start server: $e')));
//       }
//     }
//   }

//   Map<String, String> seathiveOrderIds = {};
//   Future<void> onDataReceived(Map<String, dynamic> data) async {
//     try {
//       if (!mounted) return;
//       print("📥 Data received: $data");
//       state.addReceivedData(data);
//       if (data['action'] == 'removePrinter') {
//         handleRemovePrinter(data);
//         print("🖨️ Printer removal handled.");
//       }
//       // Removed sendDataToClients calls for seat actions here to avoid duplication;
//       // Handlers in websocket_handlers.dart now handle broadcasting after local update
//     } catch (e) {
//       print("❌ Error processing received data: $e");
//       state.setErrorMessage('Error processing received data: $e');
//     }
//   }

//   Future<void> handleServerConnection() async {
//     try {
//       if (state.serverFound) {
//         final isAlive = await isServerReachable(
//           serverip,
//           int.parse(serverPort),
//         );
//         if (isAlive) {
//           print("✅ Server is reachable at $serverip:$serverPort");
//           final webSocketService = Provider.of<WebSocketServiceDine>(
//             context,
//             listen: false,
//           );
//           try {
//             await webSocketService.connect();
//             print("✅ WebSocket connected to ws://$serverip:$serverPort");
//             if (webSocketService.isConnected) {
//               final box = Hive.box('deviceData');
//               String deviceCode = box.get('deviceCode')?.toString() ?? '';
//               webSocketService.sendDeviceCodeToServer(deviceCode);
//               print("📤 Device code sent: $deviceCode");
//               final orderProvider = Provider.of<OrderProvider>(
//                 context,
//                 listen: false,
//               );
//               await orderProvider.requestDataFromServer();
//               print("📤 Requested data from server");
//               await proceedToDashboard();
//             } else {
//               print("❌ WebSocket not connected after connect attempt");
//               throw Exception("WebSocket connection failed");
//             }
//           } catch (e) {
//             print("❌ WebSocket connection error: $e");
//             if (mounted) {
//               state.setErrorMessage('WebSocket connection error: $e');
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(content: Text('WebSocket connection error: $e')),
//               );
//             }
//             await discoverServerAndHandle();
//           }
//         } else {
//           print("❌ Server at $serverip:$serverPort is not reachable");
//           await discoverServerAndHandle();
//         }
//       } else {
//         print("⚠️ Server not found....");
//         await discoverServerAndHandle();
//       }
//     } catch (e) {
//       print("❌ Error handling server connection: $e");
//       if (mounted) {
//         state.setErrorMessage('Server connection error: $e');
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(SnackBar(content: Text('Server connection error: $e')));
//       }
//     }
//   }

//   Future<void> loginUser() async {
//     try {
//       print("🔑 Login button clicked.");
//       // await handleServerConnection(); // Testing purpose

//       final loginProvider = Provider.of<LoginProviderDine>(
//         context,
//         listen: false,
//       );
//       loginProvider.setUserNameError(null);
//       loginProvider.setPasswordError(null);
//       userName = _userNameController.text.trim();
//       final password = _passwordController.text.trim();
//       if (userName.isEmpty) {
//         loginProvider.setUserNameError('Please enter a username');
//       }
//       if (password.isEmpty) {
//         loginProvider.setPasswordError('Please enter a password');
//       }
//       if (loginProvider.userNameError == null &&
//           loginProvider.passwordError == null) {
//         bool isValid = await loginProvider.validateCredentials(
//           userName,
//           password,
//         );
//         if (isValid) {
//           await handleServerConnection();
//         } else {
//           loginProvider.setUserNameError('Invalid username or password');
//           loginProvider.setPasswordError('Invalid username or password');
//         }
//       }
//     } catch (e) {
//       print("❌ Error in loginUser: $e");
//       if (mounted) {
//         state.setErrorMessage('Login error: $e');
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(SnackBar(content: Text('Login error: $e')));
//       }
//     }
//   }

//   Future<void> proceedToDashboard() async {
//     try {
//       if (appType != 'server') {
//         await Provider.of<OrderProvider>(
//           context,
//           listen: false,
//         ).requestDataFromServer();
//       }
//       Provider.of<BottomNavProvider>(context, listen: false).updateIndex(0);
//       if (mounted) {
//         Navigator.pushAndRemoveUntil(
//           context,
//           MaterialPageRoute(builder: (context) => const TableScreen()),
//           (Route<dynamic> route) => false,
//         );
//       }
//       print("🏁 Proceeded to dashboard.");
//     } catch (e) {
//       print("❌ Error proceeding to dashboard: $e");
//       if (mounted) {
//         state.setErrorMessage('Error proceeding to dashboard: $e');
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error proceeding to dashboard: $e')),
//         );
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return ChangeNotifierProvider.value(
//       value: state,
//       child: Consumer<LoginScreenState>(
//         builder: (context, state, _) {
//           return LoginUI(
//             userNameController: _userNameController,
//             passwordController: _passwordController,
//             onLogin: loginUser,
//             serverStatus: state.status, // 🔔 Display status from ChangeNotifier
//             errorMessage:
//                 state.errorMessage, // 🔔 Display error from ChangeNotifier
//           );
//         },
//       ),
//     );
//   }
// }
