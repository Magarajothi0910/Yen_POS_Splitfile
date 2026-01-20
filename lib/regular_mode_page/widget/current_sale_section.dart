import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Global/Provider/current_datetime.dart';
import 'package:yenpos/Global/Widget/custom_button_reuse.dart';
import 'package:yenpos/Global/Widget/custom_colors.dart';
import 'package:yenpos/Global/Widget/custom_sized_box.dart';
import 'package:yenpos/Global/Widget/custom_textWidgets.dart';
import 'package:yenpos/Global/global_data_manager.dart';
import 'package:yenpos/Global/globals_data.dart';

import 'package:yenpos/Sale_order/Widgets/numeric_Calculator.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/provider/payment_provider.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/salesInvoicePayandPrint.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/widgets/customer_search.dart';
import 'package:yenpos/more_page/widgets/other.dart';
import 'package:yenpos/regular_mode_page/widget/custom_reusable_widget/quantity_dialog.dart';
import 'package:yenpos/regular_mode_page/widget/custom_reusable_widget/ticket_generator.dart';
import 'package:yenpos/regular_mode_page/widget/emp_search.dart';
import 'package:yenpos/regular_mode_page/widget/search_drop_filed.dart';

import '../../more_page/providers/bt_provide2.dart';
import '../../printer_screen/provider/printer_config_provider.dart';
import '../provider/cart_page_provider.dart';
import '../split_bill_screen.dart';
import 'viewBillScreen.dart';
import 'package:flutter_swipe_action_cell/flutter_swipe_action_cell.dart';

class CurrentSaleSection extends StatefulWidget {
  CurrentSaleSection({super.key});

  @override
  State<CurrentSaleSection> createState() => CurrentSaleSectionState();
}

class CurrentSaleSectionState extends State<CurrentSaleSection> {
  final TextEditingController _customerNumberController =
      TextEditingController();

  final FocusNode _focusNode = FocusNode();

