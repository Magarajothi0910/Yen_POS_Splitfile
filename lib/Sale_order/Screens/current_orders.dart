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
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final apiService = context.read<ApiServiceSalesOrderProvider>();
      final customerScreenProvider = context.read<EditCustomerScreenProvider>();
      // customerScreenProvider.resetSelection();
      if (customerScreenProvider.selectedTransactionIndex != null &&
          customerScreenProvider.selectedTransactionIndex! >=
              apiService.filteredAllSalesOrders.length) {
        customerScreenProvider.resetSelection();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EditCustomerScreenProvider>(
      builder: (context, customerScreenProvider, child) {
        final apiService = context.watch<ApiServiceSalesOrderProvider>();
        final filteredSalesOrders = apiService.hivefilteredOrders
            .map((order) => SalesOrderDisplay.fromMap(order))
            .where(
              (order) => order.status != "Open Order",
            ) // <-- Exclude Open Order
            .toList();

        // Use WidgetsBinding inside Consumer to delay action after build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (customerScreenProvider.selectedTransactionIndex != null &&
              customerScreenProvider.selectedTransactionIndex! >=
                  filteredSalesOrders.length) {
            customerScreenProvider.resetSelection();
          }
        });

        return Scaffold(
          backgroundColor: Colors.white,
          key: ValueKey("allorders_${customerScreenProvider.isModifyMode}"),
          appBar: _buildAppBar(context, apiService, filteredSalesOrders),
          body: Row(
            children: [
              Expanded(
                flex: 1,
                child: _buildOrderList(
                  filteredSalesOrders,
                  apiService,
                  _selectedTransactionIndex,
                ),
              ),
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
                            isEditing:
                                customerScreenProvider.isModifyMode.value,
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
      },
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

          /// Previous Date Button
          IconButton(
            onPressed: () {
              apiService.changeDate(const Duration(days: -1));
            },
            icon: const Icon(Icons.arrow_back_ios, color: Colors.blue),
          ),

          /// Selected Date
          Text(
            DateFormat('dd-MM-yy').format(apiService.selectedDate!),
            style: const TextStyle(fontSize: 11),
          ),

          /// Next Date Button
          IconButton(
            onPressed: () {
              apiService.changeDate(const Duration(days: 1));
            },
            icon: const Icon(Icons.arrow_forward_ios, color: Colors.blue),
          ),

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
            onSearch: apiService.searchHiveFilteredOrders,
          ),
        ),
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
                    final bool isSelected = _selectedTransactionIndex == index;

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // --- Main Card ---
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
                            onTap: () => setState(() {
                              _selectedTransactionIndex = index;
                            }),
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
                                              // Keep only letters and spaces
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
                        Positioned(
                          top:
                              0, // Adjust for desired corner (top, bottom, left, right)
                          right: 0,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(
                                  8,
                                ), // Rounded corner for the tag
                              ),
                            ),
                            child: Text(
                              (order.orderType ?? 'ORDER').toUpperCase(),
                              style: TextStyle(
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
    // Flatten the nested list, remove duplicates, and join as comma-separated string
    String paymentTypes = '';
    if (salesOrder.advancePaymentType != null) {
      final flattened = salesOrder.advancePaymentType!
          .expand((innerList) => innerList)
          .toList();

      // Remove duplicates while keeping the order
      final uniqueList = <String>{};
      final filteredList = flattened
          .where((item) => uniqueList.add(item))
          .toList();

      paymentTypes = filteredList.join(', ');
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
            Text(
              paymentTypes.isNotEmpty ? paymentTypes : '-',
              style: TextStyle(fontSize: 11),
            ),
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
            Text(salesOrder.saleOrderNo, style: TextStyle(fontSize: 11)),
          ],
        ),
      ],
    );
  }

  Widget _buildOrderItemsList(SalesOrderDisplay salesOrder) {
    List<int> boxItemIndices = [];
    List<int> nonBoxItemIndices = [];

    final itemCount = salesOrder.varianceName?.length ?? 0;

    for (int i = 0; i < itemCount; i++) {
      final isBox =
          (salesOrder.isBoxItem != null && salesOrder.isBoxItem!.length > i)
          ? salesOrder.isBoxItem![i].toLowerCase() == 'yes'
          : false;

      if (isBox) {
        boxItemIndices.add(i);
      } else {
        nonBoxItemIndices.add(i);
      }
    }

    if (itemCount == 0) return SizedBox();

    return Expanded(
      child: ListView.separated(
        itemCount: boxItemIndices.isNotEmpty
            ? 1 + nonBoxItemIndices.length
            : nonBoxItemIndices.length,
        separatorBuilder: (_, __) => SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (boxItemIndices.isNotEmpty && index == 0) {
            return _buildBoxItemsCard(salesOrder, boxItemIndices);
          }

          final adjustedIndex = index - (boxItemIndices.isNotEmpty ? 1 : 0);
          if (adjustedIndex >= nonBoxItemIndices.length) return SizedBox();

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
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade300, width: 1.5),
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2, size: 18, color: Colors.blue.shade700),
                SizedBox(width: 8),
                Text(
                  '${salesOrder.boxQty ?? 0} ×',
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
            SizedBox(height: 10),
            Column(
              children: boxIndices
                  .map(
                    (i) => Padding(
                      padding: EdgeInsets.only(
                        bottom: i == boxIndices.last ? 0 : 8,
                      ),
                      child: _buildOrderItemTile(
                        salesOrder,
                        i,
                        showAsBoxItem: true,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItemTile(
    SalesOrderDisplay salesOrder,
    int index, {
    bool showAsBoxItem = false,
  }) {
    final varianceName = (salesOrder.varianceName.length > index)
        ? salesOrder.varianceName[index]
        : 'Unknown';
    final uom = (salesOrder.uom.length > index) ? salesOrder.uom[index] : '';
    final qty = (salesOrder.qty.length > index)
        ? salesOrder.qty[index].toDouble()
        : 0.0;
    final weight =
        (salesOrder.weight != null && salesOrder.weight!.length > index)
        ? salesOrder.weight![index] ?? 0.0
        : 0.0;
    final price = (salesOrder.price.length > index)
        ? salesOrder.price[index]
        : 0.0;
    final amount = (salesOrder.amount.length > index)
        ? salesOrder.amount[index]
        : 0.0;

    String priceDescription;
    if (uom.toLowerCase() == 'kg' || uom.toLowerCase() == 'kgs') {
      if (weight >= 1) {
        priceDescription =
            '$qty $uom (${weight.toStringAsFixed(2)} kg) × Rs.${price.toStringAsFixed(0)}/kg';
      } else {
        priceDescription =
            '$qty × ${(weight * 1000).toStringAsFixed(0)} g × Rs.${price.toStringAsFixed(0)}/kg';
      }
    } else {
      priceDescription = '$qty $uom × Rs.${price.toStringAsFixed(0)}';
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        varianceName,
        style: TextStyle(
          fontSize: 12,
          color: showAsBoxItem ? Colors.blue.shade800 : Colors.grey.shade800,
        ),
      ),
      subtitle: Text(priceDescription, style: const TextStyle(fontSize: 10)),
      trailing: Text(
        '₹${amount.toStringAsFixed(2)}',
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

    // Ensure both lists exist
    final advanceAmounts = salesOrder.advanceAmount ?? [];
    final advanceDates = salesOrder.advanceDateTime ?? [];

    // Take the shorter list length to avoid RangeError
    final int minLength = advanceAmounts.length < advanceDates.length
        ? advanceAmounts.length
        : advanceDates.length;

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
                color: Colors.orange,
              ),
            ),
          if (salesOrder.customCharge > 0)
            // Total Amount 2
            Text(
              'Total Amount: ₹${salesOrder.totalAmount2?.toStringAsFixed(0) ?? '0'}',
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
          if (salesOrder.discount > 0)
            // Order Amount
            Text(
              'Order Amount: ₹${salesOrder.finalPrice.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),

          // Advance Amount with Date & Time
          Column(
            children: List.generate(minLength, (index) {
              DateTime? dt;
              final dateStr = advanceDates[index];

              try {
                dt = DateTime.tryParse(dateStr);
              } catch (e) {
                dt = null;
              }

              final formattedDate = dt != null
                  ? dateFormatter.format(dt)
                  : dateStr;
              final formattedTime = dt != null ? timeFormatter.format(dt) : '';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Date & Time
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Paid on : $formattedDate - $formattedTime',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),

                    // Advance Amount
                    Text(
                      'Advance: ₹${advanceAmounts[index].toStringAsFixed(0)}',
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

          // Balance Amount
          Text(
            'Balance Amount: ₹${salesOrder.finalPrice.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
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
    // Normalize status: trim and lowercase
    final status = salesOrder.status?.trim().toLowerCase() ?? '';

    // Only show the button if status is "dispatched"
    if (status != 'dispatched') {
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
