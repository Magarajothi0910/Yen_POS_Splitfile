// import 'package:flutter/material.dart';
// import 'package:hive/hive.dart';
// import 'package:dio/dio.dart';
// import 'package:yenpos/Global/globals_data.dart';

// class LoginProviderDine with ChangeNotifier {
//   String? userNameError;
//   String? passwordError;
//   String? _loggedInUserName; // To store the logged-in username

//   String? get loggedInUserName => _loggedInUserName;

//   Future<List<Map<String, dynamic>>> fetchUsersFromApi() async {
//     final dio = Dio();
//     const String apiUrl = 'https://yenerp.com/masterapi/logins';
//     try {
//       final response = await dio.get(apiUrl);

//       if (response.statusCode == 200) {
//         List<dynamic> data = response.data;
//         return List<Map<String, dynamic>>.from(data.map((item) => Map<String, dynamic>.from(item)));
//       } else {
//         print('Failed to load users. Status code: ${response.statusCode}');
//         return [];
//       }
//     } catch (error) {
//       print('Error fetching users from API: $error');
//       return [];
//     }
//   }

//   Future<void> fetchAndStoreLoginData() async {
//     final usersFromApi = await fetchUsersFromApi();

//     if (usersFromApi.isNotEmpty) {
//       var loginBox = Hive.box('loginBox');
//       await loginBox.clear();
//       await loginBox.put('users', usersFromApi);
//     }
//   }

//   Future<bool> validateCredentials(String userName, String password) async {
//     var loginBox = await Hive.openBox('loginBox');
//     List<dynamic>? users = loginBox.get('users');

//     if (users != null) {
//       for (var user in users) {
//         if (user['userName'] == userName && user['password'] == password) {
//           _loggedInUserName = userName; // Store the logged-in username
//           createdBy = user['firstName'];
//           return true;
//         }
//       }
//     }
//     return false;
//   }

//   // Future<LoginStatus> validateCredentials(
//   //     String userName, String password) async {
//   //   var loginBox = await Hive.openBox('loginBox');
//   //   List<dynamic>? users = loginBox.get('users');

//   //   if (users != null) {
//   //     for (var user in users) {
//   //       if (user['userName'] == userName && user['password'] == password) {
//   //         if (user['status'] == "1") {
//   //           _loggedInUserName = userName;
//   //           return LoginStatus.success;
//   //         } else {

//   //           return LoginStatus.inactive;
//   //         }
//   //       }
//   //     }
//   //   }

//   //   return LoginStatus.invalid;
//   // }

//   void setUserNameError(String? message) {
//     userNameError = message;
//     notifyListeners();
//   }

//   void setPasswordError(String? message) {
//     passwordError = message;
//     notifyListeners();
//   }
// }
