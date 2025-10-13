// import 'dart:convert';

// import 'package:flutter/material.dart';
// import 'package:hive_flutter/hive_flutter.dart';
// import 'package:server/screens/serverScreen.dart';
// import 'package:server/screens/table_screen.dart';
// import 'package:udp/udp.dart';
// import '../services/serverreachable.dart';
// import '../services/websocketService.dart';
// import '/providers/order_provider.dart';
// import 'package:provider/provider.dart';
// import '../Dashboard/tableDashboard.dart';
// import '../models/globals.dart';
// import '../providers/product_provider.dart';
// import '../providers/login_provider.dart';

// class LoginScreen extends StatefulWidget {
//   const LoginScreen({super.key});

//   @override
//   _LoginScreenState createState() => _LoginScreenState();
// }

// class _LoginScreenState extends State<LoginScreen> {
//   final TextEditingController _userNameController = TextEditingController();
//   final TextEditingController _passwordController = TextEditingController();
//   String serverPort = "Unknown";
//   late Box box;
//   bool serverFound = false;
//   String status = 'Searching for server...';

//   @override
//   // void initState() {
//   //   super.initState();
//   //   _startDiscovery();

//   //   box = Hive.box('serverBox');
//   //   _loadFromHive();
//   //   Provider.of<LoginProvider>(context, listen: false).fetchAndStoreLoginData();
//   //   final productProvider =
//   //       Provider.of<ProductProvider>(context, listen: false);
//   //   productProvider.fetchTablesAndSaveInHive();
//   // }
//   @override
//   void initState() {
//     super.initState();
//     _initApp();
//   }

//   @override
//   void dispose() {
//     _userNameController.dispose();
//     _passwordController.dispose();
//     super.dispose();
//   }

//   Future<void> _initApp() async {
//     // discoverServer();

//     // ignore: use_build_context_synchronously
//     Provider.of<LoginProvider>(context, listen: false).fetchAndStoreLoginData();
//     // ignore: use_build_context_synchronously
//     Provider.of<ProductProvider>(context, listen: false)
//         .fetchTablesAndSaveInHive();
//     Provider.of<ServerScreen>(context, listen: false)
//         .checkIfServerWasPreviouslyStored();
//   }

//   // void discoverServer() async {
//   //   final udp = await UDP.bind(Endpoint.any());

//   //   // Send WHO_IS_SERVER to broadcast
//   //   udp.send(
//   //     utf8.encode('WHO_IS_SERVER'),
//   //     Endpoint.broadcast(port: const Port(33441)),
//   //   );
//   //   print('Sent WHO_IS_SERVER');

//   //   final serverBox = await Hive.openBox('serverBox');

//   //   // Wait max 2 seconds for response
//   //   udp.asStream(timeout: const Duration(seconds: 2)).listen((datagram) async {
//   //     if (datagram != null) {
//   //       final message = utf8.decode(datagram.data);
//   //       print('Received: $message');
//   //       if (message.startsWith('SERVER:')) {
//   //         final parts = message.split(':');
//   //         final ip = parts[1];
//   //         final port = parts[2];

//   //         // Save to Hive
//   //         await serverBox.put('serverIp', ip);
//   //         await serverBox.put('serverPort', port);

//   //         // Assign to global variable
//   //         serverip = ip;

//   //         setState(() {
//   //           status = 'Server found at $ip:$port';
//   //           serverFound = true;
//   //         });

//   //         udp.close();
//   //       }
//   //     }
//   //   }, onDone: () async {
//   //     if (!serverFound) {
//   //       final fallbackIp = serverBox.get('serverIp', defaultValue: '');
//   //       final fallbackPort = serverBox.get('serverPort', defaultValue: '');

//   //       if (fallbackIp.isNotEmpty) {
//   //         serverip = fallbackIp; // fallback to stored IP
//   //         serverPort = fallbackPort;
//   //         print('Fallback IP from Hive: $serverip:$serverPort');
//   //         setState(() {
//   //           status = 'Using saved server: $serverip:$serverPort';
//   //           serverFound = true;
//   //         });
//   //       } else {
//   //         setState(() {
//   //           status = 'No server found';
//   //         });
//   //       }
//   //     }
//   //   });
//   // }

