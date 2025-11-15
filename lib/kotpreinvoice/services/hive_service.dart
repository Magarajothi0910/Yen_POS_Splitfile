import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:yenpos/Sale_order/Widgets/Send_data_to_server.dart';
import '../models/printer.dart';
import '../providers/printer_provider.dart';

void saveOrderToHive(Map<String, dynamic> order) async {
  try {
    var orderBox = Hive.box('ordersBox');

    if (order.containsKey('date') && order['date'] is DateTime) {
      order['date'] = DateFormat('dd-MM-yyyy').format(order['date']);
    }

    await orderBox.add(order); // ✅ No encoding
    print('Order saved in Hive: ${order['hiveOrderId']}');
  } catch (e) {
    print('Error saving order to Hive: $e');
  }
}

Future<List<Map<String, dynamic>>> loadInvoicesFromHive() async {
  try {
    var invoiceBox = Hive.box('invoices');
    List<Map<String, dynamic>> invoices = [];

    for (int i = 0; i < invoiceBox.length; i++) {
      var item = invoiceBox.getAt(i);

      if (item == null) continue;

      if (item is String) {
        try {
          final decoded = jsonDecode(item);
          if (decoded is Map<String, dynamic>) {
            invoices.add(decoded);
          } else {
            print("Skipping non-map decoded string at index $i");
          }
        } catch (e) {
          print("❌ JSON decode failed at index $i: $e");
        }
      } else if (item is Map) {
        invoices.add(Map<String, dynamic>.from(item));
      } else {
        print(
          "Skipping unsupported item type at index $i: ${item.runtimeType}",
        );
      }
    }

    print('✅ Invoices in Hive: ${invoices.length}');
    return invoices;
  } catch (e) {
    print('❌ Error loading invoices from Hive: $e');
    return [];
  }
}

Future<List<Map<String, dynamic>>> loadOrdersFromHive() async {
  try {
    print('📂 Opening Hive box: ordersBox...');
    var orderBox = Hive.box('ordersBox');
    print('✅ Hive box opened successfully.');
    print('📦 Total records in Hive box: ${orderBox.length}');

    List<Map<String, dynamic>> orders = [];

    for (int i = 0; i < orderBox.length; i++) {
      var orderData = orderBox.getAt(i);
      print('🔍 Reading order at index $i: ${orderData.runtimeType}');

      try {
        if (orderData is Map) {
          print('🧩 Converting Map at index $i...');
          orders.add(Map<String, dynamic>.from(orderData));
        } else if (orderData is String) {
          print('🧾 Found JSON String at index $i, decoding...');
          final decoded = jsonDecode(orderData);
          if (decoded is Map) {
            orders.add(Map<String, dynamic>.from(decoded));
          } else if (decoded is List) {
            for (var element in decoded) {
              if (element is Map) {
                orders.add(Map<String, dynamic>.from(element));
              }
            }
          }
        } else if (orderData is List) {
          print('📦 Found List at index $i, iterating through elements...');
          for (int j = 0; j < orderData.length; j++) {
            final element = orderData[j];
            if (element is Map) {
              orders.add(Map<String, dynamic>.from(element));
              print('✅ Added converted Map from List at [$i][$j]');
            } else if (element is String) {
              try {
                final decoded = jsonDecode(element);
                if (decoded is Map) {
                  orders.add(Map<String, dynamic>.from(decoded));
                  print('✅ Decoded and added JSON Map from List at [$i][$j]');
                } else {
                  print(
                    '⚠️ Skipped non-Map decoded value at [$i][$j]: ${decoded.runtimeType}',
                  );
                }
              } catch (e) {
                print('❌ Failed to decode String at [$i][$j]: $e');
              }
            } else {
              print(
                '⚠️ Skipped unsupported element at [$i][$j]: ${element.runtimeType}',
              );
            }
          }
        } else {
          print('⚠️ Unknown format at index $i: ${orderData.runtimeType}');
        }

        print('✅ Successfully processed order at index $i.');
      } catch (e, st) {
        print('❌ Error processing order at index $i: $e');
        print(st);
      }
    }

    print('✅ All orders processed successfully.');
    print('📊 Total loaded orders: ${orders.length}');
    return orders;
  } catch (e, stackTrace) {
    print('❌ Error loading orders from Hive: $e');
    print('📜 StackTrace:\n$stackTrace');
    return [];
  }
}

