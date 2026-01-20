import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
// import 'package:yenposapp/screens/sale_order_screen.dart';
import 'package:flutter/material.dart';
// import 'package:outletmanager/widgets/common_layout.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Global/global_data_manager.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Sale_order/Models/sales_order_display_model.dart';
import 'package:yenpos/Sale_order/Provider/detailsProvider.dart';
import 'package:yenpos/Sale_order/Provider/editcustomerscreenProvider.dart';
import 'package:yenpos/Sale_order/Provider/get_sales_order_service.dart';
import 'package:yenpos/Sale_order/Screens/all_orders.dart';
import 'package:yenpos/Sale_order/Screens/edit_customerr_dropdown.dart';
import 'package:yenpos/Sale_order/Widgets/customcharge_keybaord.dart';
import 'package:yenpos/Sale_order/Widgets/date_handler.dart';
import 'package:yenpos/Sale_order/Widgets/image-picker-widget.dart';
import 'package:yenpos/Sale_order/Widgets/photoScreen.dart';
import 'package:yenpos/Sale_order/Widgets/voice_recording.dart';

// import '../../../../Global/flutter-audio-player-alt.dart';
import '../../../../Global/Audio Player/audio_provider.dart';
import '../../../../Global/Audio Player/audio_screen.dart';

import 'editsalesperson_dropdown.dart';

class EditCustomerDetails extends StatefulWidget {
  const EditCustomerDetails({
    super.key,
    this.selectedOrder,
    this.isEditing = false,
    this.orderType,
  });

  final bool isEditing;
  final String? orderType;
  final SalesOrderDisplay? selectedOrder;

  @override
  _EditCustomerDetailsState createState() => _EditCustomerDetailsState();
}

class _EditCustomerDetailsState extends State<EditCustomerDetails> {
  TextEditingController customersearchController = TextEditingController();
  String customersearchQuery = '';
  List<Map<String, String>> filteredCustomers = [];
  String? holdId;
  bool isSuggestionsVisible = false;
  List<Map<String, String>> suggestions = [];

  // String recordedFilePath = '';
  // File? _pickedImage1;
  // File? _pickedImage2;
  final String _customerType = 'Normal';

  final _formKey = GlobalKey<FormState>();
  // String? audioPlayerId;

  bool _isEditing = false;

  bool _isFormValid = false;
  final int _selectedRadioValue = 0;
  bool _showMinusButtonforaudio = true;
  bool _showMinusButtonforimage = true;

  @override
  void didUpdateWidget(EditCustomerDetails oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isEditing != widget.isEditing) {
      setState(() {
        _isEditing = widget.isEditing;
      });
    }
  }

  @override
  void dispose() {
    final customerScreenProvider = context.read<EditCustomerScreenProvider>();

    customerScreenProvider.customChargeController.removeListener(
      _customChargeListener,
    );

    quantityChangesNotifier.dispose();

    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    _isEditing = widget.isEditing;

    if (widget.selectedOrder != null) {
      _populateFields();
    }

    quantityChangesNotifier = ValueNotifier<Map<int, double>>({});

    final customerScreenProvider = context.read<EditCustomerScreenProvider>();

    customerScreenProvider.customChargeController.addListener(
      _customChargeListener,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final apiService = context.read<ApiServiceSalesOrderProvider>();

      final initialCharge =
          double.tryParse(customerScreenProvider.customChargeController.text) ??
          0.0;

      customerScreenProvider.setCustomCharge(initialCharge);
    });
  }

  // Private listener method
  void _customChargeListener() {
    final customerScreenProvider = Provider.of<EditCustomerScreenProvider>(
      context,
      listen: false,
    );
    final text = customerScreenProvider.customChargeController.text;
    final charge = double.tryParse(text) ?? 0.0;
    customerScreenProvider.setCustomCharge(
      charge,
    ); // Triggers notifyListeners()
  }

  void _populateFields() {
    final customerScreenProvider = Provider.of<EditCustomerScreenProvider>(
      context,
      listen: false,
    );

    if (widget.selectedOrder != null) {

      final customerScreenProvider = Provider.of<EditCustomerScreenProvider>(
        context,
        listen: false,
      );

      if (widget.selectedOrder != null) {
        String deliveryDate = widget.selectedOrder!.deliveryDate;

        customerScreenProvider.dateController.text = DateFormat(
          'dd-MM-yyyy',
        ).format(DateTime.parse(deliveryDate));
        String formattedEventDate = widget.selectedOrder!.eventDate ?? '';

        // ✅ Use helper method
        if (formattedEventDate != null && formattedEventDate.isNotEmpty) {
          String? formattedDate = DateFormatHelper.validateAndConvert(
            formattedEventDate,
          );
          if (formattedDate != null) {
            customerScreenProvider.birthdaydateController.text = formattedDate;
          }
        }

        customerScreenProvider.timeController.text =
            widget.selectedOrder!.deliveryTime;
        customerScreenProvider.selectedOrderType =
            widget.selectedOrder!.orderType;
        customerScreenProvider.setSelectedEvent(widget.selectedOrder!.event);

        customerScreenProvider.setSelectedDeliveryType(
          widget.selectedOrder!.deliveryType,
        );

        if (widget.selectedOrder!.deliveryType == 'Door Delivery') {
          customerScreenProvider.landmarkController.text =
              widget.selectedOrder!.landmark;
          customerScreenProvider.addressController.text =
              widget.selectedOrder!.address;
        }

        customerScreenProvider.customerNameController.text =
            widget.selectedOrder!.customerName;
        customerScreenProvider.customChargeController.text =
            (widget.selectedOrder!.customCharge).toString();

        customerScreenProvider.mobileNoController.text =
            widget.selectedOrder!.customerNumber;

        customerScreenProvider.searchController.text =
            widget.selectedOrder!.employeeName;

        customerScreenProvider.audioPlayerId =
            widget.selectedOrder!.salesOrderId;
        customerScreenProvider.photoScreenId =
            widget.selectedOrder!.salesOrderId;
      } else {}

      // ✅ CORRECTED: Custom Charge population with multiple types

      // Check if customChargeType and customCharge arrays exist
      if (widget.selectedOrder!.customChargeType != null &&
          widget.selectedOrder!.customCharge != null) {

        // Clear existing controllers
        customerScreenProvider.customChargeControllers.clear();

        // Create controllers for each charge type
        for (
          int i = 0;
          i < widget.selectedOrder!.customChargeType!.length;
          i++
        ) {
          String chargeType = widget.selectedOrder!.customChargeType![i];
          double chargeValue = 0.0;

          // Get corresponding value if available
          if (i < widget.selectedOrder!.customCharge!.length) {
            // Handle both int and double types
            dynamic value = widget.selectedOrder!.customCharge![i];
            if (value is int) {
              chargeValue = value.toDouble();
            } else if (value is double) {
              chargeValue = value;
            } else if (value is String) {
              chargeValue = double.tryParse(value) ?? 0.0;
            }
          }

          // Create and set controller
          final controller = TextEditingController(
            text: chargeValue > 0 ? chargeValue.toStringAsFixed(2) : '0.00',
          );

          customerScreenProvider.customChargeControllers[chargeType] =
              controller;

        }

        // Calculate total custom charge
        double totalCustomCharge = 0.0;
        if (widget.selectedOrder!.customCharge != null) {
          for (var charge in widget.selectedOrder!.customCharge!) {
            if (charge is int) {
              totalCustomCharge += charge.toDouble();
            } else if (charge is double) {
              totalCustomCharge += charge;
            } else if (charge is String) {
              totalCustomCharge += double.tryParse(charge.toString()) ?? 0.0;
            }
          }
        }

        // Set the total custom charge
        customerScreenProvider.customChargeController.text = totalCustomCharge
            .toStringAsFixed(2);
        customerScreenProvider.modifiedCustomCharge = totalCustomCharge;

      } else {
        // Fallback to single custom charge value
        customerScreenProvider.customChargeController.text =
            (widget.selectedOrder!.totalCustomCharge ?? 0).toString();
        customerScreenProvider.modifiedCustomCharge =
            widget.selectedOrder!.totalCustomCharge ?? 0;
      }

      // ... (മറ്റ് existing code) ...

    } else {
    }

    // Clear existing controllers first
    customerScreenProvider.customChargeControllers.clear();

    // Clear the selected charge type
    customerScreenProvider.selectedChargeType = null;

    // Check if customChargeType and customCharge arrays exist
    if (widget.selectedOrder!.customChargeType != null &&
        widget.selectedOrder!.customCharge != null) {

      // Create controllers ONLY for charges that exist in this order
      for (int i = 0; i < widget.selectedOrder!.customChargeType!.length; i++) {
        String chargeType = widget.selectedOrder!.customChargeType![i];
        double chargeValue = 0.0;

        // Get corresponding value if available
        if (i < widget.selectedOrder!.customCharge!.length) {
          // Handle both int and double types
          dynamic value = widget.selectedOrder!.customCharge![i];
          if (value is int) {
            chargeValue = value.toDouble();
          } else if (value is double) {
            chargeValue = value;
          } else if (value is String) {
            chargeValue = double.tryParse(value) ?? 0.0;
          }
        }

        // Create controller ONLY if value > 0
        // This ensures empty controllers for charges not in this order
        final controller = TextEditingController(
          text: chargeValue > 0 ? chargeValue.toStringAsFixed(2) : '',
        );

        customerScreenProvider.customChargeControllers[chargeType] = controller;

      }

      // Calculate total custom charge from THIS order only
      double totalCustomCharge = 0.0;
      if (widget.selectedOrder!.customCharge != null) {
        for (var charge in widget.selectedOrder!.customCharge!) {
          if (charge is int) {
            totalCustomCharge += charge.toDouble();
          } else if (charge is double) {
            totalCustomCharge += charge;
          } else if (charge is String) {
            totalCustomCharge += double.tryParse(charge.toString()) ?? 0.0;
          }
        }
      }

      // Set the total custom charge
      customerScreenProvider.customChargeController.text = totalCustomCharge
          .toStringAsFixed(2);
      customerScreenProvider.modifiedCustomCharge = totalCustomCharge;

    } else {
      // Fallback to single custom charge value
      double singleCharge = widget.selectedOrder!.totalCustomCharge ?? 0;
      customerScreenProvider.customChargeController.text = singleCharge > 0
          ? singleCharge.toStringAsFixed(2)
          : '0.00';
      customerScreenProvider.modifiedCustomCharge = singleCharge;
    }

    // ... (മറ്റ് existing code) ...


    // Print all controllers and their values
    customerScreenProvider.customChargeControllers.forEach((key, controller) {
    });
  }

  @override
  Widget build(BuildContext context) {
    // final cartProvider = Provider.of<CartProvider>(context);
    final customerScreenProvider = Provider.of<EditCustomerScreenProvider>(
      context,
    );

    final audioprovider = Provider.of<AudioProvider>(context, listen: false);

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

        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.zero,
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          const Padding(padding: EdgeInsets.all(5)),
                          Expanded(
                            child: TextFormField(
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              controller: customerScreenProvider.dateController,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                enabled: _isEditing,
                                labelText: "Delivery Date",
                                labelStyle: TextStyle(fontSize: 14),
                                isDense: false, // Makes the field more compact
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ), // Reduced padding
                              ),
                              style: TextStyle(fontSize: 14),
                              readOnly: _isEditing,
                              onTap: () async {
                                DateTime now = DateTime.now();
                                DateTime? pickedDate = await showDatePicker(
                                  context: context,
                                  initialDate: now,
                                  firstDate: now,
                                  lastDate: now.add(const Duration(days: 180)),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: ColorScheme.light(
                                          primary: Colors.blue,
                                          onPrimary: Colors.white,
                                          onSurface: Colors.black,
                                        ),
                                        textButtonTheme: TextButtonThemeData(
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.blue,
                                          ),
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );

                                if (pickedDate != null) {
                                  // 💾 Store ISO string internally
                                  customerScreenProvider
                                      .selectedDeliveryDateIso = pickedDate
                                      .toIso8601String();

                                  // 📝 Show in controller as dd-MM-yyyy
                                  String formattedDate = DateFormat(
                                    'dd-MM-yyyy',
                                  ).format(pickedDate);
                                  customerScreenProvider.dateController.text =
                                      formattedDate;
                                }
                              },
                              validator: (value) {
                                if (_isFormValid &&
                                    (value == null || value.isEmpty)) {
                                  return 'Delivery Date is required';
                                }
                                return null;
                              },
                            ),
                          ),
                          const Padding(padding: EdgeInsets.all(5)),
                          Expanded(
                            child: TextFormField(
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              controller: customerScreenProvider.timeController,
                              enabled: _isEditing,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Delivery Time',
                                labelStyle: TextStyle(fontSize: 14),
                                isDense: false,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                              ),
                              style: TextStyle(fontSize: 14),
                              readOnly: true,
                              onTap: () async {
                                DateTime now = DateTime.now();
                                TimeOfDay currentTime = TimeOfDay.now();

                                DateTime
                                selectedDate = DateFormat('dd-MM-yyyy').parse(
                                  customerScreenProvider.dateController.text,
                                );

                                bool isToday =
                                    selectedDate.year == now.year &&
                                    selectedDate.month == now.month &&
                                    selectedDate.day == now.day;

                                FocusScope.of(
                                  context,
                                ).requestFocus(FocusNode());

                                TimeOfDay? pickedTime = await showTimePicker(
                                  context: context,
                                  useRootNavigator:
                                      false, // 🔥 FIX: Prevents Tooltip crash
                                  initialTime: isToday
                                      ? TimeOfDay.fromDateTime(
                                          now.add(const Duration(minutes: 1)),
                                        )
                                      : const TimeOfDay(hour: 0, minute: 0),

                                  // ---- 📌 CUSTOM TIME PICKER THEME ----
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: ColorScheme.light(
                                          primary: Colors
                                              .blue, // Selected time, accents
                                          onPrimary: Colors
                                              .white, // Text on selected background
                                          onSurface:
                                              Colors.black, // Normal text
                                        ),
                                        timePickerTheme: TimePickerThemeData(
                                          dialHandColor: Colors.blue,
                                          dialBackgroundColor: Colors.white,
                                          hourMinuteColor: Colors.blue
                                              .withOpacity(0.1),
                                          hourMinuteTextColor: Colors.blue,
                                          dayPeriodColor: Colors.blue
                                              .withOpacity(0.1),
                                          dayPeriodTextColor: Colors.blue,
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );

                                if (pickedTime != null) {
                                  if (isToday &&
                                      (pickedTime.hour < currentTime.hour ||
                                          (pickedTime.hour ==
                                                  currentTime.hour &&
                                              pickedTime.minute <=
                                                  currentTime.minute))) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Delivery time must be in the future',
                                        ),
                                      ),
                                    );
                                  } else {
                                    customerScreenProvider.timeController.text =
                                        pickedTime.format(context);
                                  }
                                }
                              },
                              validator: (value) {
                                if (_isFormValid &&
                                    (value == null || value.isEmpty)) {
                                  return 'Delivery Time is required';
                                }
                                return null;
                              },
                            ),
                          ),
                          //     if (_customerType == 'Normal') ...[
                          const Padding(padding: EdgeInsets.all(5)),
                          // ],
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
                                value:
                                    customerScreenProvider
                                        .getEventList()
                                        .contains(
                                          customerScreenProvider.selectedEvent,
                                        )
                                    ? customerScreenProvider.selectedEvent
                                    : null,
                                hint: const Text(
                                  'Select Event',
                                  style: TextStyle(fontSize: 14),
                                ),
                                items: customerScreenProvider
                                    .getEventList()
                                    .map((event) {
                                      return DropdownMenuItem<String>(
                                        value: event,
                                        child: Text(event),
                                      );
                                    })
                                    .toList(),
                                onChanged: _isEditing
                                    ? (String? newValue) {
                                        if (newValue != null) {
                                          customerScreenProvider
                                              .setSelectedEvent(newValue);

                                          // Trigger rebuild
                                          setState(() {});
                                        }
                                      }
                                    : null,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(),
                                  labelText: 'Event',
                                  enabled: _isEditing,
                                  isDense: false,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
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
                            // Date field - conditional rendering with key to force rebuild
                            if (customerScreenProvider.selectedEvent != null &&
                                customerScreenProvider
                                    .selectedEvent!
                                    .isNotEmpty &&
                                customerScreenProvider.selectedEvent !=
                                    "Others")
                              Expanded(
                                child: TextFormField(
                                  key: ValueKey(
                                    'date_field_${customerScreenProvider.selectedEvent}',
                                  ),
                                  autovalidateMode:
                                      AutovalidateMode.onUserInteraction,
                                  controller: customerScreenProvider
                                      .birthdaydateController,
                                  enabled: _isEditing,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(),
                                    labelText:
                                        "${customerScreenProvider.selectedEvent} Date",
                                    labelStyle: const TextStyle(fontSize: 14),
                                    isDense: false,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 10,
                                    ),
                                  ),
                                  style: const TextStyle(fontSize: 14),
                                  readOnly: true,
                                  onTap: () async {
                                    if (_isEditing) {
                                      DateTime now = DateTime.now();
                                      DateTime? pickedDate =
                                          await showDatePicker(
                                            context: context,
                                            initialDate: DateTime.now(),
                                            firstDate: DateTime.now(),
                                            lastDate: now.add(
                                              const Duration(days: 180),
                                            ),
                                          );

                                      if (pickedDate != null) {
                                        // ✅ Always format as 'dd-MM-yyyy'
                                        String formattedDate = DateFormat(
                                          'dd-MM-yyyy',
                                        ).format(pickedDate);
                                        customerScreenProvider
                                                .birthdaydateController
                                                .text =
                                            formattedDate;
                                        setState(() {});
                                      }
                                    }
                                  },
                                  validator: (value) {
                                    if (_isFormValid &&
                                        (value == null || value.isEmpty)) {
                                      return 'Event Date is required';
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
                          if (_customerType == 'Normal' ||
                              _customerType == 'Company') ...[
                            const Padding(padding: EdgeInsets.all(5)),
                          ],
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              value:
                                  customerScreenProvider.selectedDeliveryType,
                              hint: const Text(
                                'Delivery Type',
                                style: TextStyle(fontSize: 11),
                              ),
                              items: GlobalDataManager().deliveryTypes
                                  .map<DropdownMenuItem<String>>((item) {
                                    return DropdownMenuItem<String>(
                                      value: item['deliveryType'],
                                      child: Text(item['deliveryType']),
                                    );
                                  })
                                  .toList(),
                              onChanged: _isEditing
                                  ? (String? newValue) {
                                      if (newValue != null) {
                                        customerScreenProvider
                                            .setSelectedDeliveryType(newValue);
                                        // Clear address fields when delivery type changes
                                        if (newValue.toLowerCase() !=
                                            'door delivery') {
                                          customerScreenProvider
                                              .landmarkController
                                              .clear();
                                          customerScreenProvider
                                              .addressController
                                              .clear();
                                        }
                                        // Force rebuild to show/hide landmark and address fields
                                        setState(() {});
                                      }
                                    }
                                  : null,
                              decoration: InputDecoration(
                                enabled: _isEditing,
                                border: OutlineInputBorder(),
                                labelText: 'Delivery Type',
                                labelStyle: const TextStyle(fontSize: 11),
                                isDense: false,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 13,
                                  vertical: 8,
                                ),
                              ),
                              style: const TextStyle(
                                fontSize: 13,
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
                          const Padding(padding: EdgeInsets.all(5)),
                          Expanded(
                            child: EditEmployeeSearchDropdown(
                              modifyMode: _isEditing,
                            ),
                          ),
                          const Padding(padding: EdgeInsets.all(5)),
                        ],
                      ),
                      const Padding(padding: EdgeInsets.all(5)),
                      // Conditional Address and Landmark Fields
                      if ((customerScreenProvider.selectedDeliveryType ?? '')
                              .toLowerCase() ==
                          'door delivery') ...[
                        Row(
                          children: [
                            const Padding(padding: EdgeInsets.all(5)),
                            Expanded(
                              child: TextFormField(
                                key: const ValueKey('landmark_field'),
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                controller:
                                    customerScreenProvider.landmarkController,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(),
                                  labelText: 'Landmark',
                                  enabled: _isEditing,
                                  labelStyle: const TextStyle(fontSize: 14),
                                  isDense: false,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                  hintText:
                                      'e.g., Near ABC Park, Opposite XYZ Mall',
                                  hintStyle: const TextStyle(
                                    color: Colors.grey,
                                  ),
                                ),
                                style: const TextStyle(fontSize: 14),
                                validator: (value) {
                                  if (_isFormValid &&
                                      (value == null || value.isEmpty)) {
                                    return 'Landmark is required';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const Padding(padding: EdgeInsets.all(5)),
                            Expanded(
                              child: TextFormField(
                                key: const ValueKey('address_field'),
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                controller:
                                    customerScreenProvider.addressController,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(),
                                  labelText: 'Address',
                                  enabled: _isEditing,
                                  labelStyle: const TextStyle(fontSize: 14),
                                  isDense: false,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                  hintText:
                                      'e.g., 1234 Main Street, Apartment 12',
                                  hintStyle: const TextStyle(
                                    color: Colors.grey,
                                  ),
                                ),
                                style: const TextStyle(fontSize: 14),
                                validator: (value) {
                                  if (_isFormValid &&
                                      (value == null || value.isEmpty)) {
                                    return 'Address is required';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const Padding(padding: EdgeInsets.all(5)),
                          ],
                        ),
                      ],

                      const Padding(padding: EdgeInsets.all(5)),

                      Row(
                        children: [
                          // const Padding(padding: EdgeInsets.all(5)),
                          Expanded(
                            child:
                                //  customerScreenProvider
                                //     .buildCustomerInputFields(context, _isEditing),
                                EditCustomerSearchDropdown(
                                  isModifyMode: _isEditing,
                                ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Padding(padding: EdgeInsets.all(5)),
                          if (_customerType == 'Normal' ||
                              _customerType == 'Company') ...[
                            // ========================= LEFT DROPDOWN + INPUT ==========================
                            Expanded(
                              flex: 4,
                              child: StatefulBuilder(
                                builder: (context, setState) {
                                  return Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: ElevatedButton(
                                          onPressed: () {

                                            _showCustomDialog(
                                              customerScreenProvider,
                                              setState,
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          child: Text(
                                            customerScreenProvider
                                                        .modifiedCustomCharge !=
                                                    0
                                                ? "Custom Charge: ₹${customerScreenProvider.modifiedCustomCharge.toString()}"
                                                : "Custom Charge",
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
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
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // if (customerScreenProvider.audioPlayerId == null ||
                  //     audioprovider.state.error != null ||
                  //     customerScreenProvider.audioPlayerId != null)
                  if (widget.selectedOrder!.audio == null ||
                      audioprovider.state.error != null ||
                      widget.selectedOrder!.audio != null)
                    Flexible(
                      child: Container(
                        constraints: const BoxConstraints(
                          maxWidth: 600,
                          maxHeight: 150,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Voice Recorder or Audio Player
                            if (customerScreenProvider.audioPlayerId == null ||
                                audioprovider.state.error != null)
                              Flexible(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blueGrey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: VoiceRecorder(
                                    onRecordingComplete: customerScreenProvider
                                        .handleRecordingComplete,
                                  ),
                                ),
                              ),

                            // Minus button for audio
                            if (_isEditing &&
                                _showMinusButtonforaudio &&
                                customerScreenProvider.audioPlayerId != null)
                              IconButton(
                                icon: const Icon(
                                  Icons.remove_circle,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  setState(() {
                                    customerScreenProvider.previousAudioId =
                                        customerScreenProvider.audioPlayerId;
                                    customerScreenProvider.audioPlayerId = null;
                                    _showMinusButtonforaudio = false;
                                  });
                                },
                              ),

                            if (customerScreenProvider.audioPlayerId != null &&
                                audioprovider.state.error == null)
                              Flexible(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blueGrey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  // child: AudioPlayerWidget(
                                  //     customId: customerScreenProvider
                                  //         .audioPlayerId!),
                                  child: AudioPlayerWidget(
                                    filePath: widget.selectedOrder!.audio ?? "",
                                  ),
                                ),
                              ),
                            SizedBox(width: 40),
                            // Photo Screen
                            if (customerScreenProvider.photoScreenId != null)
                              Flexible(
                                child: Container(
                                  constraints: const BoxConstraints(
                                    maxWidth: 100,
                                    maxHeight: 100,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Color.fromARGB(255, 196, 155, 155),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: PhotosScreen(
                                    imagePaths:
                                        widget.selectedOrder!.imagePaths ?? [],
                                  ),
                                ),
                              ),
                            // Minus button for image
                            if (_isEditing &&
                                _showMinusButtonforimage &&
                                customerScreenProvider.photoScreenId != null)
                              IconButton(
                                icon: const Icon(
                                  Icons.remove_circle,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  setState(() {
                                    customerScreenProvider.previousImageId =
                                        customerScreenProvider.photoScreenId;
                                    customerScreenProvider.photoScreenId = null;
                                    _showMinusButtonforimage = false;
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ),

                  // Image Picker
                  if (customerScreenProvider.photoScreenId == null &&
                      _isEditing)
                    Flexible(
                      child: MultiImagePickerWidget(
                        onImagesSelected: (images) {
                          customerScreenProvider.pickedImages = images;
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomDialog(
    EditCustomerScreenProvider customerScreenProvider,
    void Function(void Function()) setState,
  ) {
    // Initialize with current values
    final Map<String, TextEditingController> controllers = {};
    final Map<String, double> initialValues = {};

    // 1. Get all charge types from GlobalDataManager
    for (var charge in GlobalDataManager().charges) {
      final chargeType = charge['chargeType'];
      double currentValue = 0.0;

      // Check if we have existing value for this charge type
      if (customerScreenProvider.customChargeValues.containsKey(chargeType)) {
        currentValue = customerScreenProvider.customChargeValues[chargeType]!;
      }

      // Create controller with current value (only if > 0, otherwise empty)
      final controller = TextEditingController(
        text: currentValue > 0 ? currentValue.toStringAsFixed(2) : '',
      );
      controllers[chargeType] = controller;
      initialValues[chargeType] = currentValue;
    }

    // 2. Register controllers with keyboard provider
    final keyboardProvider = context.read<CustomchargeKeyboardProvider>();
    controllers.forEach((key, controller) {
      keyboardProvider.registerController(key, controller);
    });

    String selectedChargeType =
        customerScreenProvider.selectedChargeType ??
        (GlobalDataManager().charges.isNotEmpty
            ? GlobalDataManager().charges.first['chargeType']
            : '');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              child: Container(
                width: 360,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with total
                    AnimatedBuilder(
                      animation: Listenable.merge(controllers.values),
                      builder: (context, _) {
                        double total = controllers.values.fold(0.0, (
                          sum,
                          ctrl,
                        ) {
                          final text = ctrl.text.trim();
                          return text.isNotEmpty
                              ? (double.tryParse(text) ?? 0.0)
                              : 0.0;
                        });
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Text(
                            "Total Charges: Rs.${total.toStringAsFixed(0)}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Charge list
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: GlobalDataManager().charges.length,
                        separatorBuilder: (_, __) => Divider(height: 1),
                        itemBuilder: (context, index) {
                          final charge = GlobalDataManager().charges[index];
                          final controller = controllers[charge['chargeType']]!;
                          final isSelected =
                              selectedChargeType == charge['chargeType'];

                          return GestureDetector(
                            onTap: () {
                              setStateDialog(() {
                                selectedChargeType = charge['chargeType'];
                                customerScreenProvider.selectedChargeType =
                                    selectedChargeType;
                                keyboardProvider.setActiveController(
                                  charge['chargeType'],
                                );
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.blue.withOpacity(0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.blueAccent.withOpacity(0.5)
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    charge['chargeType'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 90,
                                    child: IgnorePointer(
                                      child: TextFormField(
                                        controller: controller,
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                vertical: 8,
                                                horizontal: 10,
                                              ),
                                          filled: true,
                                          fillColor: isSelected
                                              ? Colors.blue.shade50
                                              : Colors.grey.withOpacity(0.1),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          hintText: '',
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Keyboard
                    Container(
                      height: 220,
                      margin: const EdgeInsets.only(top: 8),
                      child: Consumer<CustomchargeKeyboardProvider>(
                        builder: (context, provider, _) {
                          if (selectedChargeType.isEmpty) {
                            return const Center(
                              child: Text('Select a charge to edit'),
                            );
                          }

                          final controller = controllers[selectedChargeType];
                          if (controller == null) {
                            return const Center(
                              child: Text('Selected charge not found'),
                            );
                          }

                          return CustomchargeKeyboardWidgetAll2(
                            controller: controller,
                            controllerKey: selectedChargeType,
                            onClose: () {
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancel"),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                          ),
                          onPressed: () {
                            // 1. Collect only charges with values > 0
                            final Map<String, double> updatedCharges = {};
                            controllers.forEach((chargeType, controller) {
                              final text = controller.text.trim();
                              if (text.isNotEmpty) {
                                final value = double.tryParse(text) ?? 0.0;
                                if (value > 0) {
                                  updatedCharges[chargeType] = value;
                                }
                              }
                            });

                            // 2. Calculate total
                            double totalCharges = updatedCharges.values.fold(
                              0.0,
                              (sum, value) => sum + value,
                            );

                            // 3. Update provider
                            setState(() {
                              // Store only charges with values
                              customerScreenProvider.customChargeValues.clear();
                              customerScreenProvider.customChargeValues.addAll(
                                updatedCharges,
                              );

                              // Update total charge controller
                              customerScreenProvider
                                  .customChargeController
                                  .text = totalCharges > 0
                                  ? totalCharges.toStringAsFixed(2)
                                  : '0.00';

                              // Store controllers for future use
                              customerScreenProvider.customChargeControllers
                                  .clear();
                              customerScreenProvider.customChargeControllers
                                  .addAll(controllers);

                              // Update selected type
                              customerScreenProvider.selectedChargeType =
                                  selectedChargeType;
                            });


                            Navigator.pop(context);
                          },
                          child: const Text(
                            "Apply All",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
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
    );
  }
}
