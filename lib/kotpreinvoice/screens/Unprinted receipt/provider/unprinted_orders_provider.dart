import 'dart:async'; // ✅ Import Timer
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../../services/printer_services.dart';
import '../../../providers/printer_provider.dart';

class UnprintedOrdersProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _unprintedOrders = [];
  final PrinterProviderDine printerProvider; // ✅ Required dependency
  List<Map<String, dynamic>> get unprintedOrders => _unprintedOrders;
  UnprintedOrdersProvider({required this.printerProvider}) {
    initialize();
  }
  Future<void> initialize() async {
    await fetchUnprintedOrders();
  }

  Future<void> fetchUnprintedOrders() async {
    if (!Hive.isBoxOpen('pendingPrintOrders')) {
      await Hive.openBox('pendingPrintOrders');
    }
    final box = Hive.box('pendingPrintOrders');

    final rawList = box.get('ordersBox', defaultValue: []) as List<dynamic>;
    final orders = rawList.map<Map<String, dynamic>>((raw) {
      final rawMap = raw as Map;
      return rawMap.map<String, dynamic>(
        (k, v) => MapEntry(k.toString(), v),
      );
    }).toList();
    for (var order in orders) {
      order['ipAddress'] = order['ipAddress']?.toString() ?? '';
      order['tableNumber'] = order['tableNumber']?.toString() ?? '';
      order['seat'] = order['seat']?.toString() ?? '';
      order['date'] = order['date']?.toString() ?? '';
      order['time'] = order['time']?.toString() ?? '';
      order['waiter'] = order['waiter']?.toString() ?? '';
      order['tokenNumber'] = order['tokenNumber']?.toString() ?? '';
      order['userName'] = order['userName']?.toString() ?? '';
      order['orderType'] = order['orderType']?.toString() ?? '';
      // If you store total as a num/string, ensure it’s a double:
      order['total'] = double.tryParse(order['total']?.toString() ?? '') ?? 0.0;
    }
    for (var order in orders) {
      final rawItems = (order['seatOrders'] ?? []) as List<dynamic>;
      final items = rawItems.map<Map<String, dynamic>>((rawItem) {
        final itemMap = rawItem as Map;
        return itemMap.map<String, dynamic>(
          (k, v) => MapEntry(k.toString(), v),
        );
      }).toList();

      // Build a map keyed by "itemName–quantity"
      final dedupedMap = <String, Map<String, dynamic>>{};
      for (var item in items) {
        final key = '${item['itemName']}-${item['quantity']}';

        // If we haven't seen it yet, just store it
        if (!dedupedMap.containsKey(key)) {
          dedupedMap[key] = item;
        } else {
          // If this one has a non-null config and the stored one doesn't, replace it
          final existing = dedupedMap[key]!;
          if (item['config'] != null && existing['config'] == null) {
            dedupedMap[key] = item;
          }
        }
      }

      // Replace with the deduped list
      order['seatOrders'] = dedupedMap.values.toList();
    }

    _unprintedOrders = orders;

    for (var order in _unprintedOrders) {
      _scheduleOrderDeletion(order);
    }
    notifyListeners();
  }

  void _scheduleOrderDeletion(Map<String, dynamic> order) {
    Timer(const Duration(minutes: 2), () async {
      _removeOrderFromHive(order);
    });
  }

  Future<void> _removeOrderFromHive(Map<String, dynamic> order) async {
    final box = await Hive.box('pendingPrintOrders');
    List<dynamic> pending = box.get('ordersBox', defaultValue: []);
    pending.removeWhere((o) => o['tokenNumber'] == order['tokenNumber']);
    await box.put('ordersBox', pending);
    await fetchUnprintedOrders();
  }

  Future<void> retryPrint(BuildContext context, Map<String, dynamic> order) async {
    try {
      print("orders in retry method..");
      List<Map<String, dynamic>> seatOrders = _parseSeatOrders(order["seatOrders"]);

      print("orders in retry method..1");

      // 🔍 Get Overall Printer IP
      String? overallPrinterIp = printerProvider.getOverallPrinterIp();

      // 🔍 Step 1: Group Items by Printer IP
      Map<String, List<Map<String, dynamic>>> groupedItems = {};
      print("orders in retry method..2");

      for (var item in seatOrders) {
        String varianceName = item["itemName"];
        String? printerIp = printerProvider.getPrinterIpForItem(varianceName);

        if (printerIp != null) {
          if (!groupedItems.containsKey(printerIp)) {
            groupedItems[printerIp] = [];
          }
          groupedItems[printerIp]!.add(item);
        }
      }
      print("orders in retry method..3");

      bool overallPrintSuccess = false;

      // 🔍 Step 2: Print Overall Receipt (if applicable)
      if (overallPrinterIp != null) {
        overallPrintSuccess = await PrinterService.printReceipt(
          ipAddress: overallPrinterIp,
          tableNumber: order["tableNumber"],
          seat: order["seat"],
          date: order["date"],
          time: order["time"],
          waiter: order["waiter"],
          total: order["total"],
          seatOrders: seatOrders, // ✅ Print all items in one receipt for overall printer
          tokenNumber: int.tryParse(order["tokenNumber"].toString()) ?? 0,
          userName: order["userName"],
          isOverall: true,
          orderType: order["orderType"],
        );
      }
      print("orders in retry method..4");

      // 🔍 Step 3: Print Item-Wise Receipts (Grouped)
      Map<String, bool> printResults = {};

      for (var entry in groupedItems.entries) {
        String printerIp = entry.key;
        List<Map<String, dynamic>> itemsForPrinter = entry.value;
        print("orders in retry method..5");

        bool printSuccess = await PrinterService.printReceipt(
          ipAddress: printerIp,
          tableNumber: order["tableNumber"],
          seat: order["seat"],
          date: order["date"],
          time: order["time"],
          waiter: order["waiter"],
          total: order["total"],
          seatOrders: itemsForPrinter, // ✅ Print all items assigned to this printer in one receipt
          tokenNumber: int.tryParse(order["tokenNumber"].toString()) ?? 0,
          userName: order["userName"],
          isOverall: false,
          orderType: order["orderType"],
        );

        printResults[printerIp] = printSuccess;
      }
      print("orders in retry method..6");

      // ✅ If both overall & item-wise printing succeeded, remove order
      if (overallPrintSuccess && printResults.values.every((success) => success)) {
        await _removeOrderFromHive(order);
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Order reprinted successfully!"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "❌ Some items failed to print. Check printer connections.",
              style: TextStyle(color: Colors.black),
            ),
            backgroundColor: Colors.red[200],
            duration: Duration(seconds: 3),
          ),
        );
      }

      notifyListeners();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Error: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, dynamic>> _parseSeatOrders(dynamic rawSeatOrders) {
    if (rawSeatOrders is String) {
      try {
        return (jsonDecode(rawSeatOrders) as List).map((item) => Map<String, dynamic>.from(item)).toList();
      } catch (e) {
        throw Exception("Invalid seatOrders JSON: $rawSeatOrders");
      }
    } else if (rawSeatOrders is List) {
      return rawSeatOrders.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } else {
      throw Exception("Unexpected seatOrders type: ${rawSeatOrders.runtimeType}");
    }
  }

  Future<void> clearUnprintedOrders() async {
    if (!Hive.isBoxOpen('pendingPrintOrders')) {
      await Hive.openBox('pendingPrintOrders');
    }
    final box = Hive.box('pendingPrintOrders');
    await box.put('ordersBox', []);
    _unprintedOrders = [];
    notifyListeners();
  }
}
