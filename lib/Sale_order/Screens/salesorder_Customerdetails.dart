import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Global/Widget/filesave.dart';
import 'package:yenpos/Global/globals_data.dart' as globals;
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Sale_order/Models/held_order_model.dart';
import 'package:yenpos/Sale_order/Provider/cartProvider.dart';
import 'package:yenpos/Sale_order/Provider/cart_selection_provider.dart';
import 'package:yenpos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yenpos/Sale_order/Provider/detailsProvider.dart';
import 'package:yenpos/Sale_order/Provider/get_sales_order_service.dart';
import 'package:yenpos/Sale_order/Screens/all_orders.dart';
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
  final GlobalKey keyboardKey;
  const CustomerDetails({super.key, required this.keyboardKey});

  @override
  _CustomerDetailsState createState() => _CustomerDetailsState();
}

class _CustomerDetailsState extends State<CustomerDetails> {
  final _formKey = GlobalKey<FormState>();
  bool _isFormValid = false;


  String _customerType = 'Normal';
  int? _selectedRadioValue = 0; // The selected radio button value
  // String? audioPlayerId;

  String? holdId;
  List<Map<String, String>> suggestions = [];
  bool isSuggestionsVisible = false;
  TextEditingController controller123 = TextEditingController();
  void _loadStoredImages() {
    final box = Hive.box('imagesBox');
    String? imagePath1 = box.get('image1');
    String? imagePath2 = box.get('image2');
    setState(() {
      final customerScreenProvider =
          Provider.of<CustomerScreenProvider>(context, listen: false);
      customerScreenProvider.pickedImage1 =
          imagePath1 != null ? File(imagePath1) : null;
      customerScreenProvider.pickedImage2 =
          imagePath2 != null ? File(imagePath2) : null;
    });
  }

  final _remarkFocus = FocusNode();
  final _addressFocus = FocusNode();
  final _landMarkFocus = FocusNode();
  final FocusNode _otherEventFocus = FocusNode();
  void showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  bool _validateFullOrderForm() {
    final customerScreenProvider =
        Provider.of<CustomerScreenProvider>(context, listen: false);

    String mobile = customerScreenProvider.mobileNoController.text.trim();
    String event = customerScreenProvider.selectedEvent ?? '';
    String deliveryDate = customerScreenProvider.dateController.text.trim();
    String deliveryTime = customerScreenProvider.timeController.text.trim();
    String deliveryType = customerScreenProvider.selectedDeliveryType ?? '';
    String salesPerson = customerScreenProvider.searchController.text.trim();

    if (mobile.isEmpty ||
        mobile.length != 10 ||
        !RegExp(r'^\d{10}$').hasMatch(mobile)) {
      showToast('Please enter a valid 10-digit customer mobile number');
      return false;
    }

    if (event.isEmpty) {
      showToast('Please select an event');
      return false;
    }

    if (event == 'Others' &&
        (customerScreenProvider.otherEventController.text.isEmpty)) {
      showToast('Please enter the event name');
      return false;
    }

    if ((event != 'Others') &&
        (customerScreenProvider.birthdaydateController.text.isEmpty)) {
      showToast('Please select event date');
      return false;
    }

    if (deliveryDate.isEmpty || deliveryTime.isEmpty) {
      showToast('Please select delivery date and time');
      return false;
    }

    if (deliveryType.isEmpty) {
      showToast('Please select delivery type');
      return false;
    }

    if (salesPerson.isEmpty) {
      showToast('Please select a salesperson');
      return false;
    }

    if (globals.cartItems.isEmpty) {
      showToast('Please add at least one item to cart');
      return false;
    }

    return true;
  }

  bool _validateOrderDetails() {
    final customerScreenProvider =
        Provider.of<CustomerScreenProvider>(context, listen: false);
    final detailsProvider =
        Provider.of<DetailsProvider>(context, listen: false);

    String selectedSalesperson =
        customerScreenProvider.searchController.text.trim();
    String enteredMobileNumber =
        customerScreenProvider.mobileNoController.text.trim();

    if (!detailsProvider.employeeNames.contains(selectedSalesperson)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a valid salesperson.')),
      );
      return false;
    }

