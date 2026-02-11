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
    debugPrint('initializeHive1');
    try {
      _printerBox = await Hive.openBox('printers');
      debugPrint('initializeHive2');
      _clientIp = _printerBox!.get('clientIp');
      debugPrint('initializeHive3');
      _loadPrintersFromHive();
      debugPrint('initializeHive4');
      notifyListeners();
      debugPrint('initializeHive5');
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
      debugPrint('initializeHive6');
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
        debugPrint('initializeHive7');
        notifyListeners();
      } else {}
    } catch (e) {
      debugPrint('initializeHive failed $e');
    }
  }

  String? getPrinterIpFromHive({String? type, String? itemName}) {
    debugPrint(
      "🔍 getPrinterIpFromHive called with type: '$type', itemName: '$itemName'",
    );

    try {
      final data = _printerBox?.get('data');
      debugPrint("📦 Raw data from Hive: $data");

      if (data == null || data is! List) {
        debugPrint("❌ Data is null or not a List");
        return null;
      }

      debugPrint("✅ Data is a List with ${data.length} item(s)");

      for (int i = 0; i < data.length; i++) {
        var json = data[i];
        debugPrint("\n--- Processing item $i ---");
        debugPrint("Raw entry: $json (type: ${json.runtimeType})");

        // FIX: Accept both Map<String, dynamic> and Map<dynamic, dynamic>
        Map<String, dynamic> jsonMap;
        if (json is Map<String, dynamic>) {
          jsonMap = json;
        } else if (json is Map) {
          // Safely cast dynamic keys/values to String,dynamic
          jsonMap = json.map((k, v) => MapEntry(k.toString(), v));
          debugPrint(
            "✅ Converted Map<dynamic, dynamic> to Map<String, dynamic>",
          );
        } else {
          debugPrint("⚠️ Skipping: Entry is not a Map");
          continue;
        }

        Printer? printer;
        try {
          printer = Printer.fromJson(jsonMap);
          debugPrint(
            "🎉 Successfully parsed Printer: ${printer.name}, IP: ${printer.ipAddress}, Type: ${printer.type}",
          );
        } catch (e, stack) {
          debugPrint("❌ Failed to parse Printer: $e");
          debugPrint("Stack: $stack");
          continue;
        }

        if (type != null && printer.type == type) {
          debugPrint(
            "🎯 MATCH FOUND BY TYPE '$type' → Returning ${printer.ipAddress}",
          );
          return printer.ipAddress;
        }

        if (itemName != null) {
          for (var item in printer.items) {
            if (item.trim().toLowerCase() == itemName.trim().toLowerCase()) {
              debugPrint(
                "🎯 MATCH FOUND BY ITEM '$itemName' → Returning ${printer.ipAddress}",
              );
              return printer.ipAddress;
            }
          }
        }
      }

      debugPrint("🔚 No match found");
    } catch (e, stack) {
      debugPrint("💥 Exception: $e\n$stack");
    }

    debugPrint("🔴 Returning null");
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
