import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../models/fetchDiningTax.dart';
import '../kotproviders/transactionProvider.dart';
import '../widgets/capitalizeWord.dart';

class TransactionScreen extends StatelessWidget {
  const TransactionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Function to refresh data
    Future<void> refreshData(BuildContext context) async {
      await Provider.of<TransactionProvider>(context, listen: false)
          .loadInvoices(); // Refresh invoice data
    }

    return Scaffold(
      body: Consumer<TransactionProvider>(
        builder: (context, transactionProvider, child) {
          final invoices = transactionProvider.invoices;
          if (invoices.isEmpty) {
            return const Center(
              child: Text(
                "No transactions available",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => refreshData(context), // Pull-to-refresh
            child: ListView.builder(
              itemCount: invoices.length,
              itemBuilder: (context, index) {
                final invoice = invoices[index];
                final invoiceDate = invoice['invoiceDate'] ?? "";
                final double totalAmount =
                    (invoice['totalAmount'] ?? 0).toDouble();
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
                  margin: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 10.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 3,
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor:
                          Colors.transparent, // Makes dividers transparent
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
                        style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(),
                              const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  SizedBox(
                                    width: 100,
                                    child: Text("Item",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  Text("Qty",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  Text("Amount",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const Divider(),
                              for (int i = 0; i < itemName.length; i++)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        children: [
                                          SizedBox(
                                            width:
                                                100, // Width for item name, adjust as necessary
                                            child: Text(
                                              capitalizeWords(itemName[i]),
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                              overflow: TextOverflow
                                                  .ellipsis, // Prevents text from overflowing
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              if (weight[i] > 0 &&
                                                  prices[i] > 0)
                                                Text(
                                                  '(₹${prices[i].toStringAsFixed(2)} / ${weight[i]} kg)', // Display both price and weight within brackets
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              if (weight[i] <= 0 &&
                                                  prices[i] > 0)
                                                Text(
                                                  '(₹${prices[i].toStringAsFixed(2)})', // Display only price if weight is zero or less
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              if (weight[i] > 0 &&
                                                  prices[i] <= 0)
                                                Text(
                                                  '(${weight[i]} kg)', // Display only weight if price is zero or less
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
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  "CGST: ₹${itemCGST.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  "SGST: ₹${itemSGST.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
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
                              // Text("Payment Type: $paymentType"),
                              Text("Customer Number: $customerNumber"),
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
}
