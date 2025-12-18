import 'dart:typed_data';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../components/flushbar.dart';
import '../models/fetchBranch.dart';
import '../services/invoice_number.dart';
import '../models/printer.dart';
import '../providers/printer_provider.dart';
import 'package:image/image.dart' as img;

class ReceiptPrinter with ChangeNotifier {
  final TextEditingController employeeNumberController;
  final String seathiveOrderId;

  final TextEditingController customerNumberController;
  final TextEditingController discountController;
  final TextEditingController customChargeController;
  final String selectedPaymentOptionValue;
  final BuildContext context;
  final TextEditingController customAmountController;
  final String selectedPaymentOption;
  final List<Map<String, dynamic>> items; // Add items list
  final String branchName;
  final String table;
  final String seat;
  final PrinterProviderDine printerProvider; // Add PrinterProvider

  ReceiptPrinter({
    required this.employeeNumberController,
    required this.seathiveOrderId, // Initialize printer provider
    required this.customerNumberController,
    required this.discountController,
    required this.customChargeController,
    required this.selectedPaymentOptionValue,
    required this.context,
    required this.customAmountController,
    required this.selectedPaymentOption,
    required this.items, // Initialize items list
    required this.branchName,
    required this.table,
    required this.seat,
    required this.printerProvider,
  });

  Map<String, dynamic> groupItemsWithTotal(List<Map<String, dynamic>> items) {
    double localTotal = 0.0;
    Map<String, Map<String, dynamic>> grouped = {};

    for (var item in items) {
      List<String> itemNames = List<String>.from(item['itemName'] ?? []);
      List<String> varianceNames = List<String>.from(item['varianceName'] ?? []);
      List<double> quantities = (item['qty'] ?? []).map<double>((e) => (e is int ? e.toDouble() : e as num).toDouble()).toList();
      List<double> prices = (item['price'] ?? []).map<double>((e) => (e is int ? e.toDouble() : e as num).toDouble()).toList();
      List<double> weights = (item['weight'] ?? []).map<double>((e) => (e is int ? e.toDouble() : e as num).toDouble()).toList();
      List<String> uoms = List<String>.from(item['uom'] ?? []);

      List<Map<String, dynamic>> configs = List<Map<String, dynamic>>.from(item['config'] ?? []);

      for (int i = 0; i < itemNames.length; i++) {
        if (i >= quantities.length || quantities[i] <= 0) continue;
        if (i >= configs.length) {
          // No config, default to dine in
          String uom = uoms[i];
          double amount = uom.toLowerCase() == 'kg' || uom.toLowerCase() == 'Kgs' ? prices[i] * quantities[i] * weights[i] : prices[i] * quantities[i];
          localTotal += amount;
          _addBaseItem(grouped, itemNames[i], varianceNames[i], quantities[i], prices[i], weights[i], uom, 'dine in', amount);
          continue;
        }

        var config = configs[i];
        List<double> configQuantities = (config['configQty'] ?? [quantities[i]]).map<double>((e) => (e is int ? e.toDouble() : e as num).toDouble()).toList();
        List<String> configTypes = List<String>.from(config['type'] ?? []);

        for (int j = 0; j < configQuantities.length; j++) {
          double configQty = configQuantities[j];
          if (configQty <= 0) continue;

          String itemType = j < configTypes.length ? (configTypes[j].trim().isEmpty ? 'dine in' : configTypes[j].toLowerCase()) : 'dine in';

          String uom = uoms[i];
          double amount;
          if (uom.toLowerCase() == 'kg' || uom.toLowerCase() == 'Kgs') {
            amount = prices[i] * configQty * weights[i];
          } else {
            amount = prices[i] * configQty;
          }

          String key = '${itemNames[i]}-${varianceNames[i]}-${itemType}';
          localTotal += amount;

          if (!grouped.containsKey(key)) {
            grouped[key] = {
              'itemName': itemNames[i],
              'varianceName': varianceNames[i],
              'qty': configQty,
              'price': prices[i],
              'amount': amount,
              'type': itemType,
              'uom': uom,
              'addOns': <Map<String, dynamic>>[],
            };
          } else {
            grouped[key]!['qty'] += configQty;
            grouped[key]!['amount'] += amount;
          }

          // Process add-ons for this config[j]
          if (j < config['addOn'].length && config['addOn'][j] != null && config['addOnPrice'] != null && j < config['addOnPrice'].length) {
            List<dynamic> addOnRaw = config['addOn'][j];
            List<dynamic> priceRaw = config['addOnPrice'][j];
            List<dynamic> qtyRaw = config.containsKey('addOnQuantities') && j < config['addOnQuantities'].length ? config['addOnQuantities'][j] : [];

            final names = List<String>.from(addOnRaw.expand((e) => e is List ? e : [e]));
            final addOnUnitPrices = List<double>.from(priceRaw.expand((e) => e is List ? e : [e])).map((e) => (e is int ? e.toDouble() : e as num).toDouble()).toList();
            final addOnQtys =
                qtyRaw.isNotEmpty ? List<int>.from(qtyRaw.expand((e) => e is List ? e : [e])).map((e) => (e is double ? e.toInt() : e as num).toInt()).toList() : List.filled(names.length, 1);

            for (int k = 0; k < names.length; k++) {
              double addOnUnitPrice = k < addOnUnitPrices.length ? addOnUnitPrices[k] : 0.0;
              int addOnQty = k < addOnQtys.length ? addOnQtys[k] : 1;
              double addOnTotal = addOnUnitPrice * addOnQty;
              localTotal += addOnTotal;

              grouped[key]!['addOns'].add({
                'name': names[k],
                'price': addOnUnitPrice,
                'qty': addOnQty,
                'amount': addOnTotal,
              });
            }
          }
        }
      }
    }

    return {
      'groupedItems': grouped.values.toList(),
      'total': localTotal,
    };
  }

// Helper to add base item without config
  void _addBaseItem(Map<String, Map<String, dynamic>> grouped, String itemName, String varianceName, double qty, double price, double weight, String uom, String type, double amount) {
    String key = '$itemName-$varianceName-$type';
    grouped[key] = {
      'itemName': itemName,
      'varianceName': varianceName,
      'qty': qty,
      'price': price,
      'amount': amount,
      'type': type,
      'uom': uom,
      'addOns': <Map<String, dynamic>>[],
    };
  }

