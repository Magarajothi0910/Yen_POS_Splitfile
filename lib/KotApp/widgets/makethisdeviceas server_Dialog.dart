import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/globals.dart';

// /// A reusable “no server found” dialog that asks the user
// /// if they want to promote the current device to server.
class NoServerDialog extends StatelessWidget {
  /// Called when the user taps “Make This Device Server”
  final Future<void> Function() onMakeServer;

  const NoServerDialog({Key? key, required this.onMakeServer})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('No Server Found'),
      content: const Text(
        'No server was detected on the network. '
        'Server is not running – make this device the server?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.of(context).pop();
            await onMakeServer();
          },
          child: const Text('Make This Device Server'),
        ),
      ],
    );
  }
}

// class NoServerDialog extends StatefulWidget {
//   /// Called **after** approval is granted.
//   final Future<void> Function() onMakeServer;

//   const NoServerDialog({
//     Key? key,
//     required this.onMakeServer,
//   }) : super(key: key);

//   @override
//   _NoServerDialogState createState() => _NoServerDialogState();
// }

// class _NoServerDialogState extends State<NoServerDialog> {
//   bool _isWaiting = false;
//   Timer? _pollTimer;
//   String? _approvalId;

//   @override
//   void dispose() {
//     _pollTimer?.cancel();
//     super.dispose();
//   }

//   Future<String> _fetchDeviceInfo() async {
//     final os = Platform.operatingSystem;
//     final version = Platform.operatingSystemVersion;
//     final name = Platform.localHostname;
//     return '$name ($os $version)';
//   }

//   Future<void> _sendApprovalRequest() async {
//     setState(() => _isWaiting = true);
//     print("sendApproval request....");

//     final branchAlias = aliasname; // your global alias
//     final deviceInfo = await _fetchDeviceInfo();
//     print("sendApproval request1....");

//     final uri = Uri.parse('http://192.168.29.10:8888/kotserverapproval/');
//     print("sendApproval request2....");

//     final resp = await http.post(
//       uri,
//       headers: {'Content-Type': 'application/json'},
//       body: jsonEncode({
//         'locationName': branchAlias,
//         'deviceInfo': deviceInfo,
//       }),
//     );
//     print("sendApproval request3....");

//     if (resp.statusCode == 200 || resp.statusCode == 201) {
//       print("sendApproval request4....");

//       // handle success (e.g. navigate or start polling)
//       await widget.onMakeServer();
//     } else {
//       debugPrint('Approval request failed: ${resp.statusCode}');
//       setState(() => _isWaiting = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return AlertDialog(
//       title: const Text('No Server Found'),
//       content: const Text(
//         'No server detected.\n'
//         'Send approval request to become server?',
//       ),
//       actions: [
//         TextButton(
//           onPressed: _isWaiting ? null : () => Navigator.of(context).pop(),
//           child: const Text('Cancel'),
//         ),
//         TextButton(
//           onPressed: _isWaiting ? null : _sendApprovalRequest,
//           child: Text(
//             _isWaiting ? 'Waiting for approval…' : 'Make This Device Server',
//           ),
//         ),
//       ],
//     );
//   }
// }
