import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Global/Widget/filesave.dart';
import 'package:yenpos/Global/global_data_manager.dart';
import 'package:yenpos/Global/globals_data.dart' as globals;
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yenpos/Sale_order/Models/held_order_model.dart';
import 'package:yenpos/Sale_order/Provider/cartProvider.dart';
import 'package:yenpos/Sale_order/Provider/cart_selection_provider.dart';
import 'package:yenpos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yenpos/Sale_order/Provider/detailsProvider.dart';
import 'package:yenpos/Sale_order/Provider/get_sales_order_service.dart';
import 'package:yenpos/Sale_order/Screens/all_orders.dart';
import 'package:yenpos/Sale_order/Screens/approval_order_status_data.dart';
import 'package:yenpos/Sale_order/Screens/create_sales_order.dart';
import 'package:yenpos/Sale_order/Widgets/customAll_keyboard.dart';
import 'package:yenpos/Sale_order/Widgets/employee_selection.dart';
import 'package:yenpos/Sale_order/Widgets/hold_order_status_file.dart';
import 'package:yenpos/Sale_order/Widgets/image-picker-widget.dart';
import 'package:yenpos/Sale_order/Widgets/mobilenumber_search.dart';
import 'package:yenpos/Sale_order/Widgets/photoScreen.dart';
import 'package:yenpos/Sale_order/Widgets/restore_order_date.dart';
import 'package:yenpos/Sale_order/Widgets/voice_recording.dart';

import '../../../../Global/Audio Player/audio_provider.dart';
import '../../../../Global/Audio Player/audio_screen.dart';

import '../../Global/Widget/custom_button_reuse.dart';

class CustomerDetails extends StatefulWidget {
  const CustomerDetails({super.key});

  @override
  _CustomerDetailsState createState() => _CustomerDetailsState();
}

class _CustomerDetailsState extends State<CustomerDetails> {
  final _formKey = GlobalKey<FormState>();
  bool _isFormValid = false;

  int? _selectedRadioValue = 0; // The selected radio button value
  // String? audioPlayerId;

  List<Map<String, String>> suggestions = [];
  bool isSuggestionsVisible = false;
  TextEditingController controller123 = TextEditingController();

  final _remarkFocus = FocusNode();
  final _addressFocus = FocusNode();
  final _landMarkFocus = FocusNode();
  final FocusNode _otherEventFocus = FocusNode();
  void showToast(String message, BuildContext context) {
    if (!mounted) return; // ✅ avoid calling if widget disposed
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _validateFullOrderForm() {
    final customerScreenProvider = Provider.of<CustomerScreenProvider>(
      context,
      listen: false,
    );

    String mobile = customerScreenProvider.mobileNoController.text.trim();
    String event = customerScreenProvider.selectedEvent ?? '';
    String deliveryDate = customerScreenProvider.dateController.text.trim();
    String deliveryTime = customerScreenProvider.timeController.text.trim();
    String deliveryType = customerScreenProvider.selectedDeliveryType ?? '';
    String salesPerson = customerScreenProvider.searchController.text.trim();

    if (mobile.isEmpty ||
        mobile.length != 10 ||
        !RegExp(r'^\d{10}$').hasMatch(mobile)) {
      showToast(
        'Please enter a valid 10-digit customer mobile number',
        context,
      );
      return false;
    }

    if (event.isEmpty) {
      showToast('Please select an event', context);
      return false;
    }

    if (event == 'Others' &&
        (customerScreenProvider.otherEventController.text.isEmpty)) {
      showToast('Please enter the event name', context);
      return false;
    }

    if ((event != 'Others') &&
        (customerScreenProvider.birthdaydateController.text.isEmpty)) {
      showToast('Please select event date', context);
      return false;
    }

    if (deliveryDate.isEmpty || deliveryTime.isEmpty) {
      showToast('Please select delivery date and time', context);
      return false;
    }

    if (deliveryType.isEmpty) {
      showToast('Please select delivery type', context);
      return false;
    }

    if (salesPerson.isEmpty) {
      showToast('Please select a salesperson', context);
      return false;
    }

    if (globals.cartItems.isEmpty) {
      showToast('Please add at least one item to cart', context);
      return false;
    }

    return true;
  }

  bool _validateOrderDetails() {
    final customerScreenProvider = Provider.of<CustomerScreenProvider>(
      context,
      listen: false,
    );
    final detailsProvider = Provider.of<DetailsProvider>(
      context,
      listen: false,
    );

    // Validate salesperson
    String selectedSalesperson = customerScreenProvider.searchController.text
        .trim();
    if (!detailsProvider.employeeNames.contains(selectedSalesperson)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Add a valid salesperson.')));
      return false;
    }

    // Validate mobile number
    String enteredMobileNumber = customerScreenProvider.mobileNoController.text
        .trim();
    if (enteredMobileNumber.isEmpty ||
        enteredMobileNumber.length != 10 ||
        !RegExp(r'^\d{10}$').hasMatch(enteredMobileNumber)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit mobile number.'),
        ),
      );
      return false;
    }

    // Validate box items
    bool hasInvalidBoxItems = globals.cartItems.any((item) {
      if (item.isBoxItem.toString().toLowerCase() == 'yes') {
        int boxQty = item.boxQuantity ?? 0; // treat null as 0
        int quantity = item.quantity.value;
        return boxQty <= 0 || quantity <= 0; // either invalid
      }
      return false;
    });