  Future<void> printReceiptDetails() async {
    try {
      print("🖨️ Initializing receipt print...");

      // 📋 Extract input data
      String employeeNumber = employeeNumberController.text;
      String customerNumber = customerNumberController.text.isNotEmpty ? customerNumberController.text : "N/A";
      DateTime now = DateTime.now();
      String formattedDate = DateFormat('dd-MM-yyyy').format(now);
      String formattedTime = DateFormat('hh:mm a').format(now);

      var invoiceNumberGenerator = InvoiceNumberGenerator();
      String newInvoiceNumber = await invoiceNumberGenerator.generateInvoiceNumber();

      String preInvNo = '';
      if (seathiveOrderId.isNotEmpty) {
        preInvNo = seathiveOrderId.length > 14 ? seathiveOrderId.substring(seathiveOrderId.length - 14) : seathiveOrderId;
        print("📋 PreInv No: $preInvNo");
      }

      // 🔍 Select printer
      final invoicePrinter = printerProvider.printers.firstWhere(
        (printer) => printer.type == 'Invoice',
        orElse: () {
          print("⚠️ No Invoice printer found. Using default.");
          return Printer(
            name: 'default_printer_name',
            ipAddress: 'default_ip',
            type: 'default_type',
          );
        },
      );

      print("🌐 Connecting to printer at IP: ${invoicePrinter.ipAddress}...");
      final profile = await CapabilityProfile.load();
      final printer = NetworkPrinter(PaperSize.mm80, profile);
      print("Items for invoice: $items");
      final PosPrintResult res = await printer.connect(invoicePrinter.ipAddress, port: 9100);
      if (res != PosPrintResult.success) {
        print("❌ Failed to connect to printer: ${res.msg}");
        if (context.mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showCustomFlushbar(
              context,
              "Printer connection failed: ${res.msg}",
              type: FlushbarType.error,
            );
          });
        }
        return;
      }

