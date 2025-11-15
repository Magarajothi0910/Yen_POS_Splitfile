// import 'package:flutter/material.dart';
// import 'package:hive_flutter/hive_flutter.dart';
// import 'package:dio/dio.dart';
// import 'dart:convert';

// import '../models/employee.dart';

// class EmployeeProviderDine with ChangeNotifier {
//   List<Employee> _employees = [];
//   List<Employee> get employees => _employees;
//   String? _selectedWaiter;

//   String? get selectedWaiter => _selectedWaiter;

//   EmployeeProvider() {
//     _init();
//   }

//   Future<void> _init() async {
//     Hive.box('employeeData');
//     loadEmployeesFromHive();
//   }

//   void setSelectedWaiter(String waiter) {
//     _selectedWaiter = waiter;
//     notifyListeners();
//   }

//   Future<void> fetchAndStoreEmployees() async {
//     final dio = Dio();
//     const url = 'https://yenerp.com/masterapi/employees/';
//     try {
//       final response = await dio.get(url);
//       if (response.statusCode == 200) {
//         List<dynamic> employeesData = response.data;

//         // Filter employees who have the position "Sales"
//         _employees = employeesData.where((data) {
//           return data['position'] == 'Sales';
//         }).map((data) {
//           return Employee(
//             employeeNumber: data['employeeNumber'],
//             firstName: data['firstName'],
//             lastName: data['lastname'],
//             position: data['position'],
//           );
//         }).toList();

//         // Store data in Hive (only "Sales" employees)
//         var box = Hive.box('employeeData');
//         await box.clear(); // Clear previous data to avoid duplicates
//         for (var employee in _employees) {
//           box.put(employee.employeeNumber, employee.toJson());
//         }

//         notifyListeners();
//       } else {
//         print('Failed to fetch employee data: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error fetching employee data: $e');
//     }
//   }

//   void loadEmployeesFromHive() {
//     var box = Hive.box('employeeData');
//     _employees = box.values.map((employeeData) {
//       return Employee.fromJson(Map<String, dynamic>.from(employeeData));
//     }).toList();
//     notifyListeners();
//   }

//   List<Employee> searchEmployees(String query) {
//     return _employees.where((employee) => employee.firstName.toLowerCase().contains(query.toLowerCase()) || (employee.lastName?.toLowerCase().contains(query.toLowerCase()) ?? false)).toList();
//   }
// }
