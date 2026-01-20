import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
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

final Dio _dio = Dio(
  BaseOptions(
    connectTimeout: Duration(seconds: 3),
    receiveTimeout: Duration(seconds: 3),
    sendTimeout: Duration(seconds: 3),
  ),
);

Future<List<Map<String, dynamic>>> _getReturnedItemsForInvoice(
  String invoiceNo,
) async {
  List<Map<String, dynamic>> result = [];

  // Step 1: Check local Hive first (fast/offline)
  try {
    final box = await Hive.openBox('salesReturns');
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
  } catch (e) {}

  if (result.isEmpty) {
    try {
      final response = await _dio.get(
        'https://yenerp.com/fluttertestapi/invoices/api/search-orders?q=returns_for:$invoiceNo',

        //headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> apiData = jsonDecode(response.data);
        for (var ret in apiData) {
          final List<dynamic> names = ret['varianceName'] ?? [];
          final List<dynamic> qty = ret['qty'] ?? [];
          final List<dynamic> weight = ret['weight'] ?? [];
          final List<dynamic> uomList = ret['uom'] ?? [];
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
      } else {}
    } catch (e) {}
  }

  return result;
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
    case 'salesreturn':
      return 'SR'; // Sales Return
    default:
      return '';
  }
}

List<String> orderFilters = [
  "all",
  "takeaway",
  "dinein",
  "salesorder",
  "salesreturn",
];
String _normalizeSalesType(String? type) {
  if (type == null) return "";
  final normalized = type
      .toLowerCase()
      .trim()
      .replaceAll(' ', '')
      .replaceAll('-', '');

  if (normalized == 'salesreturn') return 'salesreturn';
  if (normalized.contains('takeaway') || normalized.contains('take away'))
    return 'takeaway';
  if (normalized.contains('dinein') ||
      normalized.contains('dinning') ||
      normalized.contains('dine'))
    return 'dinein';
  if (normalized.contains('salesorder') || normalized.contains('saleorder'))
    return 'salesorder';
  return '';
}

