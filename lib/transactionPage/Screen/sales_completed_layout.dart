import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:yenpos/Global/Widget/smartsearchtextfield.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Sale_order/Provider/get_sales_order_service.dart';
import 'package:yenpos/transactionPage/Model/transaction_model.dart';
import 'package:yenpos/transactionPage/Provider/transactionProvider.dart';
import 'package:yenpos/transactionPage/widget/quantity_selector.dart';

List<Widget> buildSalesCompletedLayout(
  List<Transaction> _invoices,
  ApiServiceSalesOrderProvider apiService,
  TransactionProvider transactionProvider,
  BuildContext context,
) {
  final reversedList = _invoices.reversed.toList();

  // Group transactions by saleType
  final Map<String, List<Transaction>> groupedTransactions = {};
  for (var txn in reversedList) {
    groupedTransactions
        .putIfAbsent(txn.salesType ?? "Unknown", () => [])
        .add(txn);
  }

  return [
    // Left Panel: Search + Transaction List
    Expanded(
      flex: 1,
      child: Column(
        children: [
          // ===== Search Field =====
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SmartSearchField(
              controller: transactionProvider.searchController,
              onSearch: (query) {
                print("🟡 [TransactionPage] Search query: $query");
                apiService.searchOrders(query);
              },
            ),
          ),

          // ===== Transaction List =====
          Expanded(
            child: groupedTransactions.isEmpty
                ? const Center(child: Text("No Transactions Available"))
                : ListView(
                    padding: const EdgeInsets.all(8.0),
                    children: groupedTransactions.entries.map((entry) {
                      final saleType = entry.key;
                      final transactions = entry.value;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ===== Section Header =====
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              saleType.toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),

                          // ===== Transactions for this type =====
                          ...transactions.asMap().entries.map((txnEntry) {
                            final index = txnEntry.key;
                            final item = txnEntry.value;
                            final isSelected =
                                transactionProvider.selectedTransactionIndex ==
                                reversedList.indexOf(item);

                            String formatInvoiceDateTime(DateTime? dateTime) {
                              if (dateTime == null) return '';
                              final date =
                                  "${dateTime.day.toString().padLeft(2, '0')}-"
                                  "${dateTime.month.toString().padLeft(2, '0')}-"
                                  "${dateTime.year}";
                              final time = DateFormat.jm().format(dateTime);
                              return "$date • $time";
                            }

                            return Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: isSelected ? 6 : 2,
                              color: isSelected
                                  ? Colors.blue.shade50
                                  : Colors.white,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                title: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      item.invoiceNo.toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      "₹${item.totalAmount.toStringAsFixed(0)}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    formatInvoiceDateTime(item.invoiceDateTime),
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                onTap: () {
                                  transactionProvider.selectedTransactionIndex =
                                      reversedList.indexOf(item);
                                },
                              ),
                            );
                          }).toList(),
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    ),

    // Vertical Divider
    const VerticalDivider(),

    // Right Panel: Transaction Detail
    Expanded(
      flex: 2,
      child:
          reversedList.isEmpty ||
              transactionProvider.selectedTransactionIndex == null
          ? const Center(child: Text("Select a Transaction"))
          : _buildTransactionDetail(
              context,
              reversedList[transactionProvider.selectedTransactionIndex!],
            ),
    ),
  ];
}

Widget _buildTransactionDetail(BuildContext context, Transaction transaction) {
  String formatInvoiceDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final date =
        "${dateTime.day.toString().padLeft(2, '0')}-"
        "${dateTime.month.toString().padLeft(2, '0')}-"
        "${dateTime.year}";
    final time = DateFormat.jm().format(dateTime);
    return "$date • $time";
  }

  return SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ===== HEADER CARD =====
        _GlassCard(
          gradient: LinearGradient(
            colors: [Colors.blue.shade500, Colors.blue.shade300],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header title
                Text(
                  "Invoice #${transaction.invoiceNo}",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.4,
                    shadows: [Shadow(color: Colors.black26, blurRadius: 6)],
                  ),
                ),
                const SizedBox(height: 16),
                // Condensed Info Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _infoChip(
                      Icons.calendar_today_rounded,
                      'Date & Time',
                      formatInvoiceDateTime(transaction.invoiceDateTime),
                    ),
                    _infoChip(
                      Icons.payment_rounded,
                      'Payment',
                      transaction.paymentType ?? 'N/A',
                    ),
                    _infoChip(
                      Icons.person_rounded,
                      'Sales Person',
                      transaction.salesPersonName ?? 'N/A',
                    ),
                    _infoChip(
                      Icons.phone_rounded,
                      'Customer',
                      transaction.customerPhoneNumber ?? 'N/A',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // ===== SPLIT LAYOUT =====
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // LEFT: Items
            Expanded(
              flex: 2,
              child: _GlassCard(
                gradient: LinearGradient(
                  colors: [Colors.white.withOpacity(0.95), Colors.white70],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                blur: 20,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "🛍 Items Purchased",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Divider(thickness: 1, color: Colors.grey.shade200),

                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: transaction.itemName.length,
                        separatorBuilder: (_, __) =>
                            Divider(color: Colors.grey.withOpacity(0.2)),
                        itemBuilder: (context, index) {
                          final isKg =
                              transaction.uom[index].toLowerCase() == 'kg';
                          final qty = transaction.qty[index];
                          final formattedQty = isKg
                              ? qty.toStringAsFixed(3)
                              : qty.toStringAsFixed(0);

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                // Item Name & Details
                                Expanded(
                                  flex: 5,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        transaction.varianceName[index],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Text(
                                        '$formattedQty ${transaction.uom[index]}',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Price Tag
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.green.shade400,
                                        Colors.green.shade600,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '₹${transaction.amount[index].toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(width: 20),

            // RIGHT: Payment Details
            Expanded(
              flex: 1,
              child: _GlassCard(
                gradient: LinearGradient(
                  colors: [Colors.white.withOpacity(0.95), Colors.white70],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                blur: 20,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "💳 Payment Details",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Divider(thickness: 1, color: Colors.grey.shade200),
                      if ((transaction.discountAmount ?? 0) > 0)
                        _buildChargeRow(
                          "Discount(${transaction.discountPercentage.toStringAsFixed(2)}%)",
                          "- ₹${transaction.discountAmount!.toStringAsFixed(2)}",
                        ),

                      // if (transaction.discountPercentage > 0)
                      //   _buildChargeRow(
                      //     "Discount (%)",
                      //     "${transaction.discountPercentage.toStringAsFixed(2)}%",
                      //   ),
                      if (transaction.customCharge > 0)
                        _buildChargeRow(
                          "Custom Charge",
                          "₹${transaction.customCharge.toStringAsFixed(2)}",
                        ),
                      _buildChargeRow(
                        "Items Total",
                        "₹${transaction.totalAmount?.toStringAsFixed(2) ?? '0.00'}",
                      ),
                      if (transaction.customCharge > 0 ||
                          (transaction.discountAmount ?? 0) > 0)
                        Divider(thickness: 1, color: Colors.grey.shade200),

                      _buildChargeRow(
                        "Gross Amount",
                        "₹${transaction.grossAmount?.toStringAsFixed(2) ?? '0.00'}",
                      ),
                      Divider(thickness: 1, color: Colors.grey.shade200),
                      Text(
                        "Payment Details",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),

                      _buildChargeRow(
                        "Cash",
                        "₹${transaction.cash.toStringAsFixed(2)}",
                      ),
                      _buildChargeRow("Card", "₹${transaction.card}"),
                      _buildChargeRow("UPI", "₹${transaction.upi}"),
                      if (transaction.others != null)
                        _buildChargeRow(
                          "Others",
                          "₹${transaction.others.toString()}",
                        ),
                      Divider(thickness: 1, color: Colors.grey.shade200),
                      Text(
                        "GST BreakUps",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      _buildChargeRow(
                        "GST",
                        "₹${(transaction.gstValue?.fold<double>(0, (a, b) => a + b) ?? 0).toStringAsFixed(2)}",
                      ),

                      _buildChargeRow(
                        "Net Amount",
                        "₹${transaction.netAmount.toStringAsFixed(2)}",
                      ),
                      Divider(thickness: 1, color: Colors.grey.shade200),
                      _buildChargeRow(
                        "Total Amount",
                        "₹${transaction.totalAmount.toStringAsFixed(2)}",
                        isBold: true,
                        valueColor: Colors.amber.shade700,
                      ),

                      const SizedBox(height: 12),
                      Divider(thickness: 1, color: Colors.grey.shade200),

                      const SizedBox(height: 20),

                      // // Status
                      // if (transaction.status != null)
                      //   _buildChargeRow("Status", transaction.status ?? "N/A"),

                      // const SizedBox(height: 20),

                      // // SALES RETURN BUTTON
                      // Align(
                      //   alignment: Alignment.centerRight,
                      //   child: ElevatedButton.icon(
                      //     style: ElevatedButton.styleFrom(
                      //       backgroundColor: Colors.redAccent.shade400,
                      //       padding: const EdgeInsets.symmetric(
                      //         horizontal: 24,
                      //         vertical: 12,
                      //       ),
                      //       shape: RoundedRectangleBorder(
                      //         borderRadius: BorderRadius.circular(30),
                      //       ),
                      //       shadowColor: Colors.redAccent.withOpacity(0.4),
                      //       elevation: 5,
                      //     ),
                      //     onPressed: () =>
                      //         _showSalesReturnDialog(context, transaction),
                      //     icon: const Icon(Icons.reply, size: 18),
                      //     label: const Text(
                      //       "Sales Return",
                      //       style: TextStyle(
                      //         fontWeight: FontWeight.bold,
                      //         fontSize: 14,
                      //       ),
                      //     ),
                      //   ),
                      // ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// ===== Glassmorphism Card Wrapper =====
class _GlassCard extends StatelessWidget {
  final Widget child;
  final LinearGradient gradient;
  final double blur;

  const _GlassCard({
    required this.child,
    required this.gradient,
    this.blur = 15,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ===== Helper Widgets =====
Widget _infoChip(IconData icon, String title, String value) {
  return Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.white70),
            const SizedBox(width: 6),
            Text(title, style: TextStyle(fontSize: 13, color: Colors.white70)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

Widget _buildChargeRow(
  String title,
  String value, {
  bool isBold = false,
  Color? valueColor,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: valueColor ?? Colors.black87,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

void _showSalesReturnDialog(BuildContext context, Transaction transaction) {
  List<double> returnQuantities = List<double>.filled(
    transaction.qty.length,
    0.0,
  );

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            title: Center(
              child: Text(
                'Sales Return',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(transaction.itemName.length, (index) {
                  final isKg =
                      transaction.uom[index].toLowerCase() == "kg" ||
                      transaction.uom[index].toLowerCase() == "kgs";

                  final quantityDisplay = isKg
                      ? '${transaction.qty[index].toStringAsFixed(2)} ${transaction.uom[index]}'
                      : '${transaction.qty[index].toInt()} ${transaction.uom[index]}';

                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 8),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  transaction.itemName[index],
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  '${transaction.varianceName[index]} | Qty: $quantityDisplay',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: isKg
                                ? ElevatedButton(
                                    onPressed: () {},
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blueAccent,
                                      padding: EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                    ),
                                    child: Text(
                                      "Choose Weight",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  )
                                : QuantitySelector(
                                    initialQuantity: returnQuantities[index]
                                        .toInt(),
                                    maxQuantity: transaction.qty[index].toInt(),
                                    onQuantityChanged: (newQuantity) {
                                      setState(() {
                                        returnQuantities[index] = newQuantity
                                            .toDouble();
                                      });
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  List<Map<String, dynamic>> returnData = [];
                  for (int i = 0; i < transaction.itemName.length; i++) {
                    if (returnQuantities[i] > 0) {
                      returnData.add({
                        "itemName": transaction.itemName[i],
                        "variance": transaction.varianceName[i],
                        "returnQty": returnQuantities[i],
                        "pricePerUnit": transaction.price[i],
                        "returnPrice":
                            returnQuantities[i] * transaction.price[i],
                        "uom": transaction.uom[i],
                        "tax": transaction.tax[i] ?? 0,
                      });
                    }
                  }

                  if (returnData.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Please select items to return.")),
                    );
                    return;
                  }

                  Navigator.pop(context);
                  await postSalesReturn(context, returnData);
                },
                child: const Text('Send to Approve'),
              ),
            ],
          );
        },
      );
    },
  );
}

// Post Sales Return
Future<void> postSalesReturn(
  BuildContext context,
  List<Map<String, dynamic>> returnData,
) async {
  final String formattedDate = DateFormat("dd-MM-yyyy").format(DateTime.now());
  const url = "https://yenerp.com/fastapi/salesreturns/";

  final payload = {
    "salesReturnId": "auto_generated_id",
    "itemName": returnData.map((item) => item["itemName"]).toList(),
    "price": returnData.map((item) => item["pricePerUnit"].toString()).toList(),
    "qty": returnData.map((item) => item["returnQty"].toString()).toList(),
    "amount": returnData.map((item) => item["returnPrice"].toString()).toList(),
    "tax": returnData.map((item) => item["tax"].toString()).toList(),
    "uom": returnData.map((item) => item["uom"]).toList(),
    "totalAmount": returnData
        .fold(0.0, (sum, item) => sum + (item["returnPrice"] as double))
        .toString(),
    "status": "sales return",
    "branch": branchName,
    "date": formattedDate,
    "time": TimeOfDay.now().format(context),
  };

  try {
    final response = await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Sales return posted successfully!")),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to post sales return")));
    }
  } catch (e) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Error posting sales return")));
  }
}
