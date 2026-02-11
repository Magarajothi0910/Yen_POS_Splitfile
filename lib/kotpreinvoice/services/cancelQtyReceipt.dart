import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'dart:typed_data';

import '../providers/printer_provider.dart';

Future<void> printFormattedReceipt(Map<String, dynamic> order, PrinterProviderDine printerProvider) async {
  List<Map<String, dynamic>> config = List<Map<String, dynamic>>.from(order['config']);
  List<double> quantities = List<double>.from(order['quantities']);
  List<String> varianceNames = List<String>.from(order['varianceNames']);

  for (int i = 0; i < config.length; i++) {
    if (i < quantities.length && quantities[i] > 0) {
      String? printerIp = printerProvider.getPrinterIpForItem(varianceNames[i]);

      if (printerIp == null) {
        print("⚠️ No printer assigned for ${varianceNames[i]}");
        continue;
      }

      try {
        print("🖨 Connecting to printer at $printerIp...");
        final profile = await CapabilityProfile.load();
        final printer = NetworkPrinter(PaperSize.mm58, profile);

        final PosPrintResult res = await printer.connect(printerIp, port: 9100);
        if (res != PosPrintResult.success) {
          print("❌ Failed to connect to printer: $res");
          return;
        }

        printer.rawBytes(Uint8List.fromList([27, 64])); // ESC @ (Reset)

        // Header
        printer.text(
          _manualCenterText('ORDER CANCELLED', 30),
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ),
        );
        printer.feed(1);

        printer.text('TABLE SERVICE',
            styles: const PosStyles(
              align: PosAlign.center,
              height: PosTextSize.size2,
              width: PosTextSize.size2,
            ));
        printer.text('________________________________________________');

        _printOrderList(printer, config[i], varianceNames[i], quantities[i]);

        printer.text('================================================');
        printer.cut();
        printer.disconnect();
        print("✅ Receipt printed successfully for ${varianceNames[i]}!");
      } catch (e, st) {
        print("🔥 Error printing receipt for ${varianceNames[i]}: $e\n$st");
      }
    }
  }
}

void _printOrderList(NetworkPrinter printer, Map<String, dynamic> configItem, String varianceName, double quantity) {
  printer.text('S.No  Item Name       Qty    CancelledQty', styles: const PosStyles(bold: true));
  printer.text('________________________________________________');

  int index = 1;
  List<int> configQty = List<int>.from(configItem['configQty'] ?? []);
  List<List<Map<String, dynamic>>> addOns = (configItem['addOn'] as List<dynamic>? ?? [])
      .map((e) => (e as List<dynamic>?)?.map((s) => s is Map ? {'name': s['name'], 'quantity': s['quantity'] ?? 1} : {'name': s.toString(), 'quantity': 1}).toList() ?? [])
      .toList();

  List<String> variances = List<String>.from(configItem['variance'] ?? []);
  List<String> remarks = List<String>.from(configItem['remark'] ?? []);
  List<String> types = List<String>.from(configItem['type'] ?? []);

  for (int j = 0; j < configQty.length; j++) {
    if (configQty[j] > 0) {
      String cancelledQty = (configItem['cancelledQty'] != null && configItem['cancelledQty'].length > j) ? configItem['cancelledQty'][j].toString() : "0";

      printer.text('${index.toString().padRight(4)}${varianceName.padRight(15)}'
          '${quantity.toString().padLeft(6)}'
          '${cancelledQty.padLeft(10)}');

      // Print add-ons with quantity
      if (j < addOns.length && addOns[j].isNotEmpty) {
        printer.text('  Add-ons:', styles: const PosStyles(bold: true));
        for (var addOn in addOns[j]) {
          String name = addOn['name'] ?? 'Addon';
          int qty = addOn['quantity'] ?? 1;
          String formattedAddOn = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() + name.trim().substring(1).toLowerCase() : name.trim();
          printer.text('   $formattedAddOn x$qty');
        }
      }

      // Print variant
      if (j < variances.length && variances[j].isNotEmpty) {
        printer.text('  Variant: ${variances[j]}');
      }

      // Print remark
      if (j < remarks.length && remarks[j].isNotEmpty) {
        printer.text('  Remark: ${remarks[j]}');
      }

      index++;
      printer.feed(1);
    }
  }
}

// Helper function to center align text
String _manualCenterText(String text, int totalWidth) {
  int padSize = (totalWidth - text.length) ~/ 2;
  return padSize > 0 ? ' ' * padSize + text + ' ' * padSize : text;
}
