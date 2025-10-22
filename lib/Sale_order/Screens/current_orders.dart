import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Global/Widget/smartsearchtextfield.dart';

import 'package:yenpos/Sale_order/Models/sales_order_display_model.dart';
import 'package:yenpos/Sale_order/Print_Receipt/currentOrderPrint.dart';
import 'package:yenpos/Sale_order/Provider/editcustomerscreenProvider.dart';
import 'package:yenpos/Sale_order/Provider/get_sales_order_service.dart';
import 'package:yenpos/Sale_order/Screens/create_sales_order.dart';
import 'package:yenpos/Sale_order/Screens/editcustomerdetails.dart';

import '../../Global/Widget/custom_button_reuse.dart';
import '../../Global/Widget/custom_colors.dart';
import '../../Global/Widget/custom_sized_box.dart';
import '../../Global/Widget/todat_orders_print.dart';

class CurrentOrdersPage extends StatefulWidget {
  const CurrentOrdersPage({super.key});

  @override
  _CurrentOrdersPageState createState() => _CurrentOrdersPageState();
}

class _CurrentOrdersPageState extends State<CurrentOrdersPage> {
  int? _selectedTransactionIndex;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  DateTime? _ToDate;

  @override
  void dispose() {
    // _searchController.dispose();
    // _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final apiService = context.watch<ApiServiceSalesOrderProvider>();
    apiService.filterOrdersByDate(apiService.selectedDate!);
    // Print the raw hivefilteredOrders
    debugPrint(
      "🔹 hivefilteredOrders length => ${apiService.hivefilteredOrders.length} (Type: ${apiService.hivefilteredOrders.runtimeType})",
    );

    // Convert to SalesOrderDisplay
    final mappedOrders = apiService.hivefilteredOrders.map((order) {
    
      final mapped = SalesOrderDisplay.fromMap(order);
      debugPrint(
        "✅ Mapped SalesOrderDisplay => ${mapped.toJson()} (Type: ${mapped.runtimeType})",
      );
      return mapped;
    }).toList();

    // Filter out "Open Order"
    final filteredSalesOrders = mappedOrders.where((order) {
      debugPrint(
        "🔎 Checking orderNo: ${order.saleOrderNo}, Status: ${order.status} (Type: ${order.status.runtimeType})",
      );
      return order.status != "Open Order";
    }).toList();

    // Final debug print
    debugPrint(
      "🎯 Final filteredSalesOrders length => ${filteredSalesOrders.length} (Type: ${filteredSalesOrders.runtimeType})",
    );
    for (var order in filteredSalesOrders) {
      debugPrint(
        "📦 Filtered Order => ${order.toJson()} (Type: ${order.runtimeType})",
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(
        context,
        apiService,
        filteredSalesOrders.cast<SalesOrderDisplay>(),
      ),
      body: Row(
        children: [
          Expanded(
            flex: 1,
            child: _buildOrderList(
              filteredSalesOrders.cast<SalesOrderDisplay>(),
              apiService,
              _selectedTransactionIndex,
            ),
          ),
          // const VerticalDivider(),
          // Expanded(flex: 1, child: EditCustomerDetails()),
          const VerticalDivider(),
          Expanded(
            flex: 1,
            child: Consumer<EditCustomerScreenProvider>(
              builder: (context, customerScreenProvider, child) {
                return filteredSalesOrders.isNotEmpty &&
                        _selectedTransactionIndex != null
                    ? EditCustomerDetails(
                        key: ValueKey(
                          '${_selectedTransactionIndex}_${customerScreenProvider.isModifyMode}',
                        ),
                        selectedOrder:
                            filteredSalesOrders[_selectedTransactionIndex!],
                        isEditing: customerScreenProvider.isModifyMode.value,
                        orderType: 'CurrentOrder',
                      )
                    : _buildEmptyOrderState();
              },
            ),
          ),
          const VerticalDivider(),
          Expanded(
            flex: 1,
            child: _buildOrderDetails(
              filteredSalesOrders,
              _selectedTransactionIndex,
              apiService,
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(
    BuildContext context,
    ApiServiceSalesOrderProvider apiService,
    List<SalesOrderDisplay> hivefilteredSalesOrders,
  ) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.white,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text("${hivefilteredSalesOrders.length} "),
          const Text('Current Orders', style: TextStyle(color: Colors.black)),
          const SizedBox(width: 10),

          /// Previous Date Button
          IconButton(
            onPressed: () {
              apiService.changeDate(const Duration(days: -1));
            },
            icon: const Icon(Icons.arrow_back_ios, color: Colors.blue),
            tooltip: "Previous Date",
          ),
          const SizedBox(width: 10),

          /// Selected Date
          Text(
            DateFormat('dd-MM-yy').format(apiService.selectedDate!),
            style: const TextStyle(fontSize: 11),
          ),
          const SizedBox(width: 10),

          /// Next Date Button
          IconButton(
            onPressed: () {
              apiService.changeDate(const Duration(days: 1));
            },
            icon: const Icon(Icons.arrow_forward_ios, color: Colors.blue),
            tooltip: "Next Date",
          ),
          const SizedBox(width: 4),

          /// Print Button
          ElevatedButton(
            onPressed: () async {
              PrintUtility.printReceiptDetails(
                context,
                hivefilteredSalesOrders,
              );
            },
            child: const Text('Print'),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue,
              elevation: 2,
            ),
          ),
        ],
      ),
      centerTitle: false,

      /// Middle Button Section
      flexibleSpace: Align(
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue,
                elevation: 2,
              ),
              child: const Text('Current Order'),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushNamed('/all-orders');
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                elevation: 2,
              ),
              child: const Text('All Orders'),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => SalesOrderScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                elevation: 2,
              ),
              child: const Text('Create Order'),
            ),
          ],
        ),
      ),
      toolbarHeight: kToolbarHeight,
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
                                    order.orderType ?? '',
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
  // Helper Functions

  Widget _buildOrderDetails(
    List<SalesOrderDisplay> hivefilteredSalesOrders,
    int? selectedIndex,
    ApiServiceSalesOrderProvider apiService,
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
          _buildOrderActions(context, salesOrder),
        ],
      ),
    );
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

  Widget _buildOrderHeader(SalesOrderDisplay salesOrder) {
    // Flatten the nested list and join as comma-separated string
    String paymentTypes = '';
    if (salesOrder.advancePaymentType != null) {
      paymentTypes = salesOrder.advancePaymentType!
          .expand(
            (innerList) => innerList,
          ) // flatten List<List<String>> → List<String>
          .join(', ');
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Payment Type Column
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Type',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            Text(paymentTypes, style: TextStyle(fontSize: 11)),
          ],
        ),
        // Order Number Column
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order No',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            Text(
              salesOrder.saleOrderNo, // show full sale order number
              style: TextStyle(fontSize: 11),
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

  Widget _buildOrderItemTile(
    SalesOrderDisplay salesOrder,
    int index, {
    bool showAsBoxItem = false,
  }) {
    final uom = salesOrder.uom[index];
    final quantity = salesOrder.qty[index].toDouble();
    final weight = salesOrder.weight[index].toDouble();
    final pricePerKg = salesOrder.price[index];

    String priceDescription = '';

    if (uom.toLowerCase() == 'kg' || uom.toLowerCase() == 'kgs') {
      if (weight >= 1) {
        priceDescription =
            '$quantity $uom (${weight.toStringAsFixed(2)} kg) × Rs.${pricePerKg.toStringAsFixed(0)}/kg';
      } else {
        // Convert to grams if < 1 kg
        priceDescription =
            '$quantity × (${(weight * 1000).toStringAsFixed(0)} g) × Rs.${pricePerKg.toStringAsFixed(0)}/kg';
      }
    } else {
      // Pcs / Pkt / Others
      priceDescription =
          '${quantity.toStringAsFixed(0)} $uom × Rs.${pricePerKg.toStringAsFixed(0)}';
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        salesOrder.varianceName[index],
        style: TextStyle(
          fontSize: 12,
          color: showAsBoxItem ? Colors.blue.shade800 : Colors.grey.shade800,
        ),
      ),
      subtitle: Text(priceDescription, style: const TextStyle(fontSize: 10)),
      trailing: Text(
        '₹${salesOrder.amount[index].toStringAsFixed(2)}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: showAsBoxItem ? Colors.blue.shade800 : Colors.black,
        ),
      ),
    );
  }

  Widget _buildOrderSummary(SalesOrderDisplay salesOrder) {
    final dateFormatter = DateFormat('dd-MM-yyyy');
    final timeFormatter = DateFormat('hh:mm a'); // 12-hour format

    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Total Amount
          Text(
            'Total: ₹${salesOrder.totalAmount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          // Custom Charge
          if (salesOrder.customCharge > 0)
            Text(
              'Custom Charge: ₹${salesOrder.customCharge.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.orange, // yellowish/orange for custom charge
              ),
            ),
          // Total Amount 2
          Text(
            'Total Amount: ₹${salesOrder.totalAmount2!.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          // Discount
          if (salesOrder.discount > 0)
            Text(
              'Discount: ${salesOrder.discount}%(-): ₹${salesOrder.discountAmount.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          // Order Amount
          Text(
            'Order Amount: ₹${salesOrder.finalPrice}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          // Advance Amount with Date & Time
          if ((salesOrder.advanceAmount ?? []).isNotEmpty &&
              (salesOrder.advanceDateTime ?? []).isNotEmpty)
            Column(
              children: List.generate(salesOrder.advanceAmount!.length, (
                index,
              ) {
                DateTime? dt;
                final dateStr = salesOrder.advanceDateTime![index];

                // Safely parse string to DateTime
                try {
                  dt = DateTime.parse(dateStr);
                } catch (e) {
                  dt = null;
                }

                final formattedDate = dt != null
                    ? dateFormatter.format(dt)
                    : dateStr;
                final formattedTime = dt != null
                    ? timeFormatter.format(dt)
                    : '';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Date & Time Column
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Paid on : $formattedDate - $formattedTime',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green, // advance in green
                            ),
                          ),
                        ],
                      ),
                      // Advance Amount on the right
                      Text(
                        'Advance: ₹${salesOrder.advanceAmount![index].toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          // Balance Amount at the end
          Text(
            'Balance Amount: ₹${salesOrder.balanceAmount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.blue, // balance in blue
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderActions(
    BuildContext context,
    SalesOrderDisplay salesOrder,
  ) {
    // Only show the button if order is not completed
    if (salesOrder.status == "Sales Completed") {
      return SizedBox.shrink(); // Empty widget, button won't be shown
    }

    return Column(
      children: [
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomButton(
              text: 'Pay ₹ ${salesOrder.balanceAmount}',
              onPressed: () => _showPaymentDialog(context, salesOrder),
              backgroundColor: CustomColors.primaryColor,
              textColor: CustomColors.whiteColor,
              padding: EdgeInsets.symmetric(horizontal: 100, vertical: 22),
            ),
          ],
        ),
      ],
    );
  }

  void _showPaymentDialog(BuildContext context, SalesOrderDisplay salesOrder) {
    double totalAmount = salesOrder.balanceAmount;

    if (totalAmount != 0) {
      showDialog(
        barrierDismissible: false,
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.white,
            child: CustomSizedBox(
              width: MediaQuery.of(context).size.width * 0.5,
              child: OrderManagementPayandPrint(
                totalAmount: totalAmount,
                holdBillId: '',
                orderId: salesOrder.saleOrderNo,
                employee: salesOrder.employeeName,
                discount: salesOrder.discount,
                customerNumber: salesOrder.customerNumber,
                salesOrder: salesOrder,
              ),
            ),
          );
        },
      );
    }
  }
}
