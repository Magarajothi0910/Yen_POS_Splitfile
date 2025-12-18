import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'package:yenpos/Global/globals_data.dart' as globals;
import 'package:yenpos/Mode_page/choose_mode_screen.dart';

class LoginProvider with ChangeNotifier {
  final TextEditingController userNameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();


  bool _isSigningIn = false;
  String? _authToken;
  String? _loggedInUserName;
  String? userNameError;
  String? passwordError;

  bool get isSigningIn => _isSigningIn;
  String? get authToken => _authToken;
  String? get loggedInUserName => _loggedInUserName;

  /// 🔹 Main login method (FastAPI JWT)
  /// 🔹 Updated login method returning bool
  Future<bool> loginUser(BuildContext context) async {
    setUserNameError(null);
    setPasswordError(null);

    final username = userNameController.text.trim();
    final password = passwordController.text.trim();

    if (username.isEmpty) {
      setUserNameError('Please enter a username');
      return false;
    }
    if (password.isEmpty) {
      setPasswordError('Please enter a password');
      return false;
    }

    _isSigningIn = true;
    notifyListeners();

    final url = Uri.parse('https://yenerp.com/fastapi/logins/');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"username": username, "password": password}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final token = responseData['access_token'];

        if (token != null) {
          _authToken = token;
          _loggedInUserName = username;

          var box = await Hive.openBox('authBox');
          await box.put('token', token);
          await box.put('username', username);
          globals.userName = username;
          globals.password = password;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Login successful!"),
              backgroundColor: Colors.green,
            ),
          );

          _isSigningIn = false;
          notifyListeners();
          return true; // ✅ Login succeeded
        }
      } else if (response.statusCode == 401) {
        _showError(context, "Invalid username or password.");
      } else {
        _showError(context, "Login failed. (${response.statusCode})");
      }
    } catch (error) {
      _showError(context, "Network error: $error");
    }

    _isSigningIn = false;
    notifyListeners();
    return false; // ❌ Login failed
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void setUserNameError(String? message) {
    userNameError = message;
    notifyListeners();
  }

  void setPasswordError(String? message) {
    passwordError = message;
    notifyListeners();
  }

  Future<void> loadSavedAuth() async {
    var box = await Hive.openBox('authBox');
    _authToken = box.get('token');
    _loggedInUserName = box.get('username');
    notifyListeners();
  }

  @override
  void dispose() {
    userNameController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
