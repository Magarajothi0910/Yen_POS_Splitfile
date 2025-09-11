import 'dart:typed_data';

import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:intl/intl.dart';

import '../widgets/capitalizeWord.dart';

class PreInvoicePrinter {
  static Future<void> printReceipt({
    required String ipAddress,
    required String tableNumber,
    required String seat,
    required List<dynamic> seatOrders,
    required String receiptType,
    required String userName,
    required String waiter, // PreInvoice or Invoice
  }) async {
    try {
      final profile = await CapabilityProfile.load();
      final printer = NetworkPrinter(PaperSize.mm80, profile);

      // Connect to the printer
      final PosPrintResult res = await printer.connect(ipAddress, port: 9100);
      if (res != PosPrintResult.success) {
        return;
      }

      printer.rawBytes(Uint8List.fromList([27, 64])); // ESC @

      // Get the current date and time
      final now = DateTime.now();
      final formattedDate = DateFormat('dd-MM-yyyy').format(now);
      final formattedTime = DateFormat('HH:mm:ss').format(now);
      String kotText =
          _manualCenterText('KOT ', 5); // Assuming a 32 character line width
      // Print receipt header
      printer.text(
        '',
        styles: const PosStyles(align: PosAlign.center),
      );
      printer.text(
        "$kotText- $receiptType",
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true, // Make the text bold
          height: PosTextSize.size2, // Maximum font height
          width: PosTextSize.size2, // Maximum font width
        ),
      );
      printer.feed(1);
      final RegExp regExp = RegExp(r'\d+'); // Extract digits
      final String tableOnlyNumber =
          regExp.firstMatch(tableNumber)?.group(0) ?? tableNumber;
      final tableSeatText =
          '${'Table  : $tableOnlyNumber'.padRight(20)}Seat  : $seat';
      printer.text(
        tableSeatText,
        styles: const PosStyles(align: PosAlign.left),
      );

      printer.feed(1);
      final dateTimeText =
          '${'Date  : $formattedDate'.padRight(20)}Time  : $formattedTime';
      printer.text(
        dateTimeText,
        styles: const PosStyles(align: PosAlign.left),
      );
      printer.feed(1);

      // User and Waiter on the same row, evenly spaced
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

      // Print table and seat information with equal spacing

      // Print date and time information with equal spacing

      printer.feed(1);

      printer.text(
        '------------------------------------------------',
        styles: const PosStyles(align: PosAlign.center),
      );

      // Print Headers for Items
      printer.text(
        '${_alignText("S.N", 3)} ${_alignText("Item", 20)} ${_alignText("Price", 5)}  ${_alignText("Qty", 4)} ${_alignText("Ttl", 4)}',
        styles: const PosStyles(align: PosAlign.left, bold: true),
      );
      printer.text(
        '------------------------------------------------',
        styles: const PosStyles(align: PosAlign.center),
      );
      int serialNumber = 1; // Initialize serial number
      double overallTotal = 0.0; // Initialize overall total

      for (var orderIndex = 0; orderIndex < seatOrders.length; orderIndex++) {
        final order = seatOrders[orderIndex];

        if (order is Map<String, dynamic>) {
          List<String> itemNames = (order['itemNames'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          List<String> varianceNames =
              (order['varianceNames'] as List<dynamic>?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  [];
          List<Map<String, dynamic>> configs =
              (order['config'] as List<dynamic>?)
                      ?.map((e) => e as Map<String, dynamic>)
                      .toList() ??
                  [];
          List<double> prices = (order['prices'] as List<dynamic>?)
                  ?.map((e) => (e as num?)?.toDouble() ?? 0.0)
                  .toList() ??
              [];
          List<double> quantities = (order['quantities'] as List<dynamic>?)
                  ?.map((e) => (e as num?)?.toDouble() ?? 0.0)
                  .toList() ??
              [];
          List<double> weights = List<double>.from(
              order['weights'].map((e) => (e as num).toDouble()));
          List<double> amounts = (order['amounts'] as List<dynamic>?)
                  ?.map((e) => (e as num?)?.toDouble() ?? 0.0)
                  .toList() ??
              [];

          printer.text(
            'Order ${orderIndex + 1} (Token No: ${order['tokenNo']})',
            styles: const PosStyles(align: PosAlign.left, bold: true),
          );

          Map<String, Map<String, dynamic>> groupedItems = {};

          for (var i = 0; i < itemNames.length; i++) {
            final String itemName = varianceNames[i];
            final double price = prices[i];
            final double quantity = quantities[i];
            final double amount = amounts[i];
            final double weight = weights[i];
            final String weightText =
                weight != 0.0 ? '  ${weight.toStringAsFixed(2)}' : '';
            double calculatedAmount =
                (weight > 0) ? (quantity * price * weight) : (quantity * price);
            overallTotal += calculatedAmount;

            if (quantity > 0 && amount > 0) {
              // Grouping items by variance name
              if (groupedItems.containsKey(itemName)) {
                groupedItems[itemName]!['quantity'] += quantity;
                groupedItems[itemName]!['amount'] += amount;
              } else {
                groupedItems[itemName] = {
                  'price': price,
                  'quantity': quantity,
                  'weight': weightText,
                  'amount': amount,
                  'config': configs.firstWhere(
                    (config) => config['varianceName'] == itemName,
                    orElse: () => {},
                  )
                };
              }
            }
          }

          // Print grouped items
          groupedItems.forEach((variance, details) {
            printer.feed(1);
            printer.text(
              '${_alignText(serialNumber.toString(), 2)} ${_alignText(capitalizeWords(variance), 20)} ${_alignText(_formatNumber(details['price']), 6)}  ${_alignText(_formatNumber(details['quantity']), 5)} ${_alignText(_formatNumber(details['amount']), 5)}',
              styles: const PosStyles(align: PosAlign.left),
            );

// Print weight separately on the next line under item name
            if (details['weight'] != null &&
                details['weight'].toString().trim().isNotEmpty) {
              printer.text(
                '   Wt: ${details['weight']}',
                styles: const PosStyles(align: PosAlign.left),
              );
            }
            serialNumber++;

            // Process add-ons and variances
            final itemConfig = details['config'];
            if (itemConfig.isNotEmpty) {
              List<String> variances =
                  List<String>.from(itemConfig['variance'] ?? []);
              List<List<String>> addOns = (itemConfig['addOn']
                          as List<dynamic>?)
                      ?.map((e) =>
                          List<String>.from(e.map((item) => item.toString())))
                      .toList() ??
                  [];
              List<List<int>> addOnPrices = (itemConfig['addOnPrice']
                          as List<dynamic>?)
                      ?.map((e) => List<int>.from(e.map((item) => item as int)))
                      .toList() ??
                  [];
              List<int> configQty =
                  List<int>.from(itemConfig['configQty'] ?? []);

              // Group variances
              Map<String, int> groupedVariances = {};
              for (var v in variances) {
                if (v.isNotEmpty && v.toLowerCase() != "default") {
                  if (groupedVariances.containsKey(v)) {
                    groupedVariances[v] = (groupedVariances[v] ?? 0) + 1;
                  } else {
                    groupedVariances[v] = 1;
                  }
                }
              }

// Print grouped variances
              for (var entry in groupedVariances.entries) {
                if (entry.value > 0) {
                  printer.text(
                    '${_alignText("", 2)} - ${_alignText("${entry.key}", 20)}       ${_alignText(entry.value.toString(), 4)}',
                    styles: const PosStyles(align: PosAlign.left),
                  );
                }
              }
              // Group and print add-ons
              Map<String, Map<String, int>> groupedAddOns = {};
              for (var j = 0; j < addOns.length; j++) {
                for (var k = 0; k < addOns[j].length; k++) {
                  if (j < addOnPrices.length && k < addOnPrices[j].length) {
                    String addOnName = addOns[j][k];
                    int addOnPrice = addOnPrices[j][k];
                    int addOnQuantity =
                        (k < configQty.length) ? configQty[k] : 1;
                    int totalAddOnPrice = addOnPrice * addOnQuantity;

                    if (groupedAddOns.containsKey(addOnName)) {
                      groupedAddOns[addOnName]!['quantity'] =
                          groupedAddOns[addOnName]!['quantity']! +
                              addOnQuantity!;

                      groupedAddOns[addOnName]!['totalPrice'] =
                          groupedAddOns[addOnName]!['totalPrice']! +
                              totalAddOnPrice!;
                    } else {
                      groupedAddOns[addOnName] = {
                        'quantity': addOnQuantity,
                        'unitPrice': addOnPrice,
                        'totalPrice': totalAddOnPrice
                      };
                    }
                  }
                }
              }

              // Print grouped add-ons
              for (var entry in groupedAddOns.entries) {
                printer.text(
                  '${_alignText("", 2)} ${_alignText("-> ${capitalizeWords(entry.key)}", 20)} ${_alignText(entry.value['unitPrice'].toString(), 6)}  ${_alignText(entry.value['quantity'].toString(), 5)}  ${_alignText(entry.value['totalPrice'].toString(), 5)}',
                  styles: const PosStyles(align: PosAlign.left),
                );
                overallTotal += (entry.value['totalPrice'] ?? 0); // ✅ ADD THIS
              }
            }
          });
        }
      }

// Print total amount
      printer.text(
        '------------------------------------------------',
        styles: const PosStyles(align: PosAlign.center),
      );
      printer.text(
        'Total: ${overallTotal.toStringAsFixed(2)}',
        styles: const PosStyles(
          align: PosAlign.right,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );

      printer.feed(1);
      printer.cut();
      printer.disconnect();

      printer.feed(1);
      printer.cut();
      printer.disconnect();

    } catch (e) {
    }
  }

  static String _alignText(String text, int length) {
    return text.padRight(length).substring(0, length);
  }

  static String _formatNumber(double value) {
    return value == value.floor()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
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

T safeCast<T>(dynamic value, T defaultValue) {
  if (value is T) {
    return value;
  } else if (value is num && T == double) {
    return value.toDouble() as T;
  } else if (value is num && T == int) {
    return value.toInt() as T;
  }
  return defaultValue;
}

// import 'dart:typed_data';
// import 'package:esc_pos_utils/esc_pos_utils.dart';
// import 'package:esc_pos_printer/esc_pos_printer.dart';
// import 'package:intl/intl.dart';
// import 'package:server/widgets/capitalizeWord.dart';

// class PreInvoicePrinter {
//   static Future<void> printReceipt({
//     required String ipAddress,
//     required String tableNumber,
//     required String seat,
//     required double total,
//     required List<dynamic> seatOrders,
//     required String receiptType,
//     required String userName,
//     required String waiter,
//   }) async {
//     try {
//       final profile = await CapabilityProfile.load();
//       final printer = NetworkPrinter(PaperSize.mm80, profile);
//       final PosPrintResult res = await printer.connect(ipAddress, port: 9100);

//       if (res != PosPrintResult.success) {
//         print('Failed to connect to printer: $res');
//         return;
//       }

//       printer.rawBytes(Uint8List.fromList([27, 64])); // ESC @ reset
//       _printHeader(printer, tableNumber, seat, receiptType, userName, waiter);
//       _printOrders(printer, seatOrders);
//       _printFooter(printer, total);

//       printer.cut();
//       printer.disconnect();

//       print('Receipt printed to printer at $ipAddress');
//     } catch (e) {
//       print('Error printing receipt: $e');
//     }
//   }

//   static void _printHeader(NetworkPrinter printer, String tableNumber,
//       String seat, String receiptType, String userName, String waiter) {
//     final now = DateTime.now();
//     final date = DateFormat('dd-MM-yyyy').format(now);
//     final time = DateFormat('HH:mm:ss').format(now);

//     final tableNum =
//         RegExp(r'\d+').firstMatch(tableNumber)?.group(0) ?? tableNumber;

//     printer.text('');
//     printer.text('   KOT - $receiptType',
//         styles: PosStyles(
//             align: PosAlign.center,
//             bold: true,
//             height: PosTextSize.size2,
//             width: PosTextSize.size2));
//     printer.feed(1);
//     printer.text('Table  : $tableNum    Seat  : $seat');
//     printer.text('Date   : $date       Time  : $time');
//     printer.text('Captain: $userName');
//     printer.text('Waiter : $waiter');
//     printer.feed(1);
//     printer.text('-' * 48);
//     printer.text(
//         '${_align("S.N", 3)} ${_align("Item", 20)} ${_align("Price", 5)}  ${_align("Qty", 4)} ${_align("Ttl", 4)}',
//         styles: const PosStyles(bold: true));
//     printer.text('-' * 48);
//   }

//   static void _printOrders(NetworkPrinter printer, List<dynamic> seatOrders) {
//     int sn = 1;

//     for (var order in seatOrders) {
//       if (order is! Map<String, dynamic>) continue;

//       final token = order['tokenNo'] ?? 'N/A';
//       printer.text('Order $sn (Token: $token)',
//           styles: const PosStyles(bold: true));

//       final itemData = _groupItems(order);
//       itemData.forEach((name, item) {
//         if (item.quantity <= 0 || item.amount <= 0) return;

//         printer.feed(1);
//         printer.text(
//             '${_align(sn.toString(), 2)} ${_align(capitalizeWords(name), 20)} ${_align(_fmt(item.price), 6)}  ${_align(_fmt(item.quantity), 5)} ${_align(_fmt(item.amount), 5)}');

//         if (item.weight != null) {
//           printer.text('   Wt: ${item.weight}');
//         }

//         _printConfigs(printer, item.config);
//         sn++;
//       });
//     }
//   }

//   static void _printFooter(NetworkPrinter printer, double total) {
//     printer.text('-' * 48);
//     printer.text('Total: ${total.toStringAsFixed(2)}',
//         styles: const PosStyles(
//             align: PosAlign.right,
//             bold: true,
//             height: PosTextSize.size2,
//             width: PosTextSize.size2));
//     printer.feed(1);
//   }

//   static Map<String, ItemData> _groupItems(Map<String, dynamic> order) {
//     List<String> names = List<String>.from(order['varianceNames'] ?? []);
//     List<double> prices = List<double>.from(
//         order['prices']?.map((e) => (e as num).toDouble()) ?? []);
//     List<double> qtys = List<double>.from(
//         order['quantities']?.map((e) => (e as num).toDouble()) ?? []);
//     List<double> amts = List<double>.from(
//         order['amounts']?.map((e) => (e as num).toDouble()) ?? []);
//     List<double> weights = List<double>.from(
//         order['weights']?.map((e) => (e as num).toDouble()) ?? []);
//     List<Map<String, dynamic>> configs =
//         List<Map<String, dynamic>>.from(order['config'] ?? []);

//     Map<String, ItemData> grouped = {};
//     for (int i = 0; i < names.length; i++) {
//       final name = names[i];
//       final config = configs.firstWhere((c) => c['varianceName'] == name,
//           orElse: () => {});

//       if (grouped.containsKey(name)) {
//         grouped[name]!.quantity += qtys[i];
//         grouped[name]!.amount += amts[i];
//       } else {
//         grouped[name] = ItemData(
//           price: prices[i],
//           quantity: qtys[i],
//           amount: amts[i],
//           weight: weights[i] != 0 ? weights[i].toStringAsFixed(2) : null,
//           config: config,
//         );
//       }
//     }

//     return grouped;
//   }

//   static void _printConfigs(
//       NetworkPrinter printer, Map<String, dynamic> config) {
//     if (config.isEmpty) return;

//     final variances = List<String>.from(config['variance'] ?? []);
//     final addOns = List<List<String>>.from(
//         config['addOn']?.map<List<String>>((e) => List<String>.from(e)) ?? []);
//     final addOnPrices = List<List<int>>.from(
//         config['addOnPrice']?.map<List<int>>((e) => List<int>.from(e)) ?? []);
//     final qtys = List<int>.from(config['configQty'] ?? []);

//     // Variance print
//     variances
//         .where((v) => v.isNotEmpty && v.toLowerCase() != 'default')
//         .forEach((v) {
//       printer.text('${_align("", 2)} - ${_align(v, 20)}     1');
//     });

//     // Add-ons
//     Map<String, AddOnData> grouped = {};
//     for (int i = 0; i < addOns.length; i++) {
//       for (int j = 0; j < addOns[i].length; j++) {
//         final name = addOns[i][j];
//         final price = (i < addOnPrices.length && j < addOnPrices[i].length)
//             ? addOnPrices[i][j]
//             : 0;
//         final qty = (j < qtys.length) ? qtys[j] : 1;
//         final total = price * qty;

//         if (grouped.containsKey(name)) {
//           grouped[name]!.quantity += qty;
//           grouped[name]!.totalPrice += total;
//         } else {
//           grouped[name] =
//               AddOnData(price: price, quantity: qty, totalPrice: total);
//         }
//       }
//     }

//     for (var entry in grouped.entries) {
//       printer.text(
//           '${_align("", 2)} -> ${_align(capitalizeWords(entry.key), 20)} ${_align(entry.value.price.toString(), 6)}  ${_align(entry.value.quantity.toString(), 5)} ${_align(entry.value.totalPrice.toString(), 5)}');
//     }
//   }

//   static String _align(String text, int length) =>
//       text.padRight(length).substring(0, length);
//   static String _fmt(double val) =>
//       val == val.floor() ? val.toInt().toString() : val.toStringAsFixed(2);
// }

// class ItemData {
//   double price;
//   double quantity;
//   double amount;
//   String? weight;
//   Map<String, dynamic> config;

//   ItemData(
//       {required this.price,
//       required this.quantity,
//       required this.amount,
//       this.weight,
//       required this.config});
// }

// class AddOnData {
//   int price;
//   int quantity;
//   int totalPrice;

//   AddOnData(
//       {required this.price, required this.quantity, required this.totalPrice});
// }
