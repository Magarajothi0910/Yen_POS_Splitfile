import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../model/printer_model.dart';

class PrinterProviderpos with ChangeNotifier {
  late Box? _printerBox;
  List<Printer> _printers = [];
  List<Printer> get printers =>
      _printers.where((printer) => printer.status).toList();
  Map<String, String> deviceIps = {}; // Map to hold device ID and assigned IP
  String? _clientIp;

  String? get clientIp => _clientIp;
  Future<void> initializeHive() async {
    try {
      _printerBox = await Hive.openBox('printers');
      _clientIp = _printerBox!.get('clientIp');

      _loadPrintersFromHive();
    } catch (e) {}
  }

  Future<void> saveClientIp(String? clientIp) async {
    _clientIp = clientIp;
    await _printerBox!.put('clientIp', clientIp);

    notifyListeners();
  }

  void _loadPrintersFromHive() {
    try {
      final data = _printerBox!.get('data');

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

  String? getPrinterIpFromHive({String? type, String? itemName}) {
    try {
      final data = _printerBox?.get('data');
      if (data != null && data is List) {
        for (var json in data) {
          if (json is Map<String, dynamic>) {
            final printer = Printer.fromJson(json);

            // If type is specified (like 'Overall'), return that IP
            if (type != null && printer.type == type) {
              return printer.ipAddress;
            }

            // If itemName is specified, find printer for that item
            if (itemName != null) {
              for (var item in printer.items) {
                if (item.trim().toLowerCase() ==
                    itemName.trim().toLowerCase()) {
                  return printer.ipAddress;
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print("Error fetching printer IP from Hive: $e");
    }
    return null;
  }

  void saveIpToDevice(String deviceId, String ip) {
    deviceIps[deviceId] = ip;
    notifyListeners();
  }

  void addPrinter(Printer printer) {
    if (_printers.any((p) => p.name == printer.name)) {
      return;
    }

    final newPrinter = Printer(
      name: printer.name,
      ipAddress: printer.ipAddress,
      type: printer.type,
      items: printer.items,
    );

    _printers.add(newPrinter);
    _savePrintersToHive();
  }

  void updatePrinter(Printer updatedPrinter) {
    final index = _printers.indexWhere(
      (printer) => printer.name == updatedPrinter.name,
    );
    if (index != -1) {
      _printers[index] = updatedPrinter;
      _savePrintersToHive();
    }
  }

  void updatePrinterEdit(int index, Printer updatedPrinter) {
    if (index >= 0 && index < _printers.length) {
      _printers[index] = updatedPrinter;
      _savePrintersToHive();
      notifyListeners();
    } else {}
  }

  void removePrinter(int index) {
    if (index >= 0 && index < _printers.length) {
      final removedPrinter = _printers.removeAt(index); // Remove from list
      _savePrintersToHive(); // Save updated list to Hive
      notifyListeners(); // Notify listeners to refresh the UI
    } else {}
  }

  void removePrinterByName(String printerName) {
    final index = _printers.indexWhere(
      (printer) => printer.name == printerName,
    );
    if (index != -1) {
      final removedPrinter = _printers.removeAt(index); // Remove from list

      notifyListeners();
    } else {}
  }

  void _savePrintersToHive() {
    final data = _printers.map((printer) => printer.toJson()).toList();
    _printerBox?.put('data', data);
    notifyListeners();
  }

  String? getPrinterIpForItem(String itemName) {
    itemName = itemName.trim().toLowerCase(); // Normalize the item name
    for (final printer in _printers) {
      for (final item in printer.items) {
        // Add this line for debugging
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
}
