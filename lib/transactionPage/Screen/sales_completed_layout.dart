import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get_connect/http/src/utils/utils.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Global/Widget/smartsearchtextfield.dart';
import 'package:yenpos/Global/globals_data.dart';

import 'package:yenpos/Sale_order/Provider/get_sales_order_service.dart';
import 'package:yenpos/Sale_order/Widgets/Send_data_to_server.dart';
import 'package:yenpos/Sale_order/Widgets/numeric_Calculator.dart';
import 'package:yenpos/transactionPage/Model/transaction_model.dart';
import 'package:yenpos/transactionPage/Provider/transactionProvider.dart';
import 'package:yenpos/transactionPage/widget/glass_card.dart';

// String _getOrderShortName(String type) {
//   final t = type.toLowerCase().replaceAll(' ', '');
//   switch (t) {
//     case 'takeaway':
//       return 'TA';
//     case 'dinein':
//       return 'DI';
//     case 'salesorder':
//       return 'SO';
//     default:
//       return '';
//   }
// }

// List<String> orderFilters = ["all", "takeaway", "dinein", "salesorder"];

// List<Widget> buildSalesCompletedLayout(
//   List<Transaction> invoices,
//   ApiServiceSalesOrderProvider apiService,
//   TransactionProvider transactionProvider,
//   BuildContext context,
// ) {
//   /// Selected filter
//   String selectedFilter = transactionProvider.selectedOrderFilter ?? "all";

//   /// Reverse list
//   final reversedList = invoices.reversed.toList();

//   /// Filtered list logic
//   final filteredList = selectedFilter == "all"
//       ? reversedList
//       : reversedList
//             .where(
//               (txn) =>
//                   (txn.salesType?.toLowerCase().replaceAll(' ', '') ?? "") ==
//                   selectedFilter,
//             )
//             .toList();

//   return [
//     Expanded(
//       flex: 1,
//       child: Column(
//         children: [
//           // 🔍 Search Field
//           Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: SmartSearchField(
//               controller: transactionProvider.searchController,
//               onSearch: (q) => apiService.searchOrders(q),
//             ),
//           ),

//           Container(
//             padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: orderFilters.map((type) {
//                 bool isActive = selectedFilter == type;

