import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:yenpos/Global/Widget/custom_button_reuse.dart';
import 'package:yenpos/Global/Widget/custom_colors.dart';
import 'package:yenpos/Global/Widget/custom_sized_box.dart';
import 'package:yenpos/Global/Widget/smartsearchtextfield.dart';
import 'package:yenpos/Mode_page/Regular_mode/Provider/regular_mode_screen_provider.dart';
import 'package:yenpos/Sale_order/Models/sales_order_display_model.dart';
import 'package:yenpos/Sale_order/Print_Receipt/currentOrderPrint.dart';
import 'package:yenpos/Sale_order/Provider/cartProvider.dart';
import 'package:yenpos/Sale_order/Provider/editcustomerscreenProvider.dart';
import 'package:yenpos/Sale_order/Provider/get_sales_order_service.dart';
import 'package:yenpos/Sale_order/Screens/create_sales_order.dart';
import 'package:yenpos/Sale_order/Screens/editcustomerdetails.dart';
import 'package:yenpos/Sale_order/Widgets/add_advance_dialogue.dart';
import 'package:yenpos/Sale_order/Widgets/advance-dialog.dart';
import 'package:yenpos/Sale_order/Widgets/cancel_order_dialogue.dart';
import 'package:yenpos/Sale_order/Widgets/date_button.dart';
import 'package:yenpos/Sale_order/Widgets/numeric_Calculator.dart';
import 'package:yenpos/Sale_order/Widgets/top_message.dart';

import '../../../regular_mode_page/provider/regular_mode_screen_provider.dart'
    hide RegularModeProvider;

