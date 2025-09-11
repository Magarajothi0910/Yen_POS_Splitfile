import 'dart:typed_data';

import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../widgets/capitalizeWord.dart';

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
    required String tokenNumber,
    required String userName,
    bool isOverall = false,
    required String orderType,
  }) async {
    try {
      if (seatOrders.isEmpty) {
        return false;
      }
      final profile = await CapabilityProfile.load();
      final printer = NetworkPrinter(PaperSize.mm58, profile);

      final PosPrintResult res = await printer.connect(ipAddress, port: 9100);
      if (res != PosPrintResult.success) {

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
          });
        }

        return false;
      }

      printer.rawBytes(Uint8List.fromList([27, 64])); // ESC @

      printer.feed(1);
      // Adjust the text to be centered manually
      String kotText = _manualCenterText(
          'KOT $orderType ', 15); // Assuming a 32 character line width
      String allItemsText =
          isOverall ? _manualCenterText('OverAll Items ', 15) : '';

      printer.text(
        kotText,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true, // Make the text bold
          height: PosTextSize.size2, // Maximum font height
          width: PosTextSize.size2, // Maximum font width
        ),
      );

// Add spacing before printing "All Items"
      if (isOverall) {
        printer.feed(1); // Adds a line space
        printer.text(
          allItemsText,
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true, // Bold text
            height: PosTextSize.size2, // Increase text height
            width: PosTextSize.size2, // Increase text width
          ),
        );
      }

      printer.feed(1); // Adds a line space