//                 return GestureDetector(
//                   onTap: () {
//                     transactionProvider.selectedOrderFilter = type;
//                     transactionProvider.selectedTransactionIndex = null;
//                   },
//                   child: Container(
//                     margin: const EdgeInsets.only(right: 10),
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 14,
//                       vertical: 6,
//                     ),
//                     decoration: BoxDecoration(
//                       color: isActive ? Colors.blue : Colors.white10,
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: Text(
//                       type.toUpperCase(),
//                       style: TextStyle(
//                         color: isActive ? Colors.white : Colors.black87,
//                         fontWeight: FontWeight.bold,
//                         fontSize: 13,
//                       ),
//                     ),
//                   ),
//                 );
//               }).toList(),
//             ),
//           ),

//           Expanded(
//             child: filteredList.isEmpty
//                 ? Center(
//                     child: Text(
//                       "No ${selectedFilter.toUpperCase()} Orders",
//                       style: const TextStyle(fontSize: 16),
//                     ),
//                   )
//                 : ListView.builder(
//                     padding: const EdgeInsets.all(8),
//                     itemCount: filteredList.length,
//                     itemBuilder: (context, index) {
//                       final txn = filteredList[index];
//                       final isSelected =
//                           transactionProvider.selectedTransactionIndex == index;

//                       return Column(
//                         children: [
//                           GestureDetector(
//                             onTap: () {
//                               transactionProvider.selectedTransactionIndex =
//                                   index;
//                             },
//                             child: Container(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 16,
//                                 vertical: 14,
//                               ),
//                               decoration: BoxDecoration(
//                                 gradient: isSelected
//                                     ? LinearGradient(
//                                         colors: [
//                                           Colors.blue.shade500,
//                                           Colors.blue.shade300,
//                                         ],
//                                         begin: Alignment.topLeft,
//                                         end: Alignment.bottomRight,
//                                       )
//                                     : null,
//                                 color: isSelected ? null : Colors.transparent,
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                               child: Row(
//                                 children: [
//                                   // S.NO
//                                   SizedBox(
//                                     width: 25,
//                                     child: Text(
//                                       "${index + 1}",
//                                       style: TextStyle(
//                                         fontSize: 14,
//                                         fontWeight: FontWeight.bold,
//                                         color: isSelected
//                                             ? Colors.white
//                                             : Colors.black54,
//                                       ),
//                                     ),
//                                   ),

//                                   // INVOICE NO
//                                   SizedBox(
//                                     width: 200,
//                                     child: Text(
//                                       txn.invoiceNo.toString(),
//                                       style: TextStyle(
//                                         fontWeight: FontWeight.bold,
//                                         fontSize: 16,
//                                         color: isSelected
//                                             ? Colors.white
//                                             : Colors.black87,
//                                       ),
//                                     ),
//                                   ),

//                                   const SizedBox(width: 35),

//                                   // TAG
//                                   Container(
//                                     padding: const EdgeInsets.symmetric(
//                                       horizontal: 6,
//                                       vertical: 2,
//                                     ),
//                                     decoration: BoxDecoration(
//                                       color: isSelected
//                                           ? Colors.white
//                                           : Colors.blue[400],
//                                       // border:
//                                       //     Border.all(color: Colors.black54),
//                                       borderRadius: BorderRadius.circular(4),
//                                     ),
//                                     child: Text(
//                                       _getOrderShortName(txn.salesType.trim()),
//                                       style: TextStyle(
//                                         fontSize: 11,
//                                         fontWeight: FontWeight.w600,
//                                         color: isSelected
//                                             ? Colors.blue
//                                             : Colors.white,
//                                       ),
//                                     ),
//                                   ),

//                                   // AMOUNT
//                                   Expanded(
//                                     child: Text(
//                                       "₹${txn.totalAmount.toStringAsFixed(0)}",
//                                       textAlign: TextAlign.end,
//                                       style: TextStyle(
//                                         fontWeight: FontWeight.bold,
//                                         fontSize: 16,
//                                         color: isSelected
//                                             ? Colors.white
//                                             : Colors.black54,
//                                       ),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),

//                           //const Divider(height: 1),
//                         ],
//                       );
//                     },
//                   ),
//           ),
//         ],
//       ),
//     ),

//     const VerticalDivider(),

//     Expanded(
//       flex: 2,
//       child:
//           filteredList.isEmpty ||
//               transactionProvider.selectedTransactionIndex == null
//           ? const Center(child: Text("Select an Order"))
//           : _buildTransactionDetail(
//               context,
//               filteredList[transactionProvider.selectedTransactionIndex!],
//             ),
//     ),
//   ];
// }

// Widget _buildTransactionDetail(BuildContext context, Transaction transaction) {
//   final ScrollController _scrollController = ScrollController();
//   String formatInvoiceDateTime(DateTime? dateTime) {
//     if (dateTime == null) return '';
//     final date =
//         "${dateTime.day.toString().padLeft(2, '0')}-"
//         "${dateTime.month.toString().padLeft(2, '0')}-"
//         "${dateTime.year}";
//     final time = DateFormat.jm().format(dateTime);
//     return "$date • $time";
//   }

//   // Use the helper method to get properly aligned items
//   final items = transaction.getItems();

//   return Column(
//     children: [
//       GlassCard(
//         gradient: LinearGradient(
//           colors: [Colors.blue.shade500, Colors.blue.shade300],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         child: Padding(
//           padding: const EdgeInsets.all(20),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   infoChip(
//                     Icons.calendar_today_rounded,
//                     'Date & Time',
//                     formatInvoiceDateTime(transaction.invoiceDateTime),
//                   ),
//                   infoChip(
//                     Icons.payment_rounded,
//                     'Payment',
//                     transaction.paymentType ?? 'N/A',
//                   ),
//                   infoChip(
//                     Icons.person_rounded,
//                     'Sales Person',
//                     transaction.salesPersonName,
//                   ),
//                   infoChip(
//                     Icons.phone_rounded,
//                     'Customer',
//                     transaction.customerPhoneNumber,
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),

//       // ✅ FIX ADDED HERE
//       Expanded(
//         child: Row(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Expanded(
//               flex: 1,
//               child: Column(
//                 children: [
//                   const SizedBox(height: 20),
//                   Expanded(
//                     child: GlassCard(
//                       gradient: LinearGradient(
//                         colors: [
//                           Colors.white.withOpacity(0.95),
//                           Colors.white70,
//                         ],
//                         begin: Alignment.topRight,
//                         end: Alignment.bottomLeft,
//                       ),
//                       blur: 20,
//                       child: Scrollbar(
//                         controller: _scrollController,
//                         thumbVisibility: true,
//                         radius: const Radius.circular(8),
//                         thickness: 5,
//                         trackVisibility: false,
//                         child: Padding(
//                           padding: const EdgeInsets.all(20),
//                           child: SingleChildScrollView(
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Row(
//                                   children: [
//                                     Icon(Icons.payment_rounded),
//                                     SizedBox(width: 10),
//                                     Text(
//                                       "Payment Details",
//                                       style: TextStyle(
//                                         fontSize: 16,
//                                         fontWeight: FontWeight.w700,
//                                         color: Colors.black87,
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                                 const SizedBox(height: 10),
//                                 Divider(
//                                   thickness: 1,
//                                   color: Colors.grey.shade200,
//                                 ),

//                                 if ((transaction.discountAmount ?? 0) > 0)
//                                   buildChargeRow(
//                                     "Discount(${transaction.discountPercentage.toStringAsFixed(2)}%)",
//                                     "- ₹${transaction.discountAmount!.toStringAsFixed(2)}",
//                                   ),

//                                 if (transaction.customCharge > 0)
//                                   buildChargeRow(
//                                     "Custom Charge",
//                                     "₹${transaction.customCharge.toStringAsFixed(2)}",
//                                   ),

//                                 buildChargeRow(
//                                   "Items Total",
//                                   "₹${transaction.totalAmount.toStringAsFixed(2)}",
//                                 ),

//                                 if (transaction.customCharge > 0 ||
//                                     (transaction.discountAmount ?? 0) > 0)
//                                   Divider(
//                                     thickness: 1,
//                                     color: Colors.grey.shade200,
//                                   ),

//                                 buildChargeRow(
//                                   "Gross Amount",
//                                   "₹${transaction.grossAmount.toStringAsFixed(2) ?? '0.00'}",
//                                 ),
//                                 Divider(
//                                   thickness: 1,
//                                   color: Colors.grey.shade200,
//                                 ),

//                                 Text(
//                                   "Payment Details",
//                                   style: TextStyle(
//                                     fontSize: 14,
//                                     fontWeight: FontWeight.w700,
//                                     color: Colors.black87,
//                                   ),
//                                 ),
//                                 const SizedBox(height: 8),

//                                 buildChargeRow(
//                                   "Cash",
//                                   "₹${(transaction.cash ?? 0).toStringAsFixed(2)}",
//                                 ),
//                                 buildChargeRow(
//                                   "Card",
//                                   "₹${transaction.card ?? 0}",
//                                 ),
//                                 buildChargeRow(
//                                   "UPI",
//                                   "₹${transaction.upi ?? 0}",
//                                 ),

//                                 if (transaction.others != null)
//                                   buildChargeRow(
//                                     "Others",
//                                     "₹${transaction.others.toString()}",
//                                   ),

//                                 Divider(
//                                   thickness: 1,
//                                   color: Colors.grey.shade200,
//                                 ),

//                                 Text(
//                                   "GST BreakUps",
//                                   style: TextStyle(fontWeight: FontWeight.bold),
//                                 ),

//                                 buildChargeRow(
//                                   "GST",
//                                   "₹${(transaction.gstValue?.fold<double>(0, (a, b) => a + b) ?? 0).toStringAsFixed(2)}",
//                                 ),

//                                 buildChargeRow(
//                                   "Net Amount",
//                                   "₹${transaction.netAmount.toStringAsFixed(2)}",
//                                 ),

//                                 Divider(
//                                   thickness: 1,
//                                   color: Colors.grey.shade200,
//                                 ),

//                                 buildChargeRow(
//                                   "Total Amount",
//                                   "₹${transaction.totalAmount.toStringAsFixed(2)}",
//                                   isBold: true,
//                                   valueColor: Colors.amber.shade700,
//                                 ),

//                                 const SizedBox(height: 20),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),

//             const SizedBox(width: 20),

//             Expanded(
//               flex: 2,
//               child: Column(
//                 children: [
//                   const SizedBox(height: 20),
//                   Expanded(
//                     child: GlassCard(
//                       gradient: LinearGradient(
//                         colors: [
//                           Colors.white.withOpacity(0.95),
//                           Colors.white70,
//                         ],
//                         begin: Alignment.topLeft,
//                         end: Alignment.bottomRight,
//                       ),
//                       blur: 20,
//                       child: Scrollbar(
//                         controller: _scrollController,
//                         thumbVisibility: true,
//                         radius: const Radius.circular(8),
//                         thickness: 5,
//                         trackVisibility: false,
//                         child: Padding(
//                           padding: const EdgeInsets.all(20),
//                           child: SingleChildScrollView(
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Row(
//                                   children: [
//                                     Icon(Icons.shopping_cart_rounded),
//                                     SizedBox(width: 10),
//                                     Text(
//                                       "Items Purchased",
//                                       style: TextStyle(
//                                         fontSize: 18,
//                                         fontWeight: FontWeight.w700,
//                                         color: Colors.black87,
//                                         letterSpacing: 0.3,
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                                 const SizedBox(height: 10),
//                                 Divider(
//                                   thickness: 1,
//                                   color: Colors.grey.shade200,
//                                 ),

//                                 // Fixed items list using the helper method
//                                 items.isEmpty
//                                     ? Center(
//                                         child: Padding(
//                                           padding: const EdgeInsets.all(20.0),
//                                           child: Text(
//                                             "No items found",
//                                             style: TextStyle(
//                                               color: Colors.grey.shade600,
//                                               fontSize: 16,
//                                             ),
//                                           ),
//                                         ),
//                                       )
//                                     : ListView.separated(
//                                         shrinkWrap: true,
//                                         physics: NeverScrollableScrollPhysics(),
//                                         itemCount: items.length,
//                                         separatorBuilder: (_, __) => Divider(
//                                           color: Colors.grey.withOpacity(0.2),
//                                         ),
//                                         itemBuilder: (context, index) {
//                                           debugPrint("TItems - $items");
//                                           final item = items[index];
//                                           final isKg =
//                                               item['uom']
//                                                   ?.toString()
//                                                   .toLowerCase() ==
//                                               'kg';
//                                           final qty = (item['qty'] as num)
//                                               .toDouble();
//                                           final formattedQty = isKg
//                                               ? qty.toStringAsFixed(3)
//                                               : qty.toStringAsFixed(0);
//                                           final sellingPrice =
//                                               item['sellingPrice'] ?? 0;
//                                           final sellingAmount =
//                                               item['sellingAmount'] ?? 0;

//                                           return Padding(
//                                             padding: const EdgeInsets.symmetric(
//                                               vertical: 6,
//                                             ),
//                                             child: Row(
//                                               children: [
//                                                 Expanded(
//                                                   flex: 5,
//                                                   child: Column(
//                                                     crossAxisAlignment:
//                                                         CrossAxisAlignment
//                                                             .start,
//                                                     children: [
//                                                       Text(
//                                                         item['varianceName']
//                                                                 ?.toString() ??
//                                                             'N/A',
//                                                         style: const TextStyle(
//                                                           fontWeight:
//                                                               FontWeight.w600,
//                                                           fontSize: 15,
//                                                         ),
//                                                       ),
//                                                       Text(
//                                                         '$formattedQty ${item['uom']} x ₹$sellingPrice',
//                                                         style: TextStyle(
//                                                           color: Colors
//                                                               .grey
//                                                               .shade800,
//                                                           fontSize: 14,
//                                                         ),
//                                                       ),
//                                                     ],
//                                                   ),
//                                                 ),
//                                                 Text(
//                                                   '₹${sellingAmount.toStringAsFixed(2)}',
//                                                   style: const TextStyle(
//                                                     color: Colors.black,
//                                                     fontWeight: FontWeight.bold,
//                                                     fontSize: 16,
//                                                   ),
//                                                 ),
//                                               ],
//                                             ),
//                                           );
//                                         },
//                                       ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     ],
//   );
// }

// // ===== Helper Widgets =====
// Widget infoChip(IconData icon, String title, String value) {
//   return Expanded(
//     child: Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             Icon(icon, size: 18, color: Colors.white70),
//             const SizedBox(width: 6),
//             Text(title, style: TextStyle(fontSize: 13, color: Colors.white70)),
//           ],
//         ),
//         const SizedBox(height: 4),
//         Text(
//           value,
//           style: TextStyle(
//             fontSize: 14,
//             color: Colors.white,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//       ],
//     ),
//   );
// }

// Widget buildChargeRow(
//   String title,
//   String value, {
//   bool isBold = false,
//   Color? valueColor,
// }) {
//   return Padding(
//     padding: const EdgeInsets.symmetric(vertical: 3),
//     child: Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Text(
//           title,
//           style: TextStyle(
//             fontSize: 14,
//             color: Colors.grey.shade700,
//             fontWeight: FontWeight.w500,
//           ),
//         ),
//         Text(
//           value,
//           style: TextStyle(
//             fontSize: 14,
//             color: valueColor ?? Colors.black87,
//             fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
//           ),
//         ),
//       ],
//     ),
//   );
// }

// ==================== ADD THIS HELPER FUNCTION AT TOP (outside class) ====================
Future<bool> _hasSalesReturnForInvoice(String invoiceNo) async {
  try {
    final salesReturnBox = await Hive.openBox('salesReturns');
    return salesReturnBox.keys.any(
      (key) => key.toString().startsWith('$invoiceNo-'),
    );
  } catch (e) {
    return false;
  }
}

Future<List<Map<String, dynamic>>> _getReturnedItemsForInvoice(
  String invoiceNo,
) async {
  try {
    final box = await Hive.openBox('salesReturns');
    List<Map<String, dynamic>> result = [];

    for (var key in box.keys) {
      final data = box.get(key);
      if (data is Map && data['invoiceNo']?.toString() == invoiceNo) {
        final List<dynamic> names = data['varianceName'] ?? [];
        final List<dynamic> qty = data['qty'] ?? [];
        final List<dynamic> weight = data['weight'] ?? [];
        final List<dynamic> uomList = data['uom'] ?? [];

        for (int i = 0; i < names.length; i++) {
          final name = names[i]?.toString() ?? '';
          if (name.isEmpty) continue;

          final String unit = (uomList[i]?.toString() ?? '').toLowerCase();
          final bool isKg = unit.contains('kg');
          final double returnedQty = isKg
              ? (weight[i] as num?)?.toDouble() ?? 0.0
              : (qty[i] as num?)?.toDouble() ?? 0.0;

          if (returnedQty > 0) {
            result.add({
              'varianceName': name,
              'returnedQty': returnedQty,
              'uom': uomList[i],
            });
          }
        }
      }
    }
    return result;
  } catch (e) {
    debugPrint("Error loading returned items: $e");
    return [];
  }
}

String _getOrderShortName(String type) {
  final t = type.toLowerCase().replaceAll(' ', '');
  switch (t) {
    case 'takeaway':
      return 'TA';
    case 'dinning':
      return 'DI';
    case 'salesorder':
      return 'SO';
    default:
      return '';
  }
}

List<String> orderFilters = ["all", "takeaway", "dinning", "salesorder"];
String _normalizeSalesType(String? type) {
  if (type == null) return "";
  final normalized = type
      .toLowerCase()
      .trim()
      .replaceAll(' ', '')
      .replaceAll('-', '');

  if (normalized.contains('takeaway') || normalized.contains('take away')) {
    return 'takeaway';
  } else if (normalized.contains('dinein') ||
      normalized.contains('dinning') ||
      normalized.contains('dine-in') ||
      normalized.contains('dine')) {
    return 'dinein';
  } else if (normalized.contains('salesorder') ||
      normalized.contains('saleorder')) {
    return 'salesorder';
  }
  return '';
}

List<Widget> buildSalesCompletedLayout(
  List<Transaction> invoices,
  ApiServiceSalesOrderProvider apiService,
  TransactionProvider transactionProvider, // ← Use this one!
  BuildContext context,
) {
  // REMOVE THIS LINE ENTIRELY:
  // final transactionProvider = Provider.of<TransactionProvider>(context,listen: false);

  /// Selected filter — now correctly reacts to changes
  String selectedFilter = transactionProvider.selectedOrderFilter ?? "all";

  /// Reverse list
  final reversedList = invoices.reversed.toList();

  /// Filtered list logic
  final filteredList = selectedFilter == "all"
      ? reversedList
      : reversedList.where((txn) {
          final String normalizedType = _normalizeSalesType(txn.salesType);
          return normalizedType == selectedFilter;
        }).toList();

  // Rest of your code stays 100% the same
  return [
    Expanded(
      flex: 1,
      child: Consumer<TransactionProvider>(
        // ← ADD THIS TO MAKE IT REBUILD!
        builder: (context, provider, child) {
          // Recalculate filtered list on every provider change
          final currentFilter = provider.selectedOrderFilter ?? "all";
          final currentFiltered = currentFilter == "all"
              ? invoices.reversed.toList()
              : invoices.reversed.where((txn) {
                  final String normalizedType = _normalizeSalesType(
                    txn.salesType,
                  );
                  return normalizedType == currentFilter;
                }).toList();

          return Column(
            children: [
              // Search + Filters (same as before)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: SmartSearchField(
                  controller: provider.searchController,
                  onSearch: (q) => apiService.searchOrders(q),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 5,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: orderFilters.map((type) {
                    bool isActive = currentFilter == type;
                    return GestureDetector(
                      onTap: () {
                        provider.selectedOrderFilter = type;
                        provider.selectedTransactionIndex = null;
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isActive ? Colors.blue : Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          type.toUpperCase(),
                          style: TextStyle(
                            color: isActive ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: currentFiltered.isEmpty
                    ? Center(
                        child: Text("No ${currentFilter.toUpperCase()} Orders"),
                      )
                    : ListView.builder(
                        itemCount: currentFiltered.length,
                        itemBuilder: (context, index) {
                          final txn = currentFiltered[index];
                          final isSelected =
                              provider.selectedTransactionIndex == index;

                          return FutureBuilder<bool>(
                            future: _hasSalesReturnForInvoice(
                              txn.invoiceNo.toString(),
                            ),
                            builder: (context, snapshot) {
                              final bool hasReturn = snapshot.data ?? false;

                              return GestureDetector(
                                onTap: () =>
                                    provider.selectedTransactionIndex = index,
                                child: Stack(
                                  children: [
                                    // Your card UI...
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 5),
                                      child: Material(
                                        elevation: 4,
                                        shadowColor: Colors.black26,
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 16,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: isSelected
                                                ? LinearGradient(
                                                    colors: [
                                                      Colors.blue.shade500,
                                                      Colors.blue.shade300,
                                                    ],
                                                  )
                                                : null,
                                            color: isSelected
                                                ? null
                                                : Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 25,
                                                child: Text(
                                                  "${index + 1}",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: isSelected
                                                        ? Colors.white
                                                        : Colors.black54,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: 200,
                                                child: Text(
                                                  txn.invoiceNo.toString(),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    color: isSelected
                                                        ? Colors.white
                                                        : Colors.black87,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 35),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? Colors.white
                                                      : Colors.blue[400],
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  _getOrderShortName(
                                                    txn.salesType.trim(),
                                                  ),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: isSelected
                                                        ? Colors.blue
                                                        : Colors.white,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  "₹${txn.totalAmount.toStringAsFixed(0)}",
                                                  textAlign: TextAlign.end,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    color: isSelected
                                                        ? Colors.white
                                                        : Colors.black54,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (hasReturn)
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade500,
                                            borderRadius: BorderRadius.only(
                                              topRight: Radius.circular(8),
                                              bottomLeft: Radius.circular(8),
                                            ),
                                          ),
                                          child: Text(
                                            "RETURNED",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    ),
    const VerticalDivider(),
    Expanded(
      flex: 2,
      child:
          transactionProvider.selectedTransactionIndex == null ||
              filteredList.isEmpty
          ? const Center(child: Text("Select an Order"))
          : _buildTransactionDetail(
              context,
              filteredList[transactionProvider.selectedTransactionIndex!],
              transactionProvider, // passed correctly
            ),
    ),
  ];
}

// List<Widget> buildSalesCompletedLayout(
//   List<Transaction> invoices,
//   ApiServiceSalesOrderProvider apiService,
//   TransactionProvider transactionProvider,
//   BuildContext context,
// ) {
//   /// Selected filter
//   String selectedFilter = transactionProvider.selectedOrderFilter ?? "all";

//   /// Reverse list
//   final reversedList = invoices.reversed.toList();

//   /// Filtered list logic
//   final filteredList = selectedFilter == "all"
//       ? reversedList
//       : reversedList.where((txn) {
//           final String normalizedType = _normalizeSalesType(txn.salesType);
//           return normalizedType == selectedFilter;
//         }).toList();
//   return [
//     Expanded(
//       flex: 1,
//       child: Consumer<TransactionProvider>(
//       builder: (context, provider, child) {
//        return Column(
//           children: [
//             // 🔍 Search Field
//             Padding(
//               padding: const EdgeInsets.all(8.0),
//               child: SmartSearchField(
//                 controller: transactionProvider.searchController,
//                 onSearch: (q) => apiService.searchOrders(q),
//               ),
//             ),
//             Container(
//               padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: orderFilters.map((type) {
//                   bool isActive = selectedFilter == type;
//                   return GestureDetector(
//                     onTap: () {
//                       transactionProvider.selectedOrderFilter = type;
//                       transactionProvider.selectedTransactionIndex = null;
//                     },
//                     child: Container(
//                       margin: const EdgeInsets.only(right: 10),
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 14,
//                         vertical: 6,
//                       ),
//                       decoration: BoxDecoration(
//                         color: isActive ? Colors.blue : Colors.white10,
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       child: Text(
//                         type.toUpperCase(),
//                         style: TextStyle(
//                           color: isActive ? Colors.white : Colors.black87,
//                           fontWeight: FontWeight.bold,
//                           fontSize: 13,
//                         ),
//                       ),
//                     ),
//                   );
//                 }).toList(),
//               ),
//             ),
//             //           Container(
//             //   padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
//             //   child: Row(
//             //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             //     children: orderFilters.map((filterKey) {
//             //       String displayText;
//             //       switch (filterKey) {
//             //         case "takeaway":
//             //           displayText = "Takeaway";
//             //           break;
//             //         case "dinein":
//             //           displayText = "Dine In";
//             //           break;
//             //         case "salesorder":
//             //           displayText = "Sales Order";
//             //           break;
//             //         case "all":
//             //         default:
//             //           displayText = "All";
//             //       }

//             //       bool isActive = selectedFilter == filterKey;
//             //       return GestureDetector(
//             //         onTap: () {
//             //           transactionProvider.selectedOrderFilter = filterKey;
//             //           transactionProvider.selectedTransactionIndex = null;
//             //         },
//             //         child: Container(
//             //           margin: const EdgeInsets.only(right: 10),
//             //           padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
//             //           decoration: BoxDecoration(
//             //             color: isActive ? Colors.blue : Colors.white10,
//             //             borderRadius: BorderRadius.circular(8),
//             //           ),
//             //           child: Text(
//             //             displayText,
//             //             style: TextStyle(
//             //               color: isActive ? Colors.white : Colors.black87,
//             //               fontWeight: FontWeight.bold,
//             //               fontSize: 13,
//             //             ),
//             //           ),
//             //         ),
//             //       );
//             //     }).toList(),
//             //   ),
//             // ),
//             Expanded(
//               child: filteredList.isEmpty
//                   ? Center(
//                       child: Text(
//                         "No ${selectedFilter.toUpperCase()} Orders",
//                         style: const TextStyle(fontSize: 16),
//                       ),
//                     )
//                   : ListView.builder(
//                       //padding: const EdgeInsets.all(8),
//                       itemCount: filteredList.length,
//                       itemBuilder: (context, index) {
//                         final txn = filteredList[index];
//                         final isSelected =
//                             transactionProvider.selectedTransactionIndex == index;

//                         return FutureBuilder<bool>(
//                           future: _hasSalesReturnForInvoice(
//                             txn.invoiceNo.toString(),
//                           ),
//                           builder: (context, snapshot) {
//                             final bool hasReturn = snapshot.data ?? false;

//                             return Column(
//                               children: [
//                                 GestureDetector(
//                                   onTap: () {
//                                     transactionProvider.selectedTransactionIndex =
//                                         index;
//                                   },
//                                   child: Stack(
//                                     children: [
//                                       Padding(
//                                         padding: const EdgeInsets.only(bottom: 5),
//                                         child: Material(
//                                           elevation: 4,
//                                           shadowColor: Colors.black26,
//                                           borderRadius: BorderRadius.circular(8),
//                                           child: Container(
//                                             padding: const EdgeInsets.symmetric(
//                                               horizontal: 16,
//                                               vertical: 16,
//                                             ),
//                                             decoration: BoxDecoration(
//                                               gradient: isSelected
//                                                   ? LinearGradient(
//                                                       colors: [
//                                                         Colors.blue.shade500,
//                                                         Colors.blue.shade300,
//                                                       ],
//                                                     )
//                                                   : null,
//                                               color: isSelected
//                                                   ? null
//                                                   : Colors.white,
//                                               borderRadius: BorderRadius.circular(
//                                                 8,
//                                               ),
//                                             ),
//                                             child: Row(
//                                               children: [
//                                                 SizedBox(
//                                                   width: 25,
//                                                   child: Text(
//                                                     "${index + 1}",
//                                                     style: TextStyle(
//                                                       fontWeight: FontWeight.bold,
//                                                       color: isSelected
//                                                           ? Colors.white
//                                                           : Colors.black54,
//                                                     ),
//                                                   ),
//                                                 ),
//                                                 SizedBox(
//                                                   width: 200,
//                                                   child: Text(
//                                                     txn.invoiceNo.toString(),
//                                                     style: TextStyle(
//                                                       fontWeight: FontWeight.bold,
//                                                       fontSize: 16,
//                                                       color: isSelected
//                                                           ? Colors.white
//                                                           : Colors.black87,
//                                                     ),
//                                                   ),
//                                                 ),
//                                                 const SizedBox(width: 35),
//                                                 Container(
//                                                   padding:
//                                                       const EdgeInsets.symmetric(
//                                                         horizontal: 6,
//                                                         vertical: 2,
//                                                       ),
//                                                   decoration: BoxDecoration(
//                                                     color: isSelected
//                                                         ? Colors.white
//                                                         : Colors.blue[400],
//                                                     borderRadius:
//                                                         BorderRadius.circular(4),
//                                                   ),
//                                                   child: Text(
//                                                     _getOrderShortName(
//                                                       txn.salesType.trim(),
//                                                     ),
//                                                     style: TextStyle(
//                                                       fontSize: 11,
//                                                       fontWeight: FontWeight.w600,
//                                                       color: isSelected
//                                                           ? Colors.blue
//                                                           : Colors.white,
//                                                     ),
//                                                   ),
//                                                 ),
//                                                 Expanded(
//                                                   child: Text(
//                                                     "₹${txn.totalAmount.toStringAsFixed(0)}",
//                                                     textAlign: TextAlign.end,
//                                                     style: TextStyle(
//                                                       fontWeight: FontWeight.bold,
//                                                       fontSize: 16,
//                                                       color: isSelected
//                                                           ? Colors.white
//                                                           : Colors.black54,
//                                                     ),
//                                                   ),
//                                                 ),
//                                               ],
//                                             ),
//                                           ),
//                                         ),
//                                       ),
//                                       // RETURNED BADGE
//                                       if (hasReturn)
//                                         Positioned(
//                                           top: 0,
//                                           right: 0,
//                                           child: Container(
//                                             padding: EdgeInsets.symmetric(
//                                               horizontal: 10,
//                                               vertical: 1,
//                                             ),
//                                             decoration: BoxDecoration(
//                                               color: Colors.red.shade500,
//                                               borderRadius: BorderRadius.only(
//                                                 topRight: Radius.circular(8),
//                                                 bottomLeft: Radius.circular(8),
//                                               ),
//                                             ),
//                                             child: Text(
//                                               "RETURNED",
//                                               style: TextStyle(
//                                                 color: Colors.white,
//                                                 fontSize: 10,
//                                                 fontWeight: FontWeight.bold,
//                                               ),
//                                             ),
//                                           ),
//                                         ),
//                                     ],
//                                   ),
//                                 ),
//                               ],
//                             );
//                           },
//                         );
//                       },
//                     ),
//             ),
//           ],
//         );
//       },
//       ),
//     ),
//     const VerticalDivider(),
//     Expanded(
//       flex: 2,
//       child:
//           filteredList.isEmpty ||
//               transactionProvider.selectedTransactionIndex == null
//           ? const Center(child: Text("Select an Order"))
//           : _buildTransactionDetail(
//               context,
//               filteredList[transactionProvider.selectedTransactionIndex!],transactionProvider
//             ),
//     ),
//   ];
// }

Widget _buildTransactionDetail(
  BuildContext context,
  Transaction transaction,
  TransactionProvider transactionProvider,
) {
  // ADD THIS — Check if order is TakeAway

  final ScrollController _scrollController = ScrollController();
  String formatInvoiceDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final date =
        "${dateTime.day.toString().padLeft(2, '0')}-"
        "${dateTime.month.toString().padLeft(2, '0')}-"
        "${dateTime.year}";
    final time = DateFormat.jm().format(dateTime);
    return "$date • $time";
  }

  // Use the helper method to get properly aligned items
  final ValueNotifier<List<Map<String, dynamic>>> editableItems = ValueNotifier(
    transaction.getItems(),
  );
  final ValueNotifier<bool> isReturnMode = ValueNotifier(false);
  //final TextEditingController qtyController = TextEditingController();

  // Helper to calculate totals based on current editable items
  Map<String, dynamic> _calculateReturnData() {
    final returnedItems = editableItems.value
        .where((i) => ((i['returnQty'] as num?)?.toDouble() ?? 0) > 0)
        .toList();

    if (returnedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select at least one item to return"),
        ),
      );
      return {};
    }

    List<String> varianceitemCode = [];
    List<String> itemName = [];
    List<String> varianceName = [];
    List<int> price = [];
    List<double> sellingPrice = [];
    List<double> sellingAmount = [];
    List<double> weight = []; // ← This will get decimal for Kg items
    List<double> qtyList = []; // ← This will be 1 for Kg, actual count for Pcs
    List<double> amount = [];
    List<double> tax = [];
    List<String> uom = [];
    List<double> gstValue = [];
    List<double> gst = [];
    List<int> hsnCode = [];

    double totalPaid = 0.0;

    for (var item in returnedItems) {
      final double returnQtyInput =
          (item['returnQty'] as num?)?.toDouble() ?? 0.0;
      if (returnQtyInput <= 0) continue;

      final String unit = (item['uom']?.toString() ?? 'Pcs').toLowerCase();
      final bool isKg = unit.contains('kg') || unit.contains('kgs');

      final int mrp = (item['price'] as num).toInt();
      final double discountedPrice = (item['sellingPrice'] as num).toDouble();
      final double taxRate = (item['tax'] as num?)?.toDouble() ?? 0.0;

      final double paidLine = discountedPrice * returnQtyInput;
      final double lineGst = paidLine * taxRate / (100 + taxRate);

      varianceitemCode.add(item['varianceitemCode']?.toString() ?? '');
      itemName.add(item['itemName']?.toString() ?? '');
      varianceName.add(item['varianceName']?.toString() ?? '');
      price.add(mrp);
      sellingPrice.add(discountedPrice);
      sellingAmount.add(paidLine);
      tax.add(taxRate);
      uom.add(item['uom']?.toString() ?? 'Pcs');
      gstValue.add(lineGst);
      gst.add(taxRate);
      hsnCode.add(item['hsnCode'] ?? 0);

      if (isKg) {
        // For Kg items → weight = returned decimal, qty = 1 (or count if multiple)
        weight.add(returnQtyInput); // e.g., 0.5
        qtyList.add(1.0); // Always 1 for weight-based items
      } else {
        // For Pcs → qty = returned count, weight = 0 or original weight
        qtyList.add(returnQtyInput);
        weight.add((item['weight'] as num?)?.toDouble() ?? 0.0);
      }

      amount.add(mrp * (isKg ? returnQtyInput : returnQtyInput));
      totalPaid += paidLine;
    }

    final double totalOriginal = amount.fold(0.0, (a, b) => a + b);
    final double totalGst = gstValue.fold(0.0, (a, b) => a + b);
    final double netAmount = totalPaid - totalGst;
    final double discountAmount = totalOriginal - totalPaid;

    return {
      "varianceitemCode": varianceitemCode,
      "itemName": itemName,
      "varianceName": varianceName,
      "price": price,
      "sellingPrice": sellingPrice,
      "sellingAmount": sellingAmount,
      "weight": weight, // Now correct: 0.5 for Kg items
      "qty": qtyList, // Now correct: 1 for Kg items
      "amount": amount,
      "tax": tax,
      "uom": uom,
      "gstValue": gstValue,
      "totalAmount": totalPaid,
      "grossAmount": totalPaid,
      "netAmount": netAmount,
      "cash": totalPaid,
      "discountAmount": discountAmount,
      "discountPercentage": transaction.discountPercentage ?? 0,
      "salesType": transaction.salesType,
      "customerPhoneNumber": transaction.customerPhoneNumber,
      "salesPersonId": transaction.salesPersonId,
      "salesPersonName": transaction.salesPersonName,
      "branchId": branchId,
      "branchName": branchName,
      "aliasName": transaction.aliasName,
      "paymentType": "Cash",
      "invoiceNo": transaction.invoiceNo,
      "salesReturnNo":
          "${transaction.invoiceNo}-SR",
      "returnDateTime": DateTime.now().toIso8601String(),
      "shiftNumber": transaction.shiftNumber,
      "shiftId": shiftId.value,
      "deviceNumber": transaction.deviceNumber,
      "gst": gst,
      "hsnCode": hsnCode,
    };
  }

  bool _isPostingReturn =
      false; // Make sure this is declared outside the function

  Future<void> _postSalesReturn(TransactionProvider transactionProvider) async {
    if (_isPostingReturn) {
      debugPrint("Return already in progress. Ignoring duplicate tap.");
      return;
    }
    _isPostingReturn = true;

    debugPrint("Starting Sales Return Process...");
    debugPrint(
      "Returned Items Count: ${editableItems.value.where((i) => (i['qty'] as num) > 0).length}",
    );

    final returnData = _calculateReturnData();
    if (returnData.isEmpty) {
      debugPrint("No items selected or calculation failed. Aborting return.");
      _isPostingReturn = false;
      return;
    }

    debugPrint("Return Data Prepared:");
    debugPrint("   • Sales Return ID : ${returnData['salesReturnId']}");
    debugPrint("   • Invoice No      : ${returnData['invoiceNo']}");
    debugPrint("   • Return No       : ${returnData['salesReturnNo']}");
    debugPrint(
      "   • Items Count     : ${returnData['varianceitemCode'].length}",
    );
    debugPrint("   • Total Amount    : ₹${returnData['totalAmount']}");
    debugPrint(
      "   • Gross Amount    : ₹${returnData['grossAmount']} (Refund Amount)",
    );
    debugPrint("   • Net Amount      : ₹${returnData['netAmount']}");
    debugPrint("   • Cash Refund     : ₹${returnData['cash']}");
    debugPrint("   • Price List      : ${returnData['price']}");
    debugPrint(
      "   • Amount List     : ${returnData['amount']} (should be original MRP × qty)",
    );
    debugPrint("   • SellingPrice    : ${returnData['sellingPrice']}");
    debugPrint("   • SellingAmount   : ${returnData['sellingAmount']}");
    debugPrint("Full Return Payload: ${jsonEncode(returnData)}");

    try {
      final salesReturn = {'type': 'salesReturn', 'data': returnData};
      await sendataToServer(salesReturn);
      await transactionProvider.refreshAfterReturn();

      isReturnMode.value = false;
      debugPrint("Exited Return Mode.");
    } catch (e) {
      debugPrint("Unexpected Error during return: $e");
      debugPrint("Stack trace: ${StackTrace.current}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Return Failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _isPostingReturn = false;
      debugPrint("Return process finished. _isPostingReturn = false");
    }
  }

  double getTotalRefundAmount() {
    final hasManualEntry = editableItems.value.any(
      (i) => ((i['returnQty'] as num?)?.toDouble() ?? 0) > 0,
    );
    if (!hasManualEntry) {
      // Full return: refund entire gross amount
      return transaction.grossAmount ?? transaction.totalAmount ?? 0.0;
    }
    // Partial return: calculate from entered quantities
    return editableItems.value.fold(0.0, (sum, item) {
      final returnQty = (item['returnQty'] as num?)?.toDouble() ?? 0.0;
      final sellingPrice = (item['sellingPrice'] as num?)?.toDouble() ?? 0.0;
      return sum + (returnQty * sellingPrice);
    });
  }

  void _handleFullReturn() {
    final totalRefund = getTotalRefundAmount();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          "Full Return",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Total Refund Amount: ₹${totalRefund.toStringAsFixed(2)}\n\nDo you want to proceed with full return?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: TextStyle(color: Colors.black)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadiusGeometry.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              // Second confirmation
              showDialog(
                context: context,
                builder: (ctx2) => AlertDialog(
                  backgroundColor: Colors.white,
                  title: Text("Confirm Full Return"),
                  content: Text(
                    "Are you sure you want to return the entire order?",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx2),
                      child: Text("No", style: TextStyle(color: Colors.black)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade500,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadiusGeometry.circular(8),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx2);
                        // Auto-fill all items
                        for (var item in editableItems.value) {
                          final dynamic wList = item['weight'];
                          final dynamic uList = item['uom'];
                          final double? w = wList is List
                              ? (wList.isNotEmpty ? wList[0] : null)?.toDouble()
                              : wList?.toDouble();
                          final String u =
                              (uList is List
                                      ? (uList.isNotEmpty ? uList[0] : 'Pcs')
                                      : uList)
                                  ?.toString() ??
                              'Pcs';
                          final bool isKgItem =
                              w != null &&
                              w > 0 &&
                              u.toLowerCase().contains('kg');
                          final double displayQty = isKgItem
                              ? w!
                              : ((item['qty'] is List
                                            ? item['qty'].firstOrNull
                                            : item['qty'])
                                        ?.toDouble() ??
                                    0.0);
                          if (displayQty > 0) item['returnQty'] = displayQty;
                        }
                        editableItems.notifyListeners();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Full return selected!"),
                            backgroundColor: Colors.green,
                          ),
                        );
                        // Automatically post the return
                        _postSalesReturn(transactionProvider);
                      },
                      child: Text(
                        "Yes, Return All",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              );
            },
            child: Text("Yes, Proceed", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // PARTIAL RETURN — Two-Step with Item List
  void _handlePartialReturn() {
    final returnedItems = editableItems.value
        .where((i) => ((i['returnQty'] as num?)?.toDouble() ?? 0) > 0)
        .toList();
    if (returnedItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("No items selected for return")));
      return;
    }

    double totalRefund = 0.0;
    final List<Widget> itemWidgets = [];

    for (var item in returnedItems) {
      final name = item['varianceName']?.toString() ?? 'Unknown';
      final qty = (item['returnQty'] as num?)?.toDouble() ?? 0.0;
      final uom = item['uom']?.toString() ?? 'Pcs';
      final price = (item['sellingPrice'] as num?)?.toDouble() ?? 0.0;
      final amount = qty * price;
      totalRefund += amount;

      itemWidgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(name, style: TextStyle(fontSize: 13))),
              Text(
                "$qty $uom × ₹${price.toStringAsFixed(2)} = ₹${amount.toStringAsFixed(2)}",
              ),
            ],
          ),
        ),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text("Partial Return Summary"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Items to return:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ...itemWidgets,
            Divider(),
            Text(
              "Total Refund: ₹${totalRefund.toStringAsFixed(2)}",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: TextStyle(color: Colors.black)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade500,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadiusGeometry.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              showDialog(
                context: context,
                builder: (ctx2) => AlertDialog(
                  backgroundColor: Colors.white,
                  title: Text("Confirm Partial Return"),
                  content: Text(
                    "Are you sure you want to proceed with this return?",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx2),
                      child: Text("No", style: TextStyle(color: Colors.white)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade500,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadiusGeometry.circular(8),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx2);
                        _postSalesReturn(transactionProvider);
                      },
                      child: Text(
                        "Yes, Submit Return",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              );
            },
            child: Text("Yes, Continue", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  return Consumer<TransactionProvider>(
    builder: (context, value, child) {
      return Column(
        children: [
          GlassCard(
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      infoChip(
                        Icons.calendar_today_rounded,
                        'Date & Time',
                        formatInvoiceDateTime(transaction.invoiceDateTime),
                      ),
                      infoChip(
                        Icons.payment_rounded,
                        'Payment',
                        transaction.paymentType ?? 'N/A',
                      ),
                      infoChip(
                        Icons.person_rounded,
                        'Sales Person',
                        transaction.salesPersonName,
                      ),
                      infoChip(
                        Icons.phone_rounded,
                        'Customer',
                        transaction.customerPhoneNumber,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // ✅ FIX ADDED HERE
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Expanded(
                        child: GlassCard(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.95),
                              Colors.white70,
                            ],
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                          ),
                          blur: 20,
                          child: Scrollbar(
                            controller: _scrollController,
                            thumbVisibility: true,
                            radius: const Radius.circular(8),
                            thickness: 5,
                            trackVisibility: false,
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.payment_rounded),
                                        SizedBox(width: 10),
                                        Text(
                                          "Payment Details",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Divider(
                                      thickness: 1,
                                      color: Colors.grey.shade200,
                                    ),
                                    if ((transaction.discountAmount ?? 0) > 0)
                                      buildChargeRow(
                                        "Discount(${transaction.discountPercentage.toStringAsFixed(2)}%)",
                                        "- ₹${transaction.discountAmount!.toStringAsFixed(2)}",
                                      ),
                                    if (transaction.customCharge > 0)
                                      buildChargeRow(
                                        "Custom Charge",
                                        "₹${transaction.customCharge.toStringAsFixed(2)}",
                                      ),
                                    buildChargeRow(
                                      "Items Total",
                                      "₹${transaction.totalAmount.toStringAsFixed(2)}",
                                    ),
                                    if (transaction.customCharge > 0 ||
                                        (transaction.discountAmount ?? 0) > 0)
                                      Divider(
                                        thickness: 1,
                                        color: Colors.grey.shade200,
                                      ),
                                    buildChargeRow(
                                      "Gross Amount",
                                      "₹${transaction.grossAmount.toStringAsFixed(2) ?? '0.00'}",
                                    ),
                                    Divider(
                                      thickness: 1,
                                      color: Colors.grey.shade200,
                                    ),
                                    Text(
                                      "Payment Details",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    buildChargeRow(
                                      "Cash",
                                      "₹${(transaction.cash ?? 0).toStringAsFixed(2)}",
                                    ),
                                    buildChargeRow(
                                      "Card",
                                      "₹${transaction.card ?? 0}",
                                    ),
                                    buildChargeRow(
                                      "UPI",
                                      "₹${transaction.upi ?? 0}",
                                    ),
                                    if (transaction.others != null)
                                      buildChargeRow(
                                        "Others",
                                        "₹${transaction.others.toString()}",
                                      ),
                                    Divider(
                                      thickness: 1,
                                      color: Colors.grey.shade200,
                                    ),
                                    Text(
                                      "GST BreakUps",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    buildChargeRow(
                                      "GST",
                                      "₹${(transaction.gstValue?.fold<double>(0, (a, b) => a + b) ?? 0).toStringAsFixed(2)}",
                                    ),
                                    buildChargeRow(
                                      "Net Amount",
                                      "₹${transaction.netAmount.toStringAsFixed(2)}",
                                    ),
                                    Divider(
                                      thickness: 1,
                                      color: Colors.grey.shade200,
                                    ),
                                    buildChargeRow(
                                      "Total Amount",
                                      "₹${transaction.totalAmount.toStringAsFixed(2)}",
                                      isBold: true,
                                      valueColor: Colors.amber.shade700,
                                    ),
                                    const SizedBox(height: 20),
                                    // ADD THIS BLOCK AFTER THE TOTAL AMOUNT ROW
                                    FutureBuilder<List<Map<String, dynamic>>>(
                                      future: _getReturnedItemsForInvoice(
                                        transaction.invoiceNo.toString(),
                                      ),
                                      builder: (context, snapshot) {
                                        if (!snapshot.hasData ||
                                            snapshot.data!.isEmpty) {
                                          return const SizedBox.shrink(); // No return → show nothing
                                        }

                                        // Calculate total returned amount from past returns
                                        double totalReturned = 0.0;
                                        for (var returnedItem
                                            in snapshot.data!) {
                                          final qty =
                                              returnedItem['returnedQty']
                                                  as num? ??
                                              0.0;
                                          final itemFromList = editableItems
                                              .value
                                              .firstWhere(
                                                (i) =>
                                                    i['varianceName']
                                                        ?.toString() ==
                                                    returnedItem['varianceName']
                                                        ?.toString(),
                                                orElse: () => <String, dynamic>{
                                                  'sellingPrice': 0.0,
                                                },
                                              );
                                          final price =
                                              (itemFromList['sellingPrice']
                                                      as num?)
                                                  ?.toDouble() ??
                                              0.0;
                                          totalReturned += qty * price;
                                        }

                                        if (totalReturned <= 0)
                                          return const SizedBox.shrink();

                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 6,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                "Sales Return",
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.red.shade700,
                                                ),
                                              ),
                                              Text(
                                                "- ₹${totalReturned.toStringAsFixed(2)}",
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.red.shade700,
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
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),

                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: GlassCard(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.95),
                          Colors.white70,
                        ],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      blur: 20,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.shopping_cart_rounded),
                                    SizedBox(width: 10),
                                    Text(
                                      "Items Purchased",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                ValueListenableBuilder<bool>(
                                  valueListenable: isReturnMode,
                                  builder: (context, inMode, _) {
                                    final bool isTakeAway = transaction
                                        .salesType
                                        .toLowerCase()
                                        .contains('takeaway');

                                    return FutureBuilder<
                                      List<Map<String, dynamic>>
                                    >(
                                      future: _getReturnedItemsForInvoice(
                                        transaction.invoiceNo.toString(),
                                      ),
                                      builder: (context, snapshot) {
                                        bool hasAnyReturn = false;

                                        if (snapshot.hasData &&
                                            snapshot.data!.isNotEmpty) {
                                          final Map<String, dynamic>
                                          returnedMap = {};
                                          for (var item in snapshot.data!) {
                                            final name =
                                                item['varianceName']
                                                    ?.toString() ??
                                                '';
                                            if (name.isNotEmpty)
                                              returnedMap[name] = item;
                                          }

                                          for (var item
                                              in editableItems.value) {
                                            final name =
                                                item['varianceName']
                                                    ?.toString() ??
                                                '';
                                            if (((returnedMap[name]?['returnedQty']
                                                            as num?)
                                                        ?.toDouble() ??
                                                    0.0) >
                                                0) {
                                              hasAnyReturn = true;
                                              break;
                                            }
                                          }
                                        }

                                        final bool canEnterReturnMode =
                                            isTakeAway &&
                                            !hasAnyReturn &&
                                            !inMode;
                                        final bool canExitReturnMode =
                                            inMode; // Always allow canceling when in return mode

                                        final bool buttonEnabled =
                                            canEnterReturnMode ||
                                            canExitReturnMode;

                                        return Opacity(
                                          opacity: buttonEnabled ? 1.0 : 0.5,
                                          child: ElevatedButton.icon(
                                            onPressed: buttonEnabled
                                                ? () {
                                                    final invoiceHive =
                                                        Hive.box('invoices');
                                                    debugPrint(
                                                      'Invoice Datas : ${invoiceHive.length}',
                                                    );
                                                    if (inMode) {
                                                      // Cancel return mode
                                                      isReturnMode.value =
                                                          false;
                                                      // Optional: Clear all returnQty entries
                                                      for (var item
                                                          in editableItems
                                                              .value) {
                                                        item.remove(
                                                          'returnQty',
                                                        );
                                                      }
                                                      editableItems
                                                          .notifyListeners();
                                                    } else {
                                                      // Enter return mode
                                                      isReturnMode.value = true;
                                                    }
                                                  }
                                                : null,
                                            icon: Icon(
                                              inMode
                                                  ? Icons.cancel
                                                  : Icons.keyboard_return,
                                              color: Colors.white,
                                            ),
                                            label: Text(
                                              inMode
                                                  ? "Cancel Return"
                                                  : "Sales Return",
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              backgroundColor: inMode
                                                  ? Colors.red.shade500
                                                  : (canEnterReturnMode
                                                        ? Colors.blue.shade500
                                                        : Colors.grey.shade400),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Divider(),
                            Expanded(
                              child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                                valueListenable: editableItems,
                                builder: (context, items, _) {
                                  return ValueListenableBuilder<bool>(
                                    valueListenable: isReturnMode,
                                    builder: (context, inMode, _) {
                                      final bool hasManualEntry = items.any(
                                        (i) =>
                                            ((i['returnQty'] as num?)
                                                    ?.toDouble() ??
                                                0.0) >
                                            0.0001,
                                      );

                                      return Column(
                                        children: [
                                          Expanded(
                                            child: FutureBuilder<List<Map<String, dynamic>>>(
                                              future:
                                                  _getReturnedItemsForInvoice(
                                                    transaction.invoiceNo
                                                        .toString(),
                                                  ),
                                              builder: (context, snapshot) {
                                                final Map<
                                                  String,
                                                  Map<String, dynamic>
                                                >
                                                returnedItemsMap = {};
                                                if (snapshot.hasData) {
                                                  for (var item
                                                      in snapshot.data!) {
                                                    final name =
                                                        item['varianceName']
                                                            ?.toString() ??
                                                        '';
                                                    if (name.isNotEmpty)
                                                      returnedItemsMap[name] =
                                                          item;
                                                  }
                                                }

                                                return ValueListenableBuilder<
                                                  List<Map<String, dynamic>>
                                                >(
                                                  valueListenable:
                                                      editableItems,
                                                  builder: (context, items, _) {
                                                    return ValueListenableBuilder<
                                                      bool
                                                    >(
                                                      valueListenable:
                                                          isReturnMode,
                                                      builder: (context, inMode, _) {
                                                        return ListView.separated(
                                                          itemCount:
                                                              items.length,
                                                          separatorBuilder:
                                                              (_, __) =>
                                                                  const Divider(
                                                                    height: 1,
                                                                  ),
                                                          itemBuilder: (context, index) {
                                                            final item =
                                                                items[index];
                                                            final varianceName =
                                                                item['varianceName']
                                                                    ?.toString() ??
                                                                'Unknown Item';

                                                            // KG Logic
                                                            final dynamic
                                                            qtyList =
                                                                item['qty'];
                                                            final dynamic
                                                            weightList =
                                                                item['weight'];
                                                            final dynamic
                                                            uomList =
                                                                item['uom'];

                                                            final double qty =
                                                                (qtyList is List
                                                                        ? qtyList
                                                                              .firstOrNull
                                                                        : qtyList)
                                                                    ?.toDouble() ??
                                                                0.0;
                                                            final double?
                                                            weight =
                                                                weightList
                                                                    is List
                                                                ? (weightList.isNotEmpty
                                                                          ? weightList[0]
                                                                          : null)
                                                                      ?.toDouble()
                                                                : weightList
                                                                      ?.toDouble();
                                                            final String
                                                            uomRaw =
                                                                (uomList is List
                                                                        ? (uomList.isNotEmpty
                                                                              ? uomList[0]
                                                                              : 'Pcs')
                                                                        : uomList)
                                                                    ?.toString() ??
                                                                'Pcs';

                                                            final bool
                                                            isWeightBased =
                                                                weight !=
                                                                    null &&
                                                                weight > 0 &&
                                                                uomRaw
                                                                    .toLowerCase()
                                                                    .contains(
                                                                      'kg',
                                                                    );
                                                            final double
                                                            displayQty =
                                                                isWeightBased
                                                                ? weight!
                                                                : qty;
                                                            final String
                                                            displayUom =
                                                                isWeightBased
                                                                ? 'kg'
                                                                : uomRaw;
                                                            final bool isKg =
                                                                isWeightBased;

                                                            final double
                                                            sellingPrice =
                                                                (item['sellingPrice']
                                                                        as num?)
                                                                    ?.toDouble() ??
                                                                0.0;
                                                            final double
                                                            lineTotal =
                                                                (item['sellingAmount']
                                                                        as num?)
                                                                    ?.toDouble() ??
                                                                0.0;

                                                            final double?
                                                            currentReturnInput =
                                                                inMode
                                                                ? (item['returnQty']
                                                                          as num?)
                                                                      ?.toDouble()
                                                                : null;
                                                            final double
                                                            previouslyReturned =
                                                                returnedItemsMap[varianceName]?['returnedQty']
                                                                    ?.toDouble() ??
                                                                0.0;

                                                            return Padding(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    vertical:
                                                                        12,
                                                                  ),
                                                              child: Row(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Expanded(
                                                                    flex: 5,
                                                                    child: Column(
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .start,
                                                                      children: [
                                                                        Text(
                                                                          varianceName,
                                                                          style: TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.w600,
                                                                            fontSize:
                                                                                15,
                                                                          ),
                                                                        ),
                                                                        const SizedBox(
                                                                          height:
                                                                              6,
                                                                        ),
                                                                        Text(
                                                                          "${displayQty.toStringAsFixed(isKg ? 3 : 0)} $displayUom × ₹${sellingPrice.toStringAsFixed(2)}",
                                                                          style: TextStyle(
                                                                            color:
                                                                                Colors.grey.shade700,
                                                                            fontSize:
                                                                                13,
                                                                          ),
                                                                        ),
                                                                        if (inMode &&
                                                                            currentReturnInput !=
                                                                                null &&
                                                                            currentReturnInput >
                                                                                0)
                                                                          Padding(
                                                                            padding: const EdgeInsets.only(
                                                                              top: 4,
                                                                            ),
                                                                            child: Text(
                                                                              "Returning: ${currentReturnInput.toStringAsFixed(isKg ? 3 : 0)} $displayUom",
                                                                              style: TextStyle(
                                                                                color: Colors.red.shade500,
                                                                                fontWeight: FontWeight.bold,
                                                                                fontSize: 13,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        if (previouslyReturned >
                                                                            0)
                                                                          Padding(
                                                                            padding: const EdgeInsets.only(
                                                                              top: 4,
                                                                            ),
                                                                            child: Container(
                                                                              padding: const EdgeInsets.symmetric(
                                                                                horizontal: 8,
                                                                                vertical: 4,
                                                                              ),
                                                                              decoration: BoxDecoration(
                                                                                color: Colors.red.shade100,
                                                                                borderRadius: BorderRadius.circular(
                                                                                  6,
                                                                                ),
                                                                              ),
                                                                              child: Text(
                                                                                "RETURNED ${previouslyReturned.toStringAsFixed(isKg ? 3 : 0)} $displayUom",
                                                                                style: TextStyle(
                                                                                  color: Colors.red.shade600,
                                                                                  fontWeight: FontWeight.bold,
                                                                                  fontSize: 12,
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ),
                                                                      ],
                                                                    ),
                                                                  ),

                                                                  // RETURN QTY INPUT - FIXED FOR PCS vs KG
                                                                  if (inMode &&
                                                                      displayQty >
                                                                          0)
                                                                    SizedBox(
                                                                      width:
                                                                          100,
                                                                      child: TextField(
                                                                        readOnly:
                                                                            true,
                                                                        controller: TextEditingController()
                                                                          ..text =
                                                                              currentReturnInput !=
                                                                                  null
                                                                              ? currentReturnInput.toStringAsFixed(
                                                                                  isKg
                                                                                      ? 3
                                                                                      : 0,
                                                                                )
                                                                              : '',
                                                                        decoration: InputDecoration(
                                                                          labelText:
                                                                              "Qty",
                                                                          isDense:
                                                                              true,
                                                                          contentPadding: const EdgeInsets.all(
                                                                            10,
                                                                          ),
                                                                          border: OutlineInputBorder(
                                                                            borderRadius: BorderRadius.circular(
                                                                              6,
                                                                            ),
                                                                          ),
                                                                          suffixIcon:
                                                                              currentReturnInput !=
                                                                                  null
                                                                              ? IconButton(
                                                                                  icon: Icon(
                                                                                    Icons.clear,
                                                                                    size: 16,
                                                                                    color: Colors.red.shade600,
                                                                                  ),
                                                                                  onPressed: () {
                                                                                    item.remove(
                                                                                      'returnQty',
                                                                                    );
                                                                                    editableItems.notifyListeners();
                                                                                  },
                                                                                )
                                                                              : null,
                                                                        ),
                                                                        onTap: () {
                                                                          showDialog(
                                                                            context:
                                                                                context,
                                                                            builder: (_) => NumericCalculator(
                                                                              varianceName: varianceName,
                                                                              onValueSelected:
                                                                                  (
                                                                                    double value,
                                                                                  ) {
                                                                                    if (value <=
                                                                                        0)
                                                                                      return;

                                                                                    if (value >
                                                                                        displayQty +
                                                                                            0.0001) {
                                                                                      ScaffoldMessenger.of(
                                                                                        context,
                                                                                      ).showSnackBar(
                                                                                        SnackBar(
                                                                                          content: Text(
                                                                                            "Cannot return more than available: $displayQty $displayUom",
                                                                                          ),
                                                                                          backgroundColor: Colors.red,
                                                                                        ),
                                                                                      );
                                                                                      return;
                                                                                    }

                                                                                    // CRITICAL FIX: For PCS → force integer
                                                                                    if (!isKg) {
                                                                                      value = value.roundToDouble();
                                                                                    }

                                                                                    item['returnQty'] = value;
                                                                                    editableItems.notifyListeners();

                                                                                    ScaffoldMessenger.of(
                                                                                      context,
                                                                                    ).showSnackBar(
                                                                                      SnackBar(
                                                                                        content: Text(
                                                                                          "Return Qty: ${value.toStringAsFixed(isKg ? 3 : 0)} $displayUom",
                                                                                        ),
                                                                                        backgroundColor: Colors.green,
                                                                                        duration: Duration(
                                                                                          milliseconds: 800,
                                                                                        ),
                                                                                      ),
                                                                                    );
                                                                                  },
                                                                            ),
                                                                          );
                                                                        },
                                                                      ),
                                                                    ),

                                                                  Expanded(
                                                                    flex: 2,
                                                                    child: Column(
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .end,
                                                                      children: [
                                                                        Text(
                                                                          '₹${lineTotal.toStringAsFixed(2)}',
                                                                          style: TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                            fontSize:
                                                                                16,
                                                                          ),
                                                                        ),
                                                                        if (currentReturnInput !=
                                                                                null &&
                                                                            currentReturnInput >
                                                                                0)
                                                                          Padding(
                                                                            padding: const EdgeInsets.only(
                                                                              top: 4,
                                                                            ),
                                                                            child: Text(
                                                                              "-₹${(currentReturnInput * sellingPrice).toStringAsFixed(2)}",
                                                                              style: TextStyle(
                                                                                color: Colors.red.shade700,
                                                                                fontWeight: FontWeight.bold,
                                                                                fontSize: 13,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        if (previouslyReturned >
                                                                            0)
                                                                          Text(
                                                                            "-₹${(previouslyReturned * sellingPrice).toStringAsFixed(2)}",
                                                                            style: TextStyle(
                                                                              color: Colors.red.shade500,
                                                                              fontSize: 12,
                                                                            ),
                                                                          ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            );
                                                          },
                                                        );
                                                      },
                                                    );
                                                  },
                                                );
                                              },
                                            ),
                                          ),

                                          // Bottom buttons — unchanged
                                          if (inMode) ...[
                                            const SizedBox(height: 20),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceEvenly,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Container(
                                                  height: 60,
                                                  child: ElevatedButton.icon(
                                                    onPressed: hasManualEntry
                                                        ? null
                                                        : _handleFullReturn,
                                                    label: Text(
                                                      "Full Return",
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          Colors.blue.shade500,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Container(
                                                  height: 60,
                                                  child: ElevatedButton.icon(
                                                    onPressed: hasManualEntry
                                                        ? _handlePartialReturn
                                                        : null,
                                                    label: Text(
                                                      "Submit",
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    style: ElevatedButton.styleFrom(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                            vertical: 12,
                                                            horizontal: 16,
                                                          ),
                                                      backgroundColor:
                                                          hasManualEntry
                                                          ? Colors.blue.shade500
                                                          : Colors.grey,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                                                    valueListenable:
                                                        editableItems,
                                                    builder: (context, _, __) {
                                                      final refundAmount =
                                                          getTotalRefundAmount();
                                                      return Container(
                                                        padding: EdgeInsets.all(
                                                          15,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: Colors
                                                              .blue
                                                              .shade50,
                                                          border: Border.all(
                                                            color: Colors
                                                                .blue
                                                                .shade300,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                        child: Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Text(
                                                              "Refund",
                                                              style: TextStyle(
                                                                fontSize: 15,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                            SizedBox(width: 7),
                                                            Text(
                                                              "₹${refundAmount.toStringAsFixed(2)}",
                                                              style: TextStyle(
                                                                fontSize: 18,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Colors
                                                                    .blue
                                                                    .shade700,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

// ===== Helper Widgets =====
Widget infoChip(IconData icon, String title, String value) {
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

Widget buildChargeRow(
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

// NEW: Hive Manager for Sales Returns
// Create a new file: lib/Hive_Manager/hive_manager_sales_return.dart



// class HiveManagerSalesReturn {
//   static late Box salesReturnBox;

//   static Future<void> init() async {
//     // final appDocumentDir = await path_provider.getApplicationDocumentsDirectory();
//     // Hive.init(appDocumentDir.path);
//     salesReturnBox = await Hive.openBox('sales_returns');
//   }
// }


            // Expanded(
            //   flex: 2,
            //   child: Padding(
            //     padding: const EdgeInsets.only(top: 20),
            //     child: GlassCard(
            //       gradient: LinearGradient(
            //         colors: [Colors.white.withOpacity(0.95), Colors.white70],
            //         begin: Alignment.topRight,
            //         end: Alignment.bottomLeft,
            //       ),
            //       blur: 20,
            //       child: Padding(
            //         padding: const EdgeInsets.all(20),
            //         child: Column(
            //           crossAxisAlignment: CrossAxisAlignment.start,
            //           children: [
            //             // Header
            //             Row(
            //               mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //               children: [
            //                 Row(
            //                   children: [
            //                     Icon(Icons.shopping_cart_rounded),
            //                     SizedBox(width: 10),
            //                     Text(
            //                       "Items Purchased",
            //                       style: TextStyle(
            //                         fontSize: 18,
            //                         fontWeight: FontWeight.w700,
            //                       ),
            //                     ),
            //                   ],
            //                 ),
            //                 // ValueListenableBuilder<bool>(
            //                 //   valueListenable: isReturnMode,
            //                 //   builder: (context, inMode, _) {
            //                 //     return ElevatedButton.icon(
            //                 //       onPressed: () {
            //                 //         if (inMode) {
            //                 //           isReturnMode.value = false;
            //                 //           for (var item in editableItems.value)
            //                 //             item.remove('returnQty');
            //                 //           editableItems.notifyListeners();
            //                 //         } else {
            //                 //           isReturnMode.value = true;
            //                 //         }
            //                 //       },
            //                 //       icon: Icon(
            //                 //         inMode
            //                 //             ? Icons.cancel
            //                 //             : Icons.keyboard_return,
            //                 //         color: Colors.white,
            //                 //       ),
            //                 //       label: Text(
            //                 //         inMode ? "Cancel Return" : "Sales Return",
            //                 //         style: TextStyle(
            //                 //           color: Colors.white,
            //                 //           fontWeight: FontWeight.bold,
            //                 //         ),
            //                 //       ),
            //                 //       style: ElevatedButton.styleFrom(
            //                 //         shape: RoundedRectangleBorder(
            //                 //           borderRadius: BorderRadius.circular(8),
            //                 //         ),
            //                 //         backgroundColor: inMode
            //                 //             ? Colors.red.shade500
            //                 //             : Colors.blue.shade500,
            //                 //       ),
            //                 //     );
            //                 //   },
            //                 // ),
            //                 ValueListenableBuilder<bool>(
            //                   valueListenable: isReturnMode,
            //                   builder: (context, inMode, _) {
            //                     // Check if it's TakeAway
            //                     final bool isTakeAway = transaction.salesType
            //                         .toLowerCase()
            //                         .contains('takeaway');

            //                     return FutureBuilder<
            //                       List<Map<String, dynamic>>
            //                     >(
            //                       future: _getReturnedItemsForInvoice(
            //                         transaction.invoiceNo.toString(),
            //                       ),
            //                       builder: (context, snapshot) {
            //                         bool hasAnyReturn = false;

            //                         if (snapshot.hasData &&
            //                             snapshot.data!.isNotEmpty) {
            //                           final Map<String, dynamic> returnedMap =
            //                               {};
            //                           for (var item in snapshot.data!) {
            //                             final name =
            //                                 item['varianceName']?.toString() ??
            //                                 '';
            //                             if (name.isNotEmpty)
            //                               returnedMap[name] = item;
            //                           }

            //                           // Check if any item in current invoice has been returned
            //                           for (var item in editableItems.value) {
            //                             final name =
            //                                 item['varianceName']?.toString() ??
            //                                 '';
            //                             if (((returnedMap[name]?['returnedQty']
            //                                             as num?)
            //                                         ?.toDouble() ??
            //                                     0.0) >
            //                                 0) {
            //                               hasAnyReturn = true;
            //                               break;
            //                             }
            //                           }
            //                         }

            //                         final bool canReturn =
            //                             isTakeAway && !hasAnyReturn && !inMode;

            //                         return Opacity(
            //                           opacity: canReturn ? 1.0 : 0.5,
            //                           child: ElevatedButton.icon(
            //                             onPressed: canReturn
            //                                 ? () {
            //                                     isReturnMode.value = true;
            //                                   }
            //                                 : null,
            //                             icon: Icon(
            //                               inMode
            //                                   ? Icons.cancel
            //                                   : Icons.keyboard_return,
            //                               color: Colors.white,
            //                             ),
            //                             label: Text(
            //                               inMode
            //                                   ? "Cancel Return"
            //                                   : "Sales Return",
            //                               style: TextStyle(
            //                                 color: Colors.white,
            //                                 fontWeight: FontWeight.bold,
            //                               ),
            //                             ),
            //                             style: ElevatedButton.styleFrom(
            //                               shape: RoundedRectangleBorder(
            //                                 borderRadius: BorderRadius.circular(
            //                                   8,
            //                                 ),
            //                               ),
            //                               backgroundColor: inMode
            //                                   ? Colors.red.shade500
            //                                   : (canReturn
            //                                         ? Colors.blue.shade500
            //                                         : Colors.grey.shade400),
            //                             ),
            //                           ),
            //                         );
            //                       },
            //                     );
            //                   },
            //                 ),
            //               ],
            //             ),
            //             const SizedBox(height: 12),
            //             Divider(),
            //             Expanded(
            //               child: ValueListenableBuilder<List<Map<String, dynamic>>>(
            //                 valueListenable: editableItems,
            //                 builder: (context, items, _) {
            //                   return ValueListenableBuilder<bool>(
            //                     valueListenable: isReturnMode,
            //                     builder: (context, inMode, _) {
            //                       final bool hasManualEntry = items.any(
            //                         (i) =>
            //                             ((i['returnQty'] as num?)?.toDouble() ??
            //                                 0.0) >
            //                             0.0001,
            //                       );

            //                       return Column(
            //                         children: [
            //                           Expanded(
            //                             child: FutureBuilder<List<Map<String, dynamic>>>(
            //                               future: _getReturnedItemsForInvoice(
            //                                 transaction.invoiceNo.toString(),
            //                               ),
            //                               builder: (context, snapshot) {
            //                                 final Map<
            //                                   String,
            //                                   Map<String, dynamic>
            //                                 >
            //                                 returnedItemsMap = {};
            //                                 if (snapshot.hasData) {
            //                                   for (var item in snapshot.data!) {
            //                                     final name =
            //                                         item['varianceName']
            //                                             ?.toString() ??
            //                                         '';
            //                                     if (name.isNotEmpty)
            //                                       returnedItemsMap[name] = item;
            //                                   }
            //                                 }

            //                                 return ValueListenableBuilder<
            //                                   List<Map<String, dynamic>>
            //                                 >(
            //                                   valueListenable: editableItems,
            //                                   builder: (context, items, _) {
            //                                     return ValueListenableBuilder<
            //                                       bool
            //                                     >(
            //                                       valueListenable: isReturnMode,
            //                                       builder: (context, inMode, _) {
            //                                         return ListView.separated(
            //                                           itemCount: items.length,
            //                                           separatorBuilder:
            //                                               (_, __) =>
            //                                                   const Divider(
            //                                                     height: 1,
            //                                                   ),
            //                                           itemBuilder: (context, index) {
            //                                             final item =
            //                                                 items[index];
            //                                             final varianceName =
            //                                                 item['varianceName']
            //                                                     ?.toString() ??
            //                                                 'Unknown Item';

            //                                             // KG Logic
            //                                             final dynamic qtyList =
            //                                                 item['qty'];
            //                                             final dynamic
            //                                             weightList =
            //                                                 item['weight'];
            //                                             final dynamic uomList =
            //                                                 item['uom'];

            //                                             final double qty =
            //                                                 (qtyList is List
            //                                                         ? qtyList
            //                                                               .firstOrNull
            //                                                         : qtyList)
            //                                                     ?.toDouble() ??
            //                                                 0.0;
            //                                             final double? weight =
            //                                                 weightList is List
            //                                                 ? (weightList.isNotEmpty
            //                                                           ? weightList[0]
            //                                                           : null)
            //                                                       ?.toDouble()
            //                                                 : weightList
            //                                                       ?.toDouble();
            //                                             final String uomRaw =
            //                                                 (uomList is List
            //                                                         ? (uomList.isNotEmpty
            //                                                               ? uomList[0]
            //                                                               : 'Pcs')
            //                                                         : uomList)
            //                                                     ?.toString() ??
            //                                                 'Pcs';

            //                                             final bool
            //                                             isWeightBased =
            //                                                 weight != null &&
            //                                                 weight > 0 &&
            //                                                 uomRaw
            //                                                     .toLowerCase()
            //                                                     .contains('kg');
            //                                             final double
            //                                             displayQty =
            //                                                 isWeightBased
            //                                                 ? weight
            //                                                 : qty;
            //                                             final String
            //                                             displayUom =
            //                                                 isWeightBased
            //                                                 ? 'kg'
            //                                                 : uomRaw;
            //                                             final bool isKg =
            //                                                 isWeightBased;

            //                                             final double
            //                                             sellingPrice =
            //                                                 (item['sellingPrice']
            //                                                         as num?)
            //                                                     ?.toDouble() ??
            //                                                 0.0;
            //                                             final double lineTotal =
            //                                                 (item['sellingAmount']
            //                                                         as num?)
            //                                                     ?.toDouble() ??
            //                                                 0.0;

            //                                             final double?
            //                                             currentReturnInput =
            //                                                 inMode
            //                                                 ? (item['returnQty']
            //                                                           as num?)
            //                                                       ?.toDouble()
            //                                                 : null;
            //                                             final double
            //                                             previouslyReturned =
            //                                                 returnedItemsMap[varianceName]?['returnedQty']
            //                                                     ?.toDouble() ??
            //                                                 0.0;

            //                                             return Padding(
            //                                               padding:
            //                                                   const EdgeInsets.symmetric(
            //                                                     vertical: 12,
            //                                                   ),
            //                                               child: Row(
            //                                                 crossAxisAlignment:
            //                                                     CrossAxisAlignment
            //                                                         .start,
            //                                                 children: [
            //                                                   Expanded(
            //                                                     flex: 5,
            //                                                     child: Column(
            //                                                       crossAxisAlignment:
            //                                                           CrossAxisAlignment
            //                                                               .start,
            //                                                       children: [
            //                                                         Text(
            //                                                           varianceName,
            //                                                           style: TextStyle(
            //                                                             fontWeight:
            //                                                                 FontWeight.w600,
            //                                                             fontSize:
            //                                                                 15,
            //                                                           ),
            //                                                         ),
            //                                                         const SizedBox(
            //                                                           height: 6,
            //                                                         ),
            //                                                         Text(
            //                                                           "${displayQty.toStringAsFixed(isKg ? 3 : 0)} $displayUom × ₹${sellingPrice.toStringAsFixed(2)}",
            //                                                           style: TextStyle(
            //                                                             color: Colors
            //                                                                 .grey
            //                                                                 .shade700,
            //                                                             fontSize:
            //                                                                 13,
            //                                                           ),
            //                                                         ),
            //                                                         if (inMode &&
            //                                                             currentReturnInput !=
            //                                                                 null &&
            //                                                             currentReturnInput >
            //                                                                 0)
            //                                                           Padding(
            //                                                             padding: const EdgeInsets.only(
            //                                                               top:
            //                                                                   4,
            //                                                             ),
            //                                                             child: Text(
            //                                                               "Returning: ${currentReturnInput.toStringAsFixed(isKg ? 3 : 0)} $displayUom",
            //                                                               style: TextStyle(
            //                                                                 color:
            //                                                                     Colors.red.shade500,
            //                                                                 fontWeight:
            //                                                                     FontWeight.bold,
            //                                                                 fontSize:
            //                                                                     13,
            //                                                               ),
            //                                                             ),
            //                                                           ),
            //                                                         if (previouslyReturned >
            //                                                             0)
            //                                                           Padding(
            //                                                             padding: const EdgeInsets.only(
            //                                                               top:
            //                                                                   4,
            //                                                             ),
            //                                                             child: Container(
            //                                                               padding: const EdgeInsets.symmetric(
            //                                                                 horizontal:
            //                                                                     8,
            //                                                                 vertical:
            //                                                                     4,
            //                                                               ),
            //                                                               decoration: BoxDecoration(
            //                                                                 color:
            //                                                                     Colors.red.shade100,
            //                                                                 borderRadius: BorderRadius.circular(
            //                                                                   6,
            //                                                                 ),
            //                                                               ),
            //                                                               child: Text(
            //                                                                 "RETURNED ${previouslyReturned.toStringAsFixed(isKg ? 3 : 0)} $displayUom",
            //                                                                 style: TextStyle(
            //                                                                   color: Colors.red.shade600,
            //                                                                   fontWeight: FontWeight.bold,
            //                                                                   fontSize: 12,
            //                                                                 ),
            //                                                               ),
            //                                                             ),
            //                                                           ),
            //                                                       ],
            //                                                     ),
            //                                                   ),

            //                                                   // if (inMode &&
            //                                                   //     displayQty >
            //                                                   //         0)
            //                                                   //   SizedBox(
            //                                                   //     width: 90,
            //                                                   //     child: TextField(
            //                                                   //       keyboardType:
            //                                                   //           TextInputType.numberWithOptions(
            //                                                   //             decimal:
            //                                                   //                 true,
            //                                                   //           ),
            //                                                   //       inputFormatters: [
            //                                                   //         FilteringTextInputFormatter.allow(
            //                                                   //           RegExp(
            //                                                   //             r'[0-9.]',
            //                                                   //           ),
            //                                                   //         ),
            //                                                   //       ],
            //                                                   //       decoration: InputDecoration(
            //                                                   //         labelText:
            //                                                   //             "Qty",
            //                                                   //         isDense:
            //                                                   //             true,
            //                                                   //         contentPadding:
            //                                                   //             const EdgeInsets.all(
            //                                                   //               10,
            //                                                   //             ),
            //                                                   //         border: OutlineInputBorder(
            //                                                   //           borderRadius:
            //                                                   //               BorderRadius.circular(
            //                                                   //                 6,
            //                                                   //               ),
            //                                                   //         ),
            //                                                   //       ),

            //                                                   //       onChanged: (value) {
            //                                                   //         final val =
            //                                                   //             double.tryParse(
            //                                                   //               value,
            //                                                   //             ) ??
            //                                                   //             0.0;
            //                                                   //         if (val >
            //                                                   //                 0 &&
            //                                                   //             val <=
            //                                                   //                 (displayQty +
            //                                                   //                     0.0001)) {
            //                                                   //           // This prevents exceeding original
            //                                                   //           item['returnQty'] =
            //                                                   //               val;
            //                                                   //         } else {
            //                                                   //           item.remove(
            //                                                   //             'returnQty',
            //                                                   //           );
            //                                                   //           if (val >
            //                                                   //               displayQty) {
            //                                                   //             ScaffoldMessenger.of(
            //                                                   //               context,
            //                                                   //             ).showSnackBar(
            //                                                   //               SnackBar(
            //                                                   //                 content: Text(
            //                                                   //                   "Cannot return more than available: $displayQty $displayUom",
            //                                                   //                 ),
            //                                                   //               ),
            //                                                   //             );
            //                                                   //           }
            //                                                   //         }
            //                                                   //         editableItems
            //                                                   //             .notifyListeners();
            //                                                   //       },
            //                                                   //     ),
            //                                                   //   ),
            //                                                   if (inMode &&
            //                                                       displayQty >
            //                                                           0)
            //                                                     SizedBox(
            //                                                       width: 100,
            //                                                       child: TextField(
            //                                                         readOnly:
            //                                                             true,
            //                                                         controller: TextEditingController()
            //                                                           ..text =
            //                                                               (item['returnQty']
            //                                                                       as num?)
            //                                                                   ?.toStringAsFixed(
            //                                                                     isKg
            //                                                                         ? 3
            //                                                                         : 0,
            //                                                                   ) ??
            //                                                               '',
            //                                                         decoration: InputDecoration(
            //                                                           labelText:
            //                                                               "Qty",
            //                                                           isDense:
            //                                                               true,
            //                                                           contentPadding:
            //                                                               const EdgeInsets.all(
            //                                                                 10,
            //                                                               ),
            //                                                           border: OutlineInputBorder(
            //                                                             borderRadius:
            //                                                                 BorderRadius.circular(
            //                                                                   6,
            //                                                                 ),
            //                                                           ),
            //                                                           suffixIcon:
            //                                                               item['returnQty'] !=
            //                                                                   null
            //                                                               ? IconButton(
            //                                                                   icon: Icon(
            //                                                                     Icons.clear,
            //                                                                     size: 16,
            //                                                                     color: Colors.red.shade600,
            //                                                                   ),
            //                                                                   onPressed: () {
            //                                                                     item.remove(
            //                                                                       'returnQty',
            //                                                                     );
            //                                                                     editableItems.notifyListeners();
            //                                                                   },
            //                                                                 )
            //                                                               : null,
            //                                                         ),
            //                                                         onTap: () {
            //                                                           showDialog(
            //                                                             context:
            //                                                                 context,
            //                                                             builder:
            //                                                                 (
            //                                                                   context,
            //                                                                 ) => NumericCalculator(
            //                                                                   varianceName: varianceName,
            //                                                                   onValueSelected:
            //                                                                       (
            //                                                                         double value,
            //                                                                       ) {
            //                                                                         // This is your original callback — we handle everything here
            //                                                                         final double? val =
            //                                                                             value >
            //                                                                                 0
            //                                                                             ? value
            //                                                                             : null;
            //                                                                         if (val ==
            //                                                                                 null ||
            //                                                                             val <=
            //                                                                                 0) {
            //                                                                           // Navigator.pop(
            //                                                                           //   context,
            //                                                                           // ); // close calculator
            //                                                                           return;
            //                                                                         }

            //                                                                         if (val >
            //                                                                             displayQty +
            //                                                                                 0.0001) {
            //                                                                           ScaffoldMessenger.of(
            //                                                                             context,
            //                                                                           ).showSnackBar(
            //                                                                             SnackBar(
            //                                                                               content: Text(
            //                                                                                 "Cannot return more than available: $displayQty $displayUom",
            //                                                                                 style: TextStyle(
            //                                                                                   color: Colors.white,
            //                                                                                 ),
            //                                                                               ),
            //                                                                               backgroundColor: Colors.red,
            //                                                                             ),
            //                                                                           );
            //                                                                           // Navigator.pop(
            //                                                                           //   context,
            //                                                                           // );
            //                                                                           return;
            //                                                                         }

            //                                                                         // Valid value — apply it
            //                                                                         item['returnQty'] = val;
            //                                                                         editableItems.notifyListeners();

            //                                                                         // Optional: Show success feedback
            //                                                                         ScaffoldMessenger.of(
            //                                                                           context,
            //                                                                         ).showSnackBar(
            //                                                                           SnackBar(
            //                                                                             content: Text(
            //                                                                               "Return Qty: ${val.toStringAsFixed(isKg ? 3 : 0)} $displayUom",
            //                                                                             ),
            //                                                                             backgroundColor: Colors.green,
            //                                                                             duration: Duration(
            //                                                                               milliseconds: 800,
            //                                                                             ),
            //                                                                           ),
            //                                                                         );

            //                                                                         // Navigator.pop(
            //                                                                         //   context,
            //                                                                         // ); // close calculator
            //                                                                       },
            //                                                                 ),
            //                                                           );
            //                                                         },
            //                                                       ),
            //                                                     ),

            //                                                   // Expanded(
            //                                                   //   flex: 2,
            //                                                   //   child: Column(
            //                                                   //     crossAxisAlignment:
            //                                                   //         CrossAxisAlignment
            //                                                   //             .end,
            //                                                   //     children: [
            //                                                   //       // ALWAYS SHOW THE AMOUNT — fixed forever!
            //                                                   //       Text(
            //                                                   //         '₹${lineTotal.toStringAsFixed(2)}',
            //                                                   //         style: TextStyle(
            //                                                   //           fontWeight:
            //                                                   //               FontWeight.bold,
            //                                                   //           fontSize:
            //                                                   //               16,
            //                                                   //         ),
            //                                                   //       ),
            //                                                   //       if (previouslyReturned >
            //                                                   //           0)
            //                                                   //         Text(
            //                                                   //           "-₹${(previouslyReturned * sellingPrice).toStringAsFixed(2)}",
            //                                                   //           style: TextStyle(
            //                                                   //             color: Colors
            //                                                   //                 .red
            //                                                   //                 .shade600,
            //                                                   //             fontSize:
            //                                                   //                 12,
            //                                                   //           ),
            //                                                   //         ),
            //                                                   //     ],
            //                                                   //   ),
            //                                                   // ),
            //                                                   Expanded(
            //                                                     flex: 2,
            //                                                     child: Column(
            //                                                       crossAxisAlignment:
            //                                                           CrossAxisAlignment
            //                                                               .end,
            //                                                       children: [
            //                                                         Text(
            //                                                           '₹${lineTotal.toStringAsFixed(2)}',
            //                                                           style: TextStyle(
            //                                                             fontWeight:
            //                                                                 FontWeight.bold,
            //                                                             fontSize:
            //                                                                 16,
            //                                                           ),
            //                                                         ),

            //                                                         // LIVE: Current return amount (appears as soon as user types)
            //                                                         if (currentReturnInput !=
            //                                                                 null &&
            //                                                             currentReturnInput >
            //                                                                 0)
            //                                                           Padding(
            //                                                             padding: const EdgeInsets.only(
            //                                                               top:
            //                                                                   4,
            //                                                             ),
            //                                                             child: Text(
            //                                                               "-₹${(currentReturnInput * sellingPrice).toStringAsFixed(2)}",
            //                                                               style: TextStyle(
            //                                                                 color:
            //                                                                     Colors.red.shade700,
            //                                                                 fontWeight:
            //                                                                     FontWeight.bold,
            //                                                                 fontSize:
            //                                                                     13,
            //                                                               ),
            //                                                             ),
            //                                                           ),

            //                                                         // Previously returned amount (from past returns)
            //                                                         if (previouslyReturned >
            //                                                             0)
            //                                                           Text(
            //                                                             "-₹${(previouslyReturned * sellingPrice).toStringAsFixed(2)}",
            //                                                             style: TextStyle(
            //                                                               color: Colors
            //                                                                   .red
            //                                                                   .shade500,
            //                                                               fontSize:
            //                                                                   12,
            //                                                             ),
            //                                                           ),
            //                                                       ],
            //                                                     ),
            //                                                   ),
            //                                                 ],
            //                                               ),
            //                                             );
            //                                           },
            //                                         );
            //                                       },
            //                                     );
            //                                   },
            //                                 );
            //                               },
            //                             ),
            //                           ),

            //                           // Bottom buttons — unchanged
            //                           if (inMode) ...[
            //                             const SizedBox(height: 20),
            //                             Row(
            //                               mainAxisAlignment:
            //                                   MainAxisAlignment.spaceEvenly,
            //                               crossAxisAlignment:
            //                                   CrossAxisAlignment.end,
            //                               children: [
            //                                 Container(
            //                                   height: 60,
            //                                   child: ElevatedButton.icon(
            //                                     onPressed: hasManualEntry
            //                                         ? null
            //                                         : _handleFullReturn,
            //                                     label: Text(
            //                                       "Full Return",
            //                                       style: TextStyle(
            //                                         color: Colors.white,
            //                                         fontWeight: FontWeight.bold,
            //                                       ),
            //                                     ),
            //                                     style: ElevatedButton.styleFrom(
            //                                       backgroundColor:
            //                                           Colors.blue.shade500,
            //                                       shape: RoundedRectangleBorder(
            //                                         borderRadius:
            //                                             BorderRadius.circular(
            //                                               8,
            //                                             ),
            //                                       ),
            //                                     ),
            //                                   ),
            //                                 ),
            //                                 const SizedBox(width: 12),
            //                                 Container(
            //                                   height: 60,
            //                                   child: ElevatedButton.icon(
            //                                     onPressed: hasManualEntry
            //                                         ? _handlePartialReturn
            //                                         : null,
            //                                     label: Text(
            //                                       "Submit",
            //                                       style: TextStyle(
            //                                         color: Colors.white,
            //                                         fontWeight: FontWeight.bold,
            //                                       ),
            //                                     ),
            //                                     style: ElevatedButton.styleFrom(
            //                                       padding: EdgeInsets.symmetric(
            //                                         vertical: 12,
            //                                         horizontal: 16,
            //                                       ),
            //                                       backgroundColor:
            //                                           hasManualEntry
            //                                           ? Colors.blue.shade500
            //                                           : Colors.grey,
            //                                       shape: RoundedRectangleBorder(
            //                                         borderRadius:
            //                                             BorderRadius.circular(
            //                                               8,
            //                                             ),
            //                                       ),
            //                                     ),
            //                                   ),
            //                                 ),
            //                                 const SizedBox(width: 12),
            //                                 Expanded(
            //                                   child:
            //                                       ValueListenableBuilder<
            //                                         List<Map<String, dynamic>>
            //                                       >(
            //                                         valueListenable:
            //                                             editableItems,
            //                                         builder: (context, _, __) {
            //                                           final refundAmount =
            //                                               getTotalRefundAmount();
            //                                           return Container(
            //                                             padding: EdgeInsets.all(
            //                                               15,
            //                                             ),
            //                                             decoration: BoxDecoration(
            //                                               color: Colors
            //                                                   .blue
            //                                                   .shade50,
            //                                               border: Border.all(
            //                                                 color: Colors
            //                                                     .blue
            //                                                     .shade300,
            //                                               ),
            //                                               borderRadius:
            //                                                   BorderRadius.circular(
            //                                                     8,
            //                                                   ),
            //                                             ),
            //                                             child: Row(
            //                                               mainAxisAlignment:
            //                                                   MainAxisAlignment
            //                                                       .spaceBetween,
            //                                               children: [
            //                                                 Text(
            //                                                   "Refund",
            //                                                   style: TextStyle(
            //                                                     fontSize: 15,
            //                                                     fontWeight:
            //                                                         FontWeight
            //                                                             .bold,
            //                                                   ),
            //                                                 ),
            //                                                 SizedBox(width: 7),
            //                                                 Text(
            //                                                   "₹${refundAmount.toStringAsFixed(2)}",
            //                                                   style: TextStyle(
            //                                                     fontSize: 18,
            //                                                     fontWeight:
            //                                                         FontWeight
            //                                                             .bold,
            //                                                     color: Colors
            //                                                         .blue
            //                                                         .shade700,
            //                                                   ),
            //                                                 ),
            //                                               ],
            //                                             ),
            //                                           );
            //                                         },
            //                                       ),
            //                                 ),
            //                               ],
            //                             ),
            //                           ],
            //                         ],
            //                       );
            //                     },
            //                   );
            //                 },
            //               ),
            //             ),
            //           ],
            //         ),
            //       ),
            //     ),
            //   ),
            // ),