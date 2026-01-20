import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../components/capitalizeWord.dart';

class PrinterService {
  static Future<bool> printReceipt({
    required String ipAddress,
    required String tableNumber,
    required String seat,
    required String date,
    required String time,
    required String waiter,
    required double total,
    required List<Map<String, dynamic>> seatOrders,
    required int tokenNumber,
    required String userName,
    bool isOverall = false,
    required String orderType,
  }) async {
    try {
      if (seatOrders.isEmpty) {
        print("⚠️ No items to print for token $tokenNumber");
        return false;
      }

      print("🖨 Initializing printer at $ipAddress...");
      final profile = await CapabilityProfile.load();
      final printer = NetworkPrinter(PaperSize.mm80, profile);

      final PosPrintResult res = await printer.connect(ipAddress, port: 9100);
      if (res != PosPrintResult.success) {
        print("❌ Failed to connect to printer at $ipAddress");
        bool isAlreadyStored = await _isOrderAlreadyStored(tokenNumber);
        if (!isAlreadyStored) {
          _storeUnprintedOrder({
            "ipAddress": ipAddress,
            "tableNumber": tableNumber,
            "seat": seat,
            "date": date,
            "time": time,
            "waiter": waiter,
            "total": total,
            "seatOrders": seatOrders,
            "tokenNumber": tokenNumber,
            "userName": userName,
            "isOverall": isOverall,
            "orderType": orderType,
            // "printerName": ${printerProvider.getPrinterNameByIp(ipAddress) ?? "Unknown"}, // Added printer name to stored order
          });
          print("💾 Order stored for retry later: token $tokenNumber");
        }
        return false;
      }

      // ✅ Use generator instead of direct printer.text
      final generator = Generator(PaperSize.mm80, profile);
      const int lineWidth = 48;
      List<int> bytes = [];

      bytes += generator.reset();
      bytes += generator.feed(1);

      // Title
      bytes += generator.text(
        'KOT $orderType',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );

      // Added printer name display
      bytes += generator.text(
        'Printer:', //${printerProvider.getPrinterNameByIp(ipAddress) ?? "Unknown"}',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
        ),
      );

      if (isOverall) {
        bytes += generator.feed(1);
        bytes += generator.text(
          'OverAll Items',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ),
        );
      }

      bytes += generator.feed(1);
      bytes += generator.text(
        'Token: $tokenNumber',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );

      final RegExp regExp = RegExp(r'\d+');
      final String tableOnlyNumber = regExp.firstMatch(tableNumber)?.group(0) ?? tableNumber;

      bytes += generator.feed(1);
      bytes += generator.row([
        PosColumn(
          text: 'Table: $tableOnlyNumber',
          width: 6,
          styles: const PosStyles(
            align: PosAlign.left,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ),
        ),
        PosColumn(
          text: 'Seat: $seat',
          width: 6,
          styles: const PosStyles(
            align: PosAlign.right,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ),
        ),
      ]);

      bytes += generator.feed(1);
      bytes += generator.text('Captain     : $userName', styles: const PosStyles(align: PosAlign.left));
      bytes += generator.text('Sales person : $waiter', styles: const PosStyles(align: PosAlign.left));

      // Process orders
      List<List<Map<String, dynamic>>> processedOrders = processOrders(seatOrders);
      List<Map<String, dynamic>> diningList = processedOrders[0];
      List<Map<String, dynamic>> parcelList = processedOrders[1];

      bytes += generator.feed(1);

      // Function to print items with generator
      void printItems(String header, List<Map<String, dynamic>> items) {
        if (items.isEmpty) return;

        bytes += generator.text(
          header,
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ),
        );

        bytes += generator.text(
          '-' * lineWidth,
          styles: const PosStyles(align: PosAlign.left),
        );

        // Table header
        bytes += generator.row([
          PosColumn(
            text: 'S.No',
            width: 2,
            styles: const PosStyles(bold: true, align: PosAlign.left),
          ),
          PosColumn(
            text: 'Item Name',
            width: 7,
            styles: const PosStyles(bold: true, align: PosAlign.left),
          ),
          PosColumn(
            text: 'Qty',
            width: 3,
            styles: const PosStyles(bold: true, align: PosAlign.right),
          ),
        ]);

        bytes += generator.text(
          '-' * lineWidth,
          styles: const PosStyles(align: PosAlign.left),
        );

        int serialNumber = 1;
        for (var item in items) {
          String itemName = capitalizeWords(item["varianceName"]);
          String quantity = (item['quantity']?.toString() ?? '0');
          String weight = item["weight"] != null && item["weight"] > 0 ? 'Wt: ${item["weight"].toStringAsFixed(2)}' : '';

          // Add-ons
          List<String> detailsList = [];
          if (item['config'] != null) {
            var config = item['config'];
            List<List> addOnList = List<List>.from(config['addOn'] ?? []);
            List<List> addOnQtyList = List<List>.from(config['addOnQuantities'] ?? []);

            for (int i = 0; i < addOnList.length; i++) {
              for (int j = 0; j < addOnList[i].length; j++) {
                String addonName = addOnList[i][j].toString();
                String addonQty = (addOnQtyList.isNotEmpty && addOnQtyList[i].length > j) ? addOnQtyList[i][j].toString() : '1';
                detailsList.add('$addonName x$addonQty');
              }
            }
          }

          // Print main row
          bytes += generator.row([
            PosColumn(
              text: '$serialNumber',
              width: 2,
              styles: const PosStyles(align: PosAlign.left),
            ),
            PosColumn(
              text: itemName,
              width: 7,
              styles: const PosStyles(align: PosAlign.left),
            ),
            PosColumn(
              text: quantity,
              width: 3,
              styles: const PosStyles(align: PosAlign.right),
            ),
          ]);

          // Extra details
          if (weight.isNotEmpty) {
            bytes += generator.text(weight, styles: const PosStyles(align: PosAlign.left));
          }
          if (detailsList.isNotEmpty) {
            for (var d in detailsList) {
              bytes += generator.text('  + $d', styles: const PosStyles(align: PosAlign.left));
            }
          }
          if (item['remark'] != null && item['remark'].toString().isNotEmpty) {
            bytes += generator.text('(Remark: ${item["remark"]})', styles: const PosStyles(align: PosAlign.left));
          }

          serialNumber++;
          bytes += generator.feed(1);
        }

        bytes += generator.text(
          '=' * lineWidth,
          styles: const PosStyles(align: PosAlign.left),
        );
        bytes += generator.feed(1);
      }

      // Print dining & parcel
      printItems('Table Service', diningList);
      printItems('Parcel Items', parcelList);

      // Footer
      bytes += generator.text('Date: $date  Time: $time', styles: const PosStyles(align: PosAlign.center));

      bytes += generator.cut();

      // ✅ Send all bytes in one go
      printer.rawBytes(Uint8List.fromList(bytes));
      printer.disconnect();

      print("✅ Successfully printed receipt for token $tokenNumber on printer: printerName");
      return true;
    } catch (e, st) {
      print("🔥 Error printing receipt for token $tokenNumber: $e\n$st");
      _storeUnprintedOrder({
        "ipAddress": ipAddress,
        "tableNumber": tableNumber,
        "seat": seat,
        "date": date,
        "time": time,
        "waiter": waiter,
        "total": total,
        "seatOrders": seatOrders,
        "tokenNumber": tokenNumber,
        "userName": userName,
        "isOverall": isOverall,
        "orderType": orderType,
        //"printerName": printerName, // Added printer name to stored order
      });
      return false;
    }
  }

  /// **🔹 Check if order already exists in Hive**
  static Future<bool> _isOrderAlreadyStored(int tokenNumber) async {
    final box = Hive.box('pendingPrintOrders');
    List<dynamic> pendingOrders = box.get('ordersBox', defaultValue: []);

    return pendingOrders.any((order) => order["tokenNumber"] == tokenNumber);
  }

  static Future<void> _storeUnprintedOrder(Map<String, dynamic> orderData) async {
    print("pending orders called...");
    Box box;
    if (Hive.isBoxOpen('pendingPrintOrders')) {
      box = Hive.box('pendingPrintOrders');
    } else {
      box = await Hive.openBox('pendingPrintOrders'); // ✅ open here if needed
    }
    final List<dynamic> pendingOrders = box.get('ordersBox', defaultValue: []);

    pendingOrders.add(Map<String, dynamic>.from(orderData)); // ✅ Explicit casting
    await box.put('ordersBox', pendingOrders); // ✅ Ensure list is saved in Hive
    print("pendingOrders...$pendingOrders");
  }

  /// 🔁 Periodically retry pending orders
  static void startAutoRetry({Duration interval = const Duration(seconds: 5)}) {
    Timer.periodic(interval, (timer) async {
      await _retryUnprintedOrders();
    });
  }

  /// 🖨 Try to print all unprinted orders in Hive
  static Future<void> _retryUnprintedOrders() async {
    if (!Hive.isBoxOpen('pendingPrintOrders')) {
      await Hive.openBox('pendingPrintOrders');
    }

    final box = Hive.box('pendingPrintOrders');
    final List<dynamic> pendingOrders = box.get('ordersBox', defaultValue: []);

    if (pendingOrders.isEmpty) return;

    print("🔁 Retrying ${pendingOrders.length} pending print jobs...");

    List<Map<String, dynamic>> remainingOrders = [];

    for (var rawOrder in pendingOrders) {
      // ✅ Safely cast the order and its nested seatOrders
      final order = Map<String, dynamic>.from(rawOrder);
      final ip = order["ipAddress"];
      final token = order["tokenNumber"];

      // Deep cast for seatOrders
      final List<Map<String, dynamic>> seatOrders = (order["seatOrders"] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

      // Optional ping before connecting
      final reachable = await _isPrinterReachable(ip);
      if (!reachable) {
        print("⚠️ Printer at $ip still offline. Skipping token $token...");
        remainingOrders.add(order);
        continue;
      }

      print("🖨 Reconnecting to printer $ip for token $token...");
      final success = await PrinterService.printReceipt(
        ipAddress: ip,
        tableNumber: order["tableNumber"],
        seat: order["seat"],
        date: order["date"],
        time: order["time"],
        waiter: order["waiter"],
        total: order["total"],
        seatOrders: seatOrders,
        tokenNumber: order["tokenNumber"],
        userName: order["userName"],
        isOverall: order["isOverall"],
        orderType: order["orderType"],
      );

      if (!success) {
        print("❌ Still failed for token $token. Keeping it for next retry.");
        remainingOrders.add(order);
      } else {
        print("✅ Successfully reprinted token $token. Removing from queue.");
      }
    }

    // ✅ Write back only valid Map<String, dynamic> entries
    await box.put('ordersBox', remainingOrders);
  }

  /// 🌐 Check if the printer is reachable (simple socket test)
  static Future<bool> _isPrinterReachable(String ipAddress) async {
    try {
      final socket = await Socket.connect(ipAddress, 9100, timeout: const Duration(seconds: 3));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }
}

List<List<Map<String, dynamic>>> processOrders(List<Map<String, dynamic>> seatOrders) {
  List<Map<String, dynamic>> diningList = [];
  List<Map<String, dynamic>> parcelList = [];

  for (var order in seatOrders) {
    if (order['config'] == null) continue; // Skip if config is null

    for (var config in order['config']) {
      String varianceName = config['varianceName'] ?? 'Unknown Item';
      double weight = config['weight'] ?? 0.0;

      List<int> configQty = (config['configQty'] as List<dynamic>? ?? []).map((qty) => (qty as num?)?.toInt() ?? 0).toList();
      List<List<String>> addOns = (config['addOn'] as List<dynamic>? ?? []).map((e) => (e as List<dynamic>?)?.map((s) => s.toString()).toList() ?? []).toList();
      List<String> variances = (config['variance'] as List<dynamic>? ?? []).map((e) => e?.toString() ?? "").toList();
      List<String> remarks = (config['remark'] as List<dynamic>? ?? []).map((e) => e?.toString() ?? "").toList();
      List<String> types = (config['type'] as List<dynamic>? ?? []).map((e) => e?.toString() ?? "").toList();

      Map<String, dynamic> groupedItems = {};

      for (int i = 0; i < configQty.length; i++) {
        // Ensure index is within safe bounds
        String addOnString = i < addOns.length ? addOns[i].join(", ") : "";
        String varianceString = i < variances.length ? variances[i] : "";
        String remarkString = i < remarks.length ? remarks[i] : "";

        // Handle the type string more robustly
        String typeString = (i < types.length && types[i].trim().isNotEmpty) ? types[i].trim().toLowerCase() : "dining";

        // Create a unique key to group items
        String key = '$varianceName|$addOnString|$varianceString|$remarkString|$typeString';

        if (groupedItems.containsKey(key)) {
          // Accumulate quantity correctly
          groupedItems[key]['quantity'] += configQty[i];
        } else {
          groupedItems[key] = {
            'varianceName': varianceName,
            'weight': weight,
            'quantity': configQty[i],
            'type': typeString,
            'addOns': addOnString,
            'remark': remarkString,
            'variant': varianceString,
            'config': config,
          };
        }
      }

// Add grouped items to appropriate list only once
      groupedItems.forEach((key, item) {
        if (item['type'] == "parcel") {
          parcelList.add(item);
        } else {
          diningList.add(item);
        }
      });

// Debugging Output
    }
  }

  return [diningList, parcelList];
}