List<Widget> buildSalesCompletedLayout(
  List<Map<String, dynamic>> invoices,
  ApiServiceSalesOrderProvider apiService,
  TransactionProvider transactionProvider,
  BuildContext context,
) {
  return [
    Expanded(flex: 1, child: const _SalesListWithInfiniteScroll()),
    const VerticalDivider(),
    Expanded(
      flex: 2,
      child: Consumer<TransactionProvider>(
        builder: (context, provider, child) {
          final int? selectedIndex = provider.selectedTransactionIndex;

          if (selectedIndex == null) {
            return const Center(
              child: Text(
                "Select an Order",
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          final List<Map<String, dynamic>> currentInvoices = provider.invoices;
          final String currentFilter = provider.selectedOrderFilter ?? "all";

          final List<Map<String, dynamic>> filteredInvoices =
              currentFilter == "all"
              ? currentInvoices
              : currentInvoices.where((inv) {
                  final String normalizedType = _normalizeSalesType(
                    (inv['salesType'] ?? '').toString(),
                  );
                  return normalizedType == currentFilter;
                }).toList();

          if (selectedIndex >= filteredInvoices.length ||
              filteredInvoices.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              provider.selectedTransactionIndex = null;
            });
            return const Center(
              child: Text(
                "No order selected",
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          final Map<String, dynamic> selectedInvoice =
              filteredInvoices[selectedIndex];
          final Transaction transaction = Transaction.fromMap(selectedInvoice);

          return _buildTransactionDetail(
            context,
            transaction,
            transactionProvider,
          );
        },
      ),
    ),
  ];
}

// =============================================================================
// STATEFUL WIDGET WITH PERFECT INFINITE SCROLL (WORKS WITH 1 OR 100 ITEMS)
// =============================================================================
class _SalesListWithInfiniteScroll extends StatefulWidget {
  const _SalesListWithInfiniteScroll({Key? key}) : super(key: key);

  @override
  State<_SalesListWithInfiniteScroll> createState() =>
      _SalesListWithInfiniteScrollState();
}

class _SalesListWithInfiniteScrollState
    extends State<_SalesListWithInfiniteScroll> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (currentScroll >= maxScroll - 100) {
      context.read<TransactionProvider>().loadMoreFromServer();
    }
  }

  void _checkAndLoadMoreIfNeeded() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final viewportHeight = _scrollController.position.viewportDimension;

    if (maxScroll <= viewportHeight) {
      context.read<TransactionProvider>().loadMoreFromServer();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkAndLoadMoreIfNeeded();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, provider, child) {
        final List<Map<String, dynamic>> currentInvoices = provider.invoices;
        final String currentFilter = provider.selectedOrderFilter ?? "all";

        List<Map<String, dynamic>> filteredInvoices = currentFilter == "all"
            ? List.from(currentInvoices)
            : currentInvoices.where((inv) {
                final String salesType = (inv['salesType'] ?? '')
                    .toString()
                    .trim();
                final String normalizedType = _normalizeSalesType(salesType);
                return normalizedType == currentFilter;
              }).toList();

        // === FIXED SORTING: Original invoice always comes BEFORE its sales return ===
        filteredInvoices.sort((a, b) {
          DateTime getDate(Map<String, dynamic> inv) {
            final dynamic raw = inv['isSalesReturn'] == true
                ? inv['returnDateTime']
                : inv['invoiceDateTime'] ?? inv['orderDateTime'];
            return DateTime.tryParse(raw?.toString() ?? '') ?? DateTime(1970);
          }

          final DateTime dateA = getDate(a);
          final DateTime dateB = getDate(b);

          // Primary: newest first
          int compare = dateB.compareTo(dateA);
          if (compare != 0) return compare;

          // Secondary: if same date/time, original BEFORE return
          final bool aIsReturn =
              (a['salesType']?.toString().trim() ?? '') == 'salesReturn';
          final bool bIsReturn =
              (b['salesType']?.toString().trim() ?? '') == 'salesReturn';

          final String? aInvoiceNo = a['invoiceNo']?.toString();
          final String? bInvoiceNo = b['invoiceNo']?.toString();

          if (!aIsReturn && bIsReturn && aInvoiceNo == bInvoiceNo)
            return -1; // original first
          if (aIsReturn && !bIsReturn && aInvoiceNo == bInvoiceNo)
            return 1; // return after

          return 0;
        });

        // Group by date (unchanged)
        final Map<String, List<Map<String, dynamic>>> groupedByDate = {};
        for (var inv in filteredInvoices) {
          String dateKey;
          final dynamic dateRaw = inv['isSalesReturn'] == true
              ? inv['returnDateTime']
              : inv['invoiceDateTime'] ?? inv['orderDateTime'];
          final DateTime? date = DateTime.tryParse(dateRaw?.toString() ?? '');

          if (date == null) {
            dateKey = "Unknown Date";
          } else {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final yesterday = today.subtract(const Duration(days: 1));
            final invoiceDay = DateTime(date.year, date.month, date.day);

            if (invoiceDay == today) {
              dateKey = "Today";
            } else if (invoiceDay == yesterday) {
              dateKey = "Yesterday";
            } else {
              dateKey = DateFormat('dd/MM/yyyy').format(date);
            }
          }
          groupedByDate.putIfAbsent(dateKey, () => []);
          groupedByDate[dateKey]!.add(inv);
        }

        // Sort date keys (unchanged)
        final List<String> sortedDateKeys = [];
        if (groupedByDate.containsKey("Today")) sortedDateKeys.add("Today");
        if (groupedByDate.containsKey("Yesterday"))
          sortedDateKeys.add("Yesterday");

        final List<String> otherDates = groupedByDate.keys
            .where(
              (k) => k != "Today" && k != "Yesterday" && k != "Unknown Date",
            )
            .toList();

        if (otherDates.isNotEmpty) {
          final List<DateTime> parsed = [];
          for (var key in otherDates) {
            try {
              parsed.add(DateFormat('dd/MM/yyyy').parse(key));
            } catch (_) {}
          }
          parsed.sort((a, b) => b.compareTo(a));
          for (var d in parsed) {
            final f = DateFormat('dd/MM/yyyy').format(d);
            if (!sortedDateKeys.contains(f)) sortedDateKeys.add(f);
          }
        }
        if (groupedByDate.containsKey("Unknown Date"))
          sortedDateKeys.add("Unknown Date");

        return Column(
          children: [
            // Search (unchanged)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                cursorColor: Colors.blue,
                controller: provider.searchController,
                decoration: InputDecoration(
                  hintText: "Search by Invoice No",
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: provider.searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            provider.searchController.clear();
                            provider.searchInvoiceOrders('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onSubmitted: (value) {
                  if (value.trim().length == 17) {
                    provider.searchInvoiceOrders(value.trim());
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Please enter Full Invoice Number."),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                },
              ),
            ),

            // Filters (unchanged)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 5,
                ),
                child: Row(
                  children: orderFilters.map((type) {
                    bool isActive = currentFilter == type;
                    return GestureDetector(
                      onTap: () {
                        provider.selectedOrderFilter = type;
                        provider.resetPagination();
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
            ),

            // Infinite Scroll List
            Expanded(
              child: groupedByDate.isEmpty
                  ? const Center(child: Text("No Orders Found"))
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount:
                          sortedDateKeys.length +
                          (provider.isLoadingMore ? 1 : 0),
                      itemBuilder: (context, groupIndex) {
                        if (groupIndex == sortedDateKeys.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }

                        final dateKey = sortedDateKeys[groupIndex];
                        final items = groupedByDate[dateKey]!;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              color: dateKey == "Unknown Date"
                                  ? Colors.orange.shade50
                                  : Colors.grey.shade100,
                              child: Text(
                                dateKey,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: dateKey == "Unknown Date"
                                      ? Colors.orange.shade800
                                      : Colors.black87,
                                ),
                              ),
                            ),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: items.length,
                              itemBuilder: (context, itemIndex) {
                                // === CORRECTED: Serial number is now 1,2,3... per date group ===
                                final serialNumber = itemIndex + 1;

                                int globalIndex = 0;
                                for (int i = 0; i < groupIndex; i++) {
                                  globalIndex +=
                                      groupedByDate[sortedDateKeys[i]]!.length;
                                }
                                globalIndex += itemIndex;

                                final inv = items[itemIndex];
                                final bool isSelected =
                                    provider.selectedTransactionIndex ==
                                    globalIndex;

                                final String displayId =
                                    inv['salesType'] == "salesReturn"
                                    ? (inv['salesReturnNo']?.toString() ?? '')
                                    : (inv['invoiceNo']?.toString() ?? '');

                                // === "RETURNED" TAG: Only on original invoice ===
                                final bool isSalesReturnEntry =
                                    (inv['salesType']?.toString().trim() ??
                                        '') ==
                                    'salesReturn';
                                final String? originalInvoiceNo =
                                    inv['invoiceNo']?.toString();

                                final bool hasReturn =
                                    !isSalesReturnEntry &&
                                    originalInvoiceNo != null &&
                                    provider.invoices.any((i) {
                                      return (i['salesType']
                                                      ?.toString()
                                                      .trim() ??
                                                  '') ==
                                              'salesReturn' &&
                                          i['invoiceNo']?.toString() ==
                                              originalInvoiceNo;
                                    });

                                return GestureDetector(
                                  onTap: () =>
                                      provider.selectedTransactionIndex =
                                          globalIndex,
                                  child: Stack(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        child: Material(
                                          elevation: 4,
                                          shadowColor: Colors.black26,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              children: [
                                                SizedBox(
                                                  width: 25,
                                                  child: Text(
                                                    "$serialNumber", // Now shows 1,2,3... correctly
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: isSelected
                                                          ? Colors.white
                                                          : Colors.black54,
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 220,
                                                  child: Text(
                                                    displayId,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 15,
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
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    _getOrderShortName(
                                                      (inv['salesType'] ?? '')
                                                          .trim(),
                                                    ),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: isSelected
                                                          ? Colors.blue
                                                          : Colors.white,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    "₹${(inv['totalAmount'] ?? 0).toStringAsFixed(0)}",
                                                    textAlign: TextAlign.end,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade500,
                                              borderRadius:
                                                  const BorderRadius.only(
                                                    topRight: Radius.circular(
                                                      8,
                                                    ),
                                                    bottomLeft: Radius.circular(
                                                      8,
                                                    ),
                                                  ),
                                            ),
                                            child: const Text(
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
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

Future<bool> hasRealInternetConnection() async {
  // First, check basic connectivity
  final connectivityResult = await Connectivity().checkConnectivity();
  if (connectivityResult == ConnectivityResult.none) {
    return false;
  }

  // Then, perform a real reachability check
  try {
    final result = await InternetAddress.lookup(
      'google.com',
    ).timeout(const Duration(seconds: 6));
    return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
  } on TimeoutException {
    return false;
  } on SocketException {
    return false;
  } catch (e) {
    return false;
  }
}

Widget _buildReturnedItemsWidget(
  AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
  Transaction transaction,
  ValueNotifier<List<Map<String, dynamic>>> editableItems,
) {
  if (!snapshot.hasData || snapshot.data!.isEmpty) {
    return const SizedBox.shrink();
  }

  double totalReturned = 0.0;

  for (var returnedItem in snapshot.data!) {
    final double returnedQty =
        (returnedItem['returnedQty'] as num?)?.toDouble() ?? 0.0;
    if (returnedQty <= 0) continue;

    // Find matching original item
    final matchingItem = editableItems.value.firstWhere(
      (i) =>
          i['varianceName']?.toString() ==
          returnedItem['varianceName']?.toString(),
      orElse: () => <String, dynamic>{},
    );

    if (matchingItem.isEmpty) continue;

    final double lineTotal =
        (matchingItem['sellingAmount'] as num?)?.toDouble() ?? 0.0;

    final dynamic weightList = matchingItem['weight'];
    final double? originalWeight = weightList is List
        ? (weightList.isNotEmpty ? weightList[0] : null)?.toDouble()
        : weightList?.toDouble();

    final String uom = (matchingItem['uom']?.toString() ?? 'Pcs').toLowerCase();
    final bool isKg =
        uom.contains('kg') && originalWeight != null && originalWeight > 0;

    double returnedAmount;
    if (isKg) {
      returnedAmount = (returnedQty / originalWeight!) * lineTotal;
    } else {
      final double sellingPrice =
          (matchingItem['sellingPrice'] as num?)?.toDouble() ?? 0.0;
      returnedAmount = returnedQty * sellingPrice;
    }

    totalReturned += returnedAmount;
  }

  if (totalReturned <= 0) {
    return const SizedBox.shrink();
  }

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
}

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

      final double mrp = (item['price'] as num).toDouble();
      final double discountedPrice = (item['sellingPrice'] as num).toDouble();
      final double taxRate = (item['tax'] as num?)?.toDouble() ?? 0.0;
      final double originalWeight = (item['weight'] as num?)?.toDouble() ?? 1.0;
      final double paidLine = isKg
          ? (discountedPrice / originalWeight) * returnQtyInput
          : discountedPrice * returnQtyInput;
      final double lineGst = paidLine * taxRate / (100 + taxRate);

      final double originalLine = isKg
          ? (mrp / originalWeight) * returnQtyInput
          : mrp * returnQtyInput;

      varianceitemCode.add(item['varianceitemCode']?.toString() ?? '');
      itemName.add(item['itemName']?.toString() ?? '');
      varianceName.add(item['varianceName']?.toString() ?? '');
      price.add(mrp.toInt());
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

      amount.add(originalLine);
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
      "salesType": "salesReturn",
      "customerPhoneNumber": transaction.customerPhoneNumber,
      "salesPersonId": transaction.salesPersonId,
      "salesPersonName": transaction.salesPersonName,
      "branchId": branchId,
      "branchName": branchName,
      "aliasName": transaction.aliasName,
      "paymentType": "Cash",
      "invoiceNo": transaction.invoiceNo,
      "salesReturnNo": "${transaction.invoiceNo}-SR",
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
      return;
    }
    _isPostingReturn = true;


    final returnData = _calculateReturnData();
    if (returnData.isEmpty) {
      _isPostingReturn = false;
      return;
    }


    try {
      final salesReturn = {'type': 'salesReturn', 'data': returnData};
      await sendataToServer(salesReturn);
      await transactionProvider.refreshAfterReturn();

      // Clear the return mode
      isReturnMode.value = false;

      // IMPORTANT: Force the selected transaction to reload
      final currentIndex = transactionProvider.selectedTransactionIndex;
      if (currentIndex != null) {
        // Temporarily clear and restore selection to trigger rebuild
        transactionProvider.selectedTransactionIndex = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          transactionProvider.selectedTransactionIndex = currentIndex;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Return Failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _isPostingReturn = false;
    }
  }

  double getTotalRefundAmount() {
    final hasManualEntry = editableItems.value.any(
      (i) => ((i['returnQty'] as num?)?.toDouble() ?? 0) > 0,
    );
    if (!hasManualEntry) {
      return transaction.grossAmount ?? transaction.totalAmount ?? 0.0;
    }
    return editableItems.value.fold(0.0, (sum, item) {
      final returnQty = (item['returnQty'] as num?)?.toDouble() ?? 0.0;
      if (returnQty <= 0) return sum;

      final double sellingPrice =
          (item['sellingPrice'] as num?)?.toDouble() ?? 0.0;
      final double lineTotal =
          (item['sellingAmount'] as num?)?.toDouble() ?? 0.0;
      final dynamic weightList = item['weight'];
      final double? weight = weightList is List
          ? (weightList.isNotEmpty ? weightList[0] : null)?.toDouble()
          : weightList?.toDouble();
      final String uom = (item['uom']?.toString() ?? 'Pcs').toLowerCase();
      final bool isKg = uom.contains('kg') && weight != null && weight > 0;

      if (isKg && weight! > 0) {
        return sum + (returnQty / weight) * lineTotal;
      } else {
        return sum + (returnQty * sellingPrice);
      }
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
                borderRadius: BorderRadius.circular(8),
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
                          borderRadius: BorderRadius.circular(8),
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
      final double sellingPrice =
          (item['sellingPrice'] as num?)?.toDouble() ?? 0.0;
      final double originalWeight = (item['weight'] as num?)?.toDouble() ?? 1.0;
      final bool isKg = uom.toLowerCase().contains('kg');

      // FIXED: Correct amount calculation for Kg items
      final double amount = isKg
          ? (qty / originalWeight) * sellingPrice
          : qty * sellingPrice;

      totalRefund += amount;

      itemWidgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(name, style: TextStyle(fontSize: 13))),
              Text(
                "${qty.toStringAsFixed(isKg ? 3 : 0)} $uom × ₹${sellingPrice.toStringAsFixed(2)} = ₹${amount.toStringAsFixed(2)}",
                style: TextStyle(fontWeight: FontWeight.bold),
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
                borderRadius: BorderRadius.circular(8),
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
                      child: Text("No", style: TextStyle(color: Colors.black)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade500,
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
                        transaction.paymentType
                                ?.replaceAll('[', '')
                                .replaceAll(']', '') ??
                            'N/A',
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
                                    if ((transaction.customCharge?.fold<double>(
                                              0,
                                              (a, b) => a + b,
                                            ) ??
                                            0) >
                                        0)
                                      buildChargeRow(
                                        "Custom Charge",
                                        "₹${(transaction.customCharge?.fold<double>(0, (a, b) => a + b) ?? 0).toStringAsFixed(2)}",
                                      ),
                                    buildChargeRow(
                                      "Items Total",
                                      "₹${transaction.totalAmount.toStringAsFixed(2)}",
                                    ),
                                    if ((transaction.customCharge?.fold<double>(
                                                  0,
                                                  (a, b) => a + b,
                                                ) ??
                                                0) >
                                            0 ||
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
                                        // Add a key to force rebuild when transaction changes
                                        return KeyedSubtree(
                                          key: ValueKey(
                                            'returned_items_${transaction.invoiceNo}_${DateTime.now().millisecondsSinceEpoch}',
                                          ),
                                          child: _buildReturnedItemsWidget(
                                            snapshot,
                                            transaction,
                                            editableItems,
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
                                    IconButton(
                                      icon: Icon(
                                        Icons.refresh,
                                        color: Colors.blue,
                                      ),
                                      onPressed: () async {
                                        await transactionProvider
                                            .refreshAfterReturn();
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text("Data refreshed"),
                                            duration: Duration(seconds: 1),
                                          ),
                                        );
                                      },
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
                                            snapshot.data!.isEmpty == false) {
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
                                                ? () async {
                                                    final invoiceHive =
                                                        Hive.box('invoices');
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
                                                      final bool hasInternet =
                                                          await hasRealInternetConnection();

                                                      if (!hasInternet) {
                                                        showDialog(
                                                          context: context,
                                                          barrierDismissible:
                                                              true,
                                                          builder: (context) => Dialog(
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    20,
                                                                  ),
                                                            ),
                                                            elevation: 10,
                                                            backgroundColor:
                                                                Colors
                                                                    .transparent,
                                                            child: Container(
                                                              decoration: BoxDecoration(
                                                                gradient: LinearGradient(
                                                                  colors: [
                                                                    Colors
                                                                        .white,
                                                                    Colors
                                                                        .grey
                                                                        .shade100,
                                                                  ],
                                                                  begin: Alignment
                                                                      .topLeft,
                                                                  end: Alignment
                                                                      .bottomRight,
                                                                ),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      20,
                                                                    ),
                                                                boxShadow: [
                                                                  BoxShadow(
                                                                    color: Colors
                                                                        .black26,
                                                                    blurRadius:
                                                                        15,
                                                                    offset:
                                                                        Offset(
                                                                          0,
                                                                          8,
                                                                        ),
                                                                  ),
                                                                ],
                                                              ),
                                                              padding:
                                                                  EdgeInsets.all(
                                                                    20,
                                                                  ),
                                                              child: Column(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                children: [
                                                                  Container(
                                                                    padding:
                                                                        EdgeInsets.all(
                                                                          12,
                                                                        ),
                                                                    decoration: BoxDecoration(
                                                                      color: Colors
                                                                          .redAccent
                                                                          .withOpacity(
                                                                            0.1,
                                                                          ),
                                                                      shape: BoxShape
                                                                          .circle,
                                                                    ),
                                                                    child: Icon(
                                                                      Icons
                                                                          .wifi_off_rounded,
                                                                      color: Colors
                                                                          .redAccent,
                                                                      size: 40,
                                                                    ),
                                                                  ),
                                                                  SizedBox(
                                                                    height: 15,
                                                                  ),
                                                                  Text(
                                                                    'No Internet Connection',
                                                                    style: TextStyle(
                                                                      fontFamily:
                                                                          'Poppins',
                                                                      fontSize:
                                                                          20,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      color: Colors
                                                                          .black87,
                                                                    ),
                                                                    textAlign:
                                                                        TextAlign
                                                                            .center,
                                                                  ),
                                                                  SizedBox(
                                                                    height: 10,
                                                                  ),
                                                                  Text(
                                                                    'Please check your internet connection and try again.',
                                                                    style: TextStyle(
                                                                      fontFamily:
                                                                          'Poppins',
                                                                      fontSize:
                                                                          16,
                                                                      color: Colors
                                                                          .black54,
                                                                    ),
                                                                    textAlign:
                                                                        TextAlign
                                                                            .center,
                                                                  ),
                                                                  SizedBox(
                                                                    height: 20,
                                                                  ),
                                                                  SizedBox(
                                                                    width: double
                                                                        .infinity,
                                                                    child: ElevatedButton(
                                                                      style: ElevatedButton.styleFrom(
                                                                        backgroundColor:
                                                                            Colors.redAccent,
                                                                        padding: EdgeInsets.symmetric(
                                                                          vertical:
                                                                              14,
                                                                        ),
                                                                        shape: RoundedRectangleBorder(
                                                                          borderRadius: BorderRadius.circular(
                                                                            12,
                                                                          ),
                                                                        ),
                                                                        elevation:
                                                                            5,
                                                                      ),
                                                                      onPressed: () =>
                                                                          Navigator.pop(
                                                                            context,
                                                                          ),
                                                                      child: Text(
                                                                        'OK',
                                                                        style: TextStyle(
                                                                          fontFamily:
                                                                              'Poppins',
                                                                          fontSize:
                                                                              16,
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                          color:
                                                                              Colors.white,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                        return; // Stop further execution
                                                      }
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

                                                            double
                                                            refundForThisItem =
                                                                0.0;
                                                            if (currentReturnInput !=
                                                                    null &&
                                                                currentReturnInput >
                                                                    0) {
                                                              if (isKg &&
                                                                  weight !=
                                                                      null &&
                                                                  weight > 0) {
                                                                refundForThisItem =
                                                                    (currentReturnInput /
                                                                        weight) *
                                                                    lineTotal;
                                                              } else {
                                                                refundForThisItem =
                                                                    currentReturnInput *
                                                                    sellingPrice;
                                                              }
                                                            }
                                                            final bool
                                                            viewingOriginalInvoice =
                                                                transaction
                                                                    .salesType
                                                                    ?.toLowerCase() !=
                                                                'salesreturn';

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

                                                                        // Only show returned info when viewing ORIGINAL invoice (not sales return entry)
                                                                        if (viewingOriginalInvoice &&
                                                                            previouslyReturned >
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
                                                                              "-₹${refundForThisItem.toStringAsFixed(2)}",
                                                                              style: TextStyle(
                                                                                color: Colors.red.shade700,
                                                                                fontWeight: FontWeight.bold,
                                                                                fontSize: 13,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        if (viewingOriginalInvoice &&
                                                                            previouslyReturned >
                                                                                0)
                                                                          Padding(
                                                                            padding: const EdgeInsets.only(
                                                                              top: 4,
                                                                            ),
                                                                            child: Text(
                                                                              "-₹${(() {
                                                                                if (isKg && weight != null && weight > 0) {
                                                                                  return (previouslyReturned / weight) * lineTotal;
                                                                                } else {
                                                                                  return previouslyReturned * sellingPrice;
                                                                                }
                                                                              })().toStringAsFixed(2)}",
                                                                              style: TextStyle(
                                                                                color: Colors.red.shade500,
                                                                                fontSize: 12,
                                                                              ),
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