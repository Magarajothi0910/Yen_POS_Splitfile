// import 'package:flutter/material.dart';
// import 'package:hive/hive.dart';
// import '../modelss/printer.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yen_pos/printer_screen/model/printer_model.dart';

class PrinterProvider with ChangeNotifier {
  late Box _printerBox;
  List<Printer> _printers = [];
  List<Printer> get printers => _printers;
  String? _clientIp;
  WebSocketChannel? _ws;

  String? get clientIp => _clientIp;
  Future<void> initializeHive() async {
    try {
      _printerBox = await Hive.openBox('printers');
      _clientIp = _printerBox.get('clientIp');

      _loadPrintersFromHive();
    } catch (e) {}
  }

  void _loadPrintersFromHive() {
    try {
      final data = _printerBox.get('data');

      if (data != null && data is List) {
        _printers = data
            .map((json) {
              if (json is Map) {
                final map = Map<String, dynamic>.from(json);
                return Printer.fromJson(map);
              } else {
                return null;
              }
            })
            .whereType<Printer>()
            .toList();

        notifyListeners();
      } else {}
    } catch (e) {}
  }

  void addPrinter(Printer printer) {
    // Find if a printer with the same name already exists
    final existingPrinterIndex = _printers.indexWhere(
      (p) => p.name == printer.name,
    );

    if (existingPrinterIndex != -1) {
      // Update existing printer's properties

      _printers[existingPrinterIndex] = Printer(
        name: printer.name,
        ipAddress: printer.ipAddress,
        type: printer.type,
        items: printer.items,
      );
    } else {
      // Add new printer

      _printers.add(
        Printer(
          name: printer.name,
          ipAddress: printer.ipAddress,
          type: printer.type,
          items: printer.items,
        ),
      );
    }

    // Save the updated printers list to Hive
    _savePrintersToHive();
  }

  String? getPreInvoicePrinterIp() {
    try {
      return _printers
          .firstWhere((printer) => printer.type == 'PreInvoice')
          .ipAddress;
    } catch (e) {
      // Handle the case when no printer is found
      return null;
    }
  }

  String? getInvoicePrinterIp() {
    try {
      return _printers
          .firstWhere((printer) => printer.type == 'Invoice')
          .ipAddress;
    } catch (e) {
      // Handle the case when no printer is found
      return null;
    }
  }

  void updatePrinter(Printer updatedPrinter) {
    final index = _printers.indexWhere(
      (printer) => printer.name == updatedPrinter.name,
    );
    if (index != -1) {
      _printers[index] = updatedPrinter;
      _savePrintersToHive(); // Save updated printers to Hive storage
      notifyListeners(); // Notify listeners to update UI
    }
  }

  void removePrinter(var index) {
    _printers.removeAt(index);
    _savePrintersToHive();
  }

  void removePrinterByName(String printerName) {
    final index = _printers.indexWhere(
      (printer) => printer.name == printerName,
    );
    if (index != -1) {
      _printers.removeAt(index);
      _savePrintersToHive();
      notifyListeners();
    }
  }

  void _savePrintersToHive() {
    final data = _printers.map((printer) => printer.toJson()).toList();
    _printerBox.put('data', data);
    notifyListeners();
  }

  String? getPrinterIpForItem(String itemName) {
    itemName = itemName.trim().toLowerCase(); // Normalize the item name
    for (final printer in _printers) {
      for (final item in printer.items) {
        if (item.trim().toLowerCase() == itemName) {
          return printer.ipAddress;
        }
      }
    }
    return null;
  }

  String? getOverallPrinterIp() {
    for (var printer in _printers) {
      if (printer.type == 'Overall') {
        return printer.ipAddress;
      }
    }
    return null;
  }

  bool isItemAssignedToOtherPrinter(String itemId, String currentPrinterName) {
    for (final printer in _printers) {
      if (printer.name != currentPrinterName &&
          printer.items.contains(itemId)) {
        return true;
      }
    }
    return false;
  }
}
