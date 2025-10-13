import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../models/employee.dart';

class EmployeeProvider with ChangeNotifier {
  List<Employee> _employees = [];
  List<Employee> get employees => _employees;
  String? _selectedWaiter;

  String? get selectedWaiter => _selectedWaiter;

  EmployeeProvider() {
    _init();
  }

  Future<void> _init() async {
    await Hive.openBox('employeeData');
    loadEmployeesFromHive();
  }

  void setSelectedWaiter(String waiter) {
    _selectedWaiter = waiter;
    notifyListeners();
  }

  Future<void> fetchAndStoreEmployees() async {
    const url = 'https://yenerp.com/fastapi/employees/';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        List<dynamic> employeesData = json.decode(response.body);

        // Filter employees who have the position "Sales"
        _employees = employeesData.where((data) {
          return data['position'] == 'Sales';
        }).map((data) {
          return Employee(
            employeeNumber: data['employeeNumber'],
            firstName: data['firstName'],
            lastName: data['lastname'],
            position: data['position'],
          );
        }).toList();

        // Store data in Hive (only "Sales" employees)
        var box = Hive.box('employeeData');
        await box.clear(); // Clear previous data to avoid duplicates
        for (var employee in _employees) {
          box.put(employee.employeeNumber, employee.toJson());
        }

        notifyListeners();
      } else {}
    } catch (e) {}
  }

  void loadEmployeesFromHive() {
    var box = Hive.box('employeeData');
    _employees = box.values.map((employeeData) {
      return Employee.fromJson(Map<String, dynamic>.from(employeeData));
    }).toList();
    notifyListeners();
  }

  List<Employee> searchEmployees(String query) {
    return _employees
        .where((employee) =>
            employee.firstName.toLowerCase().contains(query.toLowerCase()) ||
            (employee.lastName?.toLowerCase().contains(query.toLowerCase()) ??
                false))
        .toList();
  }
}