//   // Future<void> loginUser() async {
//   //   final loginProvider = Provider.of<LoginProvider>(context, listen: false);
//   //   loginProvider.setUserNameError(null);
//   //   loginProvider.setPasswordError(null);

//   //   userName = _userNameController.text.trim();
//   //   final password = _passwordController.text.trim();

//   //   if (userName.isEmpty) {
//   //     loginProvider.setUserNameError('Please enter a username');
//   //   }
//   //   if (password.isEmpty) {
//   //     loginProvider.setPasswordError('Please enter a password');
//   //   }
//   //   Provider.of<OrderProvider>(context, listen: false).requestDataFromServer();
//   //   Navigator.pushAndRemoveUntil(
//   //     context,
//   //     MaterialPageRoute(builder: (context) => const DashboardScreen()),
//   //     (Route<dynamic> route) => false, // Removes all previous routes
//   //   );
//   //   if (loginProvider.userNameError == null &&
//   //       loginProvider.passwordError == null) {
//   //     bool isValid =
//   //         await loginProvider.validateCredentials(userName, password);

//   //     if (isValid) {
//   //       var box = await Hive.openBox('deviceData');
//   //       String deviceCode = box.get('deviceCode') ?? '';

//   //       Provider.of<WebSocketService>(context, listen: false)
//   //           .sendDeviceCodeToServer(deviceCode);
//   //       Provider.of<OrderProvider>(context, listen: false)
//   //           .requestDataFromServer();

//   //       // ignore: use_build_context_synchronously
//   //       Navigator.pushAndRemoveUntil(
//   //         context,
//   //         MaterialPageRoute(builder: (context) => const TableScreen()),
//   //         (Route<dynamic> route) => false, // Removes all previous routes
//   //       );
//   //     } else {
//   //       loginProvider.setUserNameError('Invalid username or password');
//   //       loginProvider.setPasswordError('Invalid username or password');
//   //     }
//   //   }
//   // }
//   Future<void> loginUser() async {
//     final loginProvider = Provider.of<LoginProvider>(context, listen: false);
//     loginProvider.setUserNameError("");
//     loginProvider.setPasswordError("");

//     userName = _userNameController.text.trim();
//     final password = _passwordController.text.trim();

//     if (userName.isEmpty) {
//       loginProvider.setUserNameError('Please enter a username');
//     }
//     if (password.isEmpty) {
//       loginProvider.setPasswordError('Please enter a password');
//     }
//     if (serverFound) {
//       final isAlive = await isServerReachable(serverip, 8383);
//       if (isAlive) {
//         proceedToDashboard();
//       } else {
//         print("Server IP exists but not reachable. Discovering again...");
//         await Provider.of<ServerScreen>(context, listen: false)
//             .discoverServerAndHandle(context);
//       }
//     } else {
//       await Provider.of<ServerScreen>(context, listen: false)
//           .discoverServerAndHandle(context);
//     }

//     // Provider.of<OrderProvider>(context, listen: false).requestDataFromServer();
//     // Navigator.pushAndRemoveUntil(
//     //   context,
//     //   MaterialPageRoute(builder: (context) => const DashboardScreen()),
//     //   (Route<dynamic> route) => false, // Removes all previous routes
//     // );
//     // if (loginProvider.userNameError == null &&
//     //     loginProvider.passwordError == null) {
//     //   bool isValid =
//     //       await loginProvider.validateCredentials(userName, password);

//     //   if (isValid) {
//     //     var box = await Hive.openBox('deviceData');
//     //     String deviceCode = box.get('deviceCode') ?? '';

//     //     Provider.of<WebSocketService>(context, listen: false)
//     //         .sendDeviceCodeToServer(deviceCode);
//     //     Provider.of<OrderProvider>(context, listen: false)
//     //         .requestDataFromServer();

