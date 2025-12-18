import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:hive/hive.dart';
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
  void _loadStoredImages() {
    final customerScreenProvider = Provider.of<CustomerScreenProvider>(
      context,
      listen: false,
    );
    final box = Hive.box('imagesBox');
    String? imagePath1 = box.get('image1');
    String? imagePath2 = box.get('image2');
    setState(() {
      customerScreenProvider.pickedImage1 = imagePath1 != null
          ? File(imagePath1)
          : null;
      customerScreenProvider.pickedImage2 = imagePath2 != null
          ? File(imagePath2)
          : null;
    });
    customerScreenProvider.clearControllers();
  }

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
        int quantity = item.quantity.value ?? 0; // treat null as 0
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
    return globals.cartItems.any((item) => (item.itemWiseDiscount ?? 0) > 6);
  }

  @override
  void initState() {
    super.initState();
    _loadStoredImages();
    final customerScreenProvider = Provider.of<CustomerScreenProvider>(
      context,
      listen: false,
    );
    customerScreenProvider.setSelectedEvent("Birth Day");
    customerScreenProvider.setSelectedDeliveryType("Pickup By Customer");
    customerScreenProvider.setSelectedCustomCharge("Custom Charges");
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
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                //mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Radio<int>(
                    value: 0,
                    groupValue: _selectedRadioValue,
                    onChanged: (int? value) {
                      setState(() {
                        _selectedRadioValue = value;
                        customerScreenProvider.customerType = 'Normal';
                        customerScreenProvider.clearControllers();
                      });
                    },
                  ),
                  Transform.translate(
                    offset: const Offset(0, 0), // Move the text up by 8 pixels
                    child: Text(
                      'Customer',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 19),
                ],
              ),
              const SizedBox(width: 10),
              // Radio button for "Other Option"
              Column(
                children: [
                  Transform.translate(
                    offset: const Offset(0, -8),
                    child: TextButton.icon(
                      icon: const Icon(Icons.assignment, color: Colors.red),
                      label: const Text(
                        "Order Status",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                      onPressed: () => showDiscountStatus(context),
                    ),
                  ),
                ],
              ),

              Transform.translate(
                offset: const Offset(0, -8),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.assignment, color: Colors.red),
                      label: const Text(
                        "Held Orders",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          customerScreenProvider.fetchHolderFromHive();

                          // Check for invalid cart items
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
                            // If all good, show held orders sheet
                            showHoldOrdersSheet(
                              context,
                              customerScreenProvider,
                            );
                          }
                        });
                      },
                    ),

                    // Badge
                    if (customerScreenProvider.hiveholdSalesOrders.isNotEmpty)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '${customerScreenProvider.hiveholdSalesOrders.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -8),
                child: IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: Colors.blue, // Set the color to blue
                  ),
                  iconSize: 28,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return Dialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              12,
                            ), // Reduced border radius
                          ),
                          elevation: 10,
                          child: Container(
                            width: MediaQuery.of(context).size.width * 0.1,
                            padding: const EdgeInsets.all(
                              16,
                            ), // Reduced padding
                            decoration: BoxDecoration(
                              color: Colors
                                  .blueAccent, // Simplified gradient to a single color
                              borderRadius: BorderRadius.circular(
                                12,
                              ), // Reduced border radius
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 50, // Reduced size
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  "Are you sure?",
                                  style: TextStyle(
                                    fontSize: 20, // Smaller font size
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  "This action will clear all data and cannot be undone.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14, // Smaller font size
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
                                          customerScreenProvider.pickedImage1 =
                                              null;
                                          customerScreenProvider.pickedImage2 =
                                              null;
                                        });

                                        Navigator.of(context).pop();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            Colors.white, // Simplified color
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ), // Reduced border radius
                                        ),
                                      ),
                                      child: const Text("Clear"),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            Colors.white, // Simplified color
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ), // Reduced border radius
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
                          height: 50,
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
                                                                      .blue[700]!,
                                                                  onPrimary:
                                                                      Colors
                                                                          .white,
                                                                  onSurface:
                                                                      Colors
                                                                          .black,
                                                                ),
                                                            datePickerTheme: DatePickerThemeData(
                                                              todayBackgroundColor:
                                                                  MaterialStateProperty.all(
                                                                    Colors
                                                                        .blue[700]!,
                                                                  ),
                                                              todayForegroundColor:
                                                                  MaterialStateProperty.all(
                                                                    Colors
                                                                        .white,
                                                                  ),
                                                              shape:
                                                                  const CircleBorder(),
                                                            ),
                                                          ),
                                                          child: CalendarDatePicker(
                                                            initialDate: now,
                                                            firstDate: now,
                                                            lastDate: now.add(
                                                              const Duration(
                                                                days: 180,
                                                              ),
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

                    SizedBox(
                      height:
                          75, // 👈 Small fixed height to avoid bottom overflow
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (customerScreenProvider.audioPlayer == null ||
                                audioprovider.state.error != null ||
                                customerScreenProvider.photoScreen != null)
                              customerScreenProvider.showAudioandImage ||
                                      customerScreenProvider.audioPlayer ==
                                          null ||
                                      audioprovider.state.error != null
                                  ? SizedBox(
                                      width: 220,
                                      child: VoiceRecorder(
                                        onRecordingComplete:
                                            handleRecordingComplete,
                                      ),
                                    )
                                  : AudioPlayerWidget(
                                      key: ValueKey(
                                        customerScreenProvider.recordedFilePath,
                                      ),
                                      filePath: customerScreenProvider
                                          .recordedFilePath,
                                    ),
                            SizedBox(width: 8),
                            // 🔹 Photo Widget
                            if (customerScreenProvider.photoScreen != null)
                              if (customerScreenProvider
                                  .pickedImages
                                  .isNotEmpty)
                                PhotosScreen(
                                  imagePaths: customerScreenProvider
                                      .pickedImages
                                      .map((f) => f.path)
                                      .toList(),
                                ),

                            if (customerScreenProvider.photoScreen == null)
                              MultiImagePickerWidget(
                                onImagesSelected: (images) {
                                  customerScreenProvider.pickedImages = images;
                                },
                              ),

                            Container(
                              height: 50,
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              child: CustomButton(
                                text: _requiresApproval()
                                    ? 'Send for Approval'
                                    : 'Place Order',
                                onPressed: globals.cartItems.isNotEmpty
                                    ? () async {
                                        if (!mounted) return; // ✅ add here
                                        if (!_validateOrderDetails() ||
                                            !_validateFullOrderForm())
                                          return;

                                        // Capture safe context
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

                                        // Check if widget is still in tree
                                        if (!mounted) return;

                                        if (_requiresApproval()) {
                                          customerScreenProvider.submitForApproval(
                                            currentContext, // use safe context
                                            cartSelectionProvider,
                                            cartProvider,
                                            customerScreenProvider
                                                .recordedFilePath,
                                            apiSalesprovider,
                                            customerScreenProvider.pickedImage1,
                                            customerScreenProvider.pickedImage2,
                                            customerScreenProvider.customerType,
                                          );
                                        } else {
                                          customerScreenProvider
                                              .showAdvancePaymentPopup(
                                                currentContext, // use safe context
                                                cartSelectionProvider,
                                                cartProvider,
                                                filePaths['audioPath'],
                                                apiSalesprovider,
                                                filePaths['imagePath1'] != null
                                                    ? File(
                                                        filePaths['imagePath1']!,
                                                      )
                                                    : null,
                                                filePaths['imagePath2'] != null
                                                    ? File(
                                                        filePaths['imagePath2']!,
                                                      )
                                                    : null,
                                                customerScreenProvider
                                                    .customerType,
                                                customerScreenProvider
                                                    .audioPlayer,
                                                customerScreenProvider.holdId,
                                              );
                                        }
                                      }
                                    : () {},
                                backgroundColor: globals.cartItems.isNotEmpty
                                    ? (_requiresApproval()
                                          ? Colors.orange
                                          : Colors.blue)
                                    : Colors.grey,
                                textColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                fontSize: 12.0,
                              ),
                            ),

                            // 🔹 Hold Order button
                            if (customerScreenProvider.customerType == 'Normal')
                              Container(
                                height: 50,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
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
                                            customerScreenProvider
                                                .selectedStoreType,
                                            currentContext,
                                          );
                                        }
                                      : () {},
                                  backgroundColor: globals.cartItems.isNotEmpty
                                      ? Colors.lightBlue
                                      : Colors.grey,
                                  textColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  fontSize: 12.0,
                                ),
                              ),

                            const SizedBox(width: 8), // Right padding
                          ],
                        ),
                      ),
                    ),

                    SizedBox(
                      height: 210,
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