  Future<bool> showConfirmationDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black54, // Subtle dark overlay
          builder: (context) => Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              constraints: const BoxConstraints(maxWidth: 420),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Warning Icon with blue circle background
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.blue.shade700,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title
                    Text(
                      "Cancel Payment?",
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Subtitle / Message
                    Text(
                      "All entered payment details including payments, discount, and customer info will be lost.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Action Buttons
                    Row(
                      children: [
                        // Stay Button
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context, false),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: Colors.grey.shade300,
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                backgroundColor: Colors.white,
                              ),
                              child: Text(
                                "No, Stay Here",
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Cancel & Close Button
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: () {
                                // Clear only payment-related data (optional enhancement)
                                final prov = Provider.of<SalesInvoiceState>(
                                  context,
                                  listen: false,
                                );
                                prov.updateMultiple(
                                  cashAmount: 0.0,
                                  upiAmount: 0.0,
                                  cardAmount: 0.0,
                                  isUpiPaid: false,
                                  isCardPaid: false,
                                );

                                Navigator.pop(context, true); // Confirm cancel
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade600,
                                elevation: 4,
                                shadowColor: Colors.blue.withOpacity(0.4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                "Yes, Cancel",
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
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
        ) ??
        false; // If dismissed (back button), treat as "No"
  }

  @override
  Widget build(BuildContext context) {
    final printerIp = Provider.of<PrinterProviderpos>(
      context,
      listen: false,
    ).getOverallPrinterIp();
    return Consumer<CurrentSaleProvider>(
      builder: (context, saleProvider, child) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Center(
                            child: CustomButton(
                              text: 'TakeAway',
                              onPressed: () {
                                saleProvider.selectOption('TakeAway');
                              },
                              backgroundColor:
                                  saleProvider.selectedOption == 'TakeAway'
                                  ? CustomColors.blueColor
                                  : CustomColors.white70Color,
                              textColor:
                                  saleProvider.selectedOption == 'TakeAway'
                                  ? CustomColors.whiteColor
                                  : CustomColors.blueColor,
                            ),
                          ),
                          const CustomSizedBox(width: 10),
                          Center(
                            child: CustomButton(
                              text: 'Online',
                              onPressed: () {
                                // final itemProvider = Provider.of<ItemProvider>(
                                //     context,
                                //     listen: false);
                                // final result =
                                //     itemProvider.checkVarianceItemCode("FG011");
                                // print("Result:");
                                // print(result);
                                // Navigator.push(
                                //   context,
                                //   MaterialPageRoute(
                                //       builder: (context) =>
                                //           const ViewInvoiceBoxScreen()),
                                // );
                                saleProvider.selectOption('Online');
                              },
                              backgroundColor:
                                  saleProvider.selectedOption == 'Online'
                                  ? CustomColors.blueColor
                                  : CustomColors.white70Color,
                              textColor: saleProvider.selectedOption == 'Online'
                                  ? CustomColors.whiteColor
                                  : CustomColors.blueColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    color: CustomColors
                        .whiteColor, // Assuming CustomColors.whiteColor is defined in your theme
                    onSelected: (value) {
                      final salesProvider = Provider.of<CurrentSaleProvider>(
                        context,
                        listen: false,
                      );
                      if (value == 'Split') {
                        // ignore: unnecessary_null_comparison
                        if (salesProvider.currentSaleItems == null ||
                            salesProvider.currentSaleItems.isEmpty ||
                            salesProvider.currentSaleItems.length < 2) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'No items to split! Maximum 2 or more items required',
                                style: TextStyle(
                                  fontFamily: "Poppins",
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              backgroundColor: Colors.red,
                              duration: Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                              margin: EdgeInsets.only(
                                left: 20,
                                bottom: 20,
                                right: 680,
                              ),
                            ),
                          );
                          return;
                        }

                        // ✅ Print `currentSaleItems` in console before opening dialog
                        for (var item in salesProvider.currentSaleItems) {}
                        showDialog(
                          context: context,
                          builder: (context) => SplitBillDialog(
                            initialItems: salesProvider
                                .currentSaleItems, // Send original items
                          ),
                        );
                      }
                      if (value == 'Merge') {
                        // ignore: unnecessary_null_comparison
                        // if (salesProvider.currentSaleItems == null ||
                        //     salesProvider.currentSaleItems.isEmpty ||
                        //     salesProvider.currentSaleItems.length < 1) {
                        //   ScaffoldMessenger.of(context).showSnackBar(
                        //     SnackBar(
                        //       content: Text(
                        //         'No items to Merge! Maximum 1 or more items required',
                        //         style: TextStyle(fontWeight: FontWeight.bold),
                        //       ),
                        //       backgroundColor: Colors.red,
                        //       duration: Duration(seconds: 2),
                        //       behavior: SnackBarBehavior.floating,
                        //       margin: EdgeInsets.only(left: 20, bottom: 20, right: 680),
                        //     ),
                        //   );
                        //   return;
                        // }
                        // _viewBills(context);
                        ViewSavedBillsWidget().viewBills(context);
                      }
                      if (value == 'Clear') {
                        salesProvider.clearItems();
                      }
                    },
                    itemBuilder: (BuildContext context) {
                      return {'Split', 'Merge', 'Clear'}.map((String choice) {
                        return PopupMenuItem<String>(
                          value: choice,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                choice == 'Split'
                                    ? Icons.call_split
                                    : choice == 'Merge'
                                    ? Icons.merge_type
                                    : Icons.clear_all,
                                color: Theme.of(context).iconTheme.color,
                              ),
                              SizedBox(width: 8),
                              Text(
                                choice,
                                style: TextStyle(
                                  fontFamily: "Poppins",
                                  fontSize: 16,
                                ), // Increased font size
                              ),
                            ],
                          ),
                        );
                      }).toList();
                    },
                  ),
                ],
              ),
            ),
            Consumer<SalesInvoiceState>(
              builder: (context, value, child) {
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(flex: 1, child: EmployeeSearch()),
                      SizedBox(width: 5),
                      Expanded(
                        flex: 2,
                        child: CustomerSearchDropdown(
                          readOnly: false,
                          showTopProducts: true,
                          customerNumberController: _customerNumberController,
                          focusNode: _focusNode,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Expanded(
              child:
                  saleProvider.saleStatus != 'hold' &&
                      saleProvider.currentSaleItems.isNotEmpty
                  ? ListView.builder(
                      itemCount: saleProvider.currentSaleItems.length,
                      itemBuilder: (context, index) {
                        final item = saleProvider.currentSaleItems[index];

                        return FutureBuilder(
                          future: Hive.openBox('items').then(
                            (lazyBox) =>
                                lazyBox.get('branchwiseItems_$aliasname'),
                          ),
                          builder: (context, snapshot) {
                            Map<dynamic, dynamic>? branchwiseItems = {};
                            if (snapshot.hasData && snapshot.data is Map) {
                              branchwiseItems = Map<dynamic, dynamic>.from(
                                snapshot.data as Map,
                              );
                            }

                            double systemStock = 0.0;

                            final itemName =
                                item['itemName']?.toString() ?? 'Unknown Item';
                            final varianceName =
                                item['varianceData']['varianceName']
                                    ?.toString() ??
                                '';

                            if (branchwiseItems != null &&
                                branchwiseItems['data'] != null &&
                                branchwiseItems['data'] is Map &&
                                branchwiseItems['data'][itemName] != null) {
                              final itemData =
                                  branchwiseItems['data'][itemName] as Map;

                              final varianceMap = itemData['variance'] as Map?;
                              if (varianceMap != null) {
                                Map? varianceData;

                                for (var v in varianceMap.values) {
                                  if (v['varianceName']?.toString() ==
                                      varianceName) {
                                    varianceData = v;
                                    break;
                                  }
                                }

                                if (varianceData != null &&
                                    varianceData['branchwise'] != null &&
                                    varianceData['branchwise'][aliasname] !=
                                        null) {
                                  systemStock =
                                      (varianceData['branchwise'][aliasname]['systemStock_$aliasname']
                                              as num?)
                                          ?.toDouble() ??
                                      0.0;
                                }
                              }
                            }

                            return SwipeActionCell(
                              backgroundColor: Colors.white,
                              trailingActions: [
                                SwipeAction(
                                  performsFirstActionWithFullSwipe: true,
                                  onTap: (handler) async {
                                    saleProvider.removeItem(index);
                                    await handler(true);
                                  },
                                  color: Colors.red,
                                  content: const Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                              key: Key(
                                '${saleProvider.currentSaleItems[index]}',
                              ),
                              child: ListTile(
                                onTap: () {
                                  final uom =
                                      item['varianceData']['variance_Uom']
                                          ?.toString()
                                          ?.toLowerCase() ??
                                      "";

                                  final price =
                                      (item['varianceData']['variance_Defaultprice']
                                              as num?)
                                          ?.toDouble() ??
                                      0.0;

                                  final qty =
                                      (item['quantity'] as num?)?.toDouble() ??
                                      1.0;

                                  if (uom == 'kgs') {
                                    showDialog(
                                      context: context,
                                      builder: (dialogContext) {
                                        return NumericCalculator(
                                          varianceName:
                                              item['varianceData']['varianceName'],
                                          onValueSelected: (weight) {
                                            if (weight <= 0) {
                                              ScaffoldMessenger.of(
                                                dialogContext,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    "Invalid weight entered.",
                                                  ),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                              return;
                                            }

                                            if (weight > systemStock) {
                                              ScaffoldMessenger.of(
                                                dialogContext,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    "Selected weight (${weight.toStringAsFixed(3)} kg) exceeds available stock (${systemStock.toStringAsFixed(3)} kg).",
                                                  ),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                              return;
                                            }

                                            saleProvider.updateItemQuantity(
                                              index,
                                              weight,
                                            );
                                          },
                                        );
                                      },
                                    );
                                  } else {
                                    showCommonQuantityDialog(
                                      context: context,
                                      itemName:
                                          item['itemName'] ??
                                          item['itemData']?['itemName'] ??
                                          'Unknown',
                                      varianceName: varianceName,
                                      price: price,
                                      initialQuantity: qty,
                                      onAddToCart: (newQty) {
                                        saleProvider.updateItemQuantity(
                                          index,
                                          newQty,
                                        );
                                      },
                                    );
                                  }
                                },
                                title: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CustomText(
                                          text:
                                              item['varianceData']['varianceName'] ??
                                              "",
                                          style: TextStyle(
                                            fontFamily: "Poppins",
                                            color: CustomColors.black
                                                .withOpacity(0.7),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        CustomText(
                                          text: saleProvider
                                              .buildQuantityPriceDisplay(item),
                                          style: const TextStyle(
                                            fontFamily: "Poppins",
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                    CustomText(
                                      text:
                                          '₹${saleProvider.calculateItemTotal(item).toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontFamily: "Poppins",
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: CustomColors.black.withOpacity(
                                          0.8,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: 100,
                            color: CustomColors.black.withOpacity(0.1),
                          ),
                          const Text(
                            'No items in cart',
                            style: TextStyle(fontFamily: "Poppins"),
                          ),
                        ],
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CustomSizedBox(height: 16),

                  Center(
                    child: CustomButton(
                      text:
                          'Charge ₹ ${saleProvider.calculateTotal().round().toString()}',
                      onPressed: () async {
                        CurrentDatetimeService().fetchCurrentDateTime();
                        debugPrint("currentDate:${currentDate.value}");
                        debugPrint("currentTime:${currentTime.value}");

                        double totalAmount = saleProvider.calculateTotal();
                        if (printerIp == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Set Printer Ip"),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        if (totalAmount == 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Cart is empty! Add items to proceed.",
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        // === STOCK VALIDATION ===
                        final globalManager = GlobalDataManager();
                        final branchwiseItemsBox = await Hive.openBox('items');
                        final branchwiseData = await branchwiseItemsBox.get(
                          'branchwiseItems_$aliasname',
                        );

                        Map<dynamic, dynamic>? branchwiseItems = {};
                        if (branchwiseData is Map) {
                          branchwiseItems = Map<dynamic, dynamic>.from(
                            branchwiseData,
                          );
                        }

                        List<Map<String, dynamic>> stockCheckList = [];
                        bool hasInsufficient = false;

                        for (var item in saleProvider.currentSaleItems) {
                          debugPrint("Checking stock for item: $item");
                          final itemName =
                              item['itemName']?.toString() ??
                              item['itemData']?['itemName']?.toString() ??
                              '';
                          final varianceName =
                              item['varianceData']['varianceName']
                                  ?.toString() ??
                              'Unknown Item';
                          debugPrint("Checking stock for item: $varianceName");
                          final itemUom =
                              (item['varianceData']['variance_Uom']
                                          ?.toString() ??
                                      '')
                                  .toLowerCase();
                          final bool isKg = itemUom.contains('kg');

                          double requiredQty = isKg
                              ? (item['weight'] as num?)?.toDouble() ?? 0.0
                              : (item['quantity'] as num?)?.toDouble() ?? 0.0;

                          double liveStock = globalManager.getSystemStock(
                            aliasname,
                            varianceName,
                          );
                          double availableStock = liveStock >= 0
                              ? liveStock
                              : 0.0;

                          if (liveStock < 0 &&
                              branchwiseItems != null &&
                              branchwiseItems['data']?[itemName] != null) {
                            final itemData = branchwiseItems['data'][itemName];
                            final varianceMap = itemData['variance'] as Map?;
                            if (varianceMap != null) {
                              for (var v in varianceMap.values) {
                                if (v['varianceName']?.toString() ==
                                    varianceName) {
                                  availableStock =
                                      (v['branchwise']?[aliasname]?['systemStock_$aliasname']
                                              as num?)
                                          ?.toDouble() ??
                                      0.0;
                                  break;
                                }
                              }
                            }
                          }

                          final bool sufficient =
                              requiredQty <= availableStock + 0.001;
                          if (!sufficient) hasInsufficient = true;

                          stockCheckList.add({
                            'item': varianceName,
                            'required': requiredQty,
                            'available': availableStock,
                            'uom': isKg ? 'kg' : 'pcs',
                            'status': sufficient ? 'OK' : 'Insufficient',
                            'isKg': isKg,
                          });
                        }

                        if (hasInsufficient) {
                          final List<Map<String, dynamic>> insufficientItems =
                              stockCheckList
                                  .where(
                                    (row) => row['status'] == 'Insufficient',
                                  )
                                  .toList();

                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (ctx) => Dialog(
                              alignment: Alignment.centerLeft,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              elevation: 30,
                              backgroundColor: Colors.transparent,
                              child: Container(
                                width: MediaQuery.of(context).size.width * 0.6,
                                constraints: const BoxConstraints(
                                  maxHeight: 700,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Colors.white, Colors.grey.shade50],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 30,
                                      offset: const Offset(0, 15),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Header - Red Alert
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 20,
                                        horizontal: 24,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade500,
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(20),
                                            ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.warning_amber_rounded,
                                            color: Colors.white,
                                            size: 40,
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  "Insufficient Stock",
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  "The following items exceed available stock. Please adjust quantities.",
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withOpacity(0.9),
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    Flexible(
                                      child: Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 10),

                                            // Table Header
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 14,
                                                    horizontal: 12,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade400,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    flex: 5,
                                                    child: Text(
                                                      "Item",
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Center(
                                                      child: Text(
                                                        "Required",
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 15,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Center(
                                                      child: Text(
                                                        "Available",
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 15,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Center(
                                                      child: Text(
                                                        "Shortage",
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 15,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            const SizedBox(height: 12),

                                            Flexible(
                                              child: ListView.separated(
                                                shrinkWrap: true,
                                                separatorBuilder: (_, __) =>
                                                    const SizedBox(height: 10),
                                                itemCount:
                                                    insufficientItems.length,
                                                itemBuilder: (context, i) {
                                                  final row =
                                                      insufficientItems[i];
                                                  final double shortage =
                                                      (row['required']
                                                          as double) -
                                                      (row['available']
                                                          as double);

                                                  return Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 16,
                                                          horizontal: 12,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.red.shade50,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                      border: Border.all(
                                                        color:
                                                            Colors.red.shade500,
                                                        width: 1.8,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          flex: 5,
                                                          child: Text(
                                                            row['item'],
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontSize: 15,
                                                              color: Colors
                                                                  .red
                                                                  .shade600,
                                                            ),
                                                          ),
                                                        ),
                                                        Expanded(
                                                          flex: 2,
                                                          child: Center(
                                                            child: Text(
                                                              "${row['required'].toStringAsFixed(row['isKg'] ? 3 : 0)} ${row['uom']}",
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Colors
                                                                    .red
                                                                    .shade600,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        Expanded(
                                                          flex: 2,
                                                          child: Center(
                                                            child: Text(
                                                              "${row['available'].toStringAsFixed(row['isKg'] ? 3 : 0)} ${row['uom']}",
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Colors
                                                                    .red
                                                                    .shade600,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        Expanded(
                                                          flex: 2,
                                                          child: Center(
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        16,
                                                                    vertical: 8,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                color: Colors
                                                                    .red
                                                                    .shade500,
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      8,
                                                                    ),
                                                              ),
                                                              child: Text(
                                                                "-${shortage.toStringAsFixed(row['isKg'] ? 3 : 0)}",
                                                                style: const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 14,
                                                                ),
                                                              ),
                                                            ),
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
                                      ),
                                    ),

                                    // Footer
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        24,
                                        0,
                                        24,
                                        24,
                                      ),
                                      child: SizedBox(
                                        width: double.infinity,
                                        height: 56,
                                        child: ElevatedButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.red.shade500,
                                            foregroundColor: Colors.white,
                                            elevation: 8,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                          ),
                                          child: const Text(
                                            "Close & Adjust Quantities",
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                          return; // Stop payment
                        }

                        showDialog(
                          context: context,
                          barrierDismissible: true,
                          builder: (BuildContext context) {
                            return WillPopScope(
                              onWillPop: () async =>
                                  await showConfirmationDialog(context),
                              child: Dialog(
                                alignment: Alignment.centerLeft,
                                backgroundColor: CustomColors.whiteColor,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: CustomSizedBox(
                                    width:
                                        MediaQuery.of(context).size.width * 0.5,
                                    child: SalesInvoicePayAndPrint(
                                      totalAmount: totalAmount,
                                      holdBillId: saleProvider.holdBillId ?? '',
                                      customerNumber:
                                          _customerNumberController.text,
                                      onDismiss: () {
                                        debugPrint(
                                          'Payment completed or dismissed safely',
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ).then((_) {
                          saleProvider.discountPercentage = 0.0;
                          saleProvider.customCharge = 0.0;
                          saleProvider.calculateTotal();
                          _customerNumberController.clear();
                        });
                      },
                      backgroundColor: CustomColors.primaryColor,
                      textColor: CustomColors.whiteColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 100,
                        vertical: 22,
                      ),
                    ),
                  ),

                  const CustomSizedBox(height: 10),

                  // Row(
                  //   mainAxisAlignment: MainAxisAlignment.center,
                  //   children: [
                  //     const ViewSavedBillsWidget(),
                  //     const CustomSizedBox(width: 5),
                  //     Center(
                  //       child: CustomButton(
                  //         text: 'Save Bill',
                  //         onPressed: () {
                  //           Provider.of<CurrentSaleProvider>(context,
                  //                   listen: false)
                  //               .saveBill(context);
                  //         },
                  //         backgroundColor: CustomColors.white70Color,
                  //         textColor: CustomColors.blueColor,
                  //       ),
                  //     ),
                  //   ],
                  // ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      //Expanded(child: ViewSavedBillsWidget()),
                      Expanded(
                        child: CustomButton(
                          text: 'ViewBills',
                          onPressed: () {
                            ViewSavedBillsWidget().viewBills(context);
                          },
                          backgroundColor: CustomColors.white70Color,
                          textColor: CustomColors.blueColor,
                        ),
                      ),
                      const CustomSizedBox(width: 2),

                      // ... Inside the CurrentSaleSection's build method ...
                      Expanded(
                        child: CustomButton(
                          text: 'SaveBill',
                          onPressed: () {
                            // Check if current sale items are empty
                            if (saleProvider.currentSaleItems.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'No items to save!',
                                    style: TextStyle(
                                      fontFamily: "Poppins",
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  backgroundColor: Colors.red,
                                  duration: Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                  margin: EdgeInsets.only(
                                    left: 20,
                                    bottom: 20,
                                    right: 680,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                              return;
                            }
                            promptForSaveBillsTitle(context, saleProvider);
                          },
                          backgroundColor: CustomColors.white70Color,
                          textColor: CustomColors.blueColor,
                        ),
                      ),
                      const CustomSizedBox(width: 2),
                      // Center(
                      //   child: CustomButton(
                      //     text: 'PreInvo',
                      //     onPressed: () async {
                      //       final saleProvider = Provider.of<CurrentSaleProvider>(context, listen: false);
                      //       final currentItems = saleProvider.currentSaleItems;

                      //       if (currentItems.isNotEmpty) {
                      //         // Log the current items to the console
                      //         for (var item in currentItems) {
                      //           // Print each item in the cart
                      //         }
                      //         final printerProvider = Provider.of<PrinterProviderpos>(context, listen: false);

                      //         // ignore: unused_local_variable
                      //         String printerIp = printerProvider.getOverallPrinterIp().toString();
                      //         // Prepare the items for printing
                      //         // await SIPreInvoicePrinter.printReceipt(
                      //         //   ipAddress:
                      //         //       printerIp, // Replace with the actual printer IP
                      //         //   invoiceDataList:
                      //         //       currentItems, // Pass current cart items
                      //         //   receiptType: "Pre-Invoice",
                      //         // );

                      //         saleProvider.clearItems();
                      //       } else {}
                      //     },
                      //     backgroundColor: CustomColors.white70Color,
                      //     textColor: CustomColors.blueColor,
                      //   ),
                      // ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(String title) {
    return Expanded(
      child: Text(
        title,
        style: TextStyle(
          fontFamily: "Poppins",
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _viewBills(BuildContext context) async {
    var box = await Hive.openBox('cartBox');

    List<Map<String, dynamic>> holdBills = box.values
        .where((bill) => bill is Map && bill['status'] == 'hold')
        .map((bill) => Map<String, dynamic>.from(bill as Map))
        .toList();

    if (holdBills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No saved bills available!'),
          backgroundColor: Colors.red,
          margin: EdgeInsets.only(left: 20, bottom: 20, right: 680),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        Set<int> selectedBills = {}; // Store selected bill indices
        List<String> selectedTicketNumbers = []; // Store selected ticket names

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Merge With..",
                    style: TextStyle(
                      fontFamily: "Poppins",
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: selectedBills.isNotEmpty
                        ? () async {
                            // Merge selected bills
                            await _mergeSelectedBills(
                              context,
                              selectedBills.toList(),
                              box,
                              selectedTicketNumbers,
                            );
                            Navigator.of(context).pop();
                          }
                        : null,
                    child: Text(
                      "CONTINUE",
                      style: TextStyle(
                        fontFamily: "Poppins",
                        color: selectedBills.isNotEmpty
                            ? CustomColors.blueColor
                            : Colors.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    color: CustomColors.blueColor,
                    child: Row(
                      children: [
                        SizedBox(width: 40),
                        _buildHeader("NAME"),
                        _buildHeader("AMOUNT"),
                        _buildHeader("TIME"),
                        _buildHeader("EMPLOYEE"),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 400,
                    height: 300,
                    child: ListView.builder(
                      itemCount: holdBills.length,
                      itemBuilder: (context, index) {
                        final bill = holdBills[index];
                        DateTime date = DateTime.parse(bill['date']);
                        String formattedDate = DateFormat(
                          'dd-MM-yyyy hh:mm a',
                        ).format(date);
                        double amount = bill['total'] ?? 0.0;

                        return Container(
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey[800]!),
                            ),
                          ),
                          child: ListTile(
                            leading: Checkbox(
                              value: selectedBills.contains(index),
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    selectedBills.add(index);
                                    // Collect selected ticket numbers
                                    final selectedBill = holdBills[index];
                                    String ticketNumber =
                                        selectedBill['ticketName'] ?? "Unknown";
                                    selectedTicketNumbers.add(ticketNumber);
                                  } else {
                                    selectedBills.remove(index);
                                    final selectedBill = holdBills[index];
                                    String ticketNumber =
                                        selectedBill['ticketName'] ?? "Unknown";
                                    selectedTicketNumbers.remove(ticketNumber);
                                  }
                                });
                              },
                              activeColor: CustomColors.blueColor,
                            ),
                            title: Text(
                              bill['ticketName'],
                              style: TextStyle(
                                fontFamily: "Poppins",
                                color: Colors.black,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              formattedDate,
                              style: TextStyle(
                                fontFamily: "Poppins",
                                color: Colors.black,
                                fontSize: 14,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "₹${amount.toStringAsFixed(2)}",
                                  style: TextStyle(
                                    fontFamily: "Poppins",
                                    color: Colors.black,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(width: 10),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () async {
                                    await box.deleteAt(index);
                                    setState(() {
                                      holdBills.removeAt(index);
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Function to merge selected bills and save them to Hive
  Future<void> _mergeSelectedBills(
    BuildContext context,
    List<int> selectedBillIndices,
    Box box,
    List<String> selectedTicketNumbers,
  ) async {
    if (selectedBillIndices.isEmpty) {
      // Step 1
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No bills selected to merge!'),
          backgroundColor: Colors.red,
          margin: EdgeInsets.only(left: 20, bottom: 20, right: 680),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Step 2: Initialize mergedBill map
    Map<String, dynamic> mergedBill = {
      'holdId': DateTime.now().millisecondsSinceEpoch
          .toString(), // Unique hold ID
      'items': [],
      'total': 0.0,
      'date': DateTime.now().toIso8601String(),
      'status': 'hold',
      'ticketName': selectedTicketNumbers.join(" + "), // Merged ticket name
    };

    double totalAmount = 0.0;

    // Step 3: Aggregate selected bills
    for (int index in selectedBillIndices) {
      Map<String, dynamic> bill = box.getAt(index);
      totalAmount += double.parse(bill['total'].toString());
      mergedBill['items'].addAll(bill['items']);
    }
    mergedBill['total'] = totalAmount;

    // Step 4: Save merged bill to Hive
    await box.add(mergedBill);

    // Step 5: Prepare data for API posting
    // ignore: unused_local_variable
    Map<String, dynamic> apiData = {
      'holdId': mergedBill['holdId'],
      'date': mergedBill['date'],
      'items': mergedBill['items'].map((item) {
        return {
          'itemCode': item['itemCode'],
          'itemName': item['itemName'],
          'qty': item['qty'],
          'price': item['price'],
          'category': item['category'],
        };
      }).toList(),
      'total': mergedBill['total'].toString(),
      'status': 'hold',
      'ticketName': mergedBill['ticketName'],
    };

    // Step 6: Optionally clear selected data from Hive
    selectedBillIndices.sort(
      (a, b) => b.compareTo(a),
    ); // Sort descending to avoid index shifting
    for (int index in selectedBillIndices) {
      await box.deleteAt(index); // Remove selected bills
    }

    // Optional API Post (Commented Out for now)
    // try {
    //   final response = await http.post(
    //     Uri.parse('http://192.168.1.114:8888/fastapi/holds/'),
    //     headers: {'Content-Type': 'application/json'},
    //     body: jsonEncode(apiData),
    //   );
    //   if (response.statusCode == 200 || response.statusCode == 201) {
    //     print('Merged bill saved and posted successfully!');
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       SnackBar(
    //           content: Text('Merged bill saved and posted successfully!'),
    //           backgroundColor: Colors.green),
    //     );
    //   } else {
    //     print('Failed to post merged data to server');
    //   }
    // } catch (e) {
    //   print('Error posting data to server: $e');
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(
    //       content: Text('Error posting data to server: $e'),
    //       backgroundColor: Colors.red,
    //       margin: EdgeInsets.only(left: 20, bottom: 20, right: 680),
    //       behavior: SnackBarBehavior.floating,
    //     ),
    //   );
    // }
  }

  void _promptForMergeTitle(
    BuildContext context,
    CurrentSaleProvider saleProvider,
  ) async {
    var box = await Hive.openBox('cartBox');
    List<Map<String, dynamic>> allBills = [];
    for (int i = 0; i < box.length; i++) {
      var bill = box.getAt(i);
      if (bill is Map && bill['status'] == 'hold') {
        allBills.add({...Map<String, dynamic>.from(bill), '_originalIndex': i});
      }
    }

    String formattedTime = DateFormat('hh:mm a').format(DateTime.now());
    TextEditingController titleController = TextEditingController(
      text: "Merged Ticket - $formattedTime",
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        Set<int> selectedBills = {}; // Track selected bill indices

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Select Bills to Merge",
                    style: TextStyle(
                      fontFamily: "Poppins",
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: selectedBills.isNotEmpty
                        ? () async {
                            String ticketName = titleController.text.trim();
                            if (ticketName.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please enter a valid ticket name!',
                                  ),
                                  backgroundColor: Colors.red,
                                  duration: Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                  margin: EdgeInsets.only(
                                    left: 20,
                                    bottom: 20,
                                    right: 680,
                                  ),
                                ),
                              );
                              return;
                            }

                            try {
                              // Collect selected bills and current sale items
                              List<Map<String, dynamic>> allItems = [
                                ...saleProvider.currentSaleItems,
                              ];
                              double totalAmount = saleProvider
                                  .calculateTotal();
                              List<String> ticketNames = [ticketName];

                              for (int index in selectedBills) {
                                final bill = allBills[index];
                                allItems.addAll(
                                  (bill['items'] as List).map(
                                    (item) => Map<String, dynamic>.from(item),
                                  ),
                                );
                                totalAmount += (bill['total'] ?? 0.0)
                                    .toDouble();
                                ticketNames.add(
                                  bill['ticketName'] ?? 'Unnamed Ticket',
                                );
                              }

                              // Create merged bill
                              Map<String, dynamic> mergedBill = {
                                'holdId': DateTime.now().millisecondsSinceEpoch
                                    .toString(),
                                'items': allItems,
                                'total': totalAmount,
                                'date': DateTime.now().toIso8601String(),
                                'status': 'hold',
                                'ticketName': ticketNames.join(" + "),
                                'isMerged': true,
                              };

                              // Save merged bill
                              await box.add(mergedBill);

                              // Delete selected bills
                              selectedBills.toList()
                                ..sort((a, b) => b.compareTo(a))
                                ..forEach((index) async {
                                  await box.deleteAt(
                                    allBills[index]['_originalIndex'],
                                  );
                                });

                              // Clear current sale items
                              saleProvider.clearItems();

                              // Show success message
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Merged ${selectedBills.length + 1} bills successfully!',
                                  ),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                  margin: const EdgeInsets.only(
                                    left: 20,
                                    bottom: 20,
                                    right: 680,
                                  ),
                                ),
                              );

                              Navigator.pop(context);
                              _viewBills(context);
                            } catch (e) {
                              print('Error merging bills: $e');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error merging bills: $e'),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                  margin: const EdgeInsets.only(
                                    left: 20,
                                    bottom: 20,
                                    right: 680,
                                  ),
                                ),
                              );
                            }
                          }
                        : null,
                    child: Text(
                      "Merge",
                      style: TextStyle(
                        fontFamily: "Poppins",
                        color: selectedBills.isNotEmpty
                            ? CustomColors.blueColor
                            : Colors.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        hintText: "Enter merged ticket name",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: CustomColors.blueColor,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: CustomColors.blueColor,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    color: CustomColors.blueColor,
                    child: Row(
                      children: [
                        const SizedBox(width: 40),
                        _buildHeader("SELECT"),
                        _buildHeader("NAME"),
                        _buildHeader("AMOUNT"),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 400,
                    height: 300,
                    child: ListView.builder(
                      itemCount: allBills.length,
                      itemBuilder: (context, index) {
                        final bill = allBills[index];
                        DateTime date = DateTime.parse(bill['date']);
                        String formattedDate = DateFormat(
                          'dd-MM-yyyy hh:mm a',
                        ).format(date);
                        double amount = bill['total'] ?? 0.0;

                        return ListTile(
                          leading: Checkbox(
                            value: selectedBills.contains(index),
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  selectedBills.add(index);
                                } else {
                                  selectedBills.remove(index);
                                }
                              });
                            },
                            activeColor: CustomColors.blueColor,
                          ),
                          title: Text(
                            bill['ticketName'] ?? 'Unnamed Ticket',
                            style: const TextStyle(
                              fontFamily: "Poppins",
                              color: CustomColors.black,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            formattedDate,
                            style: const TextStyle(
                              fontFamily: "Poppins",
                              color: CustomColors.black,
                              fontSize: 14,
                            ),
                          ),
                          trailing: Text(
                            "₹${amount.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontFamily: "Poppins",
                              color: CustomColors.black,
                              fontSize: 16,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: CustomColors.blueColor,
                    foregroundColor: CustomColors.whiteColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text("Cancel"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  //   void promptForSaveBillsTitle(BuildContext context, CurrentSaleProvider saleProvider) {
  void promptForSaveBillsTitle(
    BuildContext context,
    CurrentSaleProvider saleProvider,
  ) async {
    final ticketTitle = await TicketSequenceGenerator.generate();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: CustomColors.whiteColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            "Save Bill as: $ticketTitle",
            style: TextStyle(
              fontFamily: "Poppins",
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              "This bill will be saved as '$ticketTitle'. The ticket name is auto-generated and cannot be edited.",
              style: TextStyle(fontFamily: "Poppins", fontSize: 16),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(
                backgroundColor: CustomColors.blueColor,
                foregroundColor: CustomColors.whiteColor,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                // Save the current bill with the auto-generated title
                await saleProvider.saveBillWithTitle(context, ticketTitle);

                // Clear items after saving
                saleProvider.clearItems();

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Bill saved successfully as $ticketTitle!'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              style: TextButton.styleFrom(
                backgroundColor: CustomColors.blueColor,
                foregroundColor: CustomColors.whiteColor,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                "Save Bill",
                style: TextStyle(
                  fontFamily: "Poppins",
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
