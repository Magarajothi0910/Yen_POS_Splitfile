import 'dart:typed_data';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:intl/intl.dart';

import '../widgets/capitalizeWord.dart';

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
    try {
      final profile = await CapabilityProfile.load();
      final printer = NetworkPrinter(PaperSize.mm58, profile);

      final PosPrintResult res = await printer.connect(ipAddress, port: 9100);
      if (res != PosPrintResult.success) {
        return;
      }
      printer.rawBytes(Uint8List.fromList([27, 64])); // ESC @ (Reset Printer)

      // Process orders to split dining and parcel items
      List<List<Map<String, dynamic>>> processedOrders =
          processOrders(seatOrders);
      List<Map<String, dynamic>> diningList = processedOrders[0];
      List<Map<String, dynamic>> parcelList = processedOrders[1];

      // Print receipt header
      printer.text(
        _manualCenterText('ORDER CANCELLED    ', 30),
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );

      printer.text(receiptType,
          styles: const PosStyles(
            align: PosAlign.center,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ));
      printer.text('________________________________________________');
      printer.text('  Table: $tableNumber',
          styles: const PosStyles(bold: true));
      printer.text('  Seat: $seat', styles: const PosStyles(bold: true));
      printer.text('  Waiter: $waiter', styles: const PosStyles(bold: true));
      printer.text('  Captain: $userName', styles: const PosStyles(bold: true));
      printer.feed(1); // Adds a line space

      printer.text('Date: $formattedDate  Time: $formattedTime',
          styles: const PosStyles(align: PosAlign.center));
      printer.feed(1); // Adds a line space

      // Print Dining Items
      if (diningList.isNotEmpty) {
        printer.text('TABLE SERVICE',
            styles: const PosStyles(
              align: PosAlign.center,
              height: PosTextSize.size2,
              width: PosTextSize.size2,
            ));
        printer.text('________________________________________________');
        _printOrderList(printer, diningList);
      }
      printer.text('================================================');

      // Print Parcel Items
      if (parcelList.isNotEmpty) {
        printer.text('PARCEL ORDERS',
            styles: const PosStyles(
              bold: true,
              align: PosAlign.center,
              height: PosTextSize.size2,
              width: PosTextSize.size2,
            ));
        printer.text('________________________________________________');
        _printOrderList(printer, parcelList);
      }

      // printer.text('________________________________________________');

      printer.cut();
      printer.disconnect();
    } catch (e) {
    }
  }

  static void _printOrderList(
      NetworkPrinter printer, List<Map<String, dynamic>> orderList) {
    printer.text('S.No  Item Name            Qty    CancelledQty',
        styles: const PosStyles(bold: true));
    printer.text('________________________________________________');

    int index = 1;
    for (var item in orderList) {
      // Check and print the cancelled quantity correctly
      String cancelledQty =
          item['quantity'] > 0 ? item['quantity'].toString() : "0";

      printer.text(
          '${index.toString().padRight(2)}${capitalizeWords(item['varianceName']).padRight(20)}'
          '${item['quantity'].toString().padLeft(6)}'
          '${cancelledQty.padLeft(10)}');

      if (item['addOns'].isNotEmpty) {
        printer.text('  Add-ons:', styles: const PosStyles(bold: true));

        List<String> addOnList = item['addOns'].split(", ");
        for (var addOn in addOnList) {
          // Capitalize first letter and lowercase the rest
          String formattedAddOn = addOn.trim().isNotEmpty
              ? addOn.trim()[0].toUpperCase() +
                  addOn.trim().substring(1).toLowerCase()
              : addOn.trim();

          printer.text('   $formattedAddOn');
        }
      }

      if (item['variant'].isNotEmpty) {
        printer.text('  Variant: ${item['variant']}');
      }

      if (item['remark'].isNotEmpty) {
        printer.text('  Remark: ${item['remark']}');
      }
      index++;
      printer.feed(1); // Adds a line space
    }
  }

  static List<List<Map<String, dynamic>>> processOrders(
      List<Map<String, dynamic>> seatOrders) {
    List<Map<String, dynamic>> diningList = [];
    List<Map<String, dynamic>> parcelList = [];

    for (var order in seatOrders) {
      if (order['config'] == null) continue;

      for (var config in order['config']) {
        String varianceName = config['varianceName'] ?? '';
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
          String addOnString = i < addOns.length ? addOns[i].join(", ") : "";
          String varianceString = i < variances.length ? variances[i] : "";
          String remarkString = i < remarks.length ? remarks[i] : "";

          String typeString = (i < types.length && types[i].trim().isNotEmpty)
              ? types[i].trim().toLowerCase()
              : "dining";

          // Use the correct cancelledQty from the seatOrders
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
              'addOns': addOnString,
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
