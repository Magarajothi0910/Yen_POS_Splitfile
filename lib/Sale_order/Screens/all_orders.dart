import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:yenposapp/Global/Widget/custom_colors.dart';
import 'package:yenposapp/Global/Widget/custom_sized_box.dart';
import 'package:yenposapp/Global/Widget/smartsearchtextfield.dart';
import 'package:yenposapp/Global/globals_data.dart';
import 'package:yenposapp/Mode_page/Regular_mode/Provider/regular_mode_screen_provider.dart';
import 'package:yenposapp/Sale_order/Models/sales_order_display_model.dart';
import 'package:yenposapp/Sale_order/Print_Receipt/currentOrderPrint.dart';
import 'package:yenposapp/Sale_order/Provider/cartProvider.dart';
import 'package:yenposapp/Sale_order/Provider/editcustomerscreenProvider.dart';
import 'package:yenposapp/Sale_order/Provider/get_sales_order_service.dart';
import 'package:yenposapp/Sale_order/Screens/create_sales_order.dart';
import 'package:yenposapp/Sale_order/Screens/editcustomerdetails.dart';
import 'package:yenposapp/Sale_order/Widgets/add_advance_dialogue.dart';
import 'package:yenposapp/Sale_order/Widgets/advance-dialog.dart';

import '../../Global/Widget/custom_button_reuse.dart';

class AllOrdersPage extends StatefulWidget {
  final GlobalKey keyboardKey;
  const AllOrdersPage({super.key, required this.keyboardKey});

  @override
  _AllOrdersPageState createState() => _AllOrdersPageState();
}

class _AllOrdersPageState extends State<AllOrdersPage> {
  final TextEditingController _searchController = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController();
  Timer? _debounce;
  final bool _isAddingOrder = false;
  final Map<String, dynamic> mixbox = {};

  File? _pickedImage1;
  File? _pickedImage2;

  String _selectedFilter = "All Order";

  // The available filter options.
  final List<String> _filterOptions = [
    "All Order",
    "Pending",
    "Approved",
    "Cancel",
    "Rejected",
    'Confirm'
  ];