// Print the value part (bold) with manual spacing for alignment
      printer.text(
        '    Token:$tokenNumber     ',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true, // Bold text for the value
          height: PosTextSize.size2, // Larger font height
          width: PosTextSize.size2, // Larger font width
        ),
      );
      printer.feed(1); // Adds a line space

      // Table and Seat on the same row, evenly spaced
      final RegExp regExp = RegExp(r'\d+'); // Extract digits
      final String tableOnlyNumber =
          regExp.firstMatch(tableNumber)?.group(0) ?? tableNumber;

      String tableSeatLine = 'Table : $tableOnlyNumber     Seat: $seat';
      printer.text(
        tableSeatLine,
        styles: const PosStyles(
          align: PosAlign.left,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      printer.feed(1); // Adds a line space

      printer.text(
        'Captain     : $userName',
        styles: const PosStyles(
          align: PosAlign.left,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ),
      );
      printer.feed(1); // Adds a line space

      printer.text(
        'Assigned To : $waiter',
        styles: const PosStyles(
          align: PosAlign.left,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ),
      );

      List<List<Map<String, dynamic>>> processedOrders =
          processOrders(seatOrders);
      List<Map<String, dynamic>> diningList = processedOrders[0];
      List<Map<String, dynamic>> parcelList = processedOrders[1];
      printer.feed(1); // Adds a line space

      if (diningList.isNotEmpty) {
        printer.text('Table Service',
            styles: const PosStyles(
              align: PosAlign.center, bold: true,
              height: PosTextSize.size2, // Increase text height
              width: PosTextSize.size2, // Increase text width
            ));
        printer.text('________________________________________________');

        // Print header with proper spacing for columns
        String headerLine =
            '${'${'S.No '.padRight(4)}Item Name'.padRight(20)}${''.padRight(20)}  Qty';
        printer.text(headerLine,
            styles: const PosStyles(align: PosAlign.left, bold: true));
        printer.text('________________________________________________');

        int serialNumber = 1;
        for (var item in diningList) {
          // Prepare item name and quantity columns
          String itemName = capitalizeWords(item["varianceName"]).padRight(25);
          String quantity = item["quantity"].toString();
          String weight = item["weight"] != null && item["weight"] > 0
              ? 'Wt: ${item["weight"].toStringAsFixed(2)}'
              : '';
          // List to store add-ons and variant details
          List<String> detailsList = [];

          // Handle add-ons
          if (item['addOns'] != null && item['addOns'].toString().isNotEmpty) {
            List<String> formattedAddOns = item['addOns']
                .toString()
                .split(',')
                .map((addon) => addon.trim().isNotEmpty
                    ? addon.trim()[0].toUpperCase() +
                        addon.trim().substring(1).toLowerCase()
                    : '')
                .where((addon) => addon.isNotEmpty)
                .toList();

            detailsList.add('Add-on:');
            detailsList.addAll(formattedAddOns);
          }

          // Handle variants
          if (item['variant'] != null &&
              item['variant'].toString().isNotEmpty) {
            detailsList.add('Variant:');
            detailsList.add(capitalizeWords(item["variant"]));
          }

          // Print the first row with item name and first detail (if exists)
          if (detailsList.isNotEmpty) {
            printer.text('$serialNumber  $itemName${detailsList.first}',
                styles: const PosStyles(align: PosAlign.left));

            // Print remaining details under "Details" column
            for (int i = 1; i < detailsList.length; i++) {
              if (i == detailsList.length - 1) {
                // Print quantity only for the last add-on or variant
                printer.text(
                    ' '.padRight(25) + detailsList[i].padRight(20) + quantity,
                    styles: const PosStyles(align: PosAlign.left));
                if (weight.isNotEmpty) {
                  printer.text(' $weight',
                      styles: const PosStyles(align: PosAlign.left));
                }
              } else {
                // Print details without quantity for other lines
                printer.text(' '.padRight(25) + detailsList[i],
                    styles: const PosStyles(align: PosAlign.left));
                if (weight.isNotEmpty) {
                  printer.text(' $weight',
                      styles: const PosStyles(align: PosAlign.left));
                }
              }
            }
          } else {
            // If no add-ons/variants, print item and quantity directly
            printer.text('$serialNumber  $itemName                $quantity',
                styles: const PosStyles(align: PosAlign.left));
            if (weight.isNotEmpty) {
              printer.text(' $weight',
                  styles: const PosStyles(align: PosAlign.left));
            }
          }

          // Handle remarks if available
          if (item['remark'] != null && item['remark'].toString().isNotEmpty) {
            printer.text(' (Remark: ${item["remark"]})',
                styles: const PosStyles(align: PosAlign.left));
          }

          serialNumber++;
          printer.feed(1); // Adds a line space
        }
      }
      printer.text('================================================');
      printer.feed(1); // Adds a line space

      if (parcelList.isNotEmpty) {
        printer.text('Parcel Items',
            styles: const PosStyles(
              align: PosAlign.center, bold: true,
              height: PosTextSize.size2, // Increase text height
              width: PosTextSize.size2,
            ));
        printer.text('________________________________________________');

        // Print header with proper spacing for columns
        String headerLine =
            '${'${'S.No '.padRight(4)}Item Name'.padRight(20)}${''.padRight(20)}  Qty';
        printer.text(headerLine,
            styles: const PosStyles(align: PosAlign.left, bold: true));
        printer.text('________________________________________________');

        int serialNumber = 1;
        for (var item in parcelList) {
          // Prepare item name and quantity columns
          String itemName = capitalizeWords(item["varianceName"]).padRight(25);
          String quantity = item["quantity"].toString();
          String weight = item["weight"] != null && item["weight"] > 0
              ? 'Wt: ${item["weight"].toStringAsFixed(2)}'
              : '';
          // List to store add-ons and variant details
          List<String> detailsList = [];

          // Handle add-ons
          if (item['addOns'] != null && item['addOns'].toString().isNotEmpty) {
            List<String> formattedAddOns = item['addOns']
                .toString()
                .split(',')
                .map((addon) => addon.trim().isNotEmpty
                    ? addon.trim()[0].toUpperCase() +
                        addon.trim().substring(1).toLowerCase()
                    : '')
                .where((addon) => addon.isNotEmpty)
                .toList();

            detailsList.add('Add-on:');
            detailsList.addAll(formattedAddOns);
          }

          // Handle variants
          if (item['variant'] != null &&
              item['variant'].toString().isNotEmpty) {
            detailsList.add('Variant:');
            detailsList.add(capitalizeWords(item["variant"]));
          }

          // Print the first row with item name and first detail (if exists)
          if (detailsList.isNotEmpty) {
            printer.text('$serialNumber  $itemName${detailsList.first}',
                styles: const PosStyles(align: PosAlign.left));

            // Print remaining details under "Details" column
            for (int i = 1; i < detailsList.length; i++) {
              if (i == detailsList.length - 1) {
                // Print quantity only for the last add-on or variant
                printer.text(
                    ' '.padRight(25) + detailsList[i].padRight(20) + quantity,
                    styles: const PosStyles(align: PosAlign.left));
                if (weight.isNotEmpty) {
                  printer.text(' $weight',
                      styles: const PosStyles(align: PosAlign.left));
                }
              } else {
                // Print details without quantity for other lines
                printer.text(' '.padRight(25) + detailsList[i],
                    styles: const PosStyles(align: PosAlign.left));
                if (weight.isNotEmpty) {
                  printer.text(' $weight',
                      styles: const PosStyles(align: PosAlign.left));
                }
              }
            }
          } else {
            // If no add-ons/variants, print item and quantity directly
            printer.text('$serialNumber  $itemName                 $quantity',
                styles: const PosStyles(align: PosAlign.left));
            if (weight.isNotEmpty) {
              printer.text(' $weight',
                  styles: const PosStyles(align: PosAlign.left));
            }
          }

          // Handle remarks if available
          if (item['remark'] != null && item['remark'].toString().isNotEmpty) {
            printer.text(' (Remark: ${item["remark"]})',
                styles: const PosStyles(align: PosAlign.left));
          }

          serialNumber++;
          printer.feed(1); // Adds a line space
        }

        printer.text('________________________________________________');
      }

      printer.text('Date: $date  Time: $time',
          styles: const PosStyles(align: PosAlign.center));

      printer.cut();
      printer.disconnect();
      return true; // ✅ Return success
    } catch (e) {
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
      });
      return false;
    }
  }

  /// **🔹 Check if order already exists in Hive**
  static Future<bool> _isOrderAlreadyStored(String tokenNumber) async {
    final box = await Hive.openBox('pendingPrintOrders');
    List<dynamic> pendingOrders = box.get('orders', defaultValue: []);

    return pendingOrders.any((order) => order["tokenNumber"] == tokenNumber);
  }

  static Future<void> _storeUnprintedOrder(
      Map<String, dynamic> orderData) async {
    final box =
        await Hive.openBox('pendingPrintOrders'); // Ensure the box is open
    final List<dynamic> pendingOrders = box.get('orders', defaultValue: []);

    pendingOrders
        .add(Map<String, dynamic>.from(orderData)); // ✅ Explicit casting
    await box.put('orders', pendingOrders); // ✅ Ensure list is saved in Hive

  }

  static String _manualCenterText(String text, int totalWidth) {
    int padSize = (totalWidth - text.length) ~/ 2;
    if (padSize > 0) {
      return ' ' * padSize + text + ' ' * padSize;
    } else {
      return text;
    }
  }
}

