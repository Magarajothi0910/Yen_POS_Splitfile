// import 'package:flutter/material.dart';
// import 'package:bonsoir/bonsoir.dart';
// import 'package:hive_flutter/hive_flutter.dart';
// import '../../../../screens/kot_screen/global/globals.dart';
// import '../../../models/globals.dart';
// import '../../loginScreen.dart';
// import '../../serverScreen.dart';

// class RoleSelectionScreen extends StatefulWidget {
//   @override
//   _RoleSelectionScreenState createState() => _RoleSelectionScreenState();
// }

// class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
//   bool _serverFound = false;
//   BonsoirDiscovery? _discovery;

//   @override
//   void initState() {
//     super.initState();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Select Mode")),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             ElevatedButton(
//               onPressed: _serverFound
//                   ? null
//                   : () {
//                       appType = "Server";
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(builder: (_) => LoginScreen()),
//                       );
//                     },
//               child: const Text("Run as server"),
//             ),
//             ElevatedButton(
//               onPressed: _serverFound
//                   ? null
//                   : () {
//                       appType = "Server";
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(builder: (_) => LoginScreen()),
//                       );
//                     },
//               child: const Text("Run as client"),
//             ),
//             const SizedBox(height: 20),
//             if (_serverFound) CircularProgressIndicator(),
//             if (_serverFound)
//               const Padding(
//                 padding: EdgeInsets.only(top: 12),
//                 child: Text("Server found. Redirecting..."),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }
