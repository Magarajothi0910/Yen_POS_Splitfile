import 'dart:typed_data';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:intl/intl.dart';

import '../components/capitalizeWord.dart';

final now = DateTime.now();
final formattedDate = DateFormat('dd-MM-yyyy').format(now);
final formattedTime = DateFormat('hh:mm:ss a').format(now);

class CancelPrinterService {
  static Future<void> printUniversalReceipt({
    required String ipAddress,
    required String tableNumber,
    required String seat,
    required String userName,
    required String waiter,
    required List<Map<String, dynamic>> seatOrders,
    required String receiptType,
  }) async {
    NetworkPrinter? printer;
    try {
      print("🔌 Connecting to printer at $ipAddress...");
      print(
        "🔌 seatorder to printer at itemRemarks ${seatOrders[0]["itemRemark"][0]}",
      );
      print("🔌 seatorder to printer at ${seatOrders}");

      final profile = await CapabilityProfile.load();
      printer = NetworkPrinter(PaperSize.mm58, profile);

      final PosPrintResult res = await printer.connect(ipAddress, port: 9100);
      if (res != PosPrintResult.success) {
        print("❌ Failed to connect to printer: $res");
        return;
      }
      print("✅ Connected to printer.");

      try {
        // Reset printer
        printer.rawBytes(Uint8List.fromList([27, 64])); // ESC @
        print("♻️ Printer reset command sent.");
      } catch (resetError, stack) {
        print("⚠️ Failed to reset printer: $resetError");
        print("📌 Stacktrace: $stack");
      }

      // Process orders
      List<List<Map<String, dynamic>>> processedOrders = [];
      try {
        processedOrders = processOrders(seatOrders);
      } catch (processError, stack) {
        print("⚠️ Error processing orders: $processError");
        print("📌 Stacktrace: $stack");
        processedOrders = [[], []]; // fallback to avoid crash
      }

      List<Map<String, dynamic>> diningList = processedOrders[0];
      List<Map<String, dynamic>> parcelList = processedOrders[1];

      print("diningList is $diningList");
      print("parcel is $parcelList");

      String headerText;
      if (receiptType == 'ITEM CANCELLED' ||
          receiptType == 'Full Order Cancelled') {
        headerText = 'ORDER CANCELLED';
      } else if (receiptType == 'ITEM REVERTED') {
        headerText = '';
      } else {
        headerText = 'RECEIPT';
      }

      // Print header
      try {
        printer.text(
          _manualCenterText(headerText, 30),
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ),
        );
        printer.text(
          receiptType,
          styles: const PosStyles(
            align: PosAlign.center,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ),
        );
        printer.text('________________________________________________');
        printer.text(
          '  Table: $tableNumber',
          styles: const PosStyles(bold: true),
        );
        printer.text('  Seat: $seat', styles: const PosStyles(bold: true));
        printer.text('  Waiter: $waiter', styles: const PosStyles(bold: true));
        printer.text(
          '  Captain: $userName',
          styles: const PosStyles(bold: true),
        );

        printer.feed(1);

        printer.text(
          'Date: $formattedDate  Time: $formattedTime',
          styles: const PosStyles(align: PosAlign.center),
        );
        printer.feed(1);
      } catch (headerError, stack) {
        print("⚠️ Error printing header: $headerError");
        print("📌 Stacktrace: $stack");
      }

      // Dining Items
      if (diningList.isNotEmpty) {
        try {
          printer.text(
            'TABLE SERVICE',
            styles: const PosStyles(
              align: PosAlign.center,
              height: PosTextSize.size2,
              width: PosTextSize.size2,
            ),
          );
          printer.text('________________________________________________');
          _printOrderList(printer, diningList);
          if (receiptType == 'ITEM CANCELLED') {
            printer.text(
              ' Remark: ${seatOrders[0]["itemRemark"][0]}',
              styles: const PosStyles(bold: true),
            );
          }
        } catch (diningError, stack) {
          print("⚠️ Error printing dining list: $diningError");
          print("📌 Stacktrace: $stack");
        }
      }

      printer.text('================================================');

      // Parcel Items
      if (parcelList.isNotEmpty) {
        try {
          printer.text(
            'PARCEL ORDERS',
            styles: const PosStyles(
              bold: true,
              align: PosAlign.center,
              height: PosTextSize.size2,
              width: PosTextSize.size2,
            ),
          );
          printer.text('________________________________________________');
          _printOrderList(printer, parcelList);
        } catch (parcelError, stack) {
          print("⚠️ Error printing parcel list: $parcelError");
          print("📌 Stacktrace: $stack");
        }
      }

      // Cut receipt
      try {
        printer.cut();
        print("✂️ Cut command sent.");
      } catch (cutError, stack) {
        print("⚠️ Error cutting paper: $cutError");
        print("📌 Stacktrace: $stack");
      }

      print("✅ Receipt printed successfully!");
    } catch (e, stack) {
      print("💥 Fatal error in printUniversalReceipt: $e");
      print("📌 Stacktrace: $stack");
    } finally {
      try {
        printer?.disconnect();
        print("🔌 Printer disconnected.");
      } catch (disconnectError, stack) {
        print("⚠️ Error disconnecting printer: $disconnectError");
        print("📌 Stacktrace: $stack");
      }
    }
  }

  static void _printOrderList(
    NetworkPrinter printer,
    List<Map<String, dynamic>> orderList,
  ) {
    // Table header
    printer.text(
      'S.No  Item Name           Qty  Cancel',
      styles: const PosStyles(bold: true),
    );
    printer.text('------------------------------------------');

    int index = 1;
    for (var item in orderList) {
      String itemName = capitalizeWords(item['varianceName']);
      String qty = item['quantity'].toString();
      String cancelledQty = item['cancelledQty'] != null
          ? item['cancelledQty'].toString()
          : "0";

      // First row: main item line
      printer.text(
        '${index.toString().padRight(4)}'
        '${itemName.padRight(18).substring(0, itemName.length > 18 ? 18 : itemName.length).padRight(18)}'
        '${qty.padLeft(4)}'
        '${cancelledQty.padLeft(7)}',
      );

      // Second row onwards: Add-ons
      if (item['addOns'].isNotEmpty) {
        printer.text('   ↳ Add-ons:', styles: const PosStyles(bold: true));

        List<String> addOnList = item['addOns'].split(", ");
        for (var addOn in addOnList) {
          if (addOn.trim().isEmpty) continue;

          String formattedAddOn =
              addOn.trim()[0].toUpperCase() +
              addOn.trim().substring(1).toLowerCase();

          printer.text('      - $formattedAddOn');
        }
      }

      // Variant row
      if (item['variant'].isNotEmpty) {
        printer.text('   ↳ Variant: ${item['variant']}');
      }

      // // Remark row
      // if (item['itemRemarks'].isNotEmpty) {
      //   printer.text('   ↳ Remark: ${item['remark']}');
      // }

      index++;
      printer.feed(1); // Line spacing between items
    }

    printer.text('------------------------------------------');
  }

  static List<List<Map<String, dynamic>>> processOrders(
    List<Map<String, dynamic>> seatOrders,
  ) {
    List<Map<String, dynamic>> diningList = [];
    List<Map<String, dynamic>> parcelList = [];

    for (var order in seatOrders) {
      if (order['config'] == null) continue;

      print("order are : $order");

      for (var config in order['config']) {
        String varianceName = config['varianceName'] ?? '';
        double weight = config['weight'] ?? 0.0;

        List<int> configQty = (config['configQty'] as List<dynamic>? ?? [])
            .map((qty) => (qty as num?)?.toInt() ?? 0)
            .toList();

        // ✅ Add-on names
        List<List<String>> addOnNames =
            (config['addOn'] as List<dynamic>? ?? [])
                .map(
                  (e) =>
                      (e as List<dynamic>?)
                          ?.map((s) => s.toString())
                          .toList() ??
                      [],
                )
                .toList();

        // ✅ Add-on quantities (parallel list, same index as addOn)
        List<List<int>> addOnQuantities =
            (config['addOnQty'] as List<dynamic>? ?? [])
                .map(
                  (e) =>
                      (e as List<dynamic>?)
                          ?.map((q) => (q as num?)?.toInt() ?? 0)
                          .toList() ??
                      [],
                )
                .toList();

        List<String> variances = (config['variance'] as List<dynamic>? ?? [])
            .map((e) => e?.toString() ?? "")
            .toList();
        List<String> remarks = (config['remark'] as List<dynamic>? ?? [])
            .map((e) => e?.toString() ?? "")
            .toList();
        List<String> types = (config['type'] as List<dynamic>? ?? [])
            .map((e) => e?.toString() ?? "")
            .toList();

        Map<String, dynamic> groupedItems = {};

        for (int i = 0; i < configQty.length; i++) {
          // ✅ Combine add-ons with their quantities
          String addOnString = "";
          if (i < addOnNames.length) {
            List<String> names = addOnNames[i];
            List<int> qtys = (i < addOnQuantities.length
                ? addOnQuantities[i]
                : []);

            List<String> formatted = [];
            for (int j = 0; j < names.length; j++) {
              int qty = j < qtys.length ? qtys[j] : 1;
              formatted.add("$qty x ${names[j]}");
            }
            addOnString = formatted.join(", ");
          }

          String varianceString = i < variances.length ? variances[i] : "";
          String remarkString = i < remarks.length ? remarks[i] : "";

          String typeString = (i < types.length && types[i].trim().isNotEmpty)
              ? types[i].trim().toLowerCase()
              : "dining";

          // ✅ Use cancelledQty correctly
          double cancelledQuantity =
              order['cancelledQty'] != null && order['cancelledQty'].length > i
              ? order['cancelledQty'][i].toDouble()
              : 0.0;

          String key =
              '$varianceName|$addOnString|$varianceString|$remarkString|$typeString';

          if (groupedItems.containsKey(key)) {
            groupedItems[key]['quantity'] += configQty[i];
            groupedItems[key]['cancelledQty'] += cancelledQuantity;
          } else {
            groupedItems[key] = {
              'varianceName': varianceName,
              'weight': weight,
              'quantity': configQty[i],
              'cancelledQty': cancelledQuantity,
              'type': typeString,
              'addOns': addOnString, // ✅ now includes quantities
              'remark': remarkString,
              'variant': varianceString,
              'config': config,
            };
          }
        }

        groupedItems.forEach((key, item) {
          if (item['type'] == "parcel") {
            parcelList.add(item);
          } else {
            diningList.add(item);
          }
        });
      }
    }
    return [diningList, parcelList];
  }

  static String _manualCenterText(String text, int totalWidth) {
    int padSize = (totalWidth - text.length) ~/ 2;
    return padSize > 0 ? ' ' * padSize + text + ' ' * padSize : text;
  }
}