class AllOrdersPage extends StatefulWidget {
  const AllOrdersPage({super.key});

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
    'Confirm',
  ];
  late ValueNotifier<Map<int, double>> quantityChangesNotifier;

  // Map<int, double> quantityChanges = {};
  @override
  void initState() {
    super.initState();

    quantityChangesNotifier = ValueNotifier<Map<int, double>>({});

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
        final filteredSalesOrders = apiService.hivefilteredAllOrders
            .map((order) => SalesOrderDisplay.fromMap(order))
            .where(
              (order) => order.status != "Open Order",
            ) // <-- Exclude Open Order
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
                            selectedOrder:
                                customerScreenProvider
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
                                  _showCancelOrderDialog(context, salesOrder);
                                  // double totalAdvanceAmount = salesOrder
                                  //     .advanceAmount!
                                  //     .fold(0.0, (sum, value) => sum + value);

                                  // await showDialog(
                                  //   barrierDismissible: false,
                                  //   context: context,
                                  //   builder: (BuildContext context) {
                                  //     return Dialog(
                                  //       backgroundColor: Colors.white,
                                  //       child: SizedBox(
                                  //         width:
                                  //             MediaQuery.of(
                                  //               context,
                                  //             ).size.width *
                                  //             0.5,
                                  //         child: AdvanceAmountDialog(
                                  //           salesOrderId:
                                  //               salesOrder.salesOrderId,
                                  //           advanceAmount: totalAdvanceAmount,
                                  //           saleOrderNo: salesOrder.saleOrderNo,
                                  //         ),
                                  //       ),
                                  //     );
                                  //   },
                                  // );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                ),
                                child: Text(
                                  'Cancel Order',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            if (!isModifyMode) SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                customerScreenProvider.isModifyMode.value =
                                    !isModifyMode;
                                quantityChangesNotifier.value.clear();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isModifyMode
                                    ? Colors.green
                                    : Colors.blue,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                              ),
                              child: Text(
                                isModifyMode ? 'Cancel' : 'Modify Order',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            ValueListenableBuilder<bool>(
                              valueListenable:
                                  customerScreenProvider.isModifyMode,
                              builder: (context, isModifyMode, child) {
                                return Row(
                                  children: [
                                    if (isModifyMode) SizedBox(width: 8),
                                    if (isModifyMode)
                                      ElevatedButton(
                                        onPressed: () {
                                          try {
                                            print("Add Item button pressed.");

                                            final regularModeProvider = context
                                                .read<RegularModeProvider>();
                                            print(
                                              "RegularModeProvider found. originalItems length: ${regularModeProvider.originalItems.length}",
                                            );

                                            _showAddItemDialog(
                                              context,
                                              customerScreenProvider,
                                              regularModeProvider,
                                            );
                                          } catch (e, stackTrace) {
                                            print(
                                              "Error accessing RegularModeProvider: $e\n$stackTrace",
                                            );
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8.0,
                                            ),
                                          ),
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 6,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.add,
                                              color: Colors.white,
                                              size: 14,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Add Item',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                );
                              },
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
                  print("worked");
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
                    MaterialPageRoute(builder: (context) => SalesOrderScreen()),
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
      filteredSalesOrders.where(
        (order) =>
            (apiService.groupByDeliveryDate
                ? order.deliveryDate
                : order.orderDate) !=
            null,
      ),
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
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔍 Smart Search Bar
                SmartSearchField(
                  controller: _searchController,
                  onSearch: apiService.searchHiveFilteredAllOrders,
                ),

                const SizedBox(height: 16),

                // 📅 Date Filter & Dropdown Row
                Row(
                  children: [
                    // Start Date
                    Expanded(
                      flex: 2,
                      child: buildDateButton(
                        label: "Start Date",
                        date: apiService.startDate,
                        onTap: () async {
                          final selectedDate = await showDatePicker(
                            context: context,
                            initialDate: apiService.startDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (selectedDate != null) {
                            apiService.setStartDate(selectedDate);
                            if (apiService.endDate != null &&
                                apiService.endDate!.isBefore(selectedDate)) {
                              apiService.setEndDate(selectedDate);
                            }
                          }
                        },
                      ),
                    ),

                    const SizedBox(width: 10),

                    // End Date
                    Expanded(
                      flex: 2,
                      child: buildDateButton(
                        label: "End Date",
                        date: apiService.endDate,
                        onTap: () async {
                          final selectedDate = await showDatePicker(
                            context: context,
                            initialDate:
                                apiService.endDate ??
                                (apiService.startDate ?? DateTime.now()),
                            firstDate: apiService.startDate ?? DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (selectedDate != null) {
                            apiService.setEndDate(selectedDate);
                            apiService.fetchFilteredOrders(
                              startDate: apiService.startDate,
                              endDate: apiService.endDate,
                            );
                          }
                        },
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Filter Dropdown
                    Expanded(
                      flex: 3,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.blue.shade50,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: DropdownButtonFormField<String>(
                          value: _selectedFilter,
                          decoration: InputDecoration(
                            labelText: 'Filter Orders',
                            labelStyle: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                            border: InputBorder.none,
                          ),
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.blue.shade700,
                          ),
                          dropdownColor: Colors.white,
                          items: _filterOptions.map((String filter) {
                            return DropdownMenuItem<String>(
                              value: filter,
                              child: Text(
                                filter,
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newFilter) {
                            if (newFilter != null) {
                              setState(() => _selectedFilter = newFilter);
                              apiService.filterOrdersByStatus(newFilter);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.12),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 🗓 Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade700],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    apiService.groupByDeliveryDate
                        ? 'Orders by Delivery Date'
                        : 'Orders by Order Date',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),

              // 🔄 Animated Toggle Icon
              InkWell(
                borderRadius: BorderRadius.circular(50),
                onTap: apiService.toggleGrouping,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: apiService.groupByDeliveryDate
                          ? [Colors.indigo.shade500, Colors.indigo.shade700]
                          : [Colors.blue.shade400, Colors.blue.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    apiService.groupByDeliveryDate
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: apiService.isLoading
              ? const Center(child: CircularProgressIndicator())
              : filteredSalesOrders.isEmpty
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
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Text(
                              displayDate,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isPastDate ? Colors.red : Colors.black,
                              ),
                            ),
                          ),

                        // --- Modern card for each order ---
                        ...orders.map((order) {
                          final orderIndex = filteredSalesOrders.indexOf(order);
                          final bool isSelected = selectedIndex == orderIndex;

                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  gradient: LinearGradient(
                                    colors: order.status == "dispatched"
                                        ? [
                                            Colors.red.shade200,
                                            Colors.red.shade100,
                                          ]
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
                                  onTap: () {
                                    setState(() {
                                      customerprovider
                                          .handleTransactionSelection(
                                            orderIndex,
                                          );
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                                      fontWeight:
                                                          FontWeight.w600,
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
                                                      fontWeight:
                                                          FontWeight.w600,
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
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            TableRow(
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 2.0,
                                                      ),
                                                  child: Text(
                                                    order.saleOrderNo,
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 2.0,
                                                      ),
                                                  child: Text(
                                                    (order.employeeName ??
                                                            'N/A')
                                                        .replaceAll(
                                                          RegExp(
                                                            r'[^a-zA-Z\s]',
                                                          ),
                                                          '',
                                                        ),
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 2.0,
                                                      ),
                                                  child: Text(
                                                    (order.status ?? '')
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

                              // --- Corner Ribbon for orderType ---
                              Positioned(
                                top: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.only(
                                      bottomLeft: Radius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    (order.orderType ?? 'ORDER').toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
    // ✅ Safe access to lists
    final currentQty = (salesOrder.qty.length > index)
        ? salesOrder.qty[index]
        : 0;
    final currentWeight =
        (salesOrder.weight != null && salesOrder.weight!.length > index)
        ? (salesOrder.weight![index] is int
              ? (salesOrder.weight![index] as int).toDouble()
              : (salesOrder.weight![index] ?? 0.0))
        : 0.0;
    final uom = (salesOrder.uom.length > index) ? salesOrder.uom[index] : '';
    final isKg = uom.toLowerCase() == 'kg' || uom.toLowerCase() == 'kgs';
    final isBoxItem =
        (salesOrder.isBoxItem != null && salesOrder.isBoxItem!.length > index)
        ? salesOrder.isBoxItem![index].toLowerCase() == "yes"
        : false;

    // Helper to create item map
    Map<String, dynamic> _createItemMap() {
      return {
        'varianceName': (salesOrder.varianceName.length > index)
            ? salesOrder.varianceName[index]
            : 'Unknown',
        'itemName':
            (salesOrder.itemName != null && salesOrder.itemName!.length > index)
            ? salesOrder.itemName![index]
            : ((salesOrder.varianceName.length > index)
                  ? salesOrder.varianceName[index]
                  : 'Unknown'),
        'varianceUom': uom,
        'variancePrice': (salesOrder.price.length > index)
            ? salesOrder.price[index]
            : 0.0,
        'variancetax':
            (salesOrder.tax != null && salesOrder.tax!.length > index)
            ? salesOrder.tax![index]
            : 0,
        'varianceitemCode':
            (salesOrder.itemCode != null && salesOrder.itemCode!.length > index)
            ? salesOrder.itemCode![index]
            : '',
        'existingQuantity': currentQty,
        'existingWeight': currentWeight,
        'existingAmount': (salesOrder.amount.length > index)
            ? salesOrder.amount[index]
            : 0.0,
        'originalIndex': index,
      };
    }

    // 🟢 Normal display (not modify mode)
    if (!customerProvider.isModifyMode.value) {
      final pricePerUnit = (salesOrder.price.length > index)
          ? salesOrder.price[index]
          : 0.0;
      String priceDescription;

      if (isKg) {
        if (currentWeight >= 1) {
          priceDescription =
              '$currentQty $uom (${currentWeight.toStringAsFixed(2)} kg) × ₹${pricePerUnit.toStringAsFixed(0)}/kg';
        } else {
          priceDescription =
              '$currentQty × ${(currentWeight * 1000).toStringAsFixed(0)} g × ₹${pricePerUnit.toStringAsFixed(0)}/kg';
        }
      } else {
        priceDescription =
            '${currentQty.toInt()} $uom × ₹${pricePerUnit.toStringAsFixed(0)}';
      }

      return ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          (salesOrder.varianceName.length > index)
              ? salesOrder.varianceName[index]
              : 'Unknown',
          style: TextStyle(
            fontSize: 11,
            color: isBoxItem ? Colors.blue : Colors.grey,
            fontWeight: isBoxItem ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          priceDescription,
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
        trailing: Text(
          '₹${(salesOrder.amount.length > index ? salesOrder.amount[index] : 0.0).toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 11,
            color: isBoxItem ? Colors.blue : Colors.black,
          ),
        ),
      );
    }

    // 🟠 Modify mode display
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Item title
              Text(
                (salesOrder.varianceName.length > index)
                    ? salesOrder.varianceName[index]
                    : 'Unknown',
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
                  // Existing Qty/Weight
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isKg ? "Ex Weight" : "Ex Qty",
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      Builder(
                        builder: (_) {
                          final pricePerUnit = (salesOrder.price.length > index)
                              ? salesOrder.price[index]
                              : 0.0;
                          String displayText;
                          if (isKg) {
                            if (currentWeight >= 1) {
                              displayText =
                                  '$currentQty $uom (${currentWeight.toStringAsFixed(2)} kg) × ₹${pricePerUnit.toStringAsFixed(0)}/kg';
                            } else {
                              displayText =
                                  '$currentQty × ${(currentWeight * 1000).toStringAsFixed(0)} g × ₹${pricePerUnit.toStringAsFixed(0)}/kg';
                            }
                          } else {
                            displayText =
                                '${currentQty.toInt()} $uom × ₹${pricePerUnit.toStringAsFixed(0)}';
                          }
                          return Text(
                            displayText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  // New Qty controls
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
                          final newQuantity = currentQty + modifiedValue;

                          final modificationColor = modifiedValue > 0
                              ? Colors.green
                              : (modifiedValue < 0 ? Colors.red : Colors.black);

                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Decrease button
                              GestureDetector(
                                onTap: () {
                                  final newChanges = Map<int, double>.from(
                                    quantityChanges,
                                  );
                                  final currentModifiedValue =
                                      newChanges[index] ?? 0.0;
                                  if (currentQty + currentModifiedValue - 1 >=
                                      0) {
                                    newChanges[index] =
                                        currentModifiedValue - 1;
                                    quantityChangesNotifier.value = newChanges;
                                    customerProvider.updateItemInOrder(
                                      _createItemMap(),
                                      -1,
                                      index,
                                    );
                                  }
                                },
                                child: Container(
                                  padding: EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    Icons.remove,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                              // Quantity display
                              Container(
                                margin: EdgeInsets.symmetric(horizontal: 8),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.blue),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  newQuantity.toInt().toString(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: modificationColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              // Increase button
                              GestureDetector(
                                onTap: () {
                                  final newChanges = Map<int, double>.from(
                                    quantityChanges,
                                  );
                                  final currentModifiedValue =
                                      newChanges[index] ?? 0.0;
                                  newChanges[index] = currentModifiedValue + 1;
                                  quantityChangesNotifier.value = newChanges;
                                  customerProvider.updateItemInOrder(
                                    _createItemMap(),
                                    1,
                                    index,
                                  );
                                },
                                child: Container(
                                  padding: EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    Icons.add,
                                    size: 18,
                                    color: Colors.green,
                                  ),
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

    for (int i = 0; i < (salesOrder.varianceName?.length ?? 0); i++) {
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
          (item) => !salesOrder.varianceName.contains(item['varianceName']),
        )
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

            // Box Items
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
                            .map(
                              (index) => _buildOrderItemTile(
                                salesOrder,
                                index,
                                customerprovider,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),

            // Regular Items
            Column(
              children: regularItemIndices
                  .map(
                    (index) => _buildOrderItemTile(
                      salesOrder,
                      index,
                      customerprovider,
                    ),
                  )
                  .toList(),
            ),

            // Newly Added Items
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
                              horizontal: 6,
                              vertical: 2,
                            ),
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
                                icon: Icon(
                                  Icons.delete,
                                  size: 20,
                                  color: Colors.red,
                                ),
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

            // To Approve Items
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
                      SizedBox(height: 8),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: toApproveOrder.varianceName.length,
                        itemBuilder: (context, index) {
                          final qty = toApproveOrder.qty.length > index
                              ? toApproveOrder.qty[index]
                              : 0;
                          final uom = toApproveOrder.uom.length > index
                              ? toApproveOrder.uom[index]
                              : '';
                          final price = toApproveOrder.price.length > index
                              ? toApproveOrder.price[index]
                              : 0.0;
                          final amount = toApproveOrder.amount.length > index
                              ? toApproveOrder.amount[index]
                              : 0.0;
                          final name = toApproveOrder.varianceName[index];

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(name, style: TextStyle(fontSize: 11)),
                            subtitle: Text(
                              '$qty $uom x ₹${price.toStringAsFixed(2)}',
                              style: TextStyle(fontSize: 10),
                            ),
                            trailing: Text(
                              '₹${amount.toStringAsFixed(2)}',
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
              SizedBox(height: 20),
            ],

            // Modified Orders
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
                      SizedBox(height: 8),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: modifiedOrder.varianceName.length,
                        itemBuilder: (context, index) {
                          final name = modifiedOrder.varianceName[index];
                          final qty = modifiedOrder.qty.length > index
                              ? modifiedOrder.qty[index]
                              : 0;
                          final uom = modifiedOrder.uom.length > index
                              ? modifiedOrder.uom[index]
                              : '';
                          final price = modifiedOrder.price.length > index
                              ? modifiedOrder.price[index]
                              : 0.0;
                          final amount = modifiedOrder.amount.length > index
                              ? modifiedOrder.amount[index]
                              : 0.0;
                          final weight =
                              (modifiedOrder.weight != null &&
                                  modifiedOrder.weight!.length > index)
                              ? modifiedOrder.weight![index]
                              : 0;

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(name, style: TextStyle(fontSize: 11)),
                            subtitle: uom == 'Kgs'
                                ? Text(
                                    'Weight: $weight x ₹${price.toStringAsFixed(2)}',
                                    style: TextStyle(fontSize: 10),
                                  )
                                : Text(
                                    '$qty $uom x ₹${price.toStringAsFixed(2)}/-',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                            trailing: Text(
                              '₹${amount.toStringAsFixed(2)}',
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
              SizedBox(height: 20),
            ],

            Divider(thickness: 1.5),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary(
    SalesOrderDisplay salesOrder,
    EditCustomerScreenProvider customerprovider,
  ) {
    // Safe totals
    double totalAdvanceAmount = (salesOrder.advanceAmount ?? []).fold(
      0.0,
      (sum, value) => (value ?? 0.0).toDouble() + sum,
    );

    double modifiedTotal = customerprovider.isModifyMode.value
        ? customerprovider.calculateModifiedTotal(salesOrder)
        : (salesOrder.totalAmount ?? 0.0).toDouble();

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
      padding: const EdgeInsets.all(8.0), // reduced from 12
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _summaryRow("Total", salesOrder.totalAmount),
          if (customCharge > 0)
            _summaryRow("Custom Charge", customCharge, color: Colors.orange),
          if (customCharge > 0) _summaryRow("Total Amount", totalAmount2),
          if (discount > 0)
            _summaryRow(
              "Discount",
              discountAmount,
              prefix: "${discount.toStringAsFixed(0)}% (-)",
              color: Colors.red,
            ),
          if (discount > 0) _summaryRow("Order Amount", finalPrice),

          // ---- Modification Summary ----
          if (customerprovider.isModifyMode.value &&
              (customerprovider.increasedItems.isNotEmpty ||
                  customerprovider.decreasedItems.isNotEmpty)) ...[
            const SizedBox(height: 6),
            const Divider(height: 12),
            const Text(
              "Modification Summary",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Original Total: ₹${(salesOrder.totalAmount ?? 0.0).toStringAsFixed(2)}",
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.lineThrough,
                color: Colors.grey,
              ),
            ),
            if (customerprovider.increasedItems.isNotEmpty)
              _summaryRow(
                "Added Items",
                customerprovider.increasedItems.fold<double>(
                  0.0,
                  (sum, item) =>
                      sum + ((item['amount'] ?? 0.0) as num).toDouble(),
                ),
                color: Colors.green,
                prefix: "+",
              ),
            if (customerprovider.decreasedItems.isNotEmpty)
              _summaryRow(
                "Removed Items",
                customerprovider.decreasedItems.fold<double>(
                  0.0,
                  (sum, item) =>
                      sum + ((item['amount'] ?? 0.0) as num).toDouble(),
                ),
                color: Colors.red,
                prefix: "-",
              ),
            _summaryRow("Modified Total", modifiedTotal, color: Colors.blue),
          ],

          // ---- Advance Payments ----
          if (advanceLength > 0) ...[
            const Divider(height: 14),
            const Text(
              "Advance Payments",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 4),
            Column(
              children: List.generate(advanceLength, (index) {
                String formattedDate;
                try {
                  formattedDate = DateFormat(
                    'dd-MM-yyyy',
                  ).format(DateTime.parse(advanceDates[index]));
                } catch (_) {
                  formattedDate = advanceDates[index];
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formattedDate,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        "₹${advanceAmounts[index].toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],

          const Divider(height: 14),
          _summaryRow(
            "Balance",
            modifiedTotal - totalAdvanceAmount + customCharge,
            color: Colors.blue,
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    double? value, {
    String prefix = "",
    Color? color,
    bool bold = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0), // reduced from 3
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          Text(
            "$prefix ₹${(value ?? 0.0).toStringAsFixed(2)}",
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
              color: color ?? Colors.black,
            ),
          ),
        ],
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
                            _pickedImage1,
                            _pickedImage1,
                            modifiedTotal,
                            total,
                            totalAdvanceAmount,
                            context,
                          );
                          customerscreenprovider.isModifyMode.value = false;
                        },
                        backgroundColor: Colors.orange,
                        textColor: CustomColors.whiteColor,
                        padding: EdgeInsets.symmetric(
                          horizontal: 25,
                          vertical: 11,
                        ),
                      ),
                    if (isModifyMode &&
                        customerscreenprovider.decreasedItems.isEmpty)
                      CustomButton(
                        text: 'Save Changes',
                        onPressed: () async {
                          print("🔹 Save Changes button clicked!");

                          // Print current state values
                          print(
                            "➡️ Increased Items: ${customerscreenprovider.increasedItems}",
                          );
                          print(
                            "➡️ Decreased Items: ${customerscreenprovider.decreasedItems}",
                          );
                          print(
                            "➡️ Recorded File Path: ${customerscreenprovider.recordedFilePath}",
                          );
                          print(
                            "➡️ Picked Image 1: ${_pickedImage1 != null ? _pickedImage1!.path : 'No Image Selected'}",
                          );
                          print(
                            "➡️ Picked Image 2: ${_pickedImage2 != null ? _pickedImage2!.path : 'No Image Selected'}",
                          );
                          print("➡️ Modified Total: $modifiedTotal");
                          print("➡️ Is Modify Mode: $isModifyMode");
                          print("➡️ API Service Instance: $apiService");
                          print("➡️ Sales Order: $salesOrder");

                          // Decide audio path
                          final audioPath =
                              customerscreenprovider.recordedFilePath.isNotEmpty
                              ? customerscreenprovider.recordedFilePath
                              : null;

                          print(
                            "🎤 Final Audio Path: ${audioPath ?? 'No Audio'}",
                          );

                          // Call popup function
                          print("🚀 Calling showAdvancePaymentPopup...");
                          customerscreenprovider.showAdvancePaymentPopup(
                            context,
                            salesOrder,
                            customerscreenprovider.increasedItems,
                            customerscreenprovider.decreasedItems,
                            audioPath,
                            apiService,
                            _pickedImage1,
                            _pickedImage2,
                            modifiedTotal,
                            isModifyMode,
                            totalAdvanceAmount,
                          );
                          print("✅ showAdvancePaymentPopup call completed!");
                        },
                        backgroundColor: Colors.green,
                        textColor: CustomColors.whiteColor,
                        padding: EdgeInsets.symmetric(
                          horizontal: 25,
                          vertical: 11,
                        ),
                      ),
                    if (customerscreenprovider.decreasedItems.isEmpty &&
                        !isModifyMode)
                      Row(
                        children: [
                          if (salesOrder.status != 'Sales Completed' &&
                              salesOrder.status != 'Cancelled')
                            CustomButton(
                              text: 'Add Advance',
                              onPressed: () => _showAdvancePaymentDialog(
                                context,
                                salesOrder,
                              ),
                              backgroundColor: CustomColors.blueColor,
                              textColor: CustomColors.whiteColor,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 25,
                                vertical: 11,
                              ),
                            ),

                          SizedBox(width: 20),
                          // CustomButton(
                          //   text: 'Pay ₹ ${total.toStringAsFixed(2)}',
                          //   onPressed: () {
                          //     if (salesOrder.status == "Confirm Order") {
                          //       _showPaymentDialog(context, salesOrder);
                          //     } else {
                          //       TopMessage.show(
                          //         context,
                          //         message:
                          //             "Payment is available only after dispatch.",
                          //         backgroundColor: Colors.orangeAccent,
                          //         textColor: Colors.white,
                          //         duration: const Duration(seconds: 3),
                          //       );
                          //     }
                          //   },
                          //   backgroundColor:
                          //       salesOrder.status == "Confirm Order"
                          //       ? CustomColors.primaryColor
                          //       : Colors.grey,
                          //   textColor: CustomColors.whiteColor,
                          //   padding: const EdgeInsets.symmetric(
                          //     horizontal: 25,
                          //     vertical: 11,
                          //   ),
                          // ),
                          CustomButton(
                            text: 'Pay ₹ ${total.toStringAsFixed(2)}',
                            onPressed: () {
                              if (salesOrder.status == "dispatched") {
                                _showPaymentDialog(context, salesOrder);
                              } else {
                                TopMessage.show(
                                  context,
                                  message:
                                      "Payment is available only after dispatch.",
                                  backgroundColor: Colors.orangeAccent,
                                  textColor: Colors.white,
                                  duration: const Duration(seconds: 3),
                                );
                              }
                            },
                            backgroundColor: salesOrder.status == "dispatched"
                                ? CustomColors.primaryColor
                                : Colors.grey,
                            textColor: CustomColors.whiteColor,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 25,
                              vertical: 11,
                            ),
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
    BuildContext context,
    SalesOrderDisplay salesOrder,
  ) {
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
              child: AddAdvancePayment(salesOrder: salesOrder),
            ),
          );
        },
      );
    }
  }

  void _showCancelOrderDialog(
    BuildContext context,
    SalesOrderDisplay salesOrder,
  ) {
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
              child: CancelOrderPayment(salesOrder: salesOrder),
            ),
          );
        },
      );
    }
  }

  void _showPaymentDialog(BuildContext context, SalesOrderDisplay salesOrder) {
    double totalAmount = salesOrder.balanceAmount;
    // if (totalAmount != 0) {
    showDialog(
      context: context,
      barrierDismissible: false,
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
    // }
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
    BuildContext context,
    EditCustomerScreenProvider customerScreenProvider,
    RegularModeProvider regularModeProvider,
  ) {
    final searchController = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];

    void performSearch(String query) {
      if (query.isEmpty) {
        searchResults = [];
        return;
      }

      final queryLower = query.toLowerCase();
      searchResults = regularModeProvider.originalItems
          .expand((item) => item['variances'] as List<dynamic>)
          .where((variance) {
            final name = (variance['varianceName']?.toString() ?? '')
                .toLowerCase();
            final code = (variance['varianceitemCode']?.toString() ?? '')
                .toLowerCase();
            final uom = (variance['varianceUOM']?.toString() ?? '')
                .toLowerCase();
            return name.contains(queryLower) ||
                code.contains(queryLower) ||
                uom.contains(queryLower);
          })
          .map((variance) {
            final itemName = _getItemNameForVariance(
              regularModeProvider.originalItems,
              variance['varianceName'],
            );
            return {
              'varianceName': variance['varianceName'],
              'varianceUom': variance['varianceUOM'],
              'variancePrice': variance['varianceDefaultPrice'],
              'varianceTax': variance['tax'] ?? 0.0,
              'weight': variance['weight'] ?? 0.0,
              'varianceitemCode': variance['varianceitemCode'],
              'itemName': itemName,
            };
          })
          .toList();
    }

    void _clearSearch() {
      searchController.clear();
      searchResults = [];
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 40,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: Colors.grey.shade50,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                  maxWidth: 500,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title
                        Text(
                          'Add Item',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Search Field
                        TextField(
                          controller: searchController,
                          decoration: InputDecoration(
                            hintText: 'Search by name, code, or UOM',
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.blue.shade300,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: Colors.blue.shade300,
                              ),
                              onPressed: () {
                                _clearSearch();
                                setState(() {});
                              },
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          autofocus: true,
                          onChanged: (query) {
                            setState(() {
                              performSearch(query);
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        // Search Results
                        if (searchController.text.isNotEmpty &&
                            searchResults.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              'No items found',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          )
                        else if (searchResults.isNotEmpty)
                          SizedBox(
                            height: 300,
                            child: ListView.separated(
                              itemCount: searchResults.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final item = searchResults[index];
                                return Container(
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.blue.shade50, // Blue background
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.blue.shade100,
                                    ),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    title: Text(
                                      item['varianceName'] ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${item['itemName'] ?? ''}',
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${item['varianceUom'] ?? ''} • ₹${item['variancePrice']?.toStringAsFixed(2) ?? '0.00'} • Code: ${item['varianceitemCode'] ?? ''}',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: Icon(
                                      Icons.add_circle,
                                      color: Colors.blue.shade400,
                                    ),
                                    onTap: () {
                                      _showQuantityDialog(
                                        context,
                                        item,
                                        customerScreenProvider,
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ),

                        const SizedBox(height: 16),

                        // Close Button
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.blue.shade400,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Close',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showQuantityDialog(
    BuildContext context,
    Map<String, dynamic> item,
    EditCustomerScreenProvider customerScreenProvider,
  ) {
    final uom = (item['varianceUom'] ?? '').toString().toLowerCase();
    final varianceName = item['varianceName'] ?? '';
    final itemName = item['itemName'] ?? '';
    final price = item['variancePrice'] ?? 0.0;
    final tax = item['varianceTax'] ?? 0.0;
    final itemCode = item['varianceitemCode'] ?? '';

    // For pcs or pkt → normal quantity input
    if (uom == 'pcs' || uom == 'pkt') {
      final quantityController = TextEditingController(text: '1');

      showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 40,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.grey.shade50,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
                maxWidth: 360,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      Text(
                        'Add $varianceName',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // Quantity Input
                      TextField(
                        controller: quantityController,
                        decoration: InputDecoration(
                          labelText: 'Quantity',
                          labelStyle: TextStyle(color: Colors.blue.shade700),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Price Display
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Text(
                          'Price: ₹${price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                side: BorderSide(color: Colors.blue.shade400),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                double quantity =
                                    double.tryParse(quantityController.text) ??
                                    1;
                                customerScreenProvider.addItemToOrder(
                                  item,
                                  quantity,
                                );
                                Navigator.pop(context); // Close quantity dialog
                                Navigator.pop(context); // Close search dialog
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                backgroundColor: Colors.blue.shade400,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Add to Order',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    } else if (uom == 'kg' || uom == 'kgs') {
      // Use NumericCalculator for weight-based items
      showDialog(
        context: context,
        builder: (context) {
          return NumericCalculator(
            varianceName: varianceName,
            onValueSelected: (weight) {
              customerScreenProvider.addItemToOrder(item, weight);
            },
          );
        },
      );
      Navigator.pop(context); // Close quantity dialog
      Navigator.pop(context); // Close search dialog
    } else {
      // Default fallback for unknown UOM
      final quantityController = TextEditingController(text: '1');
      // Show the same as pcs/pkt
    }
  }

  String _getItemNameForVariance(
    List<Map<String, dynamic>> items,
    String varianceName,
  ) {
    for (final item in items) {
      for (final variance in item['variances']) {
        if (variance['varianceName'] == varianceName) {
          return item['name'] ?? '';
        }
      }
    }
    return '';
  }
}
