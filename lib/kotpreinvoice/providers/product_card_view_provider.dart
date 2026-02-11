import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class ProductCardViewProvider extends ChangeNotifier {
  String _customerPhoneNumber = "";
  String? _selectedEmployee;
  String? _storedDeviceId;
  final TextEditingController _mobileController = TextEditingController();

  String get customerPhoneNumber => _customerPhoneNumber;
  String? get selectedEmployee => _selectedEmployee;
  String? get storedDeviceId => _storedDeviceId;
  TextEditingController get mobileController => _mobileController;

  /// Load device code from Hive box
  Future<void> loadDeviceCode() async {
    try {
      var box = Hive.box('deviceData');
      _storedDeviceId = box.get('deviceCode');

      debugPrint("📱 Device code loaded: $_storedDeviceId");
      notifyListeners();
    } catch (e, st) {
      debugPrint("❌ Error loading device code: $e\n$st");
    }
  }

  /// Set customer phone number
  void setCustomerPhoneNumber(String phoneNumber) {
    try {
      _customerPhoneNumber = phoneNumber;
      _mobileController.text = phoneNumber; // Sync with controller

      debugPrint("📞 Customer phone updated: $phoneNumber");
      notifyListeners();
    } catch (e, st) {
      debugPrint("🔥 Error setting phone number: $e\n$st");
    }
  }

  /// Select employee
  void setSelectedEmployee(String? employee) {
    try {
      _selectedEmployee = employee;

      debugPrint("👨‍💼 Employee selected: $employee");
      notifyListeners();
    } catch (e, st) {
      debugPrint("🔥 Error setting selected employee: $e\n$st");
    }
  }

  @override
  void dispose() {
    try {
      _mobileController.dispose();
      debugPrint("🧹 Mobile controller disposed successfully");
    } catch (e, st) {
      debugPrint("⚠️ Error disposing mobile controller: $e\n$st");
    }
    super.dispose();
  }
}
