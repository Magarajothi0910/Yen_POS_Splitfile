// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:yenposapp/Global/custom_button_reuse.dart';
import 'package:yenposapp/Global/smartsearchtextfield.dart';
import 'package:yenposapp/KotApp/kotproviders/transactionProvider.dart';

import 'package:yenposapp/screens/sales_order/sales_order_providers/cartProvider.dart';
import 'package:yenposapp/screens/sales_order/sales_order_providers/customerScreen_provider.dart';
import 'package:yenposapp/screens/sales_order/sales_order_providers/editcustomerscreenProvider.dart';
import 'package:yenposapp/screens/sales_order/screens/all_orders_page/services/get_sales_order_service.dart';
import 'package:yenposapp/screens/sales_order/screens/create_salesOrder.dart/edit_outlet_so_customerdetails.dart';
import 'package:yenposapp/screens/sales_order/screens/model/sales_order_model.dart';
import 'package:yenposapp/screens/transactionPage/transaction_model.dart';
import 'dart:convert';
import '../../Global/globals_data.dart';

class TransactionPage extends StatefulWidget {
  final GlobalKey keyboardKey;
  const TransactionPage({super.key, required this.keyboardKey});

  @override
  _TransactionPageState createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  int _selectedIndex = 0;
  int? _selectedTransactionIndex;
  List<Map<String, dynamic>> _confirmedSalesReturns = [];

  void _onTransactionTapped(int index) {
    setState(() {
      _selectedTransactionIndex = index;
      print("👉 [_onTransactionTapped] Selected Transaction Index = $index");
    });
  }

  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    print("🎨 [TransactionPage.build] CALLED");

    final transactionProvider = context.watch<TransactionProvider>();
    final apiService = context.watch<ApiServiceSalesOrderProvider>();
    final cartProvider = Provider.of<CartProvider>(context);
    final customerScreenProvider =
        Provider.of<CustomerScreenProvider>(context, listen: false);

    // 🔹 Prepare Data
    final salesCompletedOrders = transactionProvider.invoiceList
        .map((order) => Transaction.fromMap(order))
        .toList();

    final openOrders = apiService.hivefilteredOrders
        .map((order) => SalesOrderDisplay.fromMap(order))
        .where((order) => order.status == "Open Order")
        .toList();
    setState(() {});
    print("📦 [TransactionPage] Data Summary:");
    print("   🔹 Completed Sales Orders = ${salesCompletedOrders.length}");
    print("   🔹 Open Orders = ${openOrders.length}");