Future<List<Map<String, dynamic>>> loadPrintersFromHive() async {
  try {
    var printerBox = await Hive.openBox('printers');
    List<Map<String, dynamic>> printers = [];

    print('🔍 Opening printers box, length: ${printerBox.length}');

    final data = printerBox.get('data');
    if (data != null && data is List) {
      printers = data
          .map((json) {
            if (json is Map) {
              final map = Map<String, dynamic>.from(json);
              if (map.containsKey('name') && map.containsKey('ipAddress')) {
                return map;
              } else {
                print("⚠️ Skipping invalid map: missing required fields $map");
                return null;
              }
            } else {
              print("⚠️ Invalid data format: $json");
              return null;
            }
          })
          .whereType<Map<String, dynamic>>()
          .toList();
    } else {
      print("⚠️ No 'data' key found in 'printers' box or data is not a list");
    }

    print('✅ Total loaded printers: ${printers.length}');
    print('📋 Printers: $printers');
    return printers;
  } catch (e, stackTrace) {
    print('❌ Error loading printers from Hive: $e\nStack trace: $stackTrace');
    return [];
  }
}

Future<void> deleteOrderFromHive(String hiveOrderId) async {
  var orderBox = Hive.box('ordersBox'); // Ensure the box name is correct

  // Loop through all stored orders and delete the one with the matching hiveOrderId
  for (int i = 0; i < orderBox.length; i++) {
    var orderData = orderBox.getAt(i);

    // If the stored data is a string, decode it into a map
    if (orderData is Map && orderData['hiveOrderId'] == hiveOrderId) {
      await orderBox.deleteAt(i);
      print('Deleted order from Hive: $hiveOrderId');
      break;
    }
  }
}

Future<void> saveKotInvoiceToHive(Map<String, dynamic> invoice) async {
  final invoiceBox = Hive.box('invoices');

  // ✅ Ensure date is stored in dd-MM-yyyy format (so filtering works later)
  if (invoice['invoiceDate'] is DateTime) {
    invoice['invoiceDate'] = DateFormat(
      'dd-MM-yyyy',
    ).format(invoice['invoiceDate']);
  }

  await invoiceBox.add(invoice);
  print("Invoice saved to Hive: $invoice");
}

Future<void> savePosInvoiceToHive(Map<String, dynamic> posInvoice) async {
  print("savePosInvoiceToHive 3");
  var posInvoiceBox = await Hive.openBox('posInvoiceBox');
  await posInvoiceBox.add(posInvoice);
  print("POS Invoice saved: ${posInvoice['hiveInvoiceId']}");
}

Future<void> savePrinterDetailsToHive(Map<String, dynamic> printerData) async {
  try {
    var printerBox = await Hive.openBox('printers');
    var provider =
        PrinterProviderDine(); // Note: Ideally, inject PrinterProvider via context or singleton
    await provider.printerInitializeHive();

    // Validate required fields
    if (!printerData.containsKey('name') ||
        !printerData.containsKey('ipAddress')) {
      print("❌ Invalid printer data, missing required fields: $printerData");
      return;
    }

    // Convert to Printer object
    final printer = Printer(
      name: printerData['name'].toString(),
      ipAddress: printerData['ipAddress'].toString(),
      type: printerData['type']?.toString() ?? '',
      items: List<String>.from(printerData['items'] ?? []),
    );

    // Add to PrinterProvider
    provider.addPrinter(printer);

    print("✅ Saved printer via PrinterProvider: ${printer.name}");
  } catch (e, stackTrace) {
    print(
      '❌ Error saving printer details to Hive: $e\nStack trace: $stackTrace',
    );
  }
}

Future<void> initHiveInBackground() async {
  await Hive.initFlutter();

  // Open only what background tasks need
  await Future.wait([
    Hive.openBox('ordersBox'),
    Hive.openBox('tokenBox'),
    Hive.openBox('invoices'),
    Hive.openBox('branchwise_items'),
    Hive.openBox('printerData'),
    Hive.openBox('settings'),
  ]);
}
