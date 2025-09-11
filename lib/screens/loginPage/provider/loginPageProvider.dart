import 'package:flutter/material.dart';

import '../../choose_mode/choose_mode_screen.dart';

class LoginProviderpos with ChangeNotifier {
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  String _selectedBranch = '';
  bool _isSigningIn = false;
  final GlobalKey keyboardKey = GlobalKey();
  String get selectedBranch => _selectedBranch;
  set selectedBranch(String value) {
    _selectedBranch = value;
    notifyListeners();
  }

  bool get isSigningIn => _isSigningIn;

  Future<void> signIn(BuildContext context) async {
    if (_selectedBranch.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Please select a branch before logging in."),
        backgroundColor: Colors.red,
      ));
      return;
    }

    _isSigningIn = true;
    notifyListeners();

    // Simulate a network request or database call
    await Future.delayed(const Duration(seconds: 2));

    // Assuming signIn success
    _isSigningIn = false;
    notifyListeners();

    // Navigate to the next page
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ChooseModePage(
          keyboardKey: keyboardKey,
        ),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
