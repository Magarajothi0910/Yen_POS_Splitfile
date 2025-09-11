import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart'; // Import for date formatting

class HoldOrderProvider with ChangeNotifier {
  final Box _holdOrdersBox = Hive.box('holdOrders');

  HoldOrderProvider() {
    _cleanOldOrders(); // Remove outdated orders on initialization
  }

  // Get today's date in dd-MM-yyyy format
  String get _todayDate => DateFormat('dd-MM-yyyy').format(DateTime.now());

  // Save the current cart to hold orders with date
  void saveHoldOrder(
      String tableNumber, String seat, Map<String, dynamic> cart) {
    final key = '${tableNumber}_$seat';
    final orderData = {
      'date': _todayDate, // Store order date in dd-MM-yyyy format
      'cart': cart,
    };
    _holdOrdersBox.put(key, orderData);
   
    notifyListeners();
  }

  // Retrieve hold order for a specific table and seat (only if it's today's order)
  Map<String, dynamic>? loadHoldOrder(String tableNumber, String seat) {
    final key = '${tableNumber}_$seat';
    if (_holdOrdersBox.containsKey(key)) {
      final orderData = _holdOrdersBox.get(key);
      if (orderData['date'] == _todayDate) {
        return Map<String, dynamic>.from(orderData['cart']);
      } else {
        _holdOrdersBox.delete(key); // Remove old order
      }
    }
    return null;
  }

  // Remove hold order after submission or when cleared
  void removeHoldOrder(String tableNumber, String seat) {
    final key = '${tableNumber}_$seat';
    if (_holdOrdersBox.containsKey(key)) {
      _holdOrdersBox.delete(key);
      
      notifyListeners();
    }
  }

  // Check if a hold order exists for the current date
  bool hasHoldOrder(String tableNumber, String seat) {
    final key = '${tableNumber}_$seat';
    if (_holdOrdersBox.containsKey(key)) {
      final orderData = _holdOrdersBox.get(key);
      return orderData['date'] == _todayDate;
    }
    return false;
  }

  // Get all hold orders for the current date
  List<Map<String, dynamic>> getAllHoldOrders() {
    return _holdOrdersBox.keys.where((key) {
      final orderData = _holdOrdersBox.get(key);
      return orderData['date'] == _todayDate;
    }).map((key) {
      final tableSeat = key.split('_');
      return {
        'table': tableSeat[0],
        'seat': tableSeat[1],
        'cart': _holdOrdersBox.get(key)['cart'],
      };
    }).toList();
  }

  // Delete all old orders that are not from the current date
  void _cleanOldOrders() {
    final keysToRemove = _holdOrdersBox.keys.where((key) {
      final orderData = _holdOrdersBox.get(key);
      return orderData['date'] != _todayDate; // Remove if date is old
    }).toList();

    for (var key in keysToRemove) {
      _holdOrdersBox.delete(key);
    }
  }
}
