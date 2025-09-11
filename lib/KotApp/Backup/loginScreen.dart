// import 'package:flutter/material.dart';
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

//   @override
//   void initState() {
//     super.initState();
//     Provider.of<LoginProvider>(context, listen: false).fetchAndStoreLoginData();
//     final productProvider =
//         Provider.of<ProductProvider>(context, listen: false);
//     productProvider.fetchTablesAndSaveInHive();
//   }

//   Future<void> loginUser() async {
//     final loginProvider = Provider.of<LoginProvider>(context, listen: false);
//     loginProvider.setUserNameError(null);
//     loginProvider.setPasswordError(null);

//     userName = _userNameController.text.trim();
//     final password = _passwordController.text.trim();

//     if (userName.isEmpty) {
//       loginProvider.setUserNameError('Please enter a username');
//     }
//     if (password.isEmpty) {
//       loginProvider.setPasswordError('Please enter a password');
//     }
//     Provider.of<OrderProvider>(context, listen: false).requestDataFromServer();
//     Navigator.pushAndRemoveUntil(
//       context,
//       MaterialPageRoute(builder: (context) => const DashboardScreen()),
//       (Route<dynamic> route) => false, // Removes all previous routes
//     );
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
