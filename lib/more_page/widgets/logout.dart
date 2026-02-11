import 'package:flutter/material.dart';
import 'package:yen_pos/Server_Client/serverScreen.dart';

class LogoutScreen extends StatelessWidget {
  const LogoutScreen({super.key});

  void _navigateToLogin(BuildContext context) {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton.icon(
        icon: const Icon(Icons.logout),
        label: const Text('Log Out'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
        onPressed: () {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              title: const Text(
                "Log Out",
                style: TextStyle(fontFamily: 'Poppins', color: Colors.blue),
              ),
              content: const Text(
                "Are you sure you want to log out?",
                style: TextStyle(fontFamily: 'Poppins', color: Colors.black),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _navigateToLogin(context);
                  },
                  child: const Text('Log Out'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
