import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:yen_pos/kotpreinvoice/services/format_weight.dart';

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
    required List<String> printerNames,
    bool isOverall = false,
    required String orderType,
  }) async {
    try {
      debugPrint("seatOrders => $seatOrders");
      if (seatOrders.isEmpty) return false;

      final profile = await CapabilityProfile.load();
      final printer = NetworkPrinter(PaperSize.mm80, profile);

      final res = await printer.connect(ipAddress, port: 9100);
      if (res != PosPrintResult.success) return false;

      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];
      const int lineWidth = 48;

      // ───────── HEADER ─────────
      bytes += generator.reset();
      bytes += generator.text(
        'KOT $orderType',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );

      bytes += generator.text(
        'Token: $tokenNumber',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );

      bytes += generator.text('Table: $tableNumber    Seat: $seat');
      bytes += generator.text('Captain: $userName');
      bytes += generator.text('Sales Person: $waiter');
      bytes += generator.hr(ch: '-');

      String cap(String s) => s
          .split(' ')
          .map(
            (e) => e.isEmpty
                ? e
                : e[0].toUpperCase() + e.substring(1).toLowerCase(),
          )
          .join(' ');

      // ───────── BUILD ROWS ─────────
      List<Map<String, dynamic>> buildRows(List<Map<String, dynamic>> items) {
        final List<Map<String, dynamic>> rows = [];

        for (final item in items) {
          final List configs = item['config'] ?? [];

          for (final cfg in configs) {
            final String name = cfg['varianceName'];
            final double weight = (cfg['weight'] ?? 0).toDouble();

            final List qtyList = cfg['configQty'] ?? [1];
            final List variants = cfg['variance'] ?? [];
            final List addOns = cfg['addOn'] ?? [];
            final List addOnQty = cfg['addOnQuantities'] ?? [];
            final List remarks = (cfg['remark'] is List) ? cfg['remark'] : [];
            final List types = (cfg['type'] is List) ? cfg['type'] : [];

            for (int i = 0; i < qtyList.length; i++) {
              rows.add({
                'varianceName': name,
                'weight': weight,
                'qty': 1,
                'addons': (i < addOns.length && addOns[i] is List)
                    ? List.from(addOns[i])
                    : [],
                'addonQty': (i < addOnQty.length && addOnQty[i] is List)
                    ? List.from(addOnQty[i])
                    : [],
                'variant': i < variants.length ? variants[i].toString() : '',
                'remark': i < remarks.length ? remarks[i].toString() : '',
                'type': i < types.length && types[i].toString().isNotEmpty
                    ? types[i].toString()
                    : 'Dining',
              });
            }
          }
        }
        return rows;
      }

      // ───────── MERGE SIMPLE ITEMS ONLY ─────────
      List<Map<String, dynamic>> mergeSimpleRows(
        List<Map<String, dynamic>> rows,
      ) {
        final Map<String, Map<String, dynamic>> merged = {};
        final List<Map<String, dynamic>> result = [];

        for (final row in rows) {
          final bool isSimple =
              (row['weight'] ?? 0) == 0 &&
              (row['addons'] as List).isEmpty &&
              (row['variant'] ?? '').toString().isEmpty &&
              (row['remark'] ?? '').toString().trim().isEmpty;

          if (!isSimple) {
            result.add(row); // keep complex items separate
            continue;
          }

          final key = row['varianceName'];

          if (merged.containsKey(key)) {
            merged[key]!['qty'] += row['qty'];
          } else {
            merged[key] = Map<String, dynamic>.from(row);
          }
        }

        result.addAll(merged.values);
        return result;
      }

      final allRows = buildRows(seatOrders);

      final diningRows = mergeSimpleRows(
        allRows.where((r) => r['type'] != 'Parcel').toList(),
      );

      final parcelRows = mergeSimpleRows(
        allRows.where((r) => r['type'] == 'Parcel').toList(),
      );

      // ───────── TABLE HEADER ─────────
      bytes += generator.row([
        PosColumn(text: 'S.No', width: 2, styles: const PosStyles(bold: true)),
        PosColumn(
          text: 'Item Name',
          width: 7,
          styles: const PosStyles(bold: true),
        ),
        PosColumn(
          text: 'Qty',
          width: 3,
          styles: const PosStyles(bold: true, align: PosAlign.right),
        ),
      ]);

      bytes += generator.text('-' * lineWidth);

      // ───────── DINING ─────────
      if (diningRows.isNotEmpty) {
        bytes += generator.text('DINING', styles: const PosStyles(bold: true));
        bytes += generator.text('-' * lineWidth);

        int sno = 1;
        for (final row in diningRows) {
          bytes += generator.row([
            PosColumn(text: '$sno', width: 2),
            PosColumn(text: cap(row['varianceName']), width: 7),
            PosColumn(
              text: row['qty'].toString(),
              width: 3,
              styles: const PosStyles(align: PosAlign.right),
            ),
          ]);

          final double weight = (row['weight'] ?? 0).toDouble();
          if (weight > 0) {
            bytes += generator.text(
              '  weight : ${weight.toStringAsFixed(3)} kg',
            );
          }

          for (int i = 0; i < row['addons'].length; i++) {
            bytes += generator.text(
              '  + ${row['addons'][i]} x${row['addonQty'][i]}',
            );
          }

          if ((row['variant'] ?? '').toString().isNotEmpty) {
            bytes += generator.text('  * ${row['variant']}');
          }

          final rmk = (row['remark'] ?? '').toString().trim();
          if (rmk.isNotEmpty) {
            bytes += generator.text('  Remark: $rmk');
          }

          bytes += generator.feed(1);
          sno++;
        }
      }

      // ───────── PARCEL ─────────
      if (parcelRows.isNotEmpty) {
        bytes += generator.hr(ch: '=');
        bytes += generator.text('PARCEL', styles: const PosStyles(bold: true));
        bytes += generator.text('-' * lineWidth);

        int sno = 1;
        for (final row in parcelRows) {
          bytes += generator.row([
            PosColumn(text: '$sno', width: 2),
            PosColumn(text: cap(row['varianceName']), width: 7),
            PosColumn(
              text: row['qty'].toString(),
              width: 3,
              styles: const PosStyles(align: PosAlign.right),
            ),
          ]);

          final double weight = (row['weight'] ?? 0).toDouble();
          if (weight > 0) {
            bytes += generator.text(
              '  weight : ${weight.toStringAsFixed(3)} kg',
            );
          }

          for (int i = 0; i < row['addons'].length; i++) {
            bytes += generator.text(
              '  + ${row['addons'][i]} x${row['addonQty'][i]}',
            );
          }

          if ((row['variant'] ?? '').toString().isNotEmpty) {
            bytes += generator.text('  * ${row['variant']}');
          }

          final rmk = (row['remark'] ?? '').toString().trim();
          if (rmk.isNotEmpty) {
            bytes += generator.text('  Remark: $rmk');
          }

          bytes += generator.feed(1);
          sno++;
        }
      }

      // ───────── FOOTER ─────────
      bytes += generator.text('=' * lineWidth);
      bytes += generator.text('Date: $date   Time: $time');
      bytes += generator.cut();

      printer.rawBytes(Uint8List.fromList(bytes));
      printer.disconnect();

      return true;
    } catch (e, stack) {
      debugPrint('❌ PRINT ERROR => $e');
      debugPrint('$stack');
      return false;
    }
  }

  /// **🔹 Check if order already exists in Hive**
  static Future<bool> _isOrderAlreadyStored(int tokenNumber) async {
    final box = Hive.box('pendingPrintOrders');
    List<dynamic> pendingOrders = box.get('ordersBox', defaultValue: []);

    return pendingOrders.any((order) => order["tokenNumber"] == tokenNumber);
  }

  static Future<void> _storeUnprintedOrder(
    Map<String, dynamic> orderData,
  ) async {
    print("pending orders called...");
    Box box;
    if (Hive.isBoxOpen('pendingPrintOrders')) {
      box = Hive.box('pendingPrintOrders');
    } else {
      box = await Hive.openBox('pendingPrintOrders'); // ✅ open here if needed
    }
    final List<dynamic> pendingOrders = box.get('ordersBox', defaultValue: []);

    pendingOrders.add(
      Map<String, dynamic>.from(orderData),
    ); // ✅ Explicit casting
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
      final List<Map<String, dynamic>> seatOrders =
          (order["seatOrders"] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();

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
        printerNames: [],
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
      final socket = await Socket.connect(
        ipAddress,
        9100,
        timeout: const Duration(seconds: 3),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }
}

List<List<Map<String, dynamic>>> processOrders(
  List<Map<String, dynamic>> seatOrders,
) {
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
          .map(
            (e) =>
                (e as List<dynamic>?)?.map((s) => s.toString()).toList() ?? [],
          )
          .toList();
      List<String> variances = (config['variance'] as List<dynamic>? ?? [])
          .map((e) => e?.toString() ?? "")
          .toList();
      String remark = config['remark'] ?? "";
      List<String> types = (config['type'] as List<dynamic>? ?? [])
          .map((e) => e?.toString() ?? "")
          .toList();

      Map<String, dynamic> groupedItems = {};

      for (int i = 0; i < configQty.length; i++) {
        // Ensure index is within safe bounds
        String addOnString = i < addOns.length ? addOns[i].join(", ") : "";
        String varianceString = i < variances.length ? variances[i] : "";
        // String remarkString = i < remarks.length ? remarks[i] : "";

        // Handle the type string more robustly
        String typeString = (i < types.length && types[i].trim().isNotEmpty)
            ? types[i].trim().toLowerCase()
            : "dining";

        // Create a unique key to group items
        String key =
            '$varianceName|$addOnString|$varianceString|$remark|$typeString';

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
            'remark': remark,
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

      debugPrint("Grouped Items for ${varianceName}: $groupedItems");

      // Debugging Output
    }
  }

  return [diningList, parcelList];
}
