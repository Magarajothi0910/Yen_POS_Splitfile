import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

class LoginProvider with ChangeNotifier {
  String? userNameError;
  String? passwordError;
  String? _loggedInUserName; // To store the logged-in username

  String? get loggedInUserName => _loggedInUserName;

  Future<List<Map<String, dynamic>>> fetchUsersFromApi() async {
    const String apiUrl = 'https://yenerp.com/liveapi/logins';
    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(
            data.map((item) => Map<String, dynamic>.from(item)));
      } else {
        return [];
      }
    } catch (error) {
      return [];
    }
  }

  Future<void> fetchAndStoreLoginData() async {
    final usersFromApi = await fetchUsersFromApi();

    if (usersFromApi.isNotEmpty) {
      var loginBox = await Hive.openBox('loginBox');
      await loginBox.clear();
      await loginBox.put('users', usersFromApi);
    }
  }

  Future<bool> validateCredentials(String userName, String password) async {
    var loginBox = await Hive.openBox('loginBox');
    List<dynamic>? users = loginBox.get('users');

    if (users != null) {
      for (var user in users) {
        if (user['userName'] == userName && user['password'] == password) {
          _loggedInUserName = userName; // Store the logged-in username

          return true;
        }
      }
    }
    return false;
  }

  void setUserNameError(String? message) {
    userNameError = message;
    notifyListeners();
  }

  void setPasswordError(String? message) {
    passwordError = message;
    notifyListeners();
  }
}