      print("✅ Printer connected successfully.");

      // 🖨️ Initialize generator
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      bytes += generator.reset();

      // Logo
      try {
        final box = Hive.box('logo');
        final Uint8List? imageBytes = box.get('BMlogo_bytes');
        final String? logoName = box.get('BMlogo_name');

        if (imageBytes != null) {
          print("✅ Loaded logo from Hive ($logoName) | Size: ${imageBytes.lengthInBytes} bytes");
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

      bytes += generator.feed(1);

      bytes += generator.row([
        PosColumn(
          width: 12,
          text: 'KOT INVOICE',
          styles: const PosStyles(
            align: PosAlign.center,
            height: PosTextSize.size1,
            width: PosTextSize.size2,
            bold: true,
          ),
        ),
      ]);

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
          width: 12,
          text: 'Invoice No: $newInvoiceNumber',
          styles: const PosStyles(align: PosAlign.left),
        ),
        
      ]);

      bytes += generator.feed(1);

      bytes += generator.row([
        PosColumn(
          width: 6,
          text: 'Table: $table',
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          width: 6,
          text: 'Seat: $seat',
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

      bytes += generator.feed(1);

      bytes += generator.row([
        PosColumn(
          width: 6,
          text: 'Branch: $branchName',
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          width: 6,
          text: 'Customer: $customerNumber',
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

      bytes += generator.feed(1);

      bytes += generator.row([
        PosColumn(
          width: 12,
          text: 'Sales Person: $employeeNumber',
          styles: const PosStyles(align: PosAlign.left),
        ),
      ]);

      bytes += generator.feed(1);
      bytes += generator.hr();

      bytes += generator.row([
        PosColumn(
          width: 2,
          text: 'S.No',
          styles: const PosStyles(align: PosAlign.left, bold: true),
        ),
        PosColumn(
          width: 5,
          text: 'ITEM',
          styles: const PosStyles(align: PosAlign.center, bold: true),
        ),
        PosColumn(
          width: 2,
          text: 'QTY',
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
        PosColumn(
          width: 3,
          text: 'TTL',
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]);
      bytes += generator.hr();

      bytes += generator.feed(1);

      // 🛒 Process items
      Map<String, dynamic> result = {};
      List<Map<String, dynamic>> groupedItems = [];
      double finalTotal = 0.0;

      try {
        print("🛠️ Grouping items...");
        result = groupItemsWithTotal(items);
        groupedItems = result['groupedItems'] ?? [];
        finalTotal = result['total'] ?? 0.0;

        print("📋 Grouped Items (${groupedItems.length}):");
        for (var item in groupedItems) {
          print("🍽️ Item: ${item['itemName']} | Variance: ${item['varianceName']} | Qty: ${item['qty']} | Price: ${item['price']} | Amount: ${item['amount']}");
          for (var addOn in item['addOns']) {
            print("   ➕ Add-on: ${addOn['name']} | Qty: ${addOn['qty']} | Price: ${addOn['price']} | Amount: ${addOn['amount']}");
          }
        }
        print("💵 Total: ${finalTotal.toStringAsFixed(2)}");
      } catch (e) {
        print("🔥 Error grouping items: $e");
      }

      // 📄 Process items for printing
      try {
        print("📋 Printing item table header...");

        // 🗂️ Categorize and print items
        final List<Map<String, dynamic>> dineInItems = [];
        final List<Map<String, dynamic>> parcelItems = [];

        print("🗂️ Categorizing items into Dine In and Parcel...");
        for (var item in groupedItems) {
          final type = item['type']?.toString().toLowerCase() ?? 'dine in';
          final itemData = {
            'varianceName': item['varianceName'],
            'quantity': item['qty'],
            'price': item['price'],
            'itemAmount': item['amount'],
            'addOns': item['addOns'].map((addOn) => addOn['name']).toList(),
            'addOnQuantities': item['addOns'].map((addOn) => addOn['qty']).toList(),
            'addOnPrices': item['addOns'].map((addOn) => addOn['amount']).toList(),
          };

          if (type == 'parcel') {
            parcelItems.add(itemData);
            print("📦 Added to Parcel: ${item['varianceName']}");
          } else {
            dineInItems.add(itemData);
            print("🍽️ Added to Dine In: ${item['varianceName']}");
          }
        }

        // Print items
        void printItems(String header, List<Map<String, dynamic>> items, int serialStart) {
          if (items.isEmpty) return;

          bytes += generator.row([
            PosColumn(
              width: 12,
              text: header,
              styles: const PosStyles(
                align: PosAlign.center,
                bold: true,
                height: PosTextSize.size2,
              ),
            ),
          ]);

          bytes += generator.hr();

          int serialNumber = serialStart;
          for (var item in items) {
            print("🥐 Printing Item $serialNumber: ${item['varianceName']} | Qty: ${item['quantity']} | Total: ${item['itemAmount']}");
            bytes += generator.row([
              PosColumn(
                text: serialNumber.toString(),
                width: 2,
                styles: const PosStyles(align: PosAlign.left),
              ),
              PosColumn(
                text: capitalizeWords(item['varianceName']),
                width: 5,
                styles: const PosStyles(align: PosAlign.left),
              ),
              PosColumn(
                text: _formatNumber(item['quantity']),
                width: 2,
                styles: const PosStyles(align: PosAlign.right),
              ),
              PosColumn(
                text: _formatNumber(item['itemAmount']),
                width: 3,
                styles: const PosStyles(align: PosAlign.right),
              ),
            ]);

            bytes += generator.text(
              '       (Rs. ${_formatNumber(item['price'])} # ${item['quantity']})',
              styles: const PosStyles(align: PosAlign.left),
            );

            for (int j = 0; j < item['addOns'].length; j++) {
              final addonName = item['addOns'][j];
              final qty = item['addOnQuantities'][j] ?? 1;
              final totalAddOn = item['addOnPrices'][j] ?? 0.0;
              final unitPrice = qty > 0 ? totalAddOn / qty : totalAddOn;

              print("   ➕ Add-on: $addonName | Unit Price: $unitPrice | Qty: $qty | Total: $totalAddOn");
              bytes += generator.row([
                PosColumn(
                  text: '',
                  width: 2,
                  styles: const PosStyles(align: PosAlign.left),
                ),
                PosColumn(
                  text: capitalizeWords(addonName),
                  width: 5,
                  styles: const PosStyles(align: PosAlign.left),
                ),
                PosColumn(
                  text: _formatNumber(qty),
                  width: 2,
                  styles: const PosStyles(align: PosAlign.right),
                ),
                PosColumn(
                  text: _formatNumber(totalAddOn),
                  width: 3,
                  styles: const PosStyles(align: PosAlign.right),
                ),
              ]);

              bytes += generator.text(
                '            (Rs. ${_formatNumber(unitPrice)} # $qty)',
                styles: const PosStyles(align: PosAlign.left),
              );
            }
            serialNumber++;
          }

          bytes += generator.hr();
          bytes += generator.feed(1);
        }

        printItems('TABLE SERVICE', dineInItems, 1);
        printItems('PARCEL ITEMS', parcelItems, 1);
      } catch (e) {
        print("🔥 Error printing items: $e");
      }

      // 💵 Print total
      try {
        print("💵 Printing total: ${finalTotal.toStringAsFixed(2)}");
        bytes += generator.hr();
        bytes += generator.row([
          PosColumn(
            width: 12,
            text: 'Total: Rs ${finalTotal.toStringAsFixed(2)}',
            styles: const PosStyles(
              align: PosAlign.right,
              bold: true,
              height: PosTextSize.size2,
              width: PosTextSize.size2,
            ),
          ),
        ]);
        bytes += generator.feed(1);
        bytes += generator.row([
          PosColumn(
            width: 12,
            text: 'Thank You! Visit Again!',
            styles: const PosStyles(
              align: PosAlign.center,
              bold: true,
            ),
          ),
        ]);
        bytes += generator.feed(1);
      } catch (e) {
        print("🔥 Footer printing failed: $e");
      }

      // 🏢 Print branch details
      try {
        print("🏢 Fetching branch details...");
        Map<String, dynamic>? branchDetails = await getBranchDetails();
        String branchAddress = branchDetails?['address'] ?? 'Address not available';
        String branchCity = branchDetails?['city'] ?? '';
        String branchState = branchDetails?['state'] ?? '';
        String branchPostalCode = branchDetails?['postalCode']?.toString() ?? '';
        String branchPhoneNumber = branchDetails?['phoneNumber']?.toString() ?? '';

        String fullAddress = "$branchAddress, $branchName, $branchCity $branchState - $branchPostalCode";
        List<String> addressLines = splitAddress(fullAddress);

        print("📄 Printing branch address (${addressLines.length} lines)...");
        for (var line in addressLines) {
          bytes += generator.row([
            PosColumn(
              width: 12,
              text: line,
              styles: const PosStyles(align: PosAlign.center),
            ),
          ]);
        }

        bytes += generator.row([
          PosColumn(
            width: 12,
            text: 'Phone: $branchPhoneNumber',
            styles: const PosStyles(align: PosAlign.center),
          ),
        ]);

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

        print("✅ Branch details printed.");
      } catch (e) {
        print("🔥 Error printing branch details: $e");
      }

      // 🖨️ Finalize printing
      try {
        print("✂️ Cutting paper...");
        bytes += generator.cut();
        printer.rawBytes(Uint8List.fromList(bytes));
        await Future.delayed(const Duration(milliseconds: 200));
        print("🔌 Disconnecting printer...");
        printer.disconnect();
        print("🎉 Receipt printed successfully.");
        if (context.mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showCustomFlushbar(
              context,
              "Receipt printed successfully ✅",
              type: FlushbarType.success,
            );
          });
        } else {
          print("⚠️ Skipped success flushbar, widget disposed.");
        }
      } catch (e) {
        print("🔥 Error finalizing print: $e");
        if (context.mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showCustomFlushbar(
              context,
              "Error: $e",
              type: FlushbarType.error,
            );
          });
        } else {
          print("⚠️ Skipped error flushbar, widget disposed.");
        }
      }
    } catch (e, st) {
      print("🔥 Fatal error in printReceiptDetails: $e\n$st");
      if (context.mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showCustomFlushbar(
            context,
            "Error: $e",
            type: FlushbarType.error,
          );
        });
      } else {
        print("⚠️ Skipped fatal error flushbar, widget disposed.");
      }
    }
  }

  // Helper functions (assumed to be defined elsewhere)
  String _formatNumber(num number) {
    // Implementation to format numbers
    return number.toStringAsFixed(2);
  }

  String capitalizeWords(String text) {
    // Implementation to capitalize words
    return text.split(' ').map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1).toLowerCase() : word).join(' ');
  }

  List<String> splitAddress(String address) {
    const int maxLineWidth = 18;
    List<String> lines = [];
    String remainingAddress = address;

    while (remainingAddress.length > maxLineWidth) {
      int lastIndex = remainingAddress.lastIndexOf(' ', maxLineWidth);
      if (lastIndex == -1) {
        lastIndex = maxLineWidth;
      }
      lines.add(remainingAddress.substring(0, lastIndex).trimRight());
      remainingAddress = remainingAddress.substring(lastIndex).trimLeft();
    }

    lines.add(remainingAddress);

    return lines;
  }

  List<String> splitText(String text, int maxLineWidth) {
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

  T safeCast<T>(dynamic value, T defaultValue) {
    if (value == null || value is! T) return defaultValue;
    return value as T;
  }
}
