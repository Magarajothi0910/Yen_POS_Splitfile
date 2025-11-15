import 'dart:io';
import 'dart:typed_data';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:intl/intl.dart';
import 'package:yenpos/Global/globals_data.dart';
import '../components/capitalizeWord.dart';
import 'package:yenpos/Global/globals_data.dart'; // Import for capitalizeWords

class SeatTransferPrinter {
  static Future<String> printReceipt({
    required String ipAddress,
    required String tableNumber,
    required String seat,
    required List<dynamic> seatOrders,
    required String receiptType,
    required String userName,
    required String waiter,
    required String areaName,
    required String fromTable,
    required String fromSeat,
  }) async {
    try {
      // 🕵️‍♂️ Validate input parameters
      if (seatOrders.isEmpty) {
        print('❌ No orders provided for printing');
        return 'No orders provided for printing';
      }
      if (ipAddress.isEmpty) {
        print('❌ Invalid printer IP address');
        return 'Invalid printer IP address';
      }
      print('📥 Input validated: Printing receipt for $tableNumber, seat $seat, orders: ${seatOrders.length}');

      // 🖨️ Initialize printer
      final profile = await CapabilityProfile.load();
      final printer = NetworkPrinter(PaperSize.mm80, profile);
      print('🖨️ Printer profile loaded: PaperSize.mm80');

      // 🔌 Connect to printer
      final PosPrintResult res = await printer.connect(ipAddress, port: 9100);
      if (res != PosPrintResult.success) {
        print('❌ Printer connection failed: $res');
        return 'Failed to connect to the printer: $res';
      }
      print('🔌 Printer connected successfully at $ipAddress:9100');

      // 🧹 Initialize printer
      printer.rawBytes(Uint8List.fromList([27, 64])); // ESC @ - Reset printer
      print('🧹 Printer initialized with ESC @ command');

      // 📅 Get current date and time
      final now = DateTime.now();
      final formattedDate = DateFormat('dd-MM-yyyy').format(now);
      final formattedTime = DateFormat('HH:mm:ss').format(now);
      String kotText = _manualCenterText('KOT ', 5);
      print('📅 Formatted date: $formattedDate, time: $formattedTime, KOT text: $kotText');

      // 🖌️ Print receipt header
      printer.text(
        '',
        styles: const PosStyles(align: PosAlign.center),
      );
      printer.text(
        "$kotText- $receiptType",
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      printer.feed(1);
      print('🖌️ Printed header: $kotText- $receiptType');

      // 🪑 Extract table numbers
      final RegExp regExp = RegExp(r'\d+');
      final String tableOnlyNumber = regExp.firstMatch(tableNumber)?.group(0) ?? tableNumber;
      final String toTableNumber = regExp.firstMatch(fromTable)?.group(0) ?? fromTable;
      final tableSeatText = '${'Table  : $tableOnlyNumber'.padRight(20)}Seat : $seat';
      print('🪑 Table numbers extracted: From $toTableNumber, To $tableOnlyNumber, Seat $seat');

      // 🖌️ Print transfer details
      printer.text(
        'Transferred Table',
        styles: const PosStyles(
          align: PosAlign.left,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          bold: true,
        ),
      );
      printer.feed(1);
      printer.text(
        'From ${'Table : $toTableNumber'.padRight(20)}Seat : $fromSeat',
        styles: const PosStyles(
          align: PosAlign.left,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          bold: true,
        ),
      );
      printer.feed(1);
      printer.text(
        'To   ${tableSeatText.padRight(20)}',
        styles: const PosStyles(
          align: PosAlign.left,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          bold: true,
        ),
      );
      printer.feed(1);
      print('🖌️ Printed transfer details: From Table $toTableNumber Seat $fromSeat to Table $tableOnlyNumber Seat $seat');

      // 🖌️ Print date and time
      final dateTimeText = '${'Date  : $formattedDate'.padRight(20)}Time  : $formattedTime';
      printer.text(
        dateTimeText,
        styles: const PosStyles(align: PosAlign.left),
      );
      printer.feed(1);
      print('🖌️ Printed date and time: $dateTimeText');

      // 🖌️ Print captain and waiter
      printer.text(
        'Captain     : $userName',
        styles: const PosStyles(
          align: PosAlign.left,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ),
      );
      printer.feed(1);
      printer.text(
        'Sales person: $createdBy',
        styles: const PosStyles(
          align: PosAlign.left,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ),
      );
      printer.feed(1);
      print('🖌️ Printed captain: $userName, waiter: $waiter');

      // 🖌️ Print separator
      printer.text(
        '------------------------------------------------',
        styles: const PosStyles(align: PosAlign.center),
      );
      print('🖌️ Printed separator');

      // 🖌️ Print headers for items
      printer.text(
        '${_alignText("S.N", 3)} ${_alignText("Item", 20)} ${_alignText("Price", 6)} ${_alignText("Qty", 5)} ${_alignText("Ttl", 6)}',
        styles: const PosStyles(align: PosAlign.left, bold: true),
      );
      printer.text(
        '------------------------------------------------',
        styles: const PosStyles(align: PosAlign.center),
      );
      print('🖌️ Printed item headers: S.N | Item | Price | Qty | Ttl');

      int serialNumber = 1;
      double overallTotal = 0.0;

      print('📋 Processing ${seatOrders.length} orders for printing: $seatOrders');

      for (var orderIndex = 0; orderIndex < seatOrders.length; orderIndex++) {
        final order = seatOrders[orderIndex];

        if (order is! Map<String, dynamic>) {
          print('⚠️ Invalid order format at index $orderIndex: $order');
          continue; // Skip invalid orders
        }

        try {
          // 📦 Extract order details
          List<String> itemNames = (order['itemNames'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
          List<String> varianceNames = (order['varianceNames'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
          List<Map<String, dynamic>> configs = (order['config'] as List<dynamic>?)?.map((e) => e as Map<String, dynamic>).toList() ?? [{}];
          List<double> prices = (order['prices'] as List<dynamic>?)?.map((e) => safeCast(e, 0.0)).toList() ?? [];
          List<double> quantities = (order['quantities'] as List<dynamic>?)?.map((e) => safeCast(e, 0.0)).toList() ?? [];
          List<double> weights = (order['weights'] as List<dynamic>?)?.map((e) => safeCast(e, 0.0)).toList() ?? [];
          List<double> amounts = (order['amounts'] as List<dynamic>?)?.map((e) => safeCast(e, 0.0)).toList() ?? [];

          print('📦 Order $orderIndex extracted: ${itemNames.length} items, token: ${safeCast(order['tokenNo'], 0)}');

          printer.text(
            'Order ${orderIndex + 1} (Token No: ${safeCast(order['tokenNo'], 0)})',
            styles: const PosStyles(align: PosAlign.left, bold: true),
          );

          Map<String, Map<String, dynamic>> groupedItems = {};

          // 🛠️ Group items
          for (var i = 0; i < itemNames.length; i++) {
            try {
              final String itemName = varianceNames.isNotEmpty && i < varianceNames.length ? varianceNames[i] : itemNames[i];
              final double price = i < prices.length ? prices[i] : 0.0;
              final double quantity = i < quantities.length ? quantities[i] : 0.0;
              final double amount = i < amounts.length ? amounts[i] : 0.0;
              final double weight = i < weights.length ? weights[i] : 0.0;
              final String weightText = weight != 0.0 ? weight.toStringAsFixed(2) : '';

              if (quantity > 0 && amount > 0) {
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
                    ),
                  };
                }
              }
            } catch (e, stack) {
              print('⚠️ Error processing item $i in order $orderIndex: $e\n$stack');
              continue;
            }
          }
          print('🛠️ Grouped items for order $orderIndex: $groupedItems');

          // 🖌️ Print grouped items
          groupedItems.forEach((variance, details) {
            try {
              // Calculate itemTotal for printing as price * quantity (base item only)
              final double itemTotal = safeCast(details['price'], 0.0) * safeCast(details['quantity'], 0.0);
              // Use details['amount'] for overallTotal to include item and add-on totals
              final double totalForItem = safeCast(details['amount'], 0.0);
              overallTotal += totalForItem;

              printer.text(
                '${_alignText(serialNumber.toString(), 3)} ${_alignText(capitalizeWords(variance), 20)} ${_alignText(_formatNumber(safeCast(details['price'], 0.0)), 6)} ${_alignText(_formatNumber(safeCast(details['quantity'], 0.0)), 5)} ${_alignText(_formatNumber(itemTotal), 6)}',
                styles: const PosStyles(align: PosAlign.left),
              );

              if (details['weight'] != null && details['weight'].toString().trim().isNotEmpty) {
                printer.text(
                  '   Wt: ${details['weight']}',
                  styles: const PosStyles(align: PosAlign.left),
                );
              }

              // 📦 Process add-ons and variances
              final itemConfig = details['config'] as Map<String, dynamic>;
              if (itemConfig.isNotEmpty) {
                List<String> variances = List<String>.from(safeCast(itemConfig['variance'], <String>[]));
                List<List<String>> addOns = (itemConfig['addOn'] as List<dynamic>?)?.map((e) => List<String>.from(safeCast(e, <String>[]))).toList() ?? [];
                List<List<double>> addOnPrices = (itemConfig['addOnPrice'] as List<dynamic>?)?.map((e) => List<double>.from(safeCast(e, <num>[]).map((n) => safeCast(n, 0.0)))).toList() ?? [];
                List<List<dynamic>> addOnQuantities = (itemConfig['addOnQuantities'] as List<dynamic>?)?.map((e) => List<dynamic>.from(safeCast(e, <dynamic>[]))).toList() ?? [];

                print('📦 Config for $variance: ${addOns.length} add-ons, ${variances.length} variances');

                // 🖌️ Print grouped variances
                Map<String, int> groupedVariances = {};
                for (var v in variances) {
                  if (v.isNotEmpty && v.toLowerCase() != "default") {
                    groupedVariances[v] = (groupedVariances[v] ?? 0) + 1;
                  }
                }
                for (var entry in groupedVariances.entries) {
                  if (entry.value > 0) {
                    printer.text(
                      '${_alignText("", 3)} - ${_alignText(capitalizeWords(entry.key), 20)} ${_alignText("", 6)} ${_alignText(entry.value.toString(), 5)} ${_alignText("", 6)}',
                      styles: const PosStyles(align: PosAlign.left),
                    );
                  }
                }
                print('🖌️ Printed variances for $variance: $groupedVariances');

                // 🛠️ Group and print add-ons
                Map<String, Map<String, dynamic>> groupedAddOns = {};
                for (var j = 0; j < addOns.length; j++) {
                  for (var k = 0; k < addOns[j].length; k++) {
                    try {
                      final String addOnName = safeCast(addOns[j][k], '');
                      final double addOnPrice = j < addOnPrices.length && k < addOnPrices[j].length ? safeCast(addOnPrices[j][k], 0.0) : 0.0;
                      final double addOnQuantity = j < addOnQuantities.length && k < addOnQuantities[j].length ? safeCast(addOnQuantities[j][k], 1.0) : 1.0;

                      if (addOnName.isNotEmpty && addOnPrice > 0 && addOnQuantity > 0) {
                        final double unitPrice = addOnPrice / addOnQuantity;
                        final double totalAddOnPrice = addOnPrice;

                        if (groupedAddOns.containsKey(addOnName)) {
                          groupedAddOns[addOnName]!['quantity'] = safeCast(groupedAddOns[addOnName]!['quantity'], 0.0) + addOnQuantity;
                          groupedAddOns[addOnName]!['totalPrice'] = safeCast(groupedAddOns[addOnName]!['totalPrice'], 0.0) + totalAddOnPrice;
                        } else {
                          groupedAddOns[addOnName] = {
                            'quantity': addOnQuantity,
                            'unitPrice': unitPrice,
                            'totalPrice': totalAddOnPrice,
                          };
                        }
                      }
                    } catch (e, stack) {
                      print('⚠️ Error processing add-on at index j=$j, k=$k in order $orderIndex: $e\n$stack');
                      continue;
                    }
                  }
                }
                print('🛠️ Grouped add-ons for $variance: $groupedAddOns');

                // 🖌️ Print grouped add-ons
                groupedAddOns.forEach((addOnName, details) {
                  try {
                    final double addOnTotal = safeCast(details['totalPrice'], 0.0);
                    final double unitPrice = safeCast(details['unitPrice'], 0.0);
                    final double quantity = safeCast(details['quantity'], 0.0);

                    printer.text(
                      '${_alignText("", 3)} -> ${_alignText(capitalizeWords(addOnName), 20)} ${_alignText(_formatNumber(unitPrice), 6)} ${_alignText(_formatNumber(quantity), 5)} ${_alignText(_formatNumber(addOnTotal), 6)}',
                      styles: const PosStyles(align: PosAlign.left),
                    );
                    print('🖌️ Printed add-on: $addOnName, Unit Price: $unitPrice, Quantity: $quantity, Total: $addOnTotal');
                  } catch (e, stack) {
                    print('⚠️ Error printing add-on $addOnName: $e\n$stack');
                  }
                });
              }

              serialNumber++;
            } catch (e, stack) {
              print('⚠️ Error printing item $variance: $e\n$stack');
            }
          });
        } catch (e, stack) {
          print('⚠️ Error processing order $orderIndex: $e\n$stack');
          continue;
        }
      }

      // 🖌️ Print total amount
      printer.text(
        '------------------------------------------------',
        styles: const PosStyles(align: PosAlign.center),
      );
      printer.text(
        'Total: ${_formatNumber(overallTotal)}',
        styles: const PosStyles(
          align: PosAlign.right,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      print('🖌️ Printed total: ${_formatNumber(overallTotal)}');

      // 🖨️ Finalize printing
      printer.feed(1);
      printer.cut();
      print('🖨️ Printer cut command sent');

      // 🔌 Disconnect printer
      printer.disconnect();
      print('🔌 Printer disconnected from $ipAddress');

      print('✅ Printed receipt successfully to printer at IP address $ipAddress');
      return 'Receipt printed successfully';
    } catch (e, stack) {
      print('❌ Error printing receipt: $e\n$stack');
      if (e.toString().contains('is not a subtype of type')) {
        print('⚠️ Type mismatch detected: Ensure all numeric fields (prices, quantities, amounts) are doubles in seatOrders');
      } else if (e is SocketException) {
        print('⚠️ Network error: Check printer connectivity at $ipAddress:9100');
      }
      return 'Error printing receipt: $e';
    }
  }

  static String _alignText(String text, int length) {
    return text.padRight(length).substring(0, length > text.length ? text.length : length);
  }

  static String _formatNumber(double value) {
    return value == value.floor() ? value.toInt().toString() : value.toStringAsFixed(2);
  }

  static String _manualCenterText(String text, int totalWidth) {
    int padSize = (totalWidth - text.length) ~/ 2;
    if (padSize > 0) {
      return ' ' * padSize + text + ' ' * padSize;
    }
    return text;
  }

  static T safeCast<T>(dynamic value, T defaultValue) {
    try {
      if (value is T) {
        return value;
      } else if (value is num && T == double) {
        return value.toDouble() as T;
      } else if (value is num && T == int) {
        return value.toInt() as T;
      } else if (value is List && T == List<String>) {
        return List<String>.from(value.map((e) => e.toString())) as T;
      } else if (value is List && T == List<double>) {
        return List<double>.from(value.map((e) => safeCast(e, 0.0))) as T;
      } else if (value is List && T == List<int>) {
        return List<int>.from(value.map((e) => safeCast(e, 0))) as T;
      } else if (value is List && T == List<num>) {
        return List<num>.from(value.map((e) => safeCast(e, 0))) as T;
      }
      print('⚠️ safeCast failed for value: $value, type: ${value.runtimeType}, returning default: $defaultValue');
      return defaultValue;
    } catch (e, stack) {
      print('❌ safeCast error: $e\n$stack');
      return defaultValue;
    }
  }
}