List<List<Map<String, dynamic>>> processOrders(
    List<Map<String, dynamic>> seatOrders) {
  List<Map<String, dynamic>> diningList = [];
  List<Map<String, dynamic>> parcelList = [];

  for (var order in seatOrders) {
    if (order['config'] == null) continue; // Skip if config is null

    for (var config in order['config']) {
      String varianceName = config['varianceName'] ?? 'Unknown Item';
      double weight = config['weight'] ?? 0.0;

      List<int> configQty = (config['configQty'] as List<dynamic>? ?? [])
          .map((qty) => (qty as num?)?.toInt() ?? 0)
          .toList();
      List<List<String>> addOns = (config['addOn'] as List<dynamic>? ?? [])
          .map((e) =>
              (e as List<dynamic>?)?.map((s) => s.toString()).toList() ?? [])
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
        // Ensure index is within safe bounds
        String addOnString = i < addOns.length ? addOns[i].join(", ") : "";
        String varianceString = i < variances.length ? variances[i] : "";
        String remarkString = i < remarks.length ? remarks[i] : "";

        // Handle the type string more robustly
        String typeString = (i < types.length && types[i].trim().isNotEmpty)
            ? types[i].trim().toLowerCase()
            : "dining";

        // Create a unique key to group items
        String key =
            '$varianceName|$addOnString|$varianceString|$remarkString|$typeString';

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

