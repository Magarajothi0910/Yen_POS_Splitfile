import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/printer.dart';

class PrinterProviderDine with ChangeNotifier {
  late Box _printerBox;
  List<Printer> _printers = [];
  List<Printer> get printers => _printers;
  String _selectedType = 'Overall';
  String get selectedType => _selectedType;

  Future<void> printerInitializeHive() async {
    try {
      if (!Hive.isBoxOpen('KOTprinters')) {
        await Hive.openBox('KOTprinters');
        print("✅ Opened Hive box 'KOTprinters'");
      }
      _printerBox = Hive.box('KOTprinters');
      print("✅ Hive box 'KOTprinters' is open: ${_printerBox.isOpen}");
      print("🔍 Current keys in 'KOTprinters' box: ${_printerBox.keys}");

      loadPrintersFromHive();

      print("✅ PrinterProvider initialized, printers: ${_printers.length}");
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } catch (e) {
      print("❌ Error opening Hive box 'printers': $e");
    }
  }

  void setSelectedType(String type) {
    _selectedType = type;
    notifyListeners();
  }

  void setPrintersFromWebSocket(List<Printer> printers) {
    _printers = printers;
    _savePrintersToHive();
    notifyListeners();
    print("✅ Set printers from WebSocket: ${_printers.length}");
  }

  void loadPrintersFromHive() {
    try {
      final data = _printerBox.get('data');

      if (data != null && data is List) {
        _printers = data
            .map((json) {
              if (json is Map) {
                try {
                  return Printer.fromJson(Map<String, dynamic>.from(json));
                } catch (e) {
                  print("❌ Error parsing JSON to Printer: $e, JSON: $json");
                  return null;
                }
              }
              print("⚠️ Invalid data format, expected Map but got: $json");
              return null;
            })
            .whereType<Printer>()
            .toList();
      } else {
        _printers = [];
        print("⚠️ No data found in Hive or invalid format: $data");
      }

    } catch (e) {
      print("❌ Error loading data from Hive: $e");
      _printers = [];
    }
  }

  // Add new printer - only for creating new ones
  void addPrinter(Printer printer) {
    try {
      // Check if printer with same name already exists
      final existingIndex = _printers.indexWhere((p) => p.name == printer.name);
      if (existingIndex != -1) {
        print("⚠️ Printer with name '${printer.name}' already exists at index $existingIndex");
        return;
      }

      _printers.add(printer);
      _savePrintersToHive();
      print("✅ Added new printer: ${printer.name}");
      print("📋 Current printers list: ${_printers.map((p) => p.toJson())}");
      notifyListeners();
    } catch (e) {
      print("❌ Error in addPrinter: $e");
    }
  }

  // Update existing printer by index
  void updatePrinter(int index, Printer updatedPrinter) {
    if (index >= 0 && index < _printers.length) {
      // Check if the name is being changed to an existing name
      final existingIndex = _printers.indexWhere((p) => p.name == updatedPrinter.name);
      if (existingIndex != -1 && existingIndex != index) {
        print("⚠️ Printer with name '${updatedPrinter.name}' already exists at index $existingIndex");
        return;
      }

      _printers[index] = updatedPrinter;
      _savePrintersToHive();
      print("✅ Updated printer at index $index: ${updatedPrinter.name} (IP: ${updatedPrinter.ipAddress})");
      notifyListeners();
    } else {
      print("❌ Invalid index for updatePrinter: $index");
    }
  }

  // Remove printer by index
  void removePrinter(int index) {
    if (index >= 0 && index < _printers.length) {
      final printerName = _printers[index].name;
      _printers.removeAt(index);
      _savePrintersToHive();
      print("✅ Removed printer at index $index: $printerName");
      notifyListeners();
    } else {
      print("❌ Invalid index for removePrinter: $index");
    }
  }

  // Remove printer by name (for WebSocket synchronization)
  void removePrinterByName(String printerName) {
    final index = _printers.indexWhere((printer) => printer.name == printerName);
    if (index != -1) {
      _printers.removeAt(index);
      _savePrintersToHive();
      print("✅ Removed printer: $printerName");
      notifyListeners();
    }
  }

  void _savePrintersToHive() {
    try {
      final data = _printers.map((printer) => printer.toJson()).toList();
      print("💾 Saving printers to Hive: $data");
      _printerBox.put('data', data);
      print("✅ Saved ${_printers.length} printers to Hive");
      print("🔍 Verifying saved data: ${_printerBox.get('data')}");
    } catch (e) {
      print("❌ Error saving printers to Hive: $e");
    }
  }

  String? getPrinterIpForItem(String itemId) {
    itemId = itemId.trim().toLowerCase();
    for (final printer in _printers) {
      for (final item in printer.items) {
        if (item.trim().toLowerCase() == itemId) {
          print("✅ Found printer IP for item $itemId: ${printer.ipAddress}");
          return printer.ipAddress;
        }
      }
    }
    print("⚠️ No printer found for item $itemId");
    return null;
  }

  String? getPreInvoicePrinterIp() {
    try {
      return _printers.firstWhere((printer) => printer.type == 'PreInvoice').ipAddress;
    } catch (e) {
      print("⚠️ No PreInvoice printer found");
      return null;
    }
  }

  String? getPrinterNameByItem(String itemId) {
    try {
      final normalizedItem = itemId.trim().toLowerCase();

      for (final printer in _printers) {
        for (final item in printer.items) {
          if (item.trim().toLowerCase() == normalizedItem) {
            print("✅ Found printer name '${printer.name}' for item $itemId");
            return printer.name;
          }
        }
      }

      print("⚠️ No printer found for item $itemId");
      return null;
    } catch (e) {
      print("❌ Error finding printer name for item $itemId: $e");
      return null;
    }
  }

  String? getInvoicePrinterIp() {
    try {
      return _printers.firstWhere((printer) => printer.type == 'Invoice').ipAddress;
    } catch (e) {
      print("⚠️ No Invoice printer found");
      return null;
    }
  }

  String? getOverallPrinterIp() {
    try {
      return _printers.firstWhere((printer) => printer.type == 'Overall').ipAddress;
    } catch (e) {
      print("⚠️ No Overall printer found");
      return null;
    }
  }

  bool isItemAssignedToOtherPrinter(String itemId, String currentPrinterName) {
    for (final printer in _printers) {
      if (printer.name != currentPrinterName && printer.items.contains(itemId)) {
        return true;
      }
    }
    return false;
  }

  // Helper method to get printer index by name
  int getPrinterIndexByName(String printerName) {
    return _printers.indexWhere((printer) => printer.name == printerName);
  }
}