  // Map<int, double> quantityChanges = {};
  @override
  void initState() {
    super.initState();

    quantityChangesNotifier = ValueNotifier<Map<int, double>>({});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final apiService = context.read<ApiServiceSalesOrderProvider>();
      final customerScreenProvider = context.read<EditCustomerScreenProvider>();
      // customerScreenProvider.resetSelection();
      apiService.fetchFilteredOrders(
        startDate: apiService.startDate,
        endDate: apiService.endDate,
      );
      if (customerScreenProvider.selectedTransactionIndex != null &&
          customerScreenProvider.selectedTransactionIndex! >=
              apiService.filteredAllSalesOrders.length) {
        customerScreenProvider.resetSelection();
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EditCustomerScreenProvider>(
      builder: (context, customerScreenProvider, child) {
        final apiService = context.watch<ApiServiceSalesOrderProvider>();
        final filteredSalesOrders = apiService.hivefilteredAllOrders
            .map((order) => SalesOrderDisplay.fromMap(order))
            .where((order) =>
                order.status != "Open Order") // <-- Exclude Open Order
            .toList();
        final cartProvider = Provider.of<CartProvider>(context);

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
          appBar: _buildAppBar(context, apiService),
          body: Row(
            children: [
              Expanded(
                flex: 1,
                child: _buildOrderList(
                  filteredSalesOrders,
                  apiService,
                  customerScreenProvider,
                  customerScreenProvider.selectedTransactionIndex,
                ),
              ),
              const VerticalDivider(),
              Expanded(
                flex: 1,
                child: ValueListenableBuilder<bool>(
                  valueListenable: customerScreenProvider.isModifyMode,
                  builder: (context, isModifyMode, child) {
                    return filteredSalesOrders.isNotEmpty &&
                            customerScreenProvider.selectedTransactionIndex !=
                                null
                        ? EditCustomerDetails(
                            key: ValueKey(
                              '${customerScreenProvider.selectedTransactionIndex}_${isModifyMode}',
                            ),
                            selectedOrder: customerScreenProvider
                                            .selectedTransactionIndex !=
                                        null &&
                                    customerScreenProvider
                                            .selectedTransactionIndex! <
                                        filteredSalesOrders.length
                                ? filteredSalesOrders[customerScreenProvider
                                    .selectedTransactionIndex!]
                                : null,
                            isEditing:
                                isModifyMode, // Pass isModifyMode to EditCustomerDetails
                            orderType: 'AllOrder',
                            keyboardKey: widget.keyboardKey,
                          )
                        : _buildEmptyOrderState();
                  },
                ),
              ),
              const VerticalDivider(),
              Expanded(
                child: _buildOrderDetails(
                  filteredSalesOrders,
                  customerScreenProvider.selectedTransactionIndex,
                  apiService,
                  cartProvider,
                  customerScreenProvider,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrderDetails(
    List<SalesOrderDisplay> filteredSalesOrders,
    int? selectedIndex,
    ApiServiceSalesOrderProvider apiService,
    CartProvider cartProvider,
    EditCustomerScreenProvider customerScreenProvider,
  ) {
    if (selectedIndex == null || filteredSalesOrders.isEmpty) {
      return _buildEmptyOrderState();
    }

    final salesOrder = filteredSalesOrders[selectedIndex];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (salesOrder.status == 'Confirm Order')
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: customerScreenProvider.isModifyMode,
                      builder: (context, isModifyMode, child) {
                        return Row(
                          children: [
                            if (!isModifyMode)
                              ElevatedButton(
                                onPressed: () async {
                                  double totalAdvanceAmount = salesOrder
                                      .advanceAmount!
                                      .fold(0.0, (sum, value) => sum + value);

                                  final result = await AdvanceAmountDialog.show(
                                    context,
                                    salesOrderId: salesOrder.salesOrderId,
                                    advanceAmount: totalAdvanceAmount,
                                    saleOrderNo: salesOrder.saleOrderNo,
                                    keyboardKey: widget.keyboardKey,
                                  );
                                  if (result != null) {}
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 6),
                                ),
                                child: Text(
                                  'Cancel Order',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 10),
                                ),
                              ),
                            if (!isModifyMode) SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                customerScreenProvider.isModifyMode.value =
                                    !isModifyMode;
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    isModifyMode ? Colors.green : Colors.blue,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                              ),
                              child: Text(
                                isModifyMode ? 'Cancel' : 'Modify Order',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 10),
                              ),
                            ),
                            if (isModifyMode) SizedBox(width: 8),
                            if (isModifyMode)
                              ElevatedButton(
                                onPressed: () => _showAddItemDialog(
                                  context,
                                  customerScreenProvider,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 6),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.add,
                                        color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'Add Item',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
                SizedBox(height: 16),
              ],
            ),
          SizedBox(height: 16),
          _buildOrderHeader(salesOrder),
          Divider(color: Colors.grey[400]),
          ValueListenableBuilder<bool>(
            valueListenable: customerScreenProvider.isModifyMode,
            builder: (context, isModifyMode, child) {
              return _buildOrderItemsList(salesOrder, customerScreenProvider);
            },
          ),
          _buildOrderSummary(salesOrder, customerScreenProvider),
          ValueListenableBuilder<bool>(
            valueListenable: customerScreenProvider.isModifyMode,
            builder: (context, isModifyMode, child) {
              return _buildOrderActions(
                context,
                salesOrder,
                apiService,
                cartProvider,
                customerScreenProvider,
              );
            },
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(
    BuildContext context,
    ApiServiceSalesOrderProvider apiProvider,
  ) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.white,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.start, // Align title to the left
        children: [
          Text(
            'All Orders',
            style: TextStyle(color: Colors.black), // Customize text style
          ),
        ],
      ),
      centerTitle: false, // Ensures the title stays on the left
      actions: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: FutureBuilder<List<ConnectivityResult>>(
            future: Connectivity().checkConnectivity(),
            builder: (context, snapshot) {
              String status = "Checking...";
              Color statusColor = Colors.orange;
              IconData statusIcon = Icons.signal_wifi_off;

              if (snapshot.connectionState == ConnectionState.done) {
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  ConnectivityResult connectivity = snapshot.data!.first;
                  switch (connectivity) {
                    case ConnectivityResult.wifi:
                    case ConnectivityResult.mobile:
                      status = "Online";
                      statusColor = Colors.green;
                      statusIcon = Icons.signal_wifi_4_bar;
                      break;
                    case ConnectivityResult.none:
                      status = "Offline";
                      statusColor = Colors.red;
                      statusIcon = Icons.signal_wifi_off;
                      break;
                    default:
                      status = "Network Slow";
                      statusColor = Colors.orange;
                      statusIcon = Icons.signal_wifi_bad;
                  }
                }
              }

              return Row(
                children: [
                  Icon(statusIcon, color: statusColor),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
      flexibleSpace: Align(
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.only(), // Adjust spacing
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center, // Center the buttons
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/current-orders');
                },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0), // Small curve
                  ),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  elevation: 2,
                ),
                child: Text('Current Order'),
              ),
              SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  // Handle "All Orders" action if needed

                  apiProvider.fetchAllOrders();
                },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0), // Small curve
                  ),
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue,
                  elevation: 2,
                ),
                child: Text('All Orders'),
              ),
              SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => SalesOrderScreen(
                              keyboardKey: widget.keyboardKey,
                            )),
                  );
                },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0), // Small curve
                  ),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  elevation: 2,
                ),
                child: Text('Create Order'),
              ),
            ],
          ),
        ),
      ),
      toolbarHeight: kToolbarHeight * 1, // Increase height for buttons layout
    );
  }

  Widget _buildOrderList(
    List<SalesOrderDisplay> filteredSalesOrders,
    ApiServiceSalesOrderProvider apiService,
    EditCustomerScreenProvider customerprovider,
    int? selectedIndex,
  ) {
    final String todayDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
    final ordersByDate = groupBy(
      filteredSalesOrders.where((order) =>
          (apiService.groupByDeliveryDate
              ? order.deliveryDate
              : order.orderDate) !=
          null),
      (SalesOrderDisplay order) => apiService.groupByDeliveryDate
          ? order.deliveryDate!
          : order.orderDate!,
    );

    // Sort the dates with proper null handling
    final sortedDates = ordersByDate.keys.toList()
      ..sort((a, b) {
        try {
          final dateA = DateFormat('dd-MM-yyyy').parse(a);
          final dateB = DateFormat('dd-MM-yyyy').parse(b);
          return dateA.compareTo(dateB);
        } catch (e) {
          return 0; // default to equal if parsing fails
        }
      });
    String? lastDisplayedDate;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SmartSearchField(
                controller: _searchController,
                onSearch: apiService.searchOrders,
              ),
              const SizedBox(height: 10),
              // Date Range Picker
              Row(
                children: [
                  Flexible(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        final selectedDate = await showDatePicker(
                          context: context,
                          initialDate: apiService.startDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (selectedDate != null) {
                          apiService.setStartDate(selectedDate);

                          // Reset end date if it's before start date
                          if (apiService.endDate != null &&
                              apiService.endDate!.isBefore(selectedDate)) {
                            apiService.setEndDate(selectedDate);
                          }

                          // Fetch filtered orders after setting startDate
                          apiService.fetchFilteredOrders(
                            startDate: apiService.startDate,
                            endDate: apiService.endDate,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        elevation: 2,
                      ),
                      child: Text(
                        apiService.startDate != null
                            ? DateFormat('dd-MM-yyyy')
                                .format(apiService.startDate!)
                            : 'Start Date',
                        style:
                            const TextStyle(fontSize: 10, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

// --- End Date Button ---
                  Flexible(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        final selectedDate = await showDatePicker(
                          context: context,
                          initialDate: apiService.endDate ??
                              apiService.startDate ??
                              DateTime.now(),
                          firstDate: apiService.startDate ?? DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (selectedDate != null) {
                          apiService.setEndDate(selectedDate);

                          // Fetch filtered orders after setting endDate
                          apiService.fetchFilteredOrders(
                            startDate: apiService.startDate,
                            endDate: apiService.endDate,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        elevation: 2,
                      ),
                      child: Text(
                        apiService.endDate != null
                            ? DateFormat('dd-MM-yyyy')
                                .format(apiService.endDate!)
                            : 'End Date',
                        style:
                            const TextStyle(fontSize: 10, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      dropdownColor: Colors.white,
                      value: _selectedFilter,
                      decoration: InputDecoration(
                        labelText: 'Filter Orders',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      items: _filterOptions.map((String filter) {
                        return DropdownMenuItem<String>(
                          value: filter,
                          child: Text(filter, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (String? newFilter) {
                        if (newFilter != null) {
                          setState(() {
                            _selectedFilter = newFilter;
                          });
                          apiService.filterOrdersByStatus(newFilter);
                        }
                      },
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${apiService.groupByDeliveryDate ? 'Orders by deliverydate' : 'Orders by OrderDate'}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            IconButton(
              icon: Icon(
                apiService.groupByDeliveryDate
                    ? Icons.arrow_downward // Sorting by Delivery Date
                    : Icons.arrow_upward, // Sorting by Order Date
                color: Colors.blue,
              ),
              onPressed: () {
                apiService.toggleGrouping();
              },
              tooltip: apiService.groupByDeliveryDate
                  ? 'Sorting by Delivery Date'
                  : 'Sorting by Order Date',
            ),
          ],
        ),
        Expanded(
          child: apiService.isLoading
              ? const Center(child: CircularProgressIndicator())
              : filteredSalesOrders.isEmpty
                  ? const Center(child: Text("No orders available"))
                  : ListView.builder(
                      itemCount: sortedDates.length,
                      itemBuilder: (context, index) {
                        final date = sortedDates[index];
                        final orders = ordersByDate[date]!;
                        final displayDate = date == todayDate ? "Today" : date;
                        final showDateHeader = lastDisplayedDate != date;

                        if (showDateHeader) {
                          lastDisplayedDate = date;
                        }
                        final currentDate = DateTime.now();
                        final parsedDate = DateFormat('dd-MM-yyyy').parse(date);
                        final isPastDate = parsedDate.isBefore(
                          currentDate.subtract(Duration(days: 1)),
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showDateHeader)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                child: Text(
                                  displayDate,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isPastDate ? Colors.red : Colors.black,
                                  ),
                                ),
                              ),
                            ...orders.map((order) {
                              final orderIndex = filteredSalesOrders.indexOf(
                                order,
                              );
                              return Card(
                                color: order.status == "dispatched"
                                    ? Colors.red[200]
                                    : Colors.white,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.indigo[200],
                                              borderRadius:
                                                  BorderRadius.circular(
                                                4,
                                              ),
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
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
                                            Expanded(
                                              child: Text(order.saleOrderNo),
                                            ),
                                            Expanded(
                                              child: Text(
                                                order.employeeName ?? 'N/A',
                                              ),
                                            ),
                                            Expanded(child: Text(order.status)),
                                          ],
                                        ),
                                        selected: selectedIndex == orderIndex,
                                        onTap: () => setState(() {
                                          customerprovider
                                              .handleTransactionSelection(
                                            orderIndex,
                                          );
                                        }),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        );
                      },
                    ),
        ),
      ],
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

  Widget _buildOrderItemTile(
    SalesOrderDisplay salesOrder,
    int index,
    EditCustomerScreenProvider customerProvider,
  ) {
    final isKg = salesOrder.uom[index].toLowerCase() == 'kg' ||
        salesOrder.uom[index].toLowerCase() == 'kgs';

    final currentQty = isKg
        ? (salesOrder.weight[index] is int
            ? (salesOrder.weight[index] as int).toDouble()
            : salesOrder.weight[index] ?? 0.0)
        : (salesOrder.qty[index] is int
            ? (salesOrder.qty[index] as int).toDouble()
            : salesOrder.qty[index] ?? 0.0);

    final isBoxItem = salesOrder.isBoxItem != null &&
        salesOrder.isBoxItem!.length > index &&
        salesOrder.isBoxItem![index].toLowerCase() == "yes";

    Map<String, dynamic> _createItemMap() {
      return {
        'varianceName': salesOrder.varianceName[index],
        'itemName':
            salesOrder.itemName != null && salesOrder.itemName!.length > index
                ? salesOrder.itemName![index]
                : salesOrder.varianceName[index],
        'varianceUom': salesOrder.uom[index],
        'variancePrice': salesOrder.price[index],
        'variancetax': salesOrder.tax != null && salesOrder.tax!.length > index
            ? salesOrder.tax![index]
            : 0,
        'varianceitemCode':
            salesOrder.itemCode != null && salesOrder.itemCode!.length > index
                ? salesOrder.itemCode![index]
                : '',
        'existingQuantity': currentQty,
        'existingWeight': isKg ? currentQty : 0.0,
        'existingAmount': salesOrder.amount[index],
        'originalIndex': index,
      };
    }

    if (!customerProvider.isModifyMode.value) {
      return Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              salesOrder.varianceName[index],
              style: TextStyle(
                fontSize: 11,
                color: isBoxItem ? Colors.blue : Colors.grey,
                fontWeight: isBoxItem ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              isKg
                  ? '${currentQty.toStringAsFixed(2)} ${salesOrder.uom[index]} x ₹${salesOrder.price[index]}'
                  : '${currentQty.toInt()} ${salesOrder.uom[index]} x ₹${salesOrder.price[index]}',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            trailing: Text(
              '₹${salesOrder.amount[index].toStringAsFixed(2)}',
              style: TextStyle(
                  fontSize: 11, color: isBoxItem ? Colors.blue : Colors.black),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                salesOrder.varianceName[index],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isBoxItem ? Colors.blue : Colors.black,
                ),
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isKg ? "Ex Weight" : "Ex Qty",
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      Text(
                        isKg
                            ? '${currentQty.toStringAsFixed(2)} ${salesOrder.uom[index]}'
                            : '${currentQty.toInt()} ${salesOrder.uom[index]}',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "New Qty",
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      ValueListenableBuilder<Map<int, double>>(
                        valueListenable: quantityChangesNotifier,
                        builder: (context, quantityChanges, child) {
                          final modifiedValue = quantityChanges[index] ?? 0.0;

                          // Debug print
                          print(
                              "👉 Item[$index] BaseQty=$currentQty | ModifiedValue=$modifiedValue | NewQty=${currentQty + modifiedValue}");

                          final originalQty = currentQty;
                          final newQuantity = originalQty + modifiedValue;

                          final newAmount =
                              salesOrder.price[index] * newQuantity;
                          final modificationColor = modifiedValue > 0
                              ? Colors.green
                              : (modifiedValue < 0 ? Colors.red : Colors.black);

                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  final newChanges =
                                      Map<int, double>.from(quantityChanges);
                                  final currentModifiedValue =
                                      newChanges[index] ?? 0.0;
                                  final newDelta = currentModifiedValue - 1.0;

                                  print(
                                      "🔴 MINUS pressed for Item[$index]: Base=$originalQty, CurrentDelta=$currentModifiedValue → NewDelta=$newDelta");

                                  if (originalQty + newDelta >= 0) {
                                    newChanges[index] = newDelta;
                                    quantityChangesNotifier.value = newChanges;

                                    print(
                                        "✅ Updated Delta for Item[$index]: ${quantityChangesNotifier.value}");

                                    customerProvider.updateItemInOrder(
                                      _createItemMap(),
                                      -1.0,
                                      index,
                                    );
                                  } else {
                                    print(
                                        "⚠️ Cannot go below zero for Item[$index]");
                                  }
                                },
                                child: Container(
                                  padding: EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(Icons.remove,
                                      size: 18, color: Colors.red),
                                ),
                              ),
                              Container(
                                margin: EdgeInsets.symmetric(horizontal: 8),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.blue),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isKg
                                      ? newQuantity.toStringAsFixed(2)
                                      : newQuantity.toInt().toString(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: modificationColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  final newChanges =
                                      Map<int, double>.from(quantityChanges);
                                  final currentModifiedValue =
                                      newChanges[index] ?? 0.0;
                                  final newDelta = currentModifiedValue + 1.0;

                                  print(
                                      "🟢 PLUS pressed for Item[$index]: Base=$originalQty, CurrentDelta=$currentModifiedValue → NewDelta=$newDelta");

                                  newChanges[index] = newDelta;
                                  quantityChangesNotifier.value = newChanges;

                                  print(
                                      "✅ Updated Delta for Item[$index]: ${quantityChangesNotifier.value}");

                                  customerProvider.updateItemInOrder(
                                    _createItemMap(),
                                    1.0,
                                    index,
                                  );
                                },
                                child: Container(
                                  padding: EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(Icons.add,
                                      size: 18, color: Colors.green),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Amt",
                          style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text(
                        '₹${salesOrder.amount[index].toStringAsFixed(2)}',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("New Amt",
                          style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ValueListenableBuilder<Map<int, double>>(
                        valueListenable: quantityChangesNotifier,
                        builder: (context, quantityChanges, child) {
                          final modifiedValue = quantityChanges[index] ?? 0.0;
                          final newQuantity = currentQty + modifiedValue;
                          final newAmount =
                              salesOrder.price[index] * newQuantity;
                          final modificationColor = modifiedValue > 0
                              ? Colors.green
                              : (modifiedValue < 0 ? Colors.red : Colors.black);

                          print(
                              "💰 Amount Update Item[$index]: Base=$currentQty, Delta=$modifiedValue, NewQty=$newQuantity, NewAmt=$newAmount");

                          return Text(
                            newQuantity != currentQty
                                ? '₹${newAmount.toStringAsFixed(2)}'
                                : '-',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: modificationColor,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        Divider(height: 1),
      ],
    );
  }
// Helper widgets for table cells

  Widget _buildOrderItemsList(
    SalesOrderDisplay salesOrder,
    EditCustomerScreenProvider customerprovider,
  ) {
    List<int> boxItemIndices = [];
    List<int> regularItemIndices = [];
    for (int i = 0; i < salesOrder.varianceName.length; i++) {
      if (salesOrder.isBoxItem != null &&
          salesOrder.isBoxItem!.length > i &&
          salesOrder.isBoxItem![i].toLowerCase() == "yes") {
        boxItemIndices.add(i);
      } else {
        regularItemIndices.add(i);
      }
    }

    final newItemsOnly = customerprovider.increasedItems
        .where(
            (item) => !salesOrder.varianceName.contains(item['varianceName']))
        .toList();
    return Expanded(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),

            if (boxItemIndices.isNotEmpty)
              Card(
                margin: EdgeInsets.symmetric(vertical: 8),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Box Items",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      Divider(),
                      Column(
                        children: boxItemIndices
                            .map((index) => _buildOrderItemTile(
                                salesOrder, index, customerprovider))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),

            // Display regular items
            Column(
              children: regularItemIndices
                  .map((index) =>
                      _buildOrderItemTile(salesOrder, index, customerprovider))
                  .toList(),
            ),

            if (customerprovider.isModifyMode.value && newItemsOnly.isNotEmpty)
              Card(
                margin: EdgeInsets.symmetric(vertical: 8),
                elevation: 2,
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "Newly Added Items",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Additions',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Divider(),
                      ...newItemsOnly.map((item) {
                        final uom = item['varianceUom']?.toString() ?? '';
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            item['varianceName']?.toString() ?? 'New Item',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          subtitle: Text(
                            '${item['quantity']?.toStringAsFixed(0) ?? '1'} $uom x ₹${item['variancePrice']?.toStringAsFixed(2) ?? '0.00'}',
                            style: TextStyle(fontSize: 11),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '₹${item['amount']?.toStringAsFixed(2) ?? '0.00'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete,
                                    size: 20, color: Colors.red),
                                onPressed: () =>
                                    customerprovider.removeAddedItem(item),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),

            if (salesOrder.toApprove != null &&
                salesOrder.toApprove!.isNotEmpty) ...[
              Text(
                'toapprove Items',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: salesOrder.toApprove!.length,
                itemBuilder: (context, modifyIndex) {
                  final toApproveOrder = salesOrder.toApprove![modifyIndex];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            // Icon(Icons.edit, size: 14, color: Colors.grey),
                            SizedBox(width: 8),
                          ],
                        ),
                      ),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: toApproveOrder.varianceName.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              toApproveOrder.varianceName[index],
                              style: TextStyle(fontSize: 11),
                            ),
                            subtitle: Text(
                              '${toApproveOrder.qty[index]} ${toApproveOrder.uom[index]} x ₹${toApproveOrder.price[index].toStringAsFixed(2)}',
                              style: TextStyle(fontSize: 10),
                            ),
                            trailing: Text(
                              '₹${toApproveOrder.amount[index].toStringAsFixed(2)}',
                              style: TextStyle(fontSize: 11),
                            ),
                          );
                        },
                        separatorBuilder: (context, index) =>
                            SizedBox(height: 5),
                      ),
                      Divider(),
                    ],
                  );
                },
              ),
              // Divider(thickness: 1.5),
              SizedBox(height: 20),
            ],
            Divider(thickness: 1.5),
            // if (salesOrder.modifiedOrders == null)

            if (salesOrder.modifiedOrders != null &&
                salesOrder.modifiedOrders!.isNotEmpty) ...[
              Text(
                'Existing Orders',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: salesOrder.modifiedOrders!.length,
                itemBuilder: (context, modifyIndex) {
                  final modifiedOrder = salesOrder.modifiedOrders![modifyIndex];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            // Icon(Icons.edit, size: 14, color: Colors.grey),
                            SizedBox(width: 8),
                          ],
                        ),
                      ),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: modifiedOrder.varianceName.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              modifiedOrder.varianceName[index],
                              style: TextStyle(fontSize: 11),
                            ),
                            // subtitle: Text(
                            //   '${modifiedOrder.qty[index]} ${modifiedOrder.uom[index]} x ₹${modifiedOrder.price[index].toStringAsFixed(2)}',
                            //   style: TextStyle(fontSize: 10),
                            // ),
                            subtitle: modifiedOrder.uom[index] == 'Kgs'
                                ? Text(
                                    'Weight: ${modifiedOrder.weight![index]}  x ₹${modifiedOrder.price[index].toStringAsFixed(2)}',
                                    style: TextStyle(fontSize: 10),
                                  )
                                : Text(
                                    '${modifiedOrder.qty[index]} ${modifiedOrder.uom[index]} x ₹${modifiedOrder.price[index].toStringAsFixed(2)}/-',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                            trailing: Text(
                              '₹${modifiedOrder.amount[index].toStringAsFixed(2)}',
                              style: TextStyle(fontSize: 11),
                            ),
                          );
                        },
                        separatorBuilder: (context, index) =>
                            SizedBox(height: 5),
                      ),
                      Divider(),
                    ],
                  );
                },
              ),
              // Divider(thickness: 1.5),
              SizedBox(height: 20),
            ],

            // Current Modifications Section (if in modify mode)

            // Original Order Section
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary(
    SalesOrderDisplay salesOrder,
    EditCustomerScreenProvider customerprovider,
  ) {
    // Safe total advance
    double totalAdvanceAmount = (salesOrder.advanceAmount ?? [])
        .fold(0.0, (sum, value) => (value ?? 0.0).toDouble() + sum);

    // Safe modified total
    double modifiedTotal = customerprovider.isModifyMode.value
        ? customerprovider.calculateModifiedTotal(salesOrder)
        : (salesOrder.totalAmount ?? 0.0).toDouble();

    // Safe custom charge and total amounts
    double customCharge = (salesOrder.customCharge ?? 0.0).toDouble();
    double totalAmount2 =
        (salesOrder.totalAmount2 ?? salesOrder.totalAmount ?? 0.0).toDouble();
    double discount = (salesOrder.discount ?? 0.0).toDouble();
    double discountAmount = (salesOrder.discountAmount ?? 0.0).toDouble();
    double finalPrice = (salesOrder.finalPrice ?? totalAmount2).toDouble();

    List<double> advanceAmounts = (salesOrder.advanceAmount ?? [])
        .map((e) => (e ?? 0.0).toDouble())
        .toList();
    List<String> advanceDates = salesOrder.advanceDateTime ?? [];
    int advanceLength = advanceAmounts.length < advanceDates.length
        ? advanceAmounts.length
        : advanceDates.length;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Total Amount
            Text(
              'Total: ₹${(salesOrder.totalAmount ?? 0.0).toDouble().toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),

            // Custom Charge
            if (customCharge > 0)
              Text(
                'Custom Charge: ₹${customCharge.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),

            if (customCharge > 0)
              Text(
                'Total Amount: ₹${totalAmount2.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),

            // Discount
            if (discount > 0)
              Text(
                'Discount: ${discount.toStringAsFixed(0)}%(-): ₹${discountAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),

            if (discount > 0)
              Text(
                'Order Amount: ₹${finalPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),

            // Modify Mode: Added/Removed Items
            if (customerprovider.isModifyMode.value &&
                (customerprovider.increasedItems.isNotEmpty ||
                    customerprovider.decreasedItems.isNotEmpty))
              Text(
                'Original Total: ₹${(salesOrder.totalAmount ?? 0.0).toDouble().toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.lineThrough,
                  color: Colors.grey,
                ),
              ),

            if (customerprovider.isModifyMode.value &&
                customerprovider.increasedItems.isNotEmpty)
              Text(
                'Added Items: +₹${customerprovider.increasedItems.fold<double>(0.0, (sum, item) => sum + ((item['amount'] ?? 0.0) as num).toDouble()).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),

            if (customerprovider.isModifyMode.value &&
                customerprovider.decreasedItems.isNotEmpty)
              Text(
                'Removed Items: -₹${customerprovider.decreasedItems.fold<double>(0.0, (sum, item) => sum + ((item['amount'] ?? 0.0) as num).toDouble()).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),

            if (customerprovider.isModifyMode.value &&
                (customerprovider.increasedItems.isNotEmpty ||
                    customerprovider.decreasedItems.isNotEmpty))
              Text(
                'Modified Total: ₹${modifiedTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),

            const SizedBox(height: 8),

            // Advance Amounts
            if (advanceLength > 0)
              ...List.generate(advanceLength, (index) {
                String formattedDate;
                try {
                  formattedDate = DateFormat('dd-MM-yyyy')
                      .format(DateTime.parse(advanceDates[index]));
                } catch (_) {
                  formattedDate = advanceDates[index] ?? 'Invalid Date';
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          formattedDate,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          'Amount : ₹${advanceAmounts[index].toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

            // Balance
            Text(
              'Balance: ₹${(modifiedTotal - totalAdvanceAmount).toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderActions(
    BuildContext context,
    SalesOrderDisplay salesOrder,
    ApiServiceSalesOrderProvider apiService,
    CartProvider cartProvider,
    EditCustomerScreenProvider customerscreenprovider,
  ) {
    double totalAdvanceAmount = salesOrder.advanceAmount!.fold(
      0.0,
      (sum, value) => sum + value,
    );

    final total = salesOrder.totalAmount - totalAdvanceAmount;
    double modifiedTotal = customerscreenprovider.isModifyMode.value
        ? customerscreenprovider.calculateModifiedTotal(salesOrder)
        : salesOrder.totalAmount;

    return Column(
      children: [
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: customerscreenprovider.isModifyMode,
              builder: (context, isModifyMode, child) {
                return Row(
                  children: [
                    if (customerscreenprovider.decreasedItems.isNotEmpty)
                      CustomButton(
                        text: 'Send to Approval',
                        onPressed: () async {
                          customerscreenprovider.sendToApproval(
                            salesOrder,
                            customerscreenprovider.increasedItems,
                            customerscreenprovider.decreasedItems,
                            customerscreenprovider.recordedFilePath.isNotEmpty
                                ? customerscreenprovider.recordedFilePath
                                : null,
                            customerscreenprovider.pickedImage1,
                            customerscreenprovider.pickedImage2,
                            modifiedTotal,
                            total,
                            totalAdvanceAmount,
                            context,
                          );
                          customerscreenprovider.isModifyMode.value = false;
                        },
                        backgroundColor: Colors.orange,
                        textColor: CustomColors.whiteColor,
                        padding:
                            EdgeInsets.symmetric(horizontal: 25, vertical: 11),
                      ),
                    if (isModifyMode &&
                        customerscreenprovider.decreasedItems.isEmpty)
                      CustomButton(
                        text: 'Save Changes',
                        onPressed: () async {
                          final audioPath =
                              customerscreenprovider.recordedFilePath.isNotEmpty
                                  ? customerscreenprovider.recordedFilePath
                                  : null;
                          print("audioPath $audioPath");
                          print(
                              "_pickedImage1 ${customerscreenprovider.pickedImage1}");
                          print(
                              "_pickedImage2 ${customerscreenprovider.pickedImage2}");
                          // Show advance payment popup safely
                          customerscreenprovider.showAdvancePaymentPopup(
                            context,
                            salesOrder,
                            customerscreenprovider.increasedItems,
                            customerscreenprovider.decreasedItems,
                            audioPath,
                            apiService,
                            customerscreenprovider.pickedImage1,
                            customerscreenprovider.pickedImage2,
                            modifiedTotal,
                            isModifyMode,
                          );
                        },
                        backgroundColor: Colors.green,
                        textColor: CustomColors.whiteColor,
                        padding:
                            EdgeInsets.symmetric(horizontal: 25, vertical: 11),
                      ),
                    if (customerscreenprovider.decreasedItems.isEmpty &&
                        !isModifyMode)
                      Row(
                        children: [
                          if (salesOrder.status == 'Confirm Order')
                            CustomButton(
                              text: 'Add Advance',
                              onPressed: () => _showAdvancePaymentDialog(
                                  context, salesOrder),
                              backgroundColor: CustomColors.blueColor,
                              textColor: CustomColors.whiteColor,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 25, vertical: 11),
                            ),
                          SizedBox(width: 20),
                          if (salesOrder.status == 'Confirm Order')
                            CustomButton(
                              text: 'Pay ₹ ${total.toStringAsFixed(2)}',
                              onPressed: salesOrder.status !=
                                      "SalesOrder Completed"
                                  ? () =>
                                      _showPaymentDialog(context, salesOrder)
                                  : () {},
                              backgroundColor:
                                  salesOrder.status != "SalesOrder Completed"
                                      ? CustomColors.primaryColor
                                      : Colors.grey,
                              textColor: CustomColors.whiteColor,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 25, vertical: 11),
                            ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  void _showAdvancePaymentDialog(
      BuildContext context, SalesOrderDisplay salesOrder) {
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
              child: AddAdvancePayment(
                salesOrder: salesOrder,
              ),
            ),
          );
        },
      );
    }
  }

  void _showPaymentDialog(BuildContext context, SalesOrderDisplay salesOrder) {
    double totalAmount = salesOrder.balanceAmount;
    if (totalAmount != 0) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            child: CustomSizedBox(
              width: MediaQuery.of(context).size.width * 0.5,
              child: OrderManagementPayandPrint(
                totalAmount: totalAmount,
                holdBillId: '',
                orderId: salesOrder.salesOrderId,
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

  Widget _buildOrderHeader(SalesOrderDisplay salesOrder) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Item Name',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Amount',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  void _showAddItemDialog(
    BuildContext parentContext,
    EditCustomerScreenProvider customerScreenProvider,
  ) {
    final searchController = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];
    Timer? _debounceTimer;

    final regularModeProvider = Provider.of<RegularModeProvider>(
      parentContext,
      listen: false,
    );

    void performSearch(String query) {
      if (query.isEmpty) {
        searchResults = [];
        return;
      }

      final queryLower = query.toLowerCase();

      searchResults = regularModeProvider.originalItems
          .expand((item) => item['variances'] as List<dynamic>)
          .where((variance) {
            final name =
                variance['varianceName']?.toString().toLowerCase() ?? '';
            final code =
                variance['varianceitemCode']?.toString().toLowerCase() ?? '';
            final uom = variance['varianceUOM']?.toString().toLowerCase() ?? '';

            return name.contains(queryLower) ||
                code.contains(queryLower) ||
                uom.contains(queryLower);
          })
          .map((variance) => {
                'varianceName': variance['varianceName'],
                'varianceUom': variance['varianceUOM'],
                'variancePrice': variance['varianceDefaultPrice'],
                'varianceTax': variance['tax'] ?? 0.0,
                'weight': variance['weight'] ?? 0.0,
                'varianceitemCode': variance['varianceitemCode'],
                'itemName': _getItemNameForVariance(
                    regularModeProvider.originalItems,
                    variance['varianceName']),
              })
          .toList();
    }

    void _clearSearch() {
      searchController.clear();
      searchResults = [];
      if (_debounceTimer != null && _debounceTimer!.isActive) {
        _debounceTimer!.cancel();
      }
    }

    @override
    void dispose() {
      searchController.dispose();
      _debounceTimer?.cancel();
      super.dispose();
    }

    showDialog(
      context: parentContext,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Item'),
              content: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by name, code or UOM',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _clearSearch();
                            setState(() {});
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      autofocus: true,
                      onChanged: (query) {
                        if (_debounceTimer != null &&
                            _debounceTimer!.isActive) {
                          _debounceTimer!.cancel();
                        }

                        _debounceTimer =
                            Timer(const Duration(milliseconds: 300), () {
                          setState(() {
                            performSearch(query);
                          });
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    if (searchController.text.isNotEmpty &&
                        searchResults.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text('No items found'),
                      )
                    else if (searchResults.isNotEmpty)
                      SizedBox(
                        height: 300,
                        child: ListView.separated(
                          itemCount: searchResults.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = searchResults[index];
                            return ListTile(
                              title: Text(item['varianceName'] ?? ''),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${item['itemName'] ?? ''}'),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item['varianceUom'] ?? ''} • '
                                    '₹${item['variancePrice']?.toStringAsFixed(2) ?? '0.00'} • '
                                    'Code: ${item['varianceitemCode'] ?? ''}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              onTap: () {
                                _showQuantityDialog(
                                  context,
                                  item,
                                  customerScreenProvider,
                                );
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _getItemNameForVariance(
      List<Map<String, dynamic>> items, String varianceName) {
    for (final item in items) {
      for (final variance in item['variances']) {
        if (variance['varianceName'] == varianceName) {
          return item['name'] ?? '';
        }
      }
    }
    return '';
  }

  void _showQuantityDialog(
    BuildContext context,
    Map<String, dynamic> item,
    EditCustomerScreenProvider customerScreenProvider,
  ) {
    final quantityController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add ${item['varianceName']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              Text(
                'Price: ₹${item['variancePrice']?.toStringAsFixed(2) ?? '0.00'}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // final quantity = int.tryParse(quantityController.text) ?? 1;
                // customerScreenProvider.addItemToOrder(
                //   item: item,
                //   quantity: quantity,
                // );
                double quantity = double.tryParse(quantityController.text) ?? 1;
                customerScreenProvider.addItemToOrder(
                  item,
                  quantity,
                );
                Navigator.pop(context); // Close quantity dialog
                Navigator.pop(context); // Close search dialog
              },
              child: const Text('Add to Order'),
            ),
          ],
        );
      },
    );
  }
}
