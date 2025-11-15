// import 'package:flutter/material.dart';
// import 'package:pin_code_fields/pin_code_fields.dart';
// import 'package:provider/provider.dart';
// import 'package:hive/hive.dart';
// import '../components/flushbar.dart';
// import 'package:yenpos/Global/globals_data.dart';
// import '../providers/deviceProvider.dart';
// import '../providers/product_provider.dart';
// import '../providers/install_provider.dart';
// import '../screens/serverScreen.dart';

// class InstallKOTApp extends StatefulWidget {
//   const InstallKOTApp({super.key});
//   @override
//   State<InstallKOTApp> createState() => _InstallKOTAppState();
// }

// class _InstallKOTAppState extends State<InstallKOTApp> {
//   late DeviceProviderDine deviceProvider;
//   late ProductProvider productProvider;
//   late InstallProvider installProvider;
//   @override
//   void initState() {
//     super.initState();

//     checkForStoredDeviceCode();
//   }

//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();
//     deviceProvider = Provider.of<DeviceProviderDine>(context, listen: false);
//     productProvider = Provider.of<ProductProvider>(context, listen: false);
//     installProvider = Provider.of<InstallProvider>(context, listen: false);
//   }

//   Future<void> checkForStoredDeviceCode() async {
//     var box = Hive.box('deviceData');
//     final storedDeviceCode = box.get('deviceCode')?.toString();
//     if (storedDeviceCode == null || storedDeviceCode.isEmpty) {
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         if (mounted) showDeviceCodeDialog();
//       });
//     }
//   }

//   Future<void> showDeviceCodeDialog() async {
//     final installProv = Provider.of<InstallProvider>(context, listen: false);
//     final deviceCodeController = TextEditingController();
//     return showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (dialogContext) => Consumer<InstallProvider>(
//         builder: (context, state, _) => AlertDialog(
//           backgroundColor: Colors.white,
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//           title: const Text(
//             'Enter Device Code',
//             style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
//           ),
//           content: SingleChildScrollView(
//             child: SizedBox(
//               width: MediaQuery.of(context).size.width * 0.8,
//               child: PinCodeTextField(
//                 appContext: context,
//                 length: 12,
//                 obscureText: false,
//                 animationType: AnimationType.fade,
//                 pinTheme: PinTheme(
//                   shape: PinCodeFieldShape.box,
//                   borderRadius: BorderRadius.circular(4),
//                   fieldHeight: MediaQuery.of(context).size.width > 600 ? 50 : 40,
//                   fieldWidth: MediaQuery.of(context).size.width > 600 ? 50 : 19,
//                   activeFillColor: Colors.white,
//                   selectedFillColor: Colors.grey.shade200,
//                   inactiveFillColor: Colors.grey.shade300,
//                 ),
//                 animationDuration: const Duration(milliseconds: 300),
//                 backgroundColor: Colors.transparent,
//                 enableActiveFill: true,
//                 controller: deviceCodeController,
//                 autoDismissKeyboard: true,
//                 onChanged: (value) {},
//               ),
//             ),
//           ),
//           actions: [
//             ElevatedButton(
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.blue,
//                 foregroundColor: Colors.white,
//                 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//               ),
//               onPressed: state.isSubmitting
//                   ? null
//                   : () async {
//                       installProv.setSubmitting(true);
//                       installProv.setLoading(true);
//                       final code = deviceCodeController.text.trim();
//                       if (code.isEmpty || code.length != 12) {
//                         showCustomFlushbar(
//                           context,
//                           'Please enter a valid 12-digit device code.',
//                           type: FlushbarType.warning,
//                         );
//                         installProv.resetStates();
//                         return;
//                       }
//                       try {
//                         await deviceProvider.fetchDeviceData(code);
//                         installProv.setLoading(false);
//                         if (deviceProvider.deviceData != null) {
//                           Navigator.of(context).pop();
//                           showConfirmationDialog(deviceProvider.deviceData!['branchName']);
//                         } else {
//                           showCustomFlushbar(
//                             context,
//                             "Device not found or expired.",
//                             type: FlushbarType.error,
//                           );
//                           installProv.setSubmitting(false);
//                         }
//                       } catch (e) {
//                         showCustomFlushbar(
//                           context,
//                           "Error fetching device data: $e",
//                           type: FlushbarType.error,
//                         );
//                         installProv.resetStates();
//                       }
//                     },
//               child: const Text('Submit'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> showConfirmationDialog(String branch) async {
//     final installProv = Provider.of<InstallProvider>(context, listen: false);
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) => Consumer<InstallProvider>(
//         builder: (context, state, _) => AlertDialog(
//           backgroundColor: Colors.white,
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//           title: const Text(
//             'Branch Confirmation',
//             style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
//           ),
//           content: Text(
//             'Are you part of the corresponding branch: $branch?',
//             style: const TextStyle(color: Colors.black87),
//           ),
//           actions: [
//             TextButton(
//               onPressed: state.isConfirming
//                   ? null
//                   : () async {
//                       installProv.setConfirming(true);
//                       try {
//                         final box = Hive.box('deviceData');
//                         aliasname = deviceProvider.deviceData!['branchName'];
//                         // aliasname = 'AR';
//                         await box.put('aliasName', aliasname);
//                         await box.put('branchName', aliasname);
//                         await deviceProvider.storeDeviceData(
//                           deviceProvider.deviceData!['deviceCode'],
//                           aliasname,
//                           deviceProvider.deviceData!['deviceCodeId'],
//                         );
//                         await deviceProvider.patchDeviceStatus(
//                           deviceProvider.deviceData!['deviceCodeId'],
//                         );
//                         await productProvider.loadTablesFromHive();
//                         Navigator.of(context).pop();
//                       } catch (e) {
//                         showCustomFlushbar(
//                           context,
//                           "Error updating device status: $e",
//                           type: FlushbarType.error,
//                         );
//                       } finally {
//                         installProv.resetStates();
//                       }
//                     },
//               style: TextButton.styleFrom(foregroundColor: Colors.blue),
//               child: const Text('Yes'),
//             ),
//             TextButton(
//               style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
//               onPressed: () {
//                 Navigator.of(context).pop();
//                 showErrorDialog("Branch mismatch. Please enter the correct device code.").then((_) => showDeviceCodeDialog());
//                 installProv.resetStates();
//               },
//               child: const Text('No'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> showErrorDialog(String message) async {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) => AlertDialog(
//         backgroundColor: Colors.white,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//         title: const Text(
//           'Error',
//           style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
//         ),
//         content: Text(message, style: const TextStyle(color: Colors.black87)),
//         actions: [
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.blue,
//               foregroundColor: Colors.white,
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//             ),
//             onPressed: () {
//               Navigator.of(context).pop();
//               showDeviceCodeDialog();
//             },
//             child: const Text('OK'),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Consumer<InstallProvider>(
//       builder: (context, state, _) => Stack(
//         children: [
//           const LoginScreen(),
//           if (state.isLoading)
//             Container(
//               color: Colors.black45,
//               child: const Center(
//                 child: CircularProgressIndicator(
//                   valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }
