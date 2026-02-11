// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../background_Task/background_permission_guard.dart';
// import '../background_Task/flutter_foreground_task.dart';
// import '../providers/login_provider.dart';

// class LoginUI extends StatelessWidget {
//   final TextEditingController userNameController;
//   final TextEditingController passwordController;
//   final VoidCallback onLogin;
//   final String serverStatus;
//   final String? errorMessage;

//   const LoginUI({
//     Key? key,
//     required this.userNameController,
//     required this.passwordController,
//     required this.onLogin,
//     required this.serverStatus,
//     this.errorMessage,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     final loginProvider = Provider.of<LoginProviderDine>(context);

//     WidgetsBinding.instance.addPostFrameCallback((_) async {
//       try {
//         if (Platform.isAndroid) {
//           print("📱 Android detected. Preparing background permissions...");
//           await BackgroundPermissionGuard.askIfNeeded(context);

//           print("🛠️ Initializing Foreground Service...");
//           await ForegroundHelper.init();
//         } else {
//           print("ℹ️ Foreground service skipped on ${Platform.operatingSystem}");
//         }
//       } catch (e, stack) {
//         print("❌ Error during LoginUI startup: $e");
//         print("🪲 Stacktrace: $stack");
//       }
//     });

//     return Scaffold(
//       backgroundColor: const Color(0xFFE3F2FD), // Light blue background
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
//                     // 🖼️ App Logo
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
//                     const SizedBox(height: 20),

//                     // 📡 Server Status
//                     Text(
//                       serverStatus,
//                       style: const TextStyle(
//                         fontSize: 16,
//                         color: Colors.blue, // Changed to blue
//                         fontWeight: FontWeight.w500,
//                       ),
//                       textAlign: TextAlign.center,
//                     ),
//                     const SizedBox(height: 10),

//                     // ❌ Error Message
//                     if (errorMessage != null)
//                       Padding(
//                         padding: const EdgeInsets.symmetric(horizontal: 20.0),
//                         child: Text(
//                           errorMessage!,
//                           style: const TextStyle(
//                             fontSize: 14,
//                             color: Colors.red, // Kept red for errors
//                             fontWeight: FontWeight.w400,
//                           ),
//                           textAlign: TextAlign.center,
//                         ),
//                       ),
//                     if (errorMessage != null) const SizedBox(height: 10),

//                     // 👤 Username Field
//                     SizedBox(
//                       width: 280,
//                       child: TextFormField(
//                         controller: userNameController,
//                         decoration: InputDecoration(
//                           filled: true,
//                           fillColor: const Color(0xFFBBDEFB), // Light blue fill
//                           labelText: 'Username',
//                           errorText: loginProvider.userNameError,
//                           labelStyle: const TextStyle(
//                             fontSize: 18,
//                             color: Colors.blue, // Changed to blue
//                           ),
//                           border: const OutlineInputBorder(
//                             borderRadius: BorderRadius.all(Radius.circular(12)),
//                             borderSide: BorderSide.none,
//                           ),
//                           prefixIcon: const Icon(
//                             Icons.account_circle,
//                             color: Colors.blue, // Changed to blue
//                           ),
//                           contentPadding: const EdgeInsets.symmetric(
//                             vertical: 20,
//                             horizontal: 20,
//                           ),
//                         ),
//                         onChanged: (value) {
//                           print("⌨️ Username typed: $value");
//                         },
//                       ),
//                     ),
//                     const SizedBox(height: 20),

//                     // 🔑 Password Field
//                     SizedBox(
//                       width: 280,
//                       child: TextFormField(
//                         controller: passwordController,
//                         decoration: InputDecoration(
//                           filled: true,
//                           fillColor: const Color(0xFFBBDEFB), // Light blue fill
//                           labelText: 'Password',
//                           errorText: loginProvider.passwordError,
//                           labelStyle: const TextStyle(
//                             fontSize: 18,
//                             color: Colors.blue, // Changed to blue
//                           ),
//                           border: const OutlineInputBorder(
//                             borderRadius: BorderRadius.all(Radius.circular(12)),
//                             borderSide: BorderSide.none,
//                           ),
//                           prefixIcon: const Icon(
//                             Icons.vpn_key,
//                             color: Colors.blue, // Changed to blue
//                           ),
//                           contentPadding: const EdgeInsets.symmetric(
//                             vertical: 20,
//                             horizontal: 20,
//                           ),
//                         ),
//                         obscureText: true,
//                         onChanged: (_) {
//                           print("🔒 Password field updated.");
//                         },
//                       ),
//                     ),
//                     const SizedBox(height: 30),

//                     // 🔘 Login Button
//                     Center(
//                       child: ElevatedButton(
//                         onPressed: () {
//                           try {
//                             print("🔘 Login button pressed.");
//                             onLogin();
//                           } catch (e, stack) {
//                             print("❌ Error during login: $e");
//                             print("🪲 Stacktrace: $stack");
//                           }
//                         },
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: const Color(0xFFBBDEFB), // Light blue background
//                           foregroundColor: Colors.black,
//                           elevation: 2,
//                           padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                         ),
//                         child: const Text(
//                           'LogIn',
//                           style: TextStyle(
//                             fontSize: 18,
//                             color: Colors.blue, // Changed to blue
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
