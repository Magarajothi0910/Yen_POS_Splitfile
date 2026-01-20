// ignore_for_file: unused_local_variable

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:yenpos/Global/Widget/custom_button_reuse.dart';
import 'package:yenpos/Global/Widget/smartsearchtextfield.dart';
import 'package:yenpos/Global/globals_data.dart';

import 'package:yenpos/Sale_order/Models/sales_order_display_model.dart';

import 'package:yenpos/Sale_order/Provider/cartProvider.dart';
import 'package:yenpos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yenpos/Sale_order/Provider/editcustomerscreenProvider.dart';
import 'package:yenpos/Sale_order/Provider/get_sales_order_service.dart';
import 'package:yenpos/transactionPage/Model/transaction_model.dart';

import 'package:yenpos/transactionPage/Provider/transactionProvider.dart';
import 'dart:convert';

import 'package:yenpos/transactionPage/Screen/edit_outlet_so_customerdetails.dart';
import 'package:yenpos/transactionPage/Screen/sales_completed_layout.dart';

class TransactionPage extends StatefulWidget {
  const TransactionPage({super.key});

  @override
  _TransactionPageState createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  @override
  void initState() {
    super.initState();

    // Fetch invoices from provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final transactionProvider = context.read<TransactionProvider>();
      transactionProvider.getInvoicesFromHive();
    });
  }

  @override
  Widget build(BuildContext context) {
    final transactionProvider = context.watch<TransactionProvider>();
    final apiService = context.watch<ApiServiceSalesOrderProvider>();
    final cartProvider = Provider.of<CartProvider>(context);
    final customerScreenProvider = Provider.of<CustomerScreenProvider>(
      context,
      listen: false,
    );

    // 🔹 Prepare Data
    final salesCompletedOrders = transactionProvider.invoiceList.map((order) {
      return Transaction.fromMap(order);
    }).toList();


    final openOrders = apiService.hivefilteredOrders
        .map((order) {
          return SalesOrderDisplay.fromMap(order);
        })
        .where((order) => order.status == "Open Order")
        .toList();


    // ⚠️ Be careful: setState in build can cause infinite rebuild
    // setState(() {}); // ⚠️ Removed to prevent infinite rebuild

    return DefaultTabController(
      length: 2,
      initialIndex: transactionProvider.selectedIndex,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          elevation: 0,

          centerTitle: true,
          flexibleSpace: Container(
            decoration: const BoxDecoration(color: Colors.blue),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(30), // reduced height
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Transactions',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Row(
                  children: [
                    TabBar(
                      isScrollable: true,
                      indicator: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      onTap: (index) {
                        setState(() {
                          transactionProvider.selectedIndex = index;
                          transactionProvider.selectedTransactionIndex = null;
                        });
                      },
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: Colors.black87,
                      unselectedLabelColor: Colors.white,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      tabs: const [
                        SizedBox(width: 140, child: Tab(text: "Invoices")),
                        SizedBox(width: 120, child: Tab(text: "Open Orders")),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: Column(
          children: [
            // 🔹 Transactions Section
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(color: Colors.white),
                child: Row(
                  children: transactionProvider.selectedIndex == 0
                      ? buildSalesCompletedLayout(
                          salesCompletedOrders.cast<Map<String, dynamic>>(),
                          apiService,
                          transactionProvider,
                          context,
                        )
                      : _buildOpenOrderLayout(
                          openOrders,
                          cartProvider,
                          customerScreenProvider,
                          apiService,
                          transactionProvider,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------
  // Open Order Layout (3 columns)
  // --------------------------

  // --------------------------
  // Open Order Layout (3 columns)
  // --------------------------
  List<Widget> _buildOpenOrderLayout(
    List<SalesOrderDisplay> orders,
    CartProvider cartProvider,
    CustomerScreenProvider customerScreenProvider,
    ApiServiceSalesOrderProvider apiService,
    TransactionProvider transactionProvider,
  ) {
    return [
      Expanded(
        flex: 1,
        child: _buildOrderList(
          orders,
          apiService,
          transactionProvider.selectedTransactionIndex,
          transactionProvider,
        ),
      ),
      const VerticalDivider(),
      Expanded(
        flex: 1,
        child: Consumer<EditCustomerScreenProvider>(
          builder: (context, customerScreenProvider, child) {
            return orders.isNotEmpty &&
                    transactionProvider.selectedTransactionIndex != null
                ? EditOutletCustomerDetails(
                    key: ValueKey(
                      '${transactionProvider.selectedTransactionIndex}_${customerScreenProvider.isModifyMode}',
                    ),
                    selectedOrder:
                        orders[transactionProvider.selectedTransactionIndex!],
                    isEditing: customerScreenProvider.isModifyMode.value,
                    orderType: 'CurrentOrder',
                  )
                : const Center(child: Text("No Customer Selected"));
          },
        ),
      ),
      const VerticalDivider(),
      Expanded(
        flex: 1,
        child: _buildOrderDetails(
          orders,
          transactionProvider.selectedTransactionIndex,
          Provider.of<ApiServiceSalesOrderProvider>(context),
          customerScreenProvider,
          cartProvider,
        ),
      ),
    ];
  }

  Widget _buildEmptyOrderState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 100,
            color: const Color.fromARGB(255, 97, 220, 236),
          ),
          SizedBox(height: 20),
          Text(
            "Select an order to view details",
            style: TextStyle(color: Colors.grey, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetails(
    List<SalesOrderDisplay> hivefilteredSalesOrders,
    int? selectedIndex,
    ApiServiceSalesOrderProvider apiService,
    CustomerScreenProvider customerScreenProvider,
    CartProvider cartProvider,
  ) {
    if (selectedIndex == null || hivefilteredSalesOrders.isEmpty) {
      return _buildEmptyOrderState();
    }

    final salesOrder = hivefilteredSalesOrders[selectedIndex];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOrderHeader(salesOrder),
          Divider(color: Colors.grey[400]),
          _buildOrderItemsList(salesOrder),
          _buildOrderSummary(salesOrder),
          _buildOrderActions(
            context,
            salesOrder,
            customerScreenProvider,
            cartProvider,
            apiService,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary(SalesOrderDisplay salesOrder) {
    return Align(
      alignment: Alignment.centerRight, // Align summary to the right
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end, // Align text to the right
        mainAxisSize: MainAxisSize.min, // Minimize height to fit content
        children: [
          Text(
            'Total Amount: ₹${salesOrder.totalAmount.toStringAsFixed(0)}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderActions(
    BuildContext context,
    SalesOrderDisplay salesOrder,
    CustomerScreenProvider customerScreenProvider,
    CartProvider cartProvider,
    ApiServiceSalesOrderProvider apiService,
  ) {
    return Column(
      children: [
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomButton(
              text: 'Payment',
              onPressed: () {
                customerScreenProvider.showOPAdvancePaymentPopup(
                  context,
                  salesOrder,
                  cartProvider,
                  salesOrder.audio,
                  apiService,
                  salesOrder.image1 != null ? File(salesOrder.image1!) : null,
                  salesOrder.image2 != null ? File(salesOrder.image2!) : null,
                  customerScreenProvider.customerType,
                  customerScreenProvider.audioPlayer,
                  customerScreenProvider.holdId,
                );
                // customerScreenProvider.clikedThePaymentButton();
              },
              backgroundColor: Colors.blue,
              textColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              fontSize: 16.0,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOrderItemsList(SalesOrderDisplay salesOrder) {
    // Check if isBoxItem and varianceName are not null and have the same length
    if (salesOrder.isBoxItem == null ||
        salesOrder.varianceName == null ||
        salesOrder.isBoxItem!.length != salesOrder.varianceName.length) {
      return Center(child: Text('Data is incomplete or invalid'));
    }

    // Separate box items and non-box items while maintaining original order
    List<int> boxItemIndices = [];
    List<int> nonBoxItemIndices = [];

    // Populate boxItemIndices and nonBoxItemIndices
    for (int i = 0; i < salesOrder.varianceName.length; i++) {
      if (salesOrder.isBoxItem![i].toLowerCase() == 'yes' ?? false) {
        boxItemIndices.add(i);
      } else {
        nonBoxItemIndices.add(i);
      }
    }

    // Ensure itemCount is valid; if no items, return an empty container
    int itemCount =
        nonBoxItemIndices.length + (boxItemIndices.isNotEmpty ? 1 : 0);

    if (itemCount == 0) {
      return SizedBox(); // Return an empty widget if no items to display
    }

    return Expanded(
      child: ListView.separated(
        itemCount: itemCount,
        separatorBuilder: (context, index) => SizedBox(height: 8),
        itemBuilder: (context, index) {
          // Show box items card first if present
          if (boxItemIndices.isNotEmpty && index == 0) {
            return _buildBoxItemsCard(salesOrder, boxItemIndices);
          }

          // Adjust index for non-box items
          final adjustedIndex = index - (boxItemIndices.isNotEmpty ? 1 : 0);

          // Ensure the adjustedIndex is within bounds for nonBoxItemIndices
          if (adjustedIndex >= nonBoxItemIndices.length) {
            return SizedBox(); // Return an empty widget if index is out of bounds
          }

          return _buildOrderItemTile(
            salesOrder,
            nonBoxItemIndices[adjustedIndex],
            showAsBoxItem: false,
          );
        },
      ),
    );
  }

  Widget _buildOrderItemTile(
    SalesOrderDisplay salesOrder,
    int index, {
    bool showAsBoxItem = false,
  }) {
    // Debugging output to verify values

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        salesOrder.varianceName[index],
        style: TextStyle(
          fontSize: 12,
          color: showAsBoxItem ? Colors.blue.shade800 : Colors.grey,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Builder(
            builder: (context) {
              final uom = salesOrder.uom[index];
              final isKg =
                  uom.toLowerCase() == "kg" || uom.toLowerCase() == "kgs";
              final weight = salesOrder.weight[index];
              final qty = salesOrder.qty[index];
              final price = salesOrder.price[index];

              if (isKg) {
                if (weight >= 1) {
                  return Text(
                    '${weight.toStringAsFixed(1)} kg × ₹${price.toStringAsFixed(0)}/kg',
                    style: TextStyle(fontSize: 10),
                  );
                } else {
                  final grams = weight * 1000;
                  return Text(
                    '${qty.toInt()} × ${grams.toStringAsFixed(0)} g × ₹${price.toStringAsFixed(0)}/kg',
                    style: TextStyle(fontSize: 10),
                  );
                }
              } else {
                return Text(
                  '${qty.toInt()} ${uom} × ₹${price.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 10),
                );
              }
            },
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '₹${salesOrder.amount[index].toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: showAsBoxItem ? Colors.blue.shade800 : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoxItemsCard(
    SalesOrderDisplay salesOrder,
    List<int> boxIndices,
  ) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 0, horizontal: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade300, width: 1.5),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.blue.shade50],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.blue.shade100.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.inventory_2,
                      size: 18,
                      color: Colors.blue.shade700,
                    ),
                    SizedBox(width: 8),
                    // Display boxqty here
                    Text(
                      '${salesOrder.boxQty} ×', // Your box quantity field
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'BOX ITEMS',
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade600,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${boxIndices.length}',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: boxIndices
                      .map(
                        (index) => Padding(
                          padding: EdgeInsets.only(
                            bottom: index == boxIndices.last ? 0 : 8,
                          ),
                          child: Container(
                            child: _buildOrderItemTile(
                              salesOrder,
                              index,
                              showAsBoxItem: true,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderHeader(SalesOrderDisplay salesOrder) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Type',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            Text(salesOrder.paymentType, style: TextStyle(fontSize: 11)),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order ID',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            Text(salesOrder.saleOrderNo, style: TextStyle(fontSize: 11)),
          ],
        ),
      ],
    );
  }

  Widget _buildOrderList(
    List<SalesOrderDisplay> filteredSalesOrders,
    ApiServiceSalesOrderProvider apiService,
    int? selectedIndex,
    TransactionProvider transactionProvider,
  ) {
    // SAFETY: Reset selected index if out of range
    if (transactionProvider.selectedTransactionIndex != null &&
        transactionProvider.selectedTransactionIndex! >=
            filteredSalesOrders.length) {
      transactionProvider.selectedTransactionIndex = null;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: SmartSearchField(
            controller: transactionProvider.searchController,
            onSearch: apiService.searchOrders,
          ),
        ),

        // ===================== LIST VIEW =====================
        Expanded(
          child: filteredSalesOrders.isEmpty
              ? const Center(
                  child: Text(
                    "No orders available",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: filteredSalesOrders.length,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemBuilder: (context, index) {
                    final order = filteredSalesOrders[index];

                    // SAFE CHECK: Prevent RangeError
                    final bool isSelected =
                        transactionProvider.selectedTransactionIndex != null &&
                        transactionProvider.selectedTransactionIndex! <
                            filteredSalesOrders.length &&
                        transactionProvider.selectedTransactionIndex == index;

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Main Card
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: LinearGradient(
                              colors: order.status == "dispatched"
                                  ? [Colors.red.shade200, Colors.red.shade100]
                                  : [Colors.white, Colors.grey.shade100],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(
                              color: isSelected
                                  ? Colors.indigo.shade300
                                  : Colors.grey.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),

                            // TAP EVENT (Safe index assignment)
                            onTap: () {
                              setState(() {
                                if (index < filteredSalesOrders.length) {
                                  transactionProvider.selectedTransactionIndex =
                                      index;
                                }
                              });
                            },

                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 20),
                                  Table(
                                    columnWidths: const {
                                      0: FlexColumnWidth(1),
                                      1: FlexColumnWidth(1.2),
                                      2: FlexColumnWidth(0.5),
                                    },
                                    children: [
                                      const TableRow(
                                        children: [
                                          Padding(
                                            padding: EdgeInsets.only(
                                              bottom: 6.0,
                                            ),
                                            child: Text(
                                              'Order ID',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: EdgeInsets.only(
                                              bottom: 6.0,
                                            ),
                                            child: Text(
                                              'Order Taken By',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: EdgeInsets.only(
                                              bottom: 6.0,
                                            ),
                                            child: Text(
                                              'Status',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      TableRow(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 2.0,
                                            ),
                                            child: Text(
                                              order.saleOrderNo,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 2.0,
                                            ),
                                            child: Text(
                                              (order.employeeName ?? 'N/A')
                                                  .replaceAll(
                                                    RegExp(r'[^a-zA-Z\s]'),
                                                    '',
                                                  ),
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 2.0,
                                            ),
                                            child: Text(
                                              (order.status ?? 'N/A')
                                                  .toUpperCase(),
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // TAG POSITION
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(8),
                              ),
                            ),
                            child: Text(
                              order.status.toLowerCase() == 'open order'
                                  ? 'SO'
                                  : (order.orderType ?? ''),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}
