import 'package:flutter/material.dart';

/// A reusable “no server found” dialog that asks the user
/// if they want to promote the current device to server.
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