    return DefaultTabController(
      length: 2,
      initialIndex: _selectedIndex,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FA),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          elevation: 0,
          title: const Text(
            'Transactions',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          centerTitle: true,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0D47A1),
                  Color(0xFF1976D2),
                  Color(0xFF42A5F5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
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
                    print("🖱️ [TransactionPage] Tab tapped → Index: $index");
                    setState(() {
                      _selectedIndex = index;
                      _selectedTransactionIndex = null;
                    });
                    print(
                        "✅ [TransactionPage] _selectedIndex updated → $_selectedIndex");
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
          ),
        ),
        body: Column(
          children: [
            // 🔹 Floating Search + Filter Bar
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SmartSearchField(
                      controller: _searchController,
                      onSearch: (query) {
                        print(
                            "🔎 [TransactionPage] Search query submitted → $query");
                        apiService.searchOrders(query);
                      },
                    ),
                  ),
                ],
              ),
            ),

            // 🔹 Transactions Section
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF4F6FA),
                ),
                child: Row(
                  children: _selectedIndex == 0
                      ? _buildSalesCompletedLayout(
                          salesCompletedOrders, apiService)
                      : _buildOpenOrderLayout(
                          openOrders,
                          cartProvider,
                          customerScreenProvider,
                          apiService,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSalesCompletedLayout(
    List<Transaction> orders,
    ApiServiceSalesOrderProvider apiService,
  ) {
    return [
      Expanded(
        flex: 1,
        child: Column(
          children: [
            Expanded(
              child: orders.isEmpty
                  ? const Center(child: Text("No Transactions Available"))
                  : ListView.builder(
                      itemCount: orders.length,
                      itemBuilder: (context, index) {
                        final reversedList = orders.reversed.toList();
                        final item = reversedList[index];
                        return ListTile(
                          title:
                              Text('₹${item.totalAmount.toStringAsFixed(0)}'),
                          subtitle: Text(item.branchName),
                          trailing: Text(item.invoiceTime),
                          selected: _selectedTransactionIndex != null &&
                              index ==
                                  (orders.length -
                                      1 -
                                      _selectedTransactionIndex!),
                          onTap: () {
                            setState(() {
                              _selectedTransactionIndex =
                                  orders.length - 1 - index;
                            });
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      const VerticalDivider(),
      Expanded(
        flex: 2,
        child: orders.isEmpty || _selectedTransactionIndex == null
            ? const Center(child: Text("Select a Transaction"))
            : _buildTransactionDetail(orders[_selectedTransactionIndex!]),
      ),
    ];
  }

  // --------------------------
  // Open Order Layout (3 columns)
  // --------------------------
  List<Widget> _buildOpenOrderLayout(
    List<SalesOrderDisplay> orders,
    CartProvider cartProvider,
    CustomerScreenProvider customerScreenProvider,
    ApiServiceSalesOrderProvider apiService,
  ) {
    return [
      Expanded(
        flex: 1,
        child: _buildOrderList(orders, apiService, _selectedTransactionIndex),
      ),
      const VerticalDivider(),
      Expanded(
        flex: 1,
        child: Consumer<EditCustomerScreenProvider>(
          builder: (context, customerScreenProvider, child) {
            return orders.isNotEmpty && _selectedTransactionIndex != null
                ? EditOutletCustomerDetails(
                    key: ValueKey(
                        '${_selectedTransactionIndex}_${customerScreenProvider.isModifyMode}'),
                    selectedOrder: orders[_selectedTransactionIndex!],
                    isEditing: customerScreenProvider.isModifyMode.value,
                    orderType: 'CurrentOrder',
                    keyboardKey: widget.keyboardKey,
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
          _selectedTransactionIndex,
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
          Icon(Icons.shopping_cart_outlined,
              size: 100, color: const Color.fromARGB(255, 97, 220, 236)),
          SizedBox(height: 20),
          Text("Select an order to view details",
              style: TextStyle(color: Colors.grey, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildOrderDetails(
      List<SalesOrderDisplay> hivefilteredSalesOrders,
      int? selectedIndex,
      ApiServiceSalesOrderProvider apiService,
      CustomerScreenProvider customerScreenProvider,
      CartProvider cartProvider) {
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
          _buildOrderActions(context, salesOrder, customerScreenProvider,
              cartProvider, apiService),
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
          if (salesOrder.discount > 0)
            Text(
              'Discount: ${salesOrder.discountAmount}%',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          if (salesOrder.customCharge > 0)
            Text(
              'Custom Charge: ₹${salesOrder.customCharge.toStringAsFixed(0)}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          Text(
            'Order Amount: ₹${salesOrder.totalAmount.toStringAsFixed(0)}',
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
      ApiServiceSalesOrderProvider apiService) {
    return Column(
      children: [
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomButton(
              text: 'Payment',
              onPressed: () {
                customerScreenProvider.showOutletAdvancePaymentPopup(
                  context,
                  salesOrder,
                  cartProvider,
                );

                customerScreenProvider.clikedThePaymentButton();
              },
              backgroundColor: Colors.blue,
              textColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              fontSize: 16.0,
            )
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
              salesOrder, nonBoxItemIndices[adjustedIndex],
              showAsBoxItem: false);
        },
      ),
    );
  }

  Widget _buildOrderItemTile(SalesOrderDisplay salesOrder, int index,
      {bool showAsBoxItem = false}) {
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
          Text(
            salesOrder.uom[index] != 'Kgs'
                ? '${salesOrder.qty[index]} ${salesOrder.uom[index]} x ${salesOrder.price[index]}'
                : '${salesOrder.weight[index]} ${salesOrder.uom[index]} x ${salesOrder.price[index]}',
            style: TextStyle(fontSize: 10),
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
      SalesOrderDisplay salesOrder, List<int> boxIndices) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 0, horizontal: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.blue.shade300,
          width: 1.5,
        ),
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
                      .map((index) => Padding(
                            padding: EdgeInsets.only(
                                bottom: index == boxIndices.last ? 0 : 8),
                            child: Container(
                              child: _buildOrderItemTile(
                                salesOrder,
                                index,
                                showAsBoxItem: true,
                              ),
                            ),
                          ))
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
            Text('Payment Type',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            Text(salesOrder.paymentType, style: TextStyle(fontSize: 11)),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order ID',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            Text(
              salesOrder.salesOrderId.length > 5
                  ? salesOrder.salesOrderId
                      .substring(salesOrder.salesOrderId.length - 5)
                  : salesOrder.salesOrderId,
              style: TextStyle(fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOrderList(
    List<SalesOrderDisplay> filteredSalesOrders,
    ApiServiceSalesOrderProvider apiService,
    int? selectedIndex,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: SmartSearchField(
            controller: _searchController,
            onSearch: apiService.searchOrders,
          ),
        ),
        Expanded(
          child: filteredSalesOrders.isEmpty
              ? const Center(child: Text("No orders available"))
              : ListView.builder(
                  itemCount: filteredSalesOrders.length,
                  itemBuilder: (context, index) {
                    final order = filteredSalesOrders[index];
                    return Card(
                      color: order.status == "dispatched"
                          ? Colors.red[200]
                          : Colors.white,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo[200],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    order.status.toLowerCase() == 'open order'
                                        ? 'SO'
                                        : (order.orderType ?? ''),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Order ID',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'Order Taken By',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'Status',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ListTile(
                              title: Row(
                                children: [
                                  Expanded(child: Text(order.saleOrderNo)),
                                  Expanded(
                                    child: Text(order.employeeName ?? 'N/A'),
                                  ),
                                  Expanded(child: Text(order.status)),
                                ],
                              ),
                              selected: selectedIndex == index,
                              onTap: () => setState(() {
                                _selectedTransactionIndex = index;
                              }),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTransactionDetail(Transaction transaction) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Payment Type',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(transaction.paymentType,
                      style: const TextStyle(fontSize: 16)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Invoice ID',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('Receipt #${transaction.hiveInvoiceId}',
                      style: const TextStyle(fontSize: 16)),
                ],
              ),
              Column(
                children: [
                  OutlinedButton(
                    onPressed: () {
                      _showSalesReturnDialog(transaction);
                    },
                    child: const Text("Sales Return"),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: Colors.grey[400]),
          Expanded(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: transaction.itemName.length,
              itemBuilder: (context, index) {
                // Check if the unit is in KG or PCS
                final isKg = transaction.uom[index].toLowerCase() == 'kg' ||
                    transaction.uom[index].toLowerCase() == 'kgs';
                final quantity = transaction.qty[index];

                // Format the quantity
                final formattedQuantity = isKg
                    ? quantity
                        .toStringAsFixed(3) // Display KG with 3 decimal places
                    : quantity.toStringAsFixed(0); // Display PCS as an integer

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    transaction.itemName[index],
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  subtitle: Text(
                    '${transaction.varianceName[index]} x $formattedQuantity ${transaction.uom[index]}',
                  ),
                  trailing: Text(
                    '₹${(transaction.price[index] * (double.tryParse(formattedQuantity) ?? 1.0)).toStringAsFixed(2)}', // Safely parse and calculate
                    style: const TextStyle(fontSize: 16),
                  ),
                );
              },
              separatorBuilder: (context, index) => const SizedBox(height: 10),
            ),
          ),
          if ((transaction.discountPercentage) > 0)
            Text('Discount: ${transaction.discountPercentage}%'),
          if ((transaction.customCharge) > 0)
            Text(
                'Custom Charge: ₹${transaction.customCharge.toStringAsFixed(0)}'),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                  'Total Amount: ₹${transaction.totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          if (_confirmedSalesReturns.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Text("Sales Return Details",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Divider(),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _confirmedSalesReturns.length,
                  itemBuilder: (context, index) {
                    final returnData = _confirmedSalesReturns[index];
                    return ListTile(
                      title: Text(
                        returnData["itemName"] ?? '',
                        style: const TextStyle(fontSize: 16),
                      ),
                      subtitle: Text(
                          'Variance: ${returnData["variance"] ?? ''} | Qty: ${returnData["returnQty"]?.toStringAsFixed(2) ?? '0'} ${returnData["uom"] ?? ''}'),
                      trailing: Text(
                        '₹${returnData["returnPrice"]?.toStringAsFixed(2) ?? '0.00'}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    );
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _showSalesReturnDialog(Transaction transaction) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        List<double> returnQuantities =
            List<double>.filled(transaction.qty.length, 0.0);
        // Initialize with `null` for the dropdown's initial value

        List<int?> selectedReturnQty = List<int?>.generate(
          transaction.qty.length,
          (index) =>
              transaction.uom[index].toLowerCase() == "pcs" ? null : null,
        );

        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                final isKg = transaction.uom[index].toLowerCase() == "kg" ||
                    transaction.uom[index].toLowerCase() == "kgs";
                final quantityDisplay = isKg
                    ? '${transaction.qty[index].toStringAsFixed(2)} ${transaction.uom[index]}'
                    : '${transaction.qty[index].toInt()} ${transaction.uom[index]}';

                return Card(
                  margin: EdgeInsets.symmetric(vertical: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                transaction.itemName[index],
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 5),
                              Text(
                                '${transaction.varianceName[index]} | Qty: $quantityDisplay',
                                style: TextStyle(
                                    fontSize: 14, color: Colors.black),
                              ),
                            ],
                          ),
                        ),
                        if (isKg) // For items in "kg", show the weight button
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                padding: EdgeInsets.symmetric(vertical: 8),
                              ),
                              child: Text(
                                "Choose Weight",
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        if (!isKg) // For items in "pcs", show the dropdown

                          Expanded(
                            flex: 2,
                            child: QuantitySelector(
                              initialQuantity: returnQuantities[index].toInt(),
                              maxQuantity: transaction.qty[index]
                                  .toInt(), // Set maximum quantity to the item's quantity
                              onQuantityChanged: (newQuantity) {
                                setState(() {
                                  returnQuantities[index] =
                                      newQuantity.toDouble();
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
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                List<Map<String, dynamic>> returnData = [];
                double totalReturnAmount = 0;

                for (int i = 0; i < transaction.itemName.length; i++) {
                  if (returnQuantities[i] > 0) {
                    final returnPrice =
                        returnQuantities[i] * transaction.price[i];
                    totalReturnAmount += returnPrice;

                    returnData.add({
                      "itemName": transaction.itemName[i],
                      "variance": transaction.varianceName[i],
                      "returnQty": returnQuantities[i],
                      "pricePerUnit": transaction.price[i],
                      "returnPrice": returnPrice,
                      "uom": transaction.uom[i],
                    });
                  }
                }

                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text(
                'Sent to Approve',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  final String formattedDate = DateFormat("dd-MM-yyyy").format(DateTime.now());
  Future<void> postSalesReturn(List<Map<String, dynamic>> returnData) async {
    const url = "http://192.168.0.100:8888/fastapi/salesreturns/";

    // Prepare the payload
    final payload = {
      "salesReturnId": "auto_generated_id", // Replace or generate dynamically
      "itemCode": returnData.map((item) => item["itemCode"] ?? "").toList(),
      "itemName": returnData.map((item) => item["itemName"] ?? "").toList(),
      "price":
          returnData.map((item) => item["pricePerUnit"].toString()).toList(),
      "qty": returnData.map((item) => item["returnQty"].toString()).toList(),
      "amount":
          returnData.map((item) => item["returnPrice"].toString()).toList(),
      "tax": returnData.map((item) => item["tax"]?.toString() ?? "0").toList(),
      "uom": returnData.map((item) => item["uom"] ?? "").toList(),
      "totalAmount": returnData
          .fold<double>(
            0.0,
            (double sum, item) => sum + (item["returnPrice"] as double),
          )
          .toString(),

      "status": "sales return",
      "branch": "$branchName", // Replace with actual branch
      "employeeName": "", // Replace dynamically if needed
      "netPrice": "", // Calculate or provide dynamically
      "invoiceNo": "", // Replace dynamically if needed
      "date": formattedDate,
      "time": TimeOfDay.now().format(context),
      "paymentType": "cash",
      "salesType": "sales return", // Replace dynamically if needed
      "invoiceDate": formattedDate,
      "shiftNumber": "", // Replace dynamically if needed
      "shiftId": "" // Replace dynamically if needed
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to post sales return")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error posting sales return")),
      );
    }
  }
}

class QuantitySelector extends StatefulWidget {
  final int initialQuantity;
  final int maxQuantity;
  final Function(int) onQuantityChanged;

  const QuantitySelector({
    Key? key,
    required this.initialQuantity,
    required this.maxQuantity,
    required this.onQuantityChanged,
  }) : super(key: key);

  @override
  _QuantitySelectorState createState() => _QuantitySelectorState();
}

class _QuantitySelectorState extends State<QuantitySelector> {
  late TextEditingController _controller;
  late int currentQuantity;

  @override
  void initState() {
    super.initState();
    currentQuantity = widget.initialQuantity;
    _controller = TextEditingController(text: currentQuantity.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _increment() {
    if (currentQuantity < widget.maxQuantity) {
      setState(() {
        currentQuantity++;
        _controller.text = currentQuantity.toString();
        widget.onQuantityChanged(currentQuantity);
      });
    }
  }

  void _decrement() {
    if (currentQuantity > 0) {
      setState(() {
        currentQuantity--;
        _controller.text = currentQuantity.toString();
        widget.onQuantityChanged(currentQuantity);
      });
    }
  }

  void _onChanged(String value) {
    int? newQuantity = int.tryParse(value);
    if (newQuantity == null || newQuantity < 0) {
      newQuantity = 0; // Ensure non-negative input
    } else if (newQuantity > widget.maxQuantity) {
      newQuantity =
          widget.maxQuantity; // Ensure quantity does not exceed maximum
    }

    setState(() {
      currentQuantity = newQuantity!;
      _controller.text = currentQuantity
          .toString(); // Update the text field with corrected value
      widget.onQuantityChanged(currentQuantity);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: _decrement,
        ),
        Expanded(
          child: TextField(
            textAlign: TextAlign.center,
            controller: _controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(vertical: 8.0),
            ),
            onChanged: _onChanged,
            onTap: () {
              _controller.selection = TextSelection(
                  baseOffset: 0, extentOffset: _controller.text.length);
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: _increment,
        ),
      ],
    );
  }
}