    if (enteredMobileNumber.isEmpty ||
        enteredMobileNumber.length != 10 ||
        !RegExp(r'^\d{10}$').hasMatch(enteredMobileNumber)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a valid 10-digit mobile number.')),
      );
      return false;
    }

    bool hasInvalidBoxItems = globals.cartItems
        .any((item) => item.isBoxItem == 'yes' && item.quantity <= 0);
    if (hasInvalidBoxItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Enter valid box quantity for selected items.')),
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
    Provider.of<CustomerScreenProvider>(context, listen: false)
        .setSelectedDeliveryType('Pickup by Customer');
    final customerScreenProvider =
        Provider.of<CustomerScreenProvider>(context, listen: false);
    customerScreenProvider.clearControllers();
    customerScreenProvider.setSelectedEvent('Birthday');
  }

  void handleRecordingComplete(String path) {
    setState(() {
      final customerScreenProvider =
          Provider.of<CustomerScreenProvider>(context, listen: false);
      customerScreenProvider.recordedFilePath = path;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final audioprovider = Provider.of<AudioProvider>(context, listen: false);
    final customerScreenProvider = Provider.of<CustomerScreenProvider>(context);
    final apiSalesprovider = Provider.of<ApiServiceSalesOrderProvider>(context);
    final cartSelectionProvider =
        Provider.of<CartSelectionProvider>(context, listen: false);

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
                    Navigator.of(context)
                        .pop(false); // User does not want to exit
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
            MaterialPageRoute(
              builder: (context) => AllOrdersPage(
                keyboardKey: widget.keyboardKey,
              ),
            ),
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
          title: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
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
                          _customerType = 'Normal';
                          customerScreenProvider.clearControllers();
                        });
                      },
                    ),
                    Transform.translate(
                      offset:
                          const Offset(0, 0), // Move the text up by 8 pixels
                      child: Text(
                        'Customer',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(
                      width: 19,
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                // Radio button for "Other Option"
                Column(
                  children: [
                    Transform.translate(
                      offset: const Offset(0, -8),
                      child: TextButton.icon(
                        icon: const Icon(
                          Icons.assignment,
                          color: Colors.red,
                        ),
                        label: const Text(
                          "Order Status",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                        onPressed: () => _showDiscountStatus(context),
                      ),
                    ),
                  ],
                ),

                Transform.translate(
                  offset: const Offset(0, -8),
                  child: TextButton.icon(
                    // icon: const Icon(Icons.assignment),
                    icon: const Icon(
                      Icons.assignment,
                      color: Colors.red, // Set the color to yellow
                    ),
                    label: const Text(
                      "Held Orders",
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.red),
                    ),

                    onPressed: () {
                      showHoldOrdersSheet(context, customerScreenProvider);
                    },
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
                                  12), // Reduced border radius
                            ),
                            elevation: 10,
                            child: Container(
                              width: MediaQuery.of(context).size.width * 0.1,
                              padding:
                                  const EdgeInsets.all(16), // Reduced padding
                              decoration: BoxDecoration(
                                color: Colors
                                    .blueAccent, // Simplified gradient to a single color
                                borderRadius: BorderRadius.circular(
                                    12), // Reduced border radius
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
                                          globals.cartItems.clear();

                                          customerScreenProvider
                                              .clearControllers();
                                          customerScreenProvider.audioPlayer =
                                              null;
                                          customerScreenProvider.photoScreen =
                                              null;
                                          Navigator.of(context).pop();
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Colors.white, // Simplified color
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                                8), // Reduced border radius
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
                                                8), // Reduced border radius
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
                        SizedBox(
                          width: 10,
                        ),
                        SizedBox(
                          height: 50,
                          width: 286,
                          child: TextFormField(
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            controller: TextEditingController(
                              text: customerScreenProvider
                                          .dateController.text.isNotEmpty &&
                                      customerScreenProvider
                                          .timeController.text.isNotEmpty
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
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    child: StatefulBuilder(
                                      builder: (context, setState) {
                                        return SingleChildScrollView(
                                          child: ConstrainedBox(
                                            constraints: BoxConstraints(
                                              maxWidth: 600,
                                              maxHeight: MediaQuery.of(context)
                                                      .size
                                                      .height *
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
                                                      Icon(Icons.event,
                                                          color: Colors.blue),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        "Select Delivery Date & Time",
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 18),
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
                                                                            .w600)),
                                                            SizedBox(height: 8),
                                                            Container(
                                                              decoration:
                                                                  BoxDecoration(
                                                                border: Border.all(
                                                                    color: Colors
                                                                        .blue
                                                                        .shade100),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            12),
                                                              ),
                                                              child:
                                                                  CalendarDatePicker(
                                                                initialDate:
                                                                    now,
                                                                firstDate: now,
                                                                lastDate: now.add(
                                                                    Duration(
                                                                        days:
                                                                            180)),
                                                                onDateChanged:
                                                                    (date) {
                                                                  setState(() =>
                                                                      selectedDate =
                                                                          date);
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
                                                                style:
                                                                    TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 16,
                                                                )),
                                                            SizedBox(
                                                                height: 12),

                                                            // — iOS-style wheel picker —
                                                            Container(
                                                              height: 150,
                                                              decoration:
                                                                  BoxDecoration(
                                                                border: Border.all(
                                                                    color: Colors
                                                                        .blue
                                                                        .shade100),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            12),
                                                              ),
                                                              child:
                                                                  CupertinoDatePicker(
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
                                                                        selectedMinute),
                                                                minuteInterval:
                                                                    1,
                                                                onDateTimeChanged:
                                                                    (dt) {
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
                                                                height: 12),
                                                            Row(
                                                              children: [
                                                                Icon(
                                                                    Icons
                                                                        .access_time,
                                                                    size: 18,
                                                                    color: Colors
                                                                        .blueGrey),
                                                                SizedBox(
                                                                    width: 6),
                                                                Text(
                                                                  "Selected: ${TimeOfDay(hour: selectedHour, minute: selectedMinute).format(context)}",
                                                                  style: TextStyle(
                                                                      fontSize:
                                                                          15,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w500),
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
                                                                context),
                                                        child: Text("Cancel"),
                                                      ),
                                                      ElevatedButton.icon(
                                                        onPressed: () {
                                                          final formattedDate =
                                                              DateFormat(
                                                                      'dd-MM-yyyy')
                                                                  .format(
                                                                      selectedDate);
                                                          final formattedTime =
                                                              TimeOfDay(
                                                                      hour:
                                                                          selectedHour,
                                                                      minute:
                                                                          selectedMinute)
                                                                  .format(
                                                                      context);

                                                          customerScreenProvider
                                                              .updateDate(
                                                                  formattedDate);
                                                          customerScreenProvider
                                                                  .timeController
                                                                  .text =
                                                              formattedTime;
                                                          Navigator.pop(
                                                              context);
                                                        },
                                                        icon: Icon(
                                                          Icons.check,
                                                          color: Colors.white,
                                                        ),
                                                        label: Text("Confirm",
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .white)),
                                                        style: ElevatedButton
                                                            .styleFrom(
                                                          backgroundColor:
                                                              Colors.blue
                                                                  .shade600,
                                                          shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          10)),
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
                                          .dateController.text.isEmpty ||
                                      customerScreenProvider
                                          .timeController.text.isEmpty)) {
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
                        if (_customerType == 'Normal' ||
                            _customerType == 'Company') ...[
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              value: customerScreenProvider.selectedEvent,
                              hint: const Text('Select Event',
                                  style: TextStyle(fontSize: 14)),
                              items: [
                                'Birthday',
                                'Anniversary',
                                'Wedding',
                                'Others'
                              ].map((String event) {
                                return DropdownMenuItem<String>(
                                  value: event,
                                  child: Text(event),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                customerScreenProvider
                                    .setSelectedEvent(newValue);
                              },
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Event',
                                isDense: false,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                              ),
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.black),
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
                          if (customerScreenProvider.selectedEvent != null &&
                              customerScreenProvider.selectedEvent!.isNotEmpty)
                            Expanded(
                              child: TextFormField(
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                readOnly:
                                    true, // Make it read-only to prevent manual input
                                onTap: () {
                                  if (customerScreenProvider.selectedEvent ==
                                      'Others') {
                                    // ✅ Manually activate the custom keyboard & focus

                                    // Add print statement to log activation
                                  } else {
                                    // ✅ Show calendar dialog

                                    DateTime now = DateTime.now();
                                    showGeneralDialog(
                                      context: context,
                                      barrierDismissible: true,
                                      barrierLabel: "Date Picker",
                                      pageBuilder:
                                          (context, animation1, animation2) {
                                        return Container(); // Not used
                                      },
                                      transitionBuilder:
                                          (context, a1, a2, widget) {
                                        return ScaleTransition(
                                          scale: Tween<double>(
                                                  begin: 0.5, end: 1.0)
                                              .animate(a1),
                                          child: FadeTransition(
                                            opacity: Tween<double>(
                                                    begin: 0.5, end: 1.0)
                                                .animate(a1),
                                            child: Dialog(
                                              backgroundColor:
                                                  Colors.transparent,
                                              elevation: 0,
                                              child: Container(
                                                width: double.infinity,
                                                constraints: BoxConstraints(
                                                    maxWidth: 350),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                  color: Colors.white,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.blue
                                                          .withOpacity(0.2),
                                                      blurRadius: 20,
                                                      spreadRadius: 5,
                                                    ),
                                                  ],
                                                ),
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      padding:
                                                          EdgeInsets.all(16),
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue[700],
                                                        borderRadius:
                                                            BorderRadius.only(
                                                          topLeft:
                                                              Radius.circular(
                                                                  20),
                                                          topRight:
                                                              Radius.circular(
                                                                  20),
                                                        ),
                                                      ),
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          Text(
                                                            "Choose Event Date",
                                                            style: TextStyle(
                                                              fontSize: 18,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          ),
                                                          Icon(
                                                            Icons
                                                                .calendar_today,
                                                            color: Colors.white,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Container(
                                                      height: 300,
                                                      child: Theme(
                                                        data: ThemeData(
                                                          colorScheme:
                                                              ColorScheme.light(
                                                            primary: Colors
                                                                    .blue[
                                                                700]!, // selected date circle color
                                                            onPrimary: Colors
                                                                .white, // text color inside circle
                                                            onSurface:
                                                                Colors.black,
                                                          ),
                                                          datePickerTheme:
                                                              DatePickerThemeData(
                                                            todayBackgroundColor:
                                                                MaterialStateProperty
                                                                    .all(Colors
                                                                            .blue[
                                                                        700]!), // ✅ Blue circle background
                                                            todayForegroundColor:
                                                                MaterialStateProperty
                                                                    .all(Colors
                                                                        .blue), // ✅ White text
                                                            shape:
                                                                const CircleBorder(), // ✅ Circle shape
                                                          ),
                                                        ),
                                                        child:
                                                            CalendarDatePicker(
                                                          initialDate: DateTime
                                                              .now(), // open with today selected
                                                          firstDate:
                                                              DateTime.now(),
                                                          lastDate: now.add(
                                                              const Duration(
                                                                  days: 180)),
                                                          onDateChanged:
                                                              (date) {
                                                            String
                                                                formattedDate =
                                                                DateFormat(
                                                                        'dd-MM-yyyy')
                                                                    .format(
                                                                        date);
                                                            customerScreenProvider
                                                                    .birthdaydateController
                                                                    .text =
                                                                formattedDate;
                                                            Navigator.of(
                                                                    context)
                                                                .pop();
                                                          },
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                                                      padding:
                                                          EdgeInsets.all(16),
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .end,
                                                        children: [
                                                          TextButton(
                                                            onPressed: () {
                                                              Navigator.of(
                                                                      context)
                                                                  .pop();
                                                            },
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
                                      transitionDuration:
                                          Duration(milliseconds: 300),
                                    );
                                  }
                                },
                                decoration: InputDecoration(
                                  border: const OutlineInputBorder(),
                                  labelText: customerScreenProvider
                                              .selectedEvent ==
                                          'Others'
                                      ? 'Enter Event Name'
                                      : 'Select ${customerScreenProvider.selectedEvent} Date',
                                  isDense: false,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  suffixIcon:
                                      customerScreenProvider.selectedEvent !=
                                              'Others'
                                          ? Icon(Icons.event)
                                          : null,
                                ),
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.black),
                                controller: customerScreenProvider
                                            .selectedEvent ==
                                        'Others'
                                    ? customerScreenProvider
                                        .otherEventController // ✅ show custom controller
                                    : customerScreenProvider
                                        .birthdaydateController,

                                focusNode:
                                    customerScreenProvider.selectedEvent ==
                                            'Others'
                                        ? _otherEventFocus
                                        : null,
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

                          const Padding(padding: EdgeInsets.all(5)),
                        ],
                      ],
                    ),
                    const Padding(padding: EdgeInsets.all(5)),
                    Row(
                      children: [
                        // if (customerScreenProvider.selectedEvent == 'Birthday')
                        if (_customerType != 'Normal' ||
                            _customerType != 'Company') ...[const SizedBox()],

                        if (_customerType == 'Normal' ||
                            _customerType == 'Company') ...[
                          const Padding(padding: EdgeInsets.all(5)),
                        ],
                        if (_customerType == 'Credit Customer') ...[
                          const Padding(padding: EdgeInsets.all(5))
                        ],

                        // const Padding(padding: EdgeInsets.all(5)),
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            // width: 200,
                            child: DropdownButtonFormField<String>(
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              value:
                                  customerScreenProvider.selectedDeliveryType,
                              hint: const Text('Delivery Type',
                                  style: TextStyle(fontSize: 14)),
                              items: [
                                'Pickup by Customer',
                                'Door Delivery',
                              ].map((String type) {
                                return DropdownMenuItem<String>(
                                  value: type,
                                  child: Text(type),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                customerScreenProvider
                                    .setSelectedDeliveryType(newValue);
                              },
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Delivery Type',
                                labelStyle: TextStyle(fontSize: 14),
                                isDense: false, // Makes the field more compact
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                              ),
                              style:
                                  TextStyle(fontSize: 14, color: Colors.black),
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

                    // Conditionally show Address and Landmark Fields if "Door Delivery" is selected
                    if (customerScreenProvider.selectedDeliveryType ==
                        'Door Delivery') ...[
                      // Row for Landmark and Address
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
                                    horizontal: 14, vertical: 8),

                                hintStyle: TextStyle(color: Colors.grey),
                              ),
                              style:
                                  TextStyle(fontSize: 14, color: Colors.black),
                              // validator: (value) {
                              //   if (_isFormValid &&
                              //       (value == null || value.isEmpty)) {
                              //     return 'Landmark is required';
                              //   }
                              //   return null;
                              // },
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
                              style:
                                  TextStyle(fontSize: 14, color: Colors.black),
                              onTap: () {
                                ActiveField.activate(
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
                    // if (_customerType == 'Company')
                    //   Row(children: [
                    //     // const Padding(padding: EdgeInsets.all(5)),
                    //     Expanded(
                    //       child: customerScreenProvider
                    //           .buildCompanyInputFields(context),
                    //     )
                    //   ]),

                    // if (_customerType == 'Credit Customer')
                    //   Row(children: [
                    //     // const Padding(padding: EdgeInsets.all(5)),
                    //     Expanded(
                    //         child:
                    //             //  customerScreenProvider
                    //             //     .buildCustomerInputFieldsforcredit(context),
                    //             CreditCustomerSearchDropdown())
                    //   ]),

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
                              fontSize: 14, color: Colors.black),
                          onTap: () {
                            ActiveField.activate(
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
                                              handleRecordingComplete),
                                    )
                                  : AudioPlayerWidget(
                                      filePath: customerScreenProvider
                                          .recordedFilePath),
                            SizedBox(
                              width: 8,
                            ),
                            // 🔹 Photo Widget
                            if (customerScreenProvider.photoScreen != null)
                              PhotosScreen(
                                imagePaths: [
                                  customerScreenProvider.pickedImage1!.path,
                                  customerScreenProvider.pickedImage2!.path,
                                ],
                              ),

                            if (customerScreenProvider.photoScreen == null)
                              ImagePickerWidget(
                                onImagesSelected:
                                    customerScreenProvider.onImagesSelected,
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
                                        if (_validateOrderDetails() &&
                                            _validateFullOrderForm()) {
                                          final filePaths =
                                              await FileStorageManager
                                                  .saveFiles(
                                            recordedFilePath:
                                                customerScreenProvider
                                                    .recordedFilePath,
                                            pickedImage1: customerScreenProvider
                                                .pickedImage1,
                                            pickedImage2: customerScreenProvider
                                                .pickedImage2,
                                          );

                                          if (_requiresApproval()) {
                                            customerScreenProvider
                                                .submitForApproval(
                                              context,
                                              cartSelectionProvider,
                                              cartProvider,
                                              customerScreenProvider
                                                  .recordedFilePath,
                                              apiSalesprovider,
                                              customerScreenProvider
                                                  .pickedImage1,
                                              customerScreenProvider
                                                  .pickedImage2,
                                              _customerType,
                                            );
                                          } else {
                                            customerScreenProvider
                                                .showAdvancePaymentPopup(
                                              context,
                                              cartSelectionProvider,
                                              cartProvider,
                                              filePaths['audioPath'],
                                              apiSalesprovider,
                                              filePaths['imagePath1'] != null
                                                  ? File(
                                                      filePaths['imagePath1']!)
                                                  : null,
                                              filePaths['imagePath2'] != null
                                                  ? File(
                                                      filePaths['imagePath2']!)
                                                  : null,
                                              _customerType,
                                              customerScreenProvider
                                                  .audioPlayer,
                                              holdId,
                                            );
                                            customerScreenProvider
                                                .clikedThePaymentButton();
                                          }
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
                                    horizontal: 16, vertical: 8),
                                fontSize: 12.0,
                              ),
                            ),

                            // 🔹 Hold Order
                            if (_customerType == 'Normal')
                              Container(
                                height: 50,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 6),
                                child: CustomButton(
                                  text: 'Hold Order',
                                  onPressed: globals.cartItems.isNotEmpty
                                      ? () {
                                          if (_formKey.currentState!
                                              .validate()) {
                                            customerScreenProvider.holdOrers(
                                              cartProvider,
                                              customerScreenProvider
                                                  .recordedFilePath,
                                              apiSalesprovider,
                                              customerScreenProvider
                                                  .pickedImage1,
                                              customerScreenProvider
                                                  .pickedImage2,
                                            );
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                  content: Text(
                                                      'Order data saved successfully!')),
                                            );
                                            _formKey.currentState!.reset();
                                            customerScreenProvider
                                                .clearControllers();
                                            globals.cartItems.clear();
                                          }
                                        }
                                      : () {},
                                  backgroundColor: globals.cartItems.isNotEmpty
                                      ? Colors.lightBlue
                                      : Colors.grey,
                                  textColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
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
                                      controller:
                                          ctrl ?? TextEditingController())),
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

  void _showDiscountStatus(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildApproveOrdersHeader(),
                  Expanded(
                    child: _buildApproveOrdersList(context, scrollController),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildApproveOrdersHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.blue.shade600,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const Center(
            child: Text(
              "Approval Orders Status",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<List<HeldOrder>> fetchApproveOrdersFromHive() async {
    var approveOrderBox = await Hive.openBox('salesApprovalOrder');

    if (approveOrderBox.isEmpty) {
      return [];
    }

    List<HeldOrder> approveOrders = [];

    for (var i = 0; i < approveOrderBox.length; i++) {
      var order = approveOrderBox.getAt(i);

      if (order != null && order is Map) {
        var orderMap =
            order.map((key, value) => MapEntry(key.toString(), value));

        // 📝 FULL PRINT
        orderMap.forEach((k, v) {
          if (v is Map) {
            v.forEach((subKey, subValue) {});
          } else if (v is List) {
          } else {}
        });

        // ✅ Get approval details from inside data.approvalDetails
        String? approvalType;
        String? approvalStatus;

        if (orderMap['data'] is Map &&
            orderMap['data']['approvalDetails'] is List &&
            orderMap['data']['approvalDetails'].isNotEmpty) {
          var firstDetail = orderMap['data']['approvalDetails'][0];
          if (firstDetail is Map) {
            approvalType = firstDetail['approvalType']?.toString();
            approvalStatus = firstDetail['approvalStatus']?.toString();
          }
        }

        String? status = orderMap['data']?['status']?.toString();

        // ✅ Filter
        if (approvalType == 'Cheque' ||
            approvalType == 'Discount' ||
            status == 'Waiting for Approval') {
          try {
            // Flatten "data" into a single map
            Map<String, dynamic> flatMap = {};
            if (orderMap['data'] is Map) {
              flatMap = Map<String, dynamic>.from(orderMap['data']);
            }
            // Add any other root-level fields if needed
            flatMap['salesOrderId'] = orderMap['salesOrderId'] ?? '';
            flatMap['approvalDetails'] = flatMap['approvalDetails'] ?? [];

            HeldOrder heldOrder = HeldOrder.fromMap(flatMap);
            approveOrders.add(heldOrder);
          } catch (e, stackTrace) {}
        } else {}
      }
    }

    return approveOrders;
  }

  Widget _buildApproveOrdersList(
    BuildContext context,
    ScrollController scrollController,
  ) {
    return FutureBuilder<List<HeldOrder>>(
      future: fetchApproveOrdersFromHive(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text(
              'No approve orders available',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          );
        }
        final orders = snapshot.data!;
        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            return _buildApproveOrderListItem(context, orders[index]);
          },
        );
      },
    );
  }

  Widget _buildApproveOrderListItem(BuildContext context, HeldOrder order) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: Card(
        color: Colors.white.withOpacity(0.8),
        elevation: 6,
        shadowColor: Colors.black.withOpacity(0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => restoreHeldOrderData(context, order),
          splashColor: Colors.blue.withOpacity(0.05),
          highlightColor: Colors.blueAccent.withOpacity(0.1),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.95),
                  Colors.blueGrey.withOpacity(0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(12), // reduced padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        order.customerName ?? "Unknown Customer",
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 17, // reduced from 20
                          color: Colors.black87,
                          letterSpacing: 0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _buildStatusChip(order.status),
                  ],
                ),
                const SizedBox(height: 4), // reduced from 6
                Container(
                  height: 2,
                  width: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.blueAccent, Colors.lightBlueAccent],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8), // reduced from 14

                /// Delivery Info
                _buildInfoRow(
                  Icons.calendar_month_rounded,
                  "Delivery Date: ${order.deliveryDate ?? '--'}",
                  iconColor: Colors.deepPurpleAccent,
                ),
                const SizedBox(height: 6), // reduced from 10
                _buildInfoRow(
                  Icons.access_time_filled_rounded,
                  "Delivery Time: ${order.deliveryTime ?? '--'}",
                  iconColor: Colors.orangeAccent,
                ),
                const SizedBox(height: 6),
                _buildInfoRow(
                  Icons.verified_rounded,
                  "Approval Status: ${order.approvalDetails?.isNotEmpty == true ? order.approvalDetails!.last.approvalStatus ?? 'Unknown' : 'Unknown'}",
                  iconColor: Colors.green,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String? status) {
    Color bgColor;
    switch (status?.toLowerCase()) {
      case 'approved':
        bgColor = Colors.green;
        break;
      case 'pending':
        bgColor = Colors.orange;
        break;
      case 'rejected':
        bgColor = Colors.redAccent;
        break;
      default:
        bgColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 4), // smaller chip
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            bgColor.withOpacity(0.9),
            bgColor.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: bgColor.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: Colors.white), // smaller dot
          const SizedBox(width: 4),
          Text(
            status ?? 'Unknown',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12, // reduced from 14
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text,
      {Color iconColor = Colors.blueGrey}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4), // reduced from 6
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: iconColor), // smaller icon
        ),
        const SizedBox(width: 8), // reduced from 12
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13, // reduced from 15
              color: Colors.black87,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }
}