//     //     // ignore: use_build_context_synchronously
//     //     Navigator.pushAndRemoveUntil(
//     //       context,
//     //       MaterialPageRoute(builder: (context) => const TableScreen()),
//     //       (Route<dynamic> route) => false, // Removes all previous routes
//     //     );
//     //   } else {
//     //     loginProvider.setUserNameError('Invalid username or password');
//     //     loginProvider.setPasswordError('Invalid username or password');
//     //   }
//     // }
//   }

//   void proceedToDashboard() {
//     Provider.of<OrderProvider>(context, listen: false).requestDataFromServer();

//     Navigator.pushAndRemoveUntil(
//       context,
//       MaterialPageRoute(builder: (context) => const DashboardScreen()),
//       (Route<dynamic> route) => false,
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final loginProvider = Provider.of<LoginProvider>(context);

//     return Scaffold(
//       backgroundColor: const Color(0xFFFAF8F0),
//       body: SingleChildScrollView(
//         child: Padding(
//           padding: const EdgeInsets.only(top: 20.0),
//           child: Column(
//             children: [
//               SizedBox(
//                 width: double.infinity,
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.center,
//                   children: <Widget>[
//                     Image.asset(
//                       'assets/bestmummy.png',
//                       height: 150,
//                       width: 150,
//                     ),
//                     Image.asset(
//                       'assets/kotLogin.png',
//                       height: 280,
//                       width: 280,
//                     ),
//                     const SizedBox(height: 30),
//                     SizedBox(
//                       width: 280,
//                       child: TextFormField(
//                         controller: _userNameController,
//                         decoration: InputDecoration(
//                           filled: true,
//                           fillColor: const Color(0xFFE0F7FA),
//                           labelText: 'Username',
//                           errorText: loginProvider.userNameError,
//                           labelStyle: const TextStyle(
//                             fontSize: 18,
//                             color: Color(0xFF00695C),
//                           ),
//                           border: const OutlineInputBorder(
//                             borderRadius: BorderRadius.all(Radius.circular(12)),
//                             borderSide: BorderSide.none,
//                           ),
//                           prefixIcon: const Icon(
//                             Icons.account_circle,
//                             color: Color(0xFF00695C),
//                           ),
//                           contentPadding: const EdgeInsets.symmetric(
//                             vertical: 20,
//                             horizontal: 20,
//                           ),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(height: 20),
//                     SizedBox(
//                       width: 280,
//                       child: TextFormField(
//                         controller: _passwordController,
//                         decoration: InputDecoration(
//                           filled: true,
//                           fillColor: const Color(0xFFE0F7FA),
//                           labelText: 'Password',
//                           errorText: loginProvider.passwordError,
//                           labelStyle: const TextStyle(
//                             fontSize: 18,
//                             color: Color(0xFF00695C),
//                           ),
//                           border: const OutlineInputBorder(
//                             borderRadius: BorderRadius.all(Radius.circular(12)),
//                             borderSide: BorderSide.none,
//                           ),
//                           prefixIcon: const Icon(
//                             Icons.vpn_key,
//                             color: Color(0xFF00695C),
//                           ),
//                           contentPadding: const EdgeInsets.symmetric(
//                             vertical: 20,
//                             horizontal: 20,
//                           ),
//                         ),
//                         obscureText: true,
//                       ),
//                     ),
//                     const SizedBox(height: 30),
//                     Center(
//                       child: ElevatedButton(
//                         onPressed: () {
//                           //                      Navigator.pushAndRemoveUntil(
//                           //   context,
//                           //   MaterialPageRoute(builder: (context) => TableScreen()),
//                           //   (Route<dynamic> route) => false, // Removes all previous routes
//                           // );
//                           loginUser();
//                         },
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: const Color(0xFFE0F7FA),
//                           foregroundColor: Colors.black,
//                           padding: const EdgeInsets.symmetric(
//                               horizontal: 50, vertical: 15),
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                         ),
//                         child: const Text(
//                           'LogIn',
//                           style: TextStyle(
//                             fontSize: 18,
//                             color: Color(0xFF00695C),
//                           ),
//                         ),
//                       ),
//                     ),
//                     Text(status)
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
