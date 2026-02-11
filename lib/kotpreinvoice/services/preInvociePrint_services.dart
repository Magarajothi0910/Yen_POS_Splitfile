import 'dart:typed_data';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:image/image.dart' as img;
import 'package:yen_pos/Global/globals_data.dart';
import 'package:yen_pos/kotpreinvoice/models/fetchBranch.dart';

class InvoicePrinter {
  /// Prints the Sales Invoice receipt for the given seat orders
  static Future<String> printReceipt({
    required String ipAddress,
    required String tableNumber,
    required String seat,
    required List<dynamic> seatOrders,
    required String userName,
    required String waiter,
    required String areaName,
    required String invoiceNo,
  }) async {
    try {
      if (seatOrders.isEmpty) {
        return "⚠️ No items to print";
      }

      debugPrint("seatOrders in preinvoice is : $seatOrders");

      print("🖨 Initializing printer at $ipAddress...");
      final profile = await CapabilityProfile.load();
      final printer = NetworkPrinter(PaperSize.mm80, profile);

      final PosPrintResult res = await printer.connect(ipAddress, port: 9100);
      if (res != PosPrintResult.success) {
        print("❌ Failed to connect to printer at $ipAddress: $res");
        return "❌ Failed to connect to printer: $res";
      }

      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      bytes += generator.reset();
      bytes += generator.rawBytes([0x1D, 0x4C, 0x00, 0x00]);
      bytes += generator.rawBytes([0x1B, 0x20, 0x00]);

      final salesPersonName = waiter.split('-')[1].trim();

      // Logo
      try {
        final box = Hive.box('logo');
        final Uint8List? imageBytes = box.get('BMlogo_bytes');
        final String? logoName = box.get('BMlogo_name');

        if (imageBytes != null) {
          print(
            "✅ Loaded logo from Hive ($logoName) | Size: ${imageBytes.lengthInBytes} bytes",
          );
          final img.Image? logo = img.decodeImage(imageBytes);

          if (logo != null) {
            print("🖼 Original Logo: ${logo.width}x${logo.height}");
            final img.Image whiteBg = img.Image(logo.width, logo.height);
            img.fill(whiteBg, img.getColor(255, 255, 255));
            img.copyInto(whiteBg, logo, blend: true);

            final img.Image gray = img.grayscale(whiteBg);
            img.Image binaryThreshold(img.Image src, int threshold) {
              final out = img.Image.from(src);
              for (int y = 0; y < out.height; y++) {
                for (int x = 0; x < out.width; x++) {
                  final int p = out.getPixel(x, y);
                  final int r = img.getRed(p);
                  final int g = img.getGreen(p);
                  final int b = img.getBlue(p);
                  final int lum = ((r * 299 + g * 587 + b * 114) ~/ 1000);
                  if (lum < threshold) {
                    out.setPixelRgba(x, y, 0, 0, 0, 255);
                  } else {
                    out.setPixelRgba(x, y, 255, 255, 255, 255);
                  }
                }
              }
              return out;
            }

            final img.Image thresholded = binaryThreshold(gray, 180);
            final img.Image resized = img.copyResize(thresholded, width: 250);
            final int remainder = resized.height % 8;
            img.Image aligned = resized;
            if (remainder != 0) {
              final int newHeight = resized.height + (8 - remainder);
              aligned = img.Image(resized.width, newHeight);
              img.fill(aligned, img.getColor(255, 255, 255));
              img.copyInto(aligned, resized, dstY: 0);
            }

            bytes += generator.image(aligned, align: PosAlign.center);
            print("🖨 Sent logo image to printer");
          }
        } else {
          print("⚠️ Logo not found in Hive!");
        }
      } catch (e, st) {
        print('🛑 Logo Print Error: $e');
        print(st);
      }

      // Header
      bytes += generator.row([
        PosColumn(
          width: 2,
          text: '',
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          width: 8,
          text: 'KOT Invoice',
          styles: const PosStyles(
            align: PosAlign.center,
            height: PosTextSize.size1,
            width: PosTextSize.size2,
            bold: true,
          ),
        ),
        PosColumn(
          width: 2,
          text: '',
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

      final now = DateTime.now();
      final formattedDate = DateFormat('dd-MM-yyyy').format(now);
      final formattedTime = DateFormat('hh:mm a').format(now);
      final tableOnlyNumber =
          RegExp(r'\d+').firstMatch(tableNumber)?.group(0) ?? tableNumber;

      bytes += generator.feed(1);

      bytes += generator.row([
        PosColumn(
          width: 6,
          text: 'Date: $formattedDate',
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          width: 6,
          text: 'Time: $formattedTime',
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

      bytes += generator.feed(1);

      bytes += generator.row([
        PosColumn(
          width: 5,
          text: 'Branch: $branchName',
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          width: 7,
          text: 'InvoiceNo: $invoiceNo',
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

      bytes += generator.feed(1);

      bytes += generator.row([
        PosColumn(
          width: 6,
          text: 'Sales Person: $salesPersonName',
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          width: 6,
          text: 'Table: $tableOnlyNumber / Seat: $seat',
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
      bytes += generator.feed(1);
      bytes += generator.hr();

      // Table header
      bytes += generator.row([
        PosColumn(
          width: 2,
          text: 'S.No',
          styles: const PosStyles(bold: true, align: PosAlign.left),
        ),
        PosColumn(
          width: 7,
          text: 'ITEM',
          styles: const PosStyles(bold: true, align: PosAlign.left),
        ),
        PosColumn(
          width: 3,
          text: 'AMOUNT',
          styles: const PosStyles(bold: true, align: PosAlign.right),
        ),
      ]);

      bytes += generator.hr();

      // Process orders
      final List<Map<String, dynamic>> rawItems = [];
      double originalSubTotal = 0.0;
      Map<double, double> itemTotalsMap = {};
      const bool isGSTEnabled = true;
      const double taxRate = 5.0; // Fixed 5% tax

      // for (var order in seatOrders) {
      //   debugPrint("order of the preinvoice is $order");
      //   if (order is! Map<String, dynamic>) continue;

      //   final List<Map<String, dynamic>> configs =
      //       (order['config'] as List?)
      //           ?.map((e) => e as Map<String, dynamic>)
      //           .toList() ??
      //       [];
      //   final List<double> prices =
      //       (order['prices'] as List?)
      //           ?.map((e) => safeCast<double>(e, 0.0))
      //           .toList() ??
      //       [];

      //   int configIndex = 0;

      //   // for (var config in configs) {
      //   //   debugPrint("config in preinvoice is : $config");

      //   //   final varianceName = config['varianceName']?.toString() ?? '';
      //   //   final List<int> configQty =
      //   //       (config['configQty'] as List?)
      //   //           ?.map((e) => safeCast<int>(e, 0))
      //   //           .toList() ??
      //   //       [];
      //   //   final List<List<String>> addOns =
      //   //       (config['addOn'] as List?)
      //   //           ?.map(
      //   //             (e) =>
      //   //                 List<String>.from((e as List).map((i) => i.toString())),
      //   //           )
      //   //           .toList() ??
      //   //       [];
      //   //   final List<List<int>> addOnQuantities =
      //   //       (config['addOnQuantities'] as List?)
      //   //           ?.map(
      //   //             (e) => List<int>.from(
      //   //               (e as List).map((i) => safeCast<int>(i, 0)),
      //   //             ),
      //   //           )
      //   //           .toList() ??
      //   //       [];
      //   //   final List<List<double>> addOnPrices =
      //   //       (config['addOnPrice'] as List?)
      //   //           ?.map(
      //   //             (e) => List<double>.from(
      //   //               (e as List).map((i) => safeCast<double>(i, 0.0)),
      //   //             ),
      //   //           )
      //   //           .toList() ??
      //   //       [];

      //   //   final price = (configIndex < prices.length)
      //   //       ? prices[configIndex]
      //   //       : 0.0;

      //   //   // Sum quantities for this config (variance)
      //   //   final totalQuantityForConfig = configQty.fold<int>(
      //   //     0,
      //   //     (sum, qty) => sum + qty,
      //   //   );

      //   //   debugPrint(
      //   //     "totalQuantityForConfig in preinvoice is : $totalQuantityForConfig",
      //   //   );

      //   //   // Sum add-on totals for this config
      //   //   double totalAddOnForConfig = 0.0;
      //   //   for (int i = 0; i < configQty.length; i++) {
      //   //     if (i < addOnPrices.length && addOnPrices[i].isNotEmpty) {
      //   //       totalAddOnForConfig +=
      //   //           addOnPrices[i].reduce((a, b) => a + b) * configQty[i];
      //   //     }
      //   //   }

      //   //   final itemAmount =
      //   //       (price * totalQuantityForConfig) + totalAddOnForConfig;

      //   //   debugPrint("itemAmount in preinvoice is : $itemAmount");

      //   //   final double weight = (config['weight'] as num?)?.toDouble() ?? 0.0;

      //   //   final item = {
      //   //     'varianceName': varianceName,
      //   //     'weight': weight, // ✅ CRITICAL
      //   //     'quantity': totalQuantityForConfig,
      //   //     'price': price,
      //   //     'itemAmount': itemAmount,
      //   //     'addOns': addOns,
      //   //     'addOnQuantities': addOnQuantities,
      //   //     'addOnPrices': addOnPrices,
      //   //     'configQty': configQty,
      //   //     'taxRate': taxRate,
      //   //   };

      //   //   debugPrint("item in preinvoice is : $item");

      //   //   originalSubTotal += itemAmount;
      //   //   if (isGSTEnabled) {
      //   //     itemTotalsMap[taxRate] =
      //   //         (itemTotalsMap[taxRate] ?? 0.0) + itemAmount;
      //   //   }

      //   //   rawItems.add(item);
      //   //   configIndex++;
      //   // }

      //   for (var config in configs) {
      //     debugPrint("config in preinvoice is : $config");

      //     final varianceName = config['varianceName']?.toString() ?? '';
      //     final List<int> configQty =
      //         (config['configQty'] as List?)
      //             ?.map((e) => safeCast<int>(e, 0))
      //             .toList() ??
      //         [];

      //     // 🚫 SKIP zero-quantity configs
      //     if (configQty.isEmpty || configQty.every((q) => q == 0)) {
      //       debugPrint(
      //         "⏭ Skipping config (all zero qty): $varianceName | $configQty",
      //       );
      //       configIndex++; // keep index alignment with prices
      //       continue;
      //     }

      //     final List<List<String>> addOns =
      //         (config['addOn'] as List?)
      //             ?.map(
      //               (e) =>
      //                   List<String>.from((e as List).map((i) => i.toString())),
      //             )
      //             .toList() ??
      //         [];

      //     final List<List<int>> addOnQuantities =
      //         (config['addOnQuantities'] as List?)
      //             ?.map(
      //               (e) => List<int>.from(
      //                 (e as List).map((i) => safeCast<int>(i, 0)),
      //               ),
      //             )
      //             .toList() ??
      //         [];

      //     final List<List<double>> addOnPrices =
      //         (config['addOnPrice'] as List?)
      //             ?.map(
      //               (e) => List<double>.from(
      //                 (e as List).map((i) => safeCast<double>(i, 0.0)),
      //               ),
      //             )
      //             .toList() ??
      //         [];

      //     final price = (configIndex < prices.length)
      //         ? prices[configIndex]
      //         : 0.0;

      //     // Sum quantities for this config
      //     final totalQuantityForConfig = configQty.fold<int>(
      //       0,
      //       (sum, qty) => sum + qty,
      //     );

      //     debugPrint(
      //       "totalQuantityForConfig in preinvoice is : $totalQuantityForConfig",
      //     );

      //     // Sum add-on totals
      //     double totalAddOnForConfig = 0.0;
      //     for (int i = 0; i < configQty.length; i++) {
      //       if (i < addOnPrices.length && addOnPrices[i].isNotEmpty) {
      //         totalAddOnForConfig +=
      //             addOnPrices[i].reduce((a, b) => a + b) * configQty[i];
      //       }
      //     }

      //     final itemAmount =
      //         (price * totalQuantityForConfig) + totalAddOnForConfig;

      //     final double weight = (config['weight'] as num?)?.toDouble() ?? 0.0;

      //     final item = {
      //       'varianceName': varianceName,
      //       'weight': weight,
      //       'quantity': totalQuantityForConfig,
      //       'price': price,
      //       'itemAmount': itemAmount,
      //       'addOns': addOns,
      //       'addOnQuantities': addOnQuantities,
      //       'addOnPrices': addOnPrices,
      //       'configQty': configQty,
      //       'taxRate': taxRate,
      //     };

      //     originalSubTotal += itemAmount;
      //     if (isGSTEnabled) {
      //       itemTotalsMap[taxRate] =
      //           (itemTotalsMap[taxRate] ?? 0.0) + itemAmount;
      //     }

      //     rawItems.add(item);
      //     configIndex++;
      //   }
      // }

      for (var order in seatOrders) {
        debugPrint("══════════════════════════════════════");
        debugPrint("➡️ ENTER ORDER LOOP");
        debugPrint("ORDER RAW DATA : $order");

        if (order is! Map<String, dynamic>) {
          debugPrint("❌ ORDER SKIPPED – NOT Map<String, dynamic>");
          continue;
        }

        final List<Map<String, dynamic>> configs =
            (order['config'] as List?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];

        final List<double> prices =
            (order['prices'] as List?)
                ?.map((e) => safeCast<double>(e, 0.0))
                .toList() ??
            [];

        debugPrint("CONFIG COUNT : ${configs.length}");
        debugPrint("PRICES LIST  : $prices");

        int configIndex = 0;

        for (var config in configs) {
          debugPrint("──────────────────────────────────────");
          debugPrint("➡️ CONFIG LOOP START");
          debugPrint("CONFIG INDEX (price index) : $configIndex");
          debugPrint("CONFIG RAW DATA            : $config");

          final varianceName = config['varianceName']?.toString() ?? '';
          debugPrint("VARIANCE NAME : $varianceName");

          final List<int> configQty =
              (config['configQty'] as List?)
                  ?.map((e) => safeCast<int>(e, 0))
                  .toList() ??
              [];

          debugPrint("CONFIG QTY LIST : $configQty");
          debugPrint(
            "ALL ZERO QTY ?  : ${configQty.isEmpty || configQty.every((q) => q == 0)}",
          );

          // 🚫 SKIP zero-quantity configs
          if (configQty.isEmpty || configQty.every((q) => q == 0)) {
            debugPrint("⏭ CONFIG SKIPPED (ALL QTY ZERO)");
            debugPrint("⏭ PRICE INDEX CONSUMED : $configIndex");
            configIndex++;
            continue;
          }

          final List<List<String>> addOns =
              (config['addOn'] as List?)
                  ?.map(
                    (e) =>
                        List<String>.from((e as List).map((i) => i.toString())),
                  )
                  .toList() ??
              [];

          final List<List<int>> addOnQuantities =
              (config['addOnQuantities'] as List?)
                  ?.map(
                    (e) => List<int>.from(
                      (e as List).map((i) => safeCast<int>(i, 0)),
                    ),
                  )
                  .toList() ??
              [];

          final List<List<double>> addOnPrices =
              (config['addOnPrice'] as List?)
                  ?.map(
                    (e) => List<double>.from(
                      (e as List).map((i) => safeCast<double>(i, 0.0)),
                    ),
                  )
                  .toList() ??
              [];

          debugPrint("ADDONS           : $addOns");
          debugPrint("ADDON QTY        : $addOnQuantities");
          debugPrint("ADDON PRICES     : $addOnPrices");

          final price = (configIndex < prices.length)
              ? prices[configIndex]
              : 0.0;
          debugPrint("PRICE USED (prices[$configIndex]) : $price");

          // Sum quantities
          final totalQuantityForConfig = configQty.fold<int>(
            0,
            (sum, qty) => sum + qty,
          );
          debugPrint("TOTAL QTY FOR CONFIG : $totalQuantityForConfig");

          // Sum add-on totals
          double totalAddOnForConfig = 0.0;
          for (int i = 0; i < configQty.length; i++) {
            debugPrint("ADDON LOOP INDEX : $i");

            if (i < addOnPrices.length && addOnPrices[i].isNotEmpty) {
              final addonSum =
                  addOnPrices[i].reduce((a, b) => a + b) * configQty[i];
              totalAddOnForConfig += addonSum;

              debugPrint(
                "ADDON[$i] → "
                "QTY=${configQty[i]} | "
                "PRICES=${addOnPrices[i]} | "
                "TOTAL=$addonSum",
              );
            } else {
              debugPrint("NO ADDON FOR INDEX $i");
            }
          }

          debugPrint("TOTAL ADDON AMOUNT : $totalAddOnForConfig");

          final double weight = (config['weight'] as num?)?.toDouble() ?? 0.0;
          debugPrint("ITEM WEIGHT : $weight");

          // ✅ FIXED ITEM AMOUNT LOGIC
          final bool isWeightBased = weight > 0.0;

          final double baseAmount = isWeightBased
              ? price * weight
              : price * totalQuantityForConfig;

          final double itemAmount = baseAmount + totalAddOnForConfig;

          debugPrint(
            isWeightBased
                ? "ITEM AMOUNT (WEIGHT BASED) : $price × $weight = $baseAmount"
                : "ITEM AMOUNT (PCS BASED)    : $price × $totalQuantityForConfig = $baseAmount",
          );

          debugPrint("FINAL ITEM AMOUNT : $itemAmount");

          final item = {
            'varianceName': varianceName,
            'weight': weight,
            'quantity': totalQuantityForConfig,
            'price': price,
            'itemAmount': itemAmount,
            'addOns': addOns,
            'addOnQuantities': addOnQuantities,
            'addOnPrices': addOnPrices,
            'configQty': configQty,
            'taxRate': taxRate,
          };

          debugPrint("FINAL ITEM OBJECT : $item");

          originalSubTotal += itemAmount;
          debugPrint("SUBTOTAL AFTER ITEM : $originalSubTotal");

          if (isGSTEnabled) {
            itemTotalsMap[taxRate] =
                (itemTotalsMap[taxRate] ?? 0.0) + itemAmount;
            debugPrint("GST[$taxRate] TOTAL : ${itemTotalsMap[taxRate]}");
          }

          rawItems.add(item);
          debugPrint("ITEM ADDED TO rawItems (count=${rawItems.length})");

          configIndex++;
          debugPrint("CONFIG INDEX INCREMENTED TO : $configIndex");
        }
      }

      // Group items by varianceName to aggregate quantities and totals
      // final Map<String, Map<String, dynamic>> groupedItems =
      //     <String, Map<String, dynamic>>{};
      // for (var item in rawItems) {
      //   final varianceName = item['varianceName'] as String;
      //   if (groupedItems.containsKey(varianceName)) {
      //     final existing = groupedItems[varianceName]!;
      //     existing['quantity'] =
      //         (existing['quantity'] as int) + (item['quantity'] as int);
      //     existing['itemAmount'] += item['itemAmount'];
      //     // Note: Addons are not aggregated here; if they differ across groups, you may need more complex logic
      //     // For now, we'll assume addons are consistent or print the first one's addons
      //     // If addons vary, consider summing totals but printing a note or handling separately
      //   } else {
      //     groupedItems[varianceName] = Map<String, dynamic>.from(item);
      //   }
      // }

      String itemKey(String name, double weight) =>
          '${name.trim()}|${weight.toStringAsFixed(3)}';

      final Map<String, Map<String, dynamic>> groupedItems = {};

      for (var item in rawItems) {
        final String name = item['varianceName'] as String;
        final double weight = item['weight'] as double;
        final String key = itemKey(name, weight);

        if (groupedItems.containsKey(key)) {
          final existing = groupedItems[key]!;
          existing['quantity'] =
              (existing['quantity'] as int) + (item['quantity'] as int);
          existing['itemAmount'] =
              (existing['itemAmount'] as double) +
              (item['itemAmount'] as double);
        } else {
          groupedItems[key] = Map<String, dynamic>.from(item);
        }
      }

      final List<Map<String, dynamic>> items = groupedItems.values.toList();

      debugPrint("items 02 in preinvoice is : $items");

      double grossTotal = originalSubTotal;
      double discountedGrossTotal = grossTotal; // No discount

      Map<double, double> cgstMap = {};
      Map<double, double> sgstMap = {};
      Map<double, double> netMap = {};

      if (isGSTEnabled) {
        itemTotalsMap.forEach((taxRate, grossWithTax) {
          double proportion = grossWithTax / grossTotal;
          double discountedGrossForRate =
              grossWithTax - (0.0 * proportion); // No discount

          double netForRate = discountedGrossForRate / (1 + (taxRate / 100));
          double taxForRate = discountedGrossForRate - netForRate;
          double cgstForRate = taxForRate / 2;
          double sgstForRate = taxForRate / 2;

          cgstMap[taxRate] = cgstForRate;
          sgstMap[taxRate] = sgstForRate;
          netMap[taxRate] = netForRate;
        });
      }

      double totalNetAmount = netMap.values.fold(0.0, (a, b) => a + b);
      double totalCGST = cgstMap.values.fold(0.0, (a, b) => a + b);
      double totalSGST = sgstMap.values.fold(0.0, (a, b) => a + b);
      double total = totalNetAmount + totalCGST + totalSGST;

      bytes += generator.feed(1);

      // Print grouped items
      int serialNumber = 1;
      debugPrint("itemsofthe : : $items");

      for (var groupedItem in items) {
        debugPrint("itemsofthe : : : $groupedItem");

        final itemName = capitalizeWords(groupedItem['varianceName']);
        debugPrint("itemName is $itemName");

        final int quantity = groupedItem['quantity'] ?? 0;
        debugPrint("quantity is $quantity");

        final double price = quantity == 0
            ? 0.0
            : (groupedItem['price'] as double);
        debugPrint("price is $price");

        // final double weight =
        //     (groupedItem['weight'] as num?)?.toDouble() ?? 0.0;
        // debugPrint("weight is $weight");

        // final bool isWeightBased = weight > 0.0;

        final double singleWeight =
            (groupedItem['weight'] as num?)?.toDouble() ?? 0.0;

        // final int quant = groupedItem['quantity'] ?? 0;

        final bool isWeightBased = singleWeight > 0.0;

        final double totalWeight = singleWeight * quantity;

        // ✅ CORRECT BASE AMOUNT
        final double origAmount = isWeightBased
            ? price * totalWeight
            : price * quantity;

        debugPrint("origAmount is $origAmount");

        final double taxRate = groupedItem['taxRate'];
        debugPrint("taxRate is $taxRate");

        final double itemAmount = (groupedItem['itemAmount'] as num).toDouble();

        final double addOnTotal = quantity == 0 ? 0.0 : itemAmount - origAmount;

        debugPrint("groupedItem['itemAmount'] is $itemAmount");
        debugPrint("addOnTotal is $addOnTotal");

        List<String> itemNameLines = _splitText(itemName, 15);

        bytes += generator.row([
          PosColumn(width: 1, text: serialNumber.toString()),
          PosColumn(width: 8, text: itemNameLines[0]),
          PosColumn(width: 3, text: ""),
        ]);

        if (itemNameLines.length > 1) {
          for (int j = 1; j < itemNameLines.length; j++) {
            bytes += generator.row([
              PosColumn(width: 1, text: ''),
              PosColumn(width: 8, text: itemNameLines[j]),
              PosColumn(width: 3, text: ''),
            ]);
          }
        }

        // ✅ DESCRIPTION FIX
        final String priceDescription = isWeightBased
            ? "$quantity x ${singleWeight.toStringAsFixed(3)} kg x $price (Tax $taxRate%)"
            : "$quantity x $price (Tax $taxRate%)";

        bytes += generator.row([
          PosColumn(width: 1, text: ''),
          PosColumn(width: 8, text: priceDescription),
          PosColumn(
            width: 3,
            text: "Rs ${origAmount.toStringAsFixed(2)}",
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);

        if (addOnTotal > 0) {
          bytes += generator.row([
            PosColumn(width: 1, text: ''),
            PosColumn(width: 8, text: 'AddOns Total'),
            PosColumn(
              width: 3,
              text: "Rs ${addOnTotal.toStringAsFixed(2)}",
              styles: const PosStyles(align: PosAlign.right),
            ),
          ]);
        }

        // ───── ADDONS (UNCHANGED) ─────
        final firstRawItem = rawItems.firstWhere(
          (raw) => raw['varianceName'] == groupedItem['varianceName'],
        );

        final addOns = firstRawItem['addOns'] as List;
        final addOnQuantities = firstRawItem['addOnQuantities'] as List;
        final addOnPrices = firstRawItem['addOnPrices'] as List;
        final configQty = firstRawItem['configQty'] as List<int>;

        Map<String, Map<String, dynamic>> uniqueAddOns = {};

        for (int j = 0; j < configQty.length; j++) {
          if (j < addOns.length && (addOns[j] as List).isNotEmpty) {
            for (int k = 0; k < (addOns[j] as List).length; k++) {
              final addonName = capitalizeWords((addOns[j] as List<String>)[k]);
              final qtyPerUnit = (addOnQuantities[j] as List<int>)[k] ?? 1;
              final unitPrice = (addOnPrices[j] as List<double>)[k] ?? 0.0;

              final totalQty = qtyPerUnit * configQty[j];
              final totalPrice = unitPrice * totalQty;

              uniqueAddOns.update(
                addonName,
                (e) => {
                  'name': addonName,
                  'totalQty': e['totalQty'] + totalQty,
                  'totalPrice': e['totalPrice'] + totalPrice,
                  'unitPrice': unitPrice,
                },
                ifAbsent: () => {
                  'name': addonName,
                  'totalQty': totalQty,
                  'totalPrice': totalPrice,
                  'unitPrice': unitPrice,
                },
              );
            }
          }
        }

        uniqueAddOns.values.forEach((addon) {
          bytes += generator.row([
            PosColumn(width: 1, text: ''),
            PosColumn(width: 8, text: addon['name']),
            PosColumn(
              width: 3,
              text: "",
              styles: const PosStyles(align: PosAlign.right),
            ),
          ]);
        });

        serialNumber++;
        bytes += generator.row([PosColumn(width: 12, text: '')]);
      }

      bytes += generator.hr();

      bytes += generator.row([
        PosColumn(
          width: 6,
          text: 'Item Total',
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          width: 6,
          text: 'Rs ${discountedGrossTotal.toStringAsFixed(2)}',
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

      bytes += generator.hr();

      bytes += generator.row([
        PosColumn(
          width: 12,
          text: 'TOTAL Rs ${total.round().toString()}',
          styles: const PosStyles(
            align: PosAlign.right,
            width: PosTextSize.size2,
            bold: true,
          ),
        ),
      ]);
      bytes += generator.feed(1);

      bytes += generator.hr();

      if (isGSTEnabled) {
        bytes += generator.row([
          PosColumn(
            width: 12,
            text: "Tax Details",
            styles: const PosStyles(bold: true, align: PosAlign.left),
          ),
        ]);
        bytes += generator.feed(1);

        bytes += generator.row([
          PosColumn(
            width: 5,
            text: "Net Amt",
            styles: const PosStyles(align: PosAlign.left),
          ),
          PosColumn(
            width: 2,
            text: ":",
            styles: const PosStyles(align: PosAlign.center),
          ),
          PosColumn(
            width: 5,
            text: "${totalNetAmount.toStringAsFixed(2)}",
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);

        sgstMap.forEach((rate, sgstAmount) {
          double cgstAmount = cgstMap[rate] ?? 0.0;
          final gst = cgstAmount + sgstAmount;
          bytes += generator.row([
            PosColumn(
              text: "GST($rate%) : ${gst.toStringAsFixed(2)}",
              width: 12,
              styles: const PosStyles(align: PosAlign.left),
            ),
          ]);
          bytes += generator.row([
            PosColumn(
              text:
                  "SGST(${(rate / 2).toStringAsFixed(1)}%): ${sgstAmount.toStringAsFixed(2)}",
              width: 6,
              styles: const PosStyles(align: PosAlign.left),
            ),
            PosColumn(
              text:
                  "CGST(${(rate / 2).toStringAsFixed(1)}%): ${cgstAmount.toStringAsFixed(2)}",
              width: 6,
              styles: const PosStyles(align: PosAlign.left),
            ),
          ]);
        });
      }

      bytes += generator.hr();

      bytes += generator.row([
        PosColumn(
          width: 12,
          text: 'Thank You ! Visit Again !',
          styles: const PosStyles(align: PosAlign.center, bold: true),
        ),
      ]);

      bytes += generator.feed(1);

      try {
        print("🏢 Fetching branch details...");
        Map<String, dynamic>? branchDetails = await getBranchDetails();
        String branchAddress =
            branchDetails?['address'] ?? 'Address not available';
        String branchCity = branchDetails?['city'] ?? '';
        String branchState = branchDetails?['state'] ?? '';
        String branchPostalCode =
            branchDetails?['postalCode']?.toString() ?? '';
        String branchPhoneNumber =
            branchDetails?['phoneNumber']?.toString() ?? '';

        String fullAddress =
            "$branchAddress, $branchName, $branchCity $branchState - $branchPostalCode";
        List<String> addressLines = splitAddress(fullAddress, maxLineWidth: 32);

        print("📄 Printing branch address (${addressLines.length} lines)...");
        for (var line in addressLines) {
          bytes += generator.text(
            _manualCenterText(line, 6),
            styles: const PosStyles(
              align: PosAlign.center,
              codeTable: 'CP1252',
            ),
          );
        }

        bytes += generator.text(
          _manualCenterText('Phone: $branchPhoneNumber', 5),
          styles: const PosStyles(align: PosAlign.center, codeTable: 'CP1252'),
        );

        bytes += generator.feed(1);

        print("✅ Branch details printed.");
      } catch (e) {
        print("🔥 Error printing branch details: $e");
      }

      bytes += generator.row([
        PosColumn(
          width: 6,
          text: 'GST: 33AATFB4124B1ZW',
          styles: const PosStyles(align: PosAlign.center),
        ),
        PosColumn(
          width: 6,
          text: 'FSSAI: 12420017000428',
          styles: const PosStyles(align: PosAlign.center),
        ),
      ]);

      bytes += generator.feed(2);
      bytes += generator.cut();

      // Send all bytes
      printer.rawBytes(Uint8List.fromList(bytes));
      await Future.delayed(const Duration(milliseconds: 200));
      printer.disconnect();

      print('🎉 Receipt printed successfully to printer at $ipAddress');
      return 'Receipt printed successfully';
    } catch (e, st) {
      print('🔥 Error printing receipt: $e\n$st');
      return 'Error printing receipt: $e';
    }
  }

  static String _manualCenterText(String text, int spaces) {
    // Implementation to center text with specified spaces
    return ' ' * spaces + text + ' ' * spaces;
  }

  static String capitalizeWords(String text) {
    if (text.isEmpty) return text;
    return text
        .toLowerCase()
        .split(' ')
        .map(
          (word) => word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1)}'
              : word,
        )
        .join(' ');
  }

  static List<String> _splitText(String text, int maxLineWidth) {
    List<String> lines = [];
    String remainingText = text;

    while (remainingText.length > maxLineWidth) {
      int lastIndex = remainingText.lastIndexOf(' ', maxLineWidth);
      if (lastIndex == -1) {
        lastIndex = maxLineWidth;
      }
      lines.add(remainingText.substring(0, lastIndex).trimRight());
      remainingText = remainingText.substring(lastIndex).trimLeft();
    }

    lines.add(remainingText);

    return lines;
  }

  static List<String> splitAddress(String address, {int maxLineWidth = 32}) {
    List<String> lines = [];
    String remaining = address;

    while (remaining.length > maxLineWidth) {
      int breakIndex = remaining.lastIndexOf(' ', maxLineWidth);
      if (breakIndex == -1) breakIndex = maxLineWidth;

      lines.add(remaining.substring(0, breakIndex).trim());
      remaining = remaining.substring(breakIndex).trim();
    }

    if (remaining.isNotEmpty) {
      lines.add(remaining);
    }

    return lines;
  }
}

/// Safe casting helper
T safeCast<T>(dynamic value, T defaultValue) {
  if (value is T) return value;
  if (value is num && T == double) return value.toDouble() as T;
  if (value is num && T == int) return value.toInt() as T;
  return defaultValue;
}
