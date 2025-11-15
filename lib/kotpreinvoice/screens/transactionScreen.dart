import 'package:flutter/material.dart';
import '../components/capitalizeWord.dart';
import 'package:provider/provider.dart';
import '../components/flushbar.dart';
import '../providers/printer_provider.dart';
import '../services/invoiceReceipt.dart';
import '../models/fetchDiningTax.dart';
import '../providers/transactionProvider.dart';

class TransactionScreen extends StatelessWidget {
  const TransactionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Function to refresh data
    Future<void> refreshData(BuildContext context) async {
      await Provider.of<TransactionProviderDine>(context, listen: false).loadInvoices(); // Refresh invoice data
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Consumer<TransactionProviderDine>(
        builder: (context, transactionProvider, child) {
          final invoices = transactionProvider.invoices;
          print("invoices.length   ${invoices.length}");
          if (invoices.isEmpty) {
            return const Center(
              child: Text(
                "No transactions available",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => refreshData(context),
            child: ListView.builder(
              itemCount: invoices.length,
              itemBuilder: (context, index) {
                final invoice = invoices[index];
                print("transaction list: $invoices");
                final invoiceDate = invoice['invoiceDate'] ?? "";
                final double totalAmount = (invoice['totalAmount'] ?? 0).toDouble();
                final tax = invoice['tax'] ?? [];
                final customerNumber = invoice['customerNumber'] ?? "N/A";

                final itemName = invoice['varianceName'] ?? [];
                final qty = invoice['qty'] ?? [];
                final weight = invoice['weight'] ?? [];
                final prices = invoice['price'] ?? [];
                final amounts = invoice['amount'] ?? [];

                double taxPercentage = getTaxPercentage();
                double itemTax = totalAmount * (taxPercentage / 100);
                double itemSGST = itemTax / 2;
                double itemCGST = itemTax / 2;

                return Card(
                  color: Colors.white,
                  margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 6,
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent, // Makes dividers transparent
                    ),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
                      title: Text(
                        "Inv Id: ${invoice['hiveInvoiceId']}",
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        "Date: $invoiceDate - ₹${totalAmount.toStringAsFixed(2)}",
                        style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(),
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  SizedBox(
                                    width: 100,
                                    child: Text("Item", style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                  Text("Qty", style: TextStyle(fontWeight: FontWeight.bold)),
                                  Text("Amount", style: TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const Divider(),
                              for (int i = 0; i < itemName.length; i++)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                            width: 100, // Width for item name, adjust as necessary
                                            child: Text(
                                              capitalizeWords(itemName[i]),
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                              overflow: TextOverflow.ellipsis, // Prevents text overflow
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              if (weight[i] > 0 && prices[i] > 0)
                                                Text(
                                                  '(₹${prices[i].toStringAsFixed(2)} / ${weight[i]} kg)',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              if (weight[i] <= 0 && prices[i] > 0)
                                                Text(
                                                  '(₹${prices[i].toStringAsFixed(2)})',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              if (weight[i] > 0 && prices[i] <= 0)
                                                Text(
                                                  '(${weight[i]} kg)',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                            ],
                                          )
                                        ],
                                      ),
                                      Text(
                                        qty[i].toString(),
                                        style: const TextStyle(
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        "₹${amounts[i].toStringAsFixed(2)}",
                                        style: const TextStyle(
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const Divider(),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  "Tax: ${taxPercentage.toStringAsFixed(0)}%",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  "CGST: ₹${itemCGST.toStringAsFixed(2)}",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  "SGST: ₹${itemSGST.toStringAsFixed(2)}",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  "Total Amount: ₹${totalAmount.toString()}",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text("Customer Number: $customerNumber"),

                              // 🔹 Reprint Button Added Here
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    try {
                                      print("🧾 Reprinting invoice details for: ${invoice['hiveInvoiceId']}");

                                      // Log full invoice for debugging
                                      for (var entry in invoice.entries) {
                                        print("  ${entry.key}: ${entry.value}");
                                      }

                                      // Access printer provider
                                      final printerProvider = Provider.of<PrinterProviderDine>(context, listen: false);

                                      // Extract or mock necessary fields for ReceiptPrinter
                                      final employeeNumberController = TextEditingController(text: invoice['employeeNumber'] ?? '');
                                      final customerNumberController = TextEditingController(text: invoice['customerNumber'] ?? '');
                                      final discountController = TextEditingController(text: invoice['discount']?.toString() ?? '0');
                                      final customChargeController = TextEditingController(text: invoice['customCharge']?.toString() ?? '0');
                                      final customAmountController = TextEditingController(text: invoice['totalAmount']?.toString() ?? '0');

                                      final seatInfo = extractTableAndSeat(invoice['seathiveOrderId'] ?? '');
                                      final tableNumber = seatInfo['table']!;
                                      final seatLetter = seatInfo['seat']!;

                                      // If your invoice items are already in 'items' key, pass that
                                      final List<Map<String, dynamic>> items = [
                                        {
                                          'itemName': invoice['itemName'] ?? [],
                                          'varianceName': invoice['varianceName'] ?? [],
                                          'qty': invoice['qty'] ?? [],
                                          'price': invoice['price'] ?? [],
                                          'weight': invoice['weight'] ?? [],
                                          'uom': invoice['uom'] ?? [],
                                          'config': invoice['kotaddOns'] ?? [],
                                        }
                                      ];

                                      // Create and call the printer
                                      await ReceiptPrinter(
                                        employeeNumberController: employeeNumberController,
                                        seathiveOrderId: invoice['hiveInvoiceId'] ?? '',
                                        customerNumberController: customerNumberController,
                                        discountController: discountController,
                                        customChargeController: customChargeController,
                                        selectedPaymentOptionValue: invoice['paymentType'] ?? '',
                                        context: context,
                                        customAmountController: customAmountController,
                                        selectedPaymentOption: invoice['paymentType'] ?? 'Cash',
                                        items: items,
                                        branchName: invoice['branchName'] ?? 'Main Branch',
                                        table: tableNumber,
                                        seat: seatLetter,
                                        printerProvider: printerProvider,
                                      ).printReceiptDetails();
                                    } catch (e) {
                                      print("❌ Error while reprinting: $e");
                                      if (context.mounted) {
                                        showCustomFlushbar(
                                          context,
                                          "Error while reprinting: $e",
                                          type: FlushbarType.error,
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.print, size: 16),
                                  label: const Text(
                                    "Reprint",
                                    style: TextStyle(fontSize: 13),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Map<String, String> extractTableAndSeat(String seathiveOrderId) {
    try {
      final tablePattern = RegExp(r'Table\s*(\d+)(?:\((\w)\))?');
      final match = tablePattern.firstMatch(seathiveOrderId);

      if (match != null) {
        final tableNumber = match.group(1) ?? 'Unknown';
        final seatLetter = match.group(2) ?? 'A'; // Default A if no seat shown
        return {'table': tableNumber, 'seat': seatLetter};
      } else {
        return {'table': 'Unknown', 'seat': 'A'};
      }
    } catch (e) {
      print("⚠️ Error extracting table/seat from $seathiveOrderId: $e");
      return {'table': 'Unknown', 'seat': 'A'};
    }
  }
}