    if (hasInvalidBoxItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter valid box quantity for selected items.'),
        ),
      );
      return false;
    }

    return true;
  }

  bool _requiresApproval() {
    final provider = Provider.of<CustomerScreenProvider>(
      context,
      listen: false,
    );

    // 🔴 HIGHEST PRIORITY RULE
    // If restoring an APPROVED order → NEVER require approval again
    if (provider.isRestoringApprovalOrder) {
      final status = provider.originalApprovalStatus?.toLowerCase() ?? '';

      if (status.contains('approved')) {
        return false; // ✅ FORCE PLACE ORDER
      }

      // Pending / Rejected → must go for approval again
      if (status.contains('pending') || status.contains('rejected')) {
        return true;
      }
    }

    // ---------------- NORMAL NEW ORDER LOGIC ----------------

    final lazyBox = HiveManager.discounts;
    final discountsFromBox = lazyBox.values.toList();

    List<Map<String, dynamic>> discountList = [];
    for (var inner in discountsFromBox) {
      if (inner is List) {
        for (var d in inner) {
          if (d is Map) {
            discountList.add(Map<String, dynamic>.from(d));
          }
        }
      }
    }

    final activeDiscounts = discountList
        .where((d) => d['status'] == 'active')
        .toList();

    final discountThreshold = activeDiscounts.isNotEmpty
        ? (activeDiscounts.first['discountPercentage'] ?? 0)
        : 0;

    return globals.cartItems.any((item) {
      final itemDiscount = item.itemWiseDiscount ?? 0;
      return itemDiscount > discountThreshold;
    });
  }

  @override
  void initState() {
    super.initState();

    final customerScreenProvider = Provider.of<CustomerScreenProvider>(
      context,
      listen: false,
    );
    customerScreenProvider.setSelectedEvent("Birth Day");
    customerScreenProvider.setSelectedDeliveryType("Pickup By Customer");
  }

  void handleRecordingComplete(String path) {
    setState(() {
      final customerScreenProvider = Provider.of<CustomerScreenProvider>(
        context,
        listen: false,
      );
      customerScreenProvider.recordedFilePath = path;

      customerScreenProvider.recordedFilePath = path;

      // 🔥 FORCE recreate AudioPlayerWidget
      customerScreenProvider.audioPlayer = null;
      customerScreenProvider.notifyListeners();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);

    final audioprovider = Provider.of<AudioProvider>(context, listen: false);
    final customerScreenProvider = Provider.of<CustomerScreenProvider>(context);
    final apiSalesprovider = Provider.of<ApiServiceSalesOrderProvider>(context);
    final cartSelectionProvider = Provider.of<CartSelectionProvider>(
      context,
      listen: false,
    );

    return WillPopScope(
      onWillPop: () async {
        // Show confirmation dialog when the back button is pressed
        bool shouldExit = await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirmation'),
              content: const Text('Do you want to go back?'),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).pop(false); // User does not want to exit
                  },
                  child: const Text('No'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(true); // User wants to exit
                  },
                  child: const Text('Yes'),
                ),
              ],
            );
          },
        );

        // If the user chooses to exit, close the app
        if (shouldExit == true) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AllOrdersPage()),
          );
        }
        // If the user dismisses the dialog, default behavior is not to exit
        return shouldExit;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.white,
          title: Container(
            width: double.infinity, // Full width
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Even spacing
              children: [
                // Left Section - Radio buttons
                Container(
                  child: Row(
                    children: [
                      Radio<int>(
                        value: 0,
                        groupValue: _selectedRadioValue,
                        onChanged: (int? value) {
                          setState(() {
                            _selectedRadioValue = value ?? 0;
                            customerScreenProvider.customerType = 'Normal';
                            customerScreenProvider.clearControllers();
                          });
                        },
                      ),
                      Text(
                        'Customer',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10),
                // Center Section - Buttons
                Container(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(
                          Icons.assignment,
                          color: Colors.white, // Changed to white
                          size: 16,
                        ),
                        label: const Text(
                          "Approval Order",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white, // Changed to white
                          ),
                        ),
                        onPressed: () => showDiscountStatus(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue, // Solid blue color
                          foregroundColor: Colors
                              .white, // This affects text/icon color when using style
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(
                              color: Colors.blue,
                              width: 1,
                            ), // Blue border to match
                          ),
                          elevation: 0,
                        ),
                      ),
                      SizedBox(width: 10),
                      ElevatedButton.icon(
                        icon: Stack(
                          children: [
                            const Icon(
                              Icons.assignment,
                              color: Colors.white, // Changed to white
                              size: 16,
                            ),
                            if (customerScreenProvider
                                .hiveholdSalesOrders
                                .isNotEmpty)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.white, // White badge background
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.blue,
                                      width: 1,
                                    ), // Blue border
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 12,
                                    minHeight: 12,
                                  ),
                                  child: Text(
                                    '${customerScreenProvider.hiveholdSalesOrders.length}',
                                    style: const TextStyle(
                                      color: Colors.blue, // Blue text
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        label: const Text(
                          "Held Orders",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white, // Changed to white
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            customerScreenProvider.fetchHolderFromHive();
                            if (customerScreenProvider.hasInvalidCartItems()) {
                              showDialog(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    title: const Text("Error"),
                                    content: const Text(
                                      "Some items in the cart are invalid or cannot be processed.",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        child: const Text("OK"),
                                      ),
                                    ],
                                  );
                                },
                              );
                            } else {
                              showHoldOrdersSheet(
                                context,
                                customerScreenProvider,
                              );
                            }
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue, // Solid blue background
                          foregroundColor:
                              Colors.white, // This affects text/icon color
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(
                              color: Colors.blue,
                              width: 1,
                            ), // Blue border
                          ),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),

                // Right Section - Delete button
                Container(
                  child: IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.blue,
                      size: 28,
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return Dialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 10,
                            child: Container(
                              width: MediaQuery.of(context).size.width * 0.1,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    size: 50,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    "Are you sure?",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    "This action will clear all data and cannot be undone.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      ElevatedButton(
                                        onPressed: () {
                                          setState(() {
                                            globals.cartItems.clear();
                                            customerScreenProvider
                                                .clearControllers();
                                            customerScreenProvider.audioPlayer =
                                                null;
                                            customerScreenProvider.photoScreen =
                                                null;
                                            customerScreenProvider
                                                    .recordedFilePath =
                                                '';
                                            customerScreenProvider
                                                    .pickedImage1 =
                                                null;
                                            customerScreenProvider
                                                    .pickedImage2 =
                                                null;
                                          });
                                          Navigator.of(context).pop();
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        child: const Text("Clear"),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        child: const Text("Cancel"),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
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
        body: Center(
          child: SizedBox(
            height: double.infinity,
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                // onChanged: _validateForm,
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Padding(padding: EdgeInsets.all(5)),
                        SizedBox(width: 290, child: CustomerSearchDropdown()),
                        SizedBox(width: 10),
                        SizedBox(
                          height: 45,
                          width: 286,
                          child: TextFormField(
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            controller: TextEditingController(
                              text:
                                  customerScreenProvider
                                          .dateController
                                          .text
                                          .isNotEmpty &&
                                      customerScreenProvider
                                          .timeController
                                          .text
                                          .isNotEmpty
                                  ? '${customerScreenProvider.dateController.text} | ${customerScreenProvider.timeController.text}'
                                  : '',
                            ),
                            decoration: InputDecoration(
                              prefixIcon: Icon(Icons.event),
                              border: OutlineInputBorder(),
                              labelText: "Delivery Date & Time",
                              hintText: "Choose delivery date and time",
                            ),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            readOnly: true,
                            onTap: () async {
                              DateTime now = DateTime.now();
                              DateTime selectedDate = now;
                              TimeOfDay selectedTime = TimeOfDay.now();

                              await showDialog(
                                context: context,
                                barrierDismissible: true,
                                builder: (context) {
                                  // initial local state
                                  int selectedHour = selectedTime.hour;
                                  int selectedMinute = selectedTime.minute;

                                  return Dialog(
                                    backgroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: StatefulBuilder(
                                      builder: (context, setState) {
                                        return SingleChildScrollView(
                                          child: ConstrainedBox(
                                            constraints: BoxConstraints(
                                              maxWidth: 600,
                                              maxHeight:
                                                  MediaQuery.of(
                                                    context,
                                                  ).size.height *
                                                  0.85,
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  // Title
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.event,
                                                        color: Colors.blue,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        "Select Delivery Date & Time",
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 18,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Divider(thickness: 1.2),
                                                  SizedBox(height: 12),

                                                  // Side-by-side Date & Time
                                                  Row(
                                                    children: [
                                                      // Date picker
                                                      Expanded(
                                                        flex: 3,
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              "Delivery Date",
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                            SizedBox(height: 8),
                                                            Container(
                                                              decoration: BoxDecoration(
                                                                border: Border.all(
                                                                  color: Colors
                                                                      .blue
                                                                      .shade100,
                                                                ),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      12,
                                                                    ),
                                                              ),
                                                              child: CalendarDatePicker(
                                                                initialDate:
                                                                    now,
                                                                firstDate: now,
                                                                lastDate: now
                                                                    .add(
                                                                      Duration(
                                                                        days:
                                                                            180,
                                                                      ),
                                                                    ),
                                                                onDateChanged:
                                                                    (date) {
                                                                      setState(
                                                                        () => selectedDate =
                                                                            date,
                                                                      );
                                                                    },
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),

                                                      SizedBox(width: 12),

                                                      // Time picker
                                                      Expanded(
                                                        flex: 2,
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              "Delivery Time",
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 16,
                                                              ),
                                                            ),
                                                            SizedBox(
                                                              height: 12,
                                                            ),

                                                            // — iOS-style wheel picker —
                                                            Container(
                                                              height: 150,
                                                              decoration: BoxDecoration(
                                                                border: Border.all(
                                                                  color: Colors
                                                                      .blue
                                                                      .shade100,
                                                                ),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      12,
                                                                    ),
                                                              ),
                                                              child: CupertinoDatePicker(
                                                                mode:
                                                                    CupertinoDatePickerMode
                                                                        .time,
                                                                use24hFormat:
                                                                    false,
                                                                initialDateTime:
                                                                    DateTime(
                                                                      0,
                                                                      0,
                                                                      0,
                                                                      selectedHour,
                                                                      selectedMinute,
                                                                    ),
                                                                minuteInterval:
                                                                    1,
                                                                onDateTimeChanged: (dt) {
                                                                  setState(() {
                                                                    selectedHour =
                                                                        dt.hour;
                                                                    selectedMinute =
                                                                        dt.minute;
                                                                  });
                                                                },
                                                              ),
                                                            ),

                                                            SizedBox(
                                                              height: 12,
                                                            ),
                                                            Row(
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .access_time,
                                                                  size: 18,
                                                                  color: Colors
                                                                      .blueGrey,
                                                                ),
                                                                SizedBox(
                                                                  width: 6,
                                                                ),
                                                                Text(
                                                                  "Selected: ${TimeOfDay(hour: selectedHour, minute: selectedMinute).format(context)}",
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        15,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),

                                                  SizedBox(height: 20),

                                                  // Actions
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.end,
                                                    children: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                              context,
                                                            ),
                                                        child: Text("Cancel"),
                                                      ),
                                                      ElevatedButton.icon(
                                                        onPressed: () {
                                                          final formattedDate =
                                                              DateFormat(
                                                                'dd-MM-yyyy',
                                                              ).format(
                                                                selectedDate,
                                                              );
                                                          final formattedTime =
                                                              TimeOfDay(
                                                                hour:
                                                                    selectedHour,
                                                                minute:
                                                                    selectedMinute,
                                                              ).format(context);

                                                          customerScreenProvider
                                                              .updateDate(
                                                                formattedDate,
                                                              );
                                                          customerScreenProvider
                                                                  .timeController
                                                                  .text =
                                                              formattedTime;
                                                          Navigator.pop(
                                                            context,
                                                          );
                                                        },
                                                        icon: Icon(
                                                          Icons.check,
                                                          color: Colors.white,
                                                        ),
                                                        label: Text(
                                                          "Confirm",
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              Colors
                                                                  .blue
                                                                  .shade600,
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  10,
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
                                        );
                                      },
                                    ),
                                  );
                                },
                              );
                            },
                            validator: (value) {
                              if (_isFormValid &&
                                  (customerScreenProvider
                                          .dateController
                                          .text
                                          .isEmpty ||
                                      customerScreenProvider
                                          .timeController
                                          .text
                                          .isEmpty)) {
                                return 'Delivery Date & Time are required';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    const Padding(padding: EdgeInsets.all(5)),

                    Row(
                      children: [
                        const Padding(padding: EdgeInsets.all(5)),
                        if (customerScreenProvider.customerType == 'Normal' ||
                            customerScreenProvider.customerType ==
                                'Company') ...[
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              value:
                                  customerScreenProvider
                                      .getEventList()
                                      .contains(
                                        customerScreenProvider.selectedEvent,
                                      )
                                  ? customerScreenProvider.selectedEvent
                                  : 'Birth Day', // 👈 default to "Birthday"
                              hint: const Text(
                                'Select Event',
                                style: TextStyle(fontSize: 14),
                              ),
                              items: customerScreenProvider.getEventList().map((
                                event,
                              ) {
                                return DropdownMenuItem<String>(
                                  value: event,
                                  child: Text(event),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                customerScreenProvider.setSelectedEvent(
                                  newValue,
                                );
                              },
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Event',
                                isDense: false,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                              ),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black,
                              ),
                              dropdownColor: Colors.white,
                              validator: (value) {
                                if (_isFormValid &&
                                    (value == null || value.isEmpty)) {
                                  return 'Please select an event';
                                }
                                return null;
                              },
                            ),
                          ),

                          const Padding(padding: EdgeInsets.all(5)),
                          // Show extra text field for entering date or custom event
                          // Event Date / Other Text Field
                          if (customerScreenProvider.selectedEvent != null &&
                              customerScreenProvider.selectedEvent!.isNotEmpty)
                            Expanded(
                              child: Builder(
                                builder: (context) => TextFormField(
                                  autovalidateMode:
                                      AutovalidateMode.onUserInteraction,
                                  readOnly: true,
                                  showCursor: true,
                                  controller:
                                      customerScreenProvider.selectedEvent ==
                                          'Others'
                                      ? customerScreenProvider
                                            .otherEventController
                                      : customerScreenProvider
                                            .birthdaydateController,
                                  focusNode:
                                      customerScreenProvider.selectedEvent ==
                                          'Others'
                                      ? _otherEventFocus
                                      : null,
                                  onTap: () {
                                    if (customerScreenProvider.selectedEvent ==
                                        'Others') {
                                      // Activate text field for typing
                                      ActiveField.activate(
                                        context: context,
                                        ctrl: customerScreenProvider
                                            .otherEventController,
                                        node: _otherEventFocus,
                                      );
                                    } else {
                                      DateTime now = DateTime.now();
                                      showGeneralDialog(
                                        context: context,
                                        barrierDismissible: true,
                                        barrierLabel: "Event Date Picker",
                                        pageBuilder: (context, anim1, anim2) =>
                                            Container(),
                                        transitionBuilder: (context, a1, a2, widget) {
                                          return ScaleTransition(
                                            scale: Tween<double>(
                                              begin: 0.5,
                                              end: 1.0,
                                            ).animate(a1),
                                            child: FadeTransition(
                                              opacity: Tween<double>(
                                                begin: 0.5,
                                                end: 1.0,
                                              ).animate(a1),
                                              child: Dialog(
                                                backgroundColor:
                                                    Colors.transparent,
                                                child: Container(
                                                  width: double.infinity,
                                                  constraints:
                                                      const BoxConstraints(
                                                        maxWidth: 350,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black12,
                                                        blurRadius: 15,
                                                        spreadRadius: 5,
                                                      ),
                                                    ],
                                                  ),
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      // Header
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              16,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color:
                                                              Colors.blue[700],
                                                          borderRadius:
                                                              const BorderRadius.only(
                                                                topLeft:
                                                                    Radius.circular(
                                                                      20,
                                                                    ),
                                                                topRight:
                                                                    Radius.circular(
                                                                      20,
                                                                    ),
                                                              ),
                                                        ),
                                                        child: Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: const [
                                                            Text(
                                                              "Choose Event Date",
                                                              style: TextStyle(
                                                                fontSize: 18,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                            ),
                                                            Icon(
                                                              Icons
                                                                  .calendar_today,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      // Calendar
                                                      Container(
                                                        height: 300,
                                                        padding:
                                                            const EdgeInsets.all(
                                                              8,
                                                            ),
                                                        child: Theme(
                                                          data: ThemeData(
                                                            colorScheme:
                                                                ColorScheme.light(
                                                                  primary: Colors
                                                                      .blue[700]!, // Selected date color
                                                                  onPrimary:
                                                                      Colors
                                                                          .white,
                                                                  onSurface:
                                                                      Colors
                                                                          .black,
                                                                ),
                                                            datePickerTheme: DatePickerThemeData(
                                                              // Remove special styling for current date
                                                              todayBackgroundColor:
                                                                  MaterialStateProperty.all(
                                                                    Colors
                                                                        .transparent, // No background color
                                                                  ),
                                                              todayForegroundColor:
                                                                  MaterialStateProperty.all(
                                                                    Colors
                                                                        .black, // Normal text color
                                                                  ),
                                                              todayBorder:
                                                                  BorderSide
                                                                      .none, // No border
                                                              shape:
                                                                  const CircleBorder(),
                                                            ),
                                                          ),
                                                          child: CalendarDatePicker(
                                                            initialDate:
                                                                now, // Starts showing from today
                                                            firstDate:
                                                                now, // Can't select dates before today
                                                            lastDate: now.add(
                                                              const Duration(
                                                                days: 180,
                                                              ), // Exactly 6 months from today
                                                            ),
                                                            onDateChanged: (date) {
                                                              final formattedDate =
                                                                  DateFormat(
                                                                    'dd-MM-yyyy',
                                                                  ).format(
                                                                    date,
                                                                  );
                                                              customerScreenProvider
                                                                      .birthdaydateController
                                                                      .text =
                                                                  formattedDate;
                                                              Navigator.of(
                                                                context,
                                                              ).pop();
                                                            },
                                                          ),
                                                        ),
                                                      ),
                                                      // Cancel Button
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              16,
                                                            ),
                                                        child: Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .end,
                                                          children: [
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.of(
                                                                    context,
                                                                  ).pop(),
                                                              child: Text(
                                                                "Cancel",
                                                                style: TextStyle(
                                                                  color: Colors
                                                                      .grey[600],
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                        transitionDuration: const Duration(
                                          milliseconds: 300,
                                        ),
                                      );
                                    }
                                  },

                                  decoration: InputDecoration(
                                    border: const OutlineInputBorder(),
                                    labelText:
                                        customerScreenProvider.selectedEvent ==
                                            'Others'
                                        ? 'Enter Event Name'
                                        : 'Select ${customerScreenProvider.selectedEvent} Date',
                                    suffixIcon:
                                        customerScreenProvider.selectedEvent !=
                                            'Others'
                                        ? const Icon(Icons.event)
                                        : null,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black,
                                  ),
                                  validator: (value) {
                                    if (_isFormValid &&
                                        (value == null || value.isEmpty)) {
                                      return customerScreenProvider
                                                  .selectedEvent ==
                                              'Others'
                                          ? 'Please enter the event'
                                          : 'Please select a date';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ),
                          const Padding(padding: EdgeInsets.all(5)),
                        ],
                      ],
                    ),
                    const Padding(padding: EdgeInsets.all(5)),
                    Row(
                      children: [
                        // if (customerScreenProvider.selectedEvent == 'Birthday')
                        if (customerScreenProvider.customerType != 'Normal' ||
                            customerScreenProvider.customerType !=
                                'Company') ...[
                          const SizedBox(),
                        ],

                        if (customerScreenProvider.customerType == 'Normal' ||
                            customerScreenProvider.customerType ==
                                'Company') ...[
                          const Padding(padding: EdgeInsets.all(5)),
                        ],
                        if (customerScreenProvider.customerType ==
                            'Credit Customer') ...[
                          const Padding(padding: EdgeInsets.all(5)),
                        ],

                        // const Padding(padding: EdgeInsets.all(5)),
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: DropdownButtonFormField<String>(
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              value:
                                  GlobalDataManager().deliveryTypes.any(
                                    (item) =>
                                        item['deliveryType'] ==
                                        customerScreenProvider
                                            .selectedDeliveryType,
                                  )
                                  ? customerScreenProvider.selectedDeliveryType
                                  : "Pickup By Customer", // ✅ Corrected spelling
                              hint: const Text(
                                'Delivery Type',
                                style: TextStyle(fontSize: 14),
                              ),
                              items: GlobalDataManager().deliveryTypes
                                  .map<DropdownMenuItem<String>>((item) {
                                    return DropdownMenuItem<String>(
                                      value: item['deliveryType'],
                                      child: Text(item['deliveryType']),
                                    );
                                  })
                                  .toList(),
                              onChanged: (String? newValue) {
                                customerScreenProvider.setSelectedDeliveryType(
                                  newValue,
                                );
                              },
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Delivery Type',
                                labelStyle: TextStyle(fontSize: 14),
                                isDense: false,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                              ),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black,
                              ),
                              dropdownColor: Colors.white,
                              validator: (value) {
                                if (_isFormValid &&
                                    (value == null || value.isEmpty)) {
                                  return 'Delivery Type is required';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        const Padding(padding: EdgeInsets.all(5)),
                        Expanded(child: EmployeeSearchDropdown()),
                        const Padding(padding: EdgeInsets.all(5)),
                      ],
                    ),

                    //   ],
                    if ((customerScreenProvider.selectedDeliveryType ?? '')
                            .toLowerCase() ==
                        'door delivery') ...[
                      const Padding(padding: EdgeInsets.all(5)),
                      Row(
                        children: [
                          const Padding(padding: EdgeInsets.all(5)),
                          Expanded(
                            child: TextFormField(
                              // autovalidateMode:
                              //     AutovalidateMode.onUserInteraction,
                              showCursor: true, // Ensure cursor is visible
                              readOnly: true,
                              onTap: () {
                                ActiveField.activate(
                                  context: context,
                                  ctrl:
                                      customerScreenProvider.landmarkController,
                                  node: _landMarkFocus,
                                );
                              },
                              focusNode: _landMarkFocus,
                              controller:
                                  customerScreenProvider.landmarkController,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Landmark',
                                labelStyle: TextStyle(fontSize: 14),
                                isDense: false, // Makes the field more compact
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),

                                hintStyle: TextStyle(color: Colors.grey),
                              ),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const Padding(padding: EdgeInsets.all(5)),
                          Expanded(
                            child: TextFormField(
                              showCursor: true, // Ensure cursor is visible
                              readOnly: true,
                              focusNode: _addressFocus,
                              controller:
                                  customerScreenProvider.addressController,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Address',
                                labelStyle: TextStyle(fontSize: 14),
                                isDense: false, // Makes the field more compact
                                hintStyle: TextStyle(color: Colors.grey),
                              ),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black,
                              ),
                              onTap: () {
                                ActiveField.activate(
                                  context: context,
                                  ctrl:
                                      customerScreenProvider.addressController,
                                  node: _addressFocus,
                                );
                              },
                            ),
                          ),
                          const Padding(padding: EdgeInsets.all(5)),
                        ],
                      ),
                    ],

                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SizedBox(
                        height: 50,
                        width: double.infinity,
                        child: TextField(
                          showCursor: true, // Ensure cursor is visible
                          readOnly: true,
                          focusNode: _remarkFocus,
                          controller: customerScreenProvider.remarkController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Remarks',
                            labelStyle: TextStyle(fontSize: 14),
                            hintStyle: TextStyle(color: Colors.grey),
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                          ),
                          onTap: () {
                            ActiveField.activate(
                              context: context,
                              ctrl: customerScreenProvider.remarkController,
                              node: _remarkFocus,
                            );
                          },
                        ),
                      ),
                    ),

                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 🎵 AUDIO SECTION
                            SizedBox(
                              width: 150,
                              child:
                                  customerScreenProvider
                                      .recordedFilePath
                                      .isEmpty
                                  ? KeyedSubtree(
                                      key: const ValueKey('voice_recorder'),
                                      child: SizedBox(
                                        width: 100,
                                        height: 70,
                                        child: VoiceRecorder(
                                          key: const ValueKey(
                                            'recorder_instance',
                                          ),
                                          onRecordingComplete:
                                              handleRecordingComplete,
                                        ),
                                      ),
                                    )
                                  : ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxHeight: 90,
                                        minHeight: 90,
                                      ),
                                      child: SizedBox(
                                        width: 180,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // 🔹 AUDIO PLAYER (FIXED HEIGHT)
                                            SizedBox(
                                              height: 56,
                                              child: AudioPlayerWidget(
                                                key: ValueKey(
                                                  'audio_${customerScreenProvider.recordedFilePath}',
                                                ),
                                                filePath: customerScreenProvider
                                                    .recordedFilePath,
                                                onDispose: () {
                                                  WidgetsBinding.instance
                                                      .addPostFrameCallback((
                                                        _,
                                                      ) {
                                                        customerScreenProvider
                                                            .resetAudioWidget();
                                                      });
                                                },
                                              ),
                                            ),

                                            const SizedBox(height: 6),

                                            // 🔹 RE-RECORD BUTTON
                                            SizedBox(
                                              height: 28,
                                              child: InkWell(
                                                onTap: () {
                                                  showDialog(
                                                    context: context,
                                                    barrierDismissible: false,
                                                    builder: (dialogContext) => Dialog(
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              20,
                                                            ),
                                                      ),
                                                      elevation: 10,
                                                      backgroundColor:
                                                          Colors.white,
                                                      child: SizedBox(
                                                        width:
                                                            MediaQuery.of(
                                                              context,
                                                            ).size.width *
                                                            0.55, // 🔹 narrower width
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                24.0,
                                                              ),
                                                          child: Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              // 🎵 ICON / HEADER
                                                              Container(
                                                                padding:
                                                                    const EdgeInsets.all(
                                                                      12,
                                                                    ),
                                                                decoration: BoxDecoration(
                                                                  color: Colors
                                                                      .orange
                                                                      .shade100,
                                                                  shape: BoxShape
                                                                      .circle,
                                                                ),
                                                                child: const Icon(
                                                                  Icons.mic,
                                                                  color: Colors
                                                                      .orange,
                                                                  size: 32,
                                                                ),
                                                              ),

                                                              const SizedBox(
                                                                height: 16,
                                                              ),

                                                              // 🔹 Title
                                                              Text(
                                                                'Re-record Audio?',
                                                                style: TextStyle(
                                                                  fontSize: 20,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Colors
                                                                      .grey[900],
                                                                  letterSpacing:
                                                                      0.5,
                                                                ),
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                              ),

                                                              const SizedBox(
                                                                height: 12,
                                                              ),

                                                              // 🔹 Description
                                                              Text(
                                                                'This will replace your current recording with a new one.',
                                                                style: TextStyle(
                                                                  fontSize: 14,
                                                                  color: Colors
                                                                      .grey[700],
                                                                  height: 1.4,
                                                                ),
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                              ),

                                                              const SizedBox(
                                                                height: 24,
                                                              ),

                                                              // 🔹 Buttons (Outlined + Filled)
                                                              Row(
                                                                children: [
                                                                  Expanded(
                                                                    child: OutlinedButton(
                                                                      style: OutlinedButton.styleFrom(
                                                                        side: BorderSide(
                                                                          color: Colors
                                                                              .grey
                                                                              .shade300,
                                                                        ),
                                                                        shape: RoundedRectangleBorder(
                                                                          borderRadius: BorderRadius.circular(
                                                                            12,
                                                                          ),
                                                                        ),
                                                                        padding: const EdgeInsets.symmetric(
                                                                          vertical:
                                                                              14,
                                                                        ),
                                                                      ),
                                                                      onPressed: () =>
                                                                          Navigator.pop(
                                                                            dialogContext,
                                                                          ),
                                                                      child: Text(
                                                                        'Cancel',
                                                                        style: TextStyle(
                                                                          fontSize:
                                                                              14,
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                          color:
                                                                              Colors.grey[800],
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),

                                                                  const SizedBox(
                                                                    width: 16,
                                                                  ),

                                                                  Expanded(
                                                                    child: ElevatedButton(
                                                                      style: ElevatedButton.styleFrom(
                                                                        padding: const EdgeInsets.symmetric(
                                                                          vertical:
                                                                              14,
                                                                        ),
                                                                        shape: RoundedRectangleBorder(
                                                                          borderRadius: BorderRadius.circular(
                                                                            12,
                                                                          ),
                                                                        ),
                                                                        elevation:
                                                                            4,
                                                                        backgroundColor:
                                                                            Colors.orange,
                                                                      ),
                                                                      onPressed: () {
                                                                        customerScreenProvider
                                                                            .resetAudioRecording();
                                                                        Navigator.pop(
                                                                          dialogContext,
                                                                        );
                                                                      },
                                                                      child: const Text(
                                                                        'Re-record',
                                                                        style: TextStyle(
                                                                          fontSize:
                                                                              14,
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                          color:
                                                                              Colors.white,
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
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: const [
                                                    Icon(
                                                      Icons.replay,
                                                      size: 12,
                                                      color: Colors.orange,
                                                    ),
                                                    SizedBox(width: 4),
                                                    Text(
                                                      'Re-record',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.orange,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                            ),
                            // IMAGE SECTION
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: 100, // Max height for image section
                              ),
                              child: SizedBox(
                                width: 180,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Main Image Container
                                    Container(
                                      height: 60,
                                      child: Row(
                                        children: [
                                          if (customerScreenProvider
                                              .pickedImages
                                              .isEmpty)
                                            KeyedSubtree(
                                              key: const ValueKey(
                                                'image_picker',
                                              ),
                                              child: SizedBox(
                                                width: 160,
                                                child: MultiImagePickerWidget(
                                                  key: const ValueKey(
                                                    'image_picker_instance',
                                                  ),
                                                  onImagesSelected: (images) {
                                                    customerScreenProvider
                                                        .addImages(images);
                                                    customerScreenProvider
                                                        .notifyListeners();
                                                  },
                                                ),
                                              ),
                                            )
                                          else
                                            Expanded(
                                              child: ConstrainedBox(
                                                constraints: BoxConstraints(
                                                  maxHeight: 60,
                                                ),
                                                child: PhotosScreen(
                                                  key: ValueKey(
                                                    'photos_${customerScreenProvider.pickedImages.hashCode}',
                                                  ),
                                                  imagePaths:
                                                      customerScreenProvider
                                                          .pickedImages
                                                          .map((f) => f.path)
                                                          .toList(),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),

                                    // Add More Images Button
                                    if (customerScreenProvider
                                        .pickedImages
                                        .isNotEmpty)
                                      Container(
                                        height: 24,
                                        child: // Inside your UI where you show Add More button
                                        InkWell(
                                          onTap: () async {
                                            final images =
                                                await showDialog<List<File>>(
                                                  context: context,
                                                  builder: (context) =>
                                                      AddMoreImagesDialog(
                                                        existingImages:
                                                            customerScreenProvider
                                                                .pickedImages,
                                                      ),
                                                );

                                            if (images != null) {
                                              // Replace the provider's images with the updated list
                                              customerScreenProvider.setImages(
                                                images,
                                              );
                                            }
                                          },
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Icon(
                                                Icons.add_photo_alternate,
                                                size: 14,
                                                color: Colors.green,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'Add More',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(width: 10),

                            // ✅ PLACE / APPROVAL BUTTON
                            SizedBox(
                              height: 60,
                              child: CustomButton(
                                text:
                                    customerScreenProvider
                                        .isRestoringApprovalOrder
                                    ? 'Place Order'
                                    : (_requiresApproval()
                                          ? 'Send for Approval'
                                          : 'Place Order'),
                                onPressed: globals.cartItems.isNotEmpty
                                    ? () async {
                                        if (!mounted) {
                                          return;
                                        }

                                        // Validate order details
                                        final isValidOrderDetails =
                                            _validateOrderDetails();
                                        final isValidFullOrderForm =
                                            _validateFullOrderForm();

                                        if (!isValidOrderDetails ||
                                            !isValidFullOrderForm) {
                                          return;
                                        }

                                        final currentContext = context;

                                        // If restoring approval order, force Place Order behavior
                                        if (customerScreenProvider
                                            .isRestoringApprovalOrder) {
                                          final filePaths =
                                              await FileStorageManager.saveFiles(
                                                recordedFilePath:
                                                    customerScreenProvider
                                                        .recordedFilePath,
                                                pickedImage1:
                                                    customerScreenProvider
                                                        .pickedImage1,
                                                pickedImage2:
                                                    customerScreenProvider
                                                        .pickedImage2,
                                              );

                                          if (!mounted) {
                                            return;
                                          }

                                          customerScreenProvider
                                              .showAdvancePaymentPopup(
                                                currentContext,
                                                cartSelectionProvider,
                                                cartProvider,
                                                filePaths['audioPath'],
                                                apiSalesprovider,
                                                customerScreenProvider
                                                    .customerType,
                                                customerScreenProvider
                                                    .audioPlayer,
                                                customerScreenProvider.holdId,
                                              );
                                          Provider.of<CustomerScreenProvider>(
                                            context,
                                            listen: false,
                                          ).resetAudioWidget();
                                          return;
                                        }

                                        // Original logic for non-restored orders
                                        final filePaths =
                                            await FileStorageManager.saveFiles(
                                              recordedFilePath:
                                                  customerScreenProvider
                                                      .recordedFilePath,
                                              pickedImage1:
                                                  customerScreenProvider
                                                      .pickedImage1,
                                              pickedImage2:
                                                  customerScreenProvider
                                                      .pickedImage2,
                                            );

                                        if (!mounted) {
                                          return;
                                        }

                                        if (_requiresApproval()) {
                                          customerScreenProvider
                                              .submitForApproval(
                                                currentContext,
                                                cartSelectionProvider,
                                                cartProvider,
                                                customerScreenProvider
                                                    .recordedFilePath,
                                                apiSalesprovider,
                                                customerScreenProvider
                                                    .pickedImage1,
                                                customerScreenProvider
                                                    .pickedImage2,
                                                customerScreenProvider
                                                    .customerType,
                                              );
                                          Provider.of<CustomerScreenProvider>(
                                            context,
                                            listen: false,
                                          ).resetAudioWidget();
                                        } else {
                                          customerScreenProvider
                                              .showAdvancePaymentPopup(
                                                currentContext,
                                                cartSelectionProvider,
                                                cartProvider,
                                                filePaths['audioPath'],
                                                apiSalesprovider,
                                                customerScreenProvider
                                                    .customerType,
                                                customerScreenProvider
                                                    .audioPlayer,
                                                customerScreenProvider.holdId,
                                              );
                                        
                                          Navigator.of(
                                            context,
                                          ).pushAndRemoveUntil(
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  SalesOrderScreen(),
                                            ),
                                            (route) => false,
                                          );
                                        }
                                      }
                                    : () {},
                                backgroundColor: globals.cartItems.isNotEmpty
                                    ? (customerScreenProvider
                                                  .isRestoringApprovalOrder ||
                                              !_requiresApproval())
                                          ? Colors.blue
                                          : Colors.orange
                                    : Colors.grey,
                                textColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 8,
                                ),
                                fontSize: 12,
                              ),
                            ),

                            const SizedBox(width: 10),

                            // 🔹 HOLD ORDER BUTTON
                            if (customerScreenProvider.customerType == 'Normal')
                              SizedBox(
                                height: 60,
                                child: CustomButton(
                                  text: 'Hold Order',
                                  onPressed: globals.cartItems.isNotEmpty
                                      ? () async {
                                          if (!_formKey.currentState!
                                              .validate())
                                            return;

                                          final currentContext = context;

                                          final filePaths =
                                              await FileStorageManager.saveFiles(
                                                recordedFilePath:
                                                    customerScreenProvider
                                                        .recordedFilePath,
                                                pickedImage1:
                                                    customerScreenProvider
                                                        .pickedImage1,
                                                pickedImage2:
                                                    customerScreenProvider
                                                        .pickedImage2,
                                              );

                                          if (!mounted) return;

                                          await customerScreenProvider.heldrder(
                                            cartProvider,
                                            cartSelectionProvider,
                                            customerScreenProvider.totalAdvance,
                                            customerScreenProvider.orderAmount,
                                            customerScreenProvider.discount,
                                            customerScreenProvider
                                                .deductedAmount,
                                            customerScreenProvider.totalAmount,
                                            customerScreenProvider
                                                .remarkController
                                                .text,
                                            filePaths['audioPath'],
                                            apiSalesprovider,
                                            filePaths['imagePath1'] != null
                                                ? File(filePaths['imagePath1']!)
                                                : null,
                                            filePaths['imagePath2'] != null
                                                ? File(filePaths['imagePath2']!)
                                                : null,
                                            customerScreenProvider
                                                .patchHoldOrderId,
                                            customerScreenProvider.orderType,
                                            currentContext,
                                          );
                                          Provider.of<CustomerScreenProvider>(
                                            context,
                                            listen: false,
                                          ).resetAudioWidget();
                                        }
                                      : () {},
                                  backgroundColor: globals.cartItems.isNotEmpty
                                      ? Colors.lightBlue
                                      : Colors.grey,
                                  textColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 8,
                                  ),
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    SizedBox(
                      height: 200,
                      child: ValueListenableBuilder<TextEditingController?>(
                        valueListenable: ActiveField.controller,
                        builder: (context, ctrl, __) {
                          return Column(
                            children: [
                              const SizedBox(height: 8),
                              Expanded(
                                child: CustomKeyboardWidgetAll2(
                                  controller: ctrl ?? TextEditingController(),
                                ),
                              ),
                            ],
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
      ),
    );
  }
}

class AddMoreImagesDialog extends StatefulWidget {
  final List<File> existingImages;

  const AddMoreImagesDialog({Key? key, required this.existingImages})
    : super(key: key);

  @override
  State<AddMoreImagesDialog> createState() => _AddMoreImagesDialogState();
}

class _AddMoreImagesDialogState extends State<AddMoreImagesDialog> {
  late List<File> _selectedImages;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _selectedImages = List<File>.from(widget.existingImages); // Copy once
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile>? pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles != null && pickedFiles.isNotEmpty) {
        setState(() {
          for (var xfile in pickedFiles) {
            final file = File(xfile.path);
            if (!_selectedImages.any((f) => f.path == file.path)) {
              _selectedImages.add(file);
            }
          }
        });
      }
    } catch (e) {}
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 10,
      backgroundColor: Colors.white,
      child: Container(
        width: 350,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'Add More Images',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Image count
            Text(
              'Total: ${_selectedImages.length} images',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),

            // Image grid
            if (_selectedImages.isNotEmpty)
              SizedBox(
                height: 200,
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _selectedImages[index],
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

            const SizedBox(height: 16),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickImages,
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text('Add Images'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      side: BorderSide(color: Colors.grey.shade300),
                      foregroundColor: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, _selectedImages),
                    icon: const Icon(Icons.check),
                    label: const Text('Confirm'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
