import 'package:intl/intl.dart';
// import 'package:yenposapp/screens/sale_order_screen.dart';
import 'package:flutter/material.dart';
// import 'package:outletmanager/widgets/common_layout.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Sale_order/Models/sales_order_display_model.dart';
import 'package:yenpos/Sale_order/Provider/detailsProvider.dart';
import 'package:yenpos/Sale_order/Provider/editcustomerscreenProvider.dart';
import 'package:yenpos/Sale_order/Screens/all_orders.dart';
import 'package:yenpos/Sale_order/Screens/edit_customerr_dropdown.dart';
import 'package:yenpos/Sale_order/Widgets/image-picker-widget.dart';
import 'package:yenpos/Sale_order/Widgets/photoScreen.dart';
import 'package:yenpos/Sale_order/Widgets/voice_recording.dart';

// import '../../../../Global/flutter-audio-player-alt.dart';
import '../../../../Global/Audio Player/audio_provider.dart';
import '../../../../Global/Audio Player/audio_screen.dart';

import 'editsalesperson_dropdown.dart';


class EditCustomerDetails extends StatefulWidget {
  final SalesOrderDisplay? selectedOrder;
  final bool isEditing;
  final String? orderType;
  final GlobalKey keyboardKey;
  const EditCustomerDetails(
      {super.key,
      this.selectedOrder,
      this.isEditing = false,
      this.orderType,
      required this.keyboardKey});
  @override
  _EditCustomerDetailsState createState() => _EditCustomerDetailsState();
}

class _EditCustomerDetailsState extends State<EditCustomerDetails> {
  final _formKey = GlobalKey<FormState>();
  bool _isFormValid = false;

  // String recordedFilePath = '';
  // File? _pickedImage1;
  // File? _pickedImage2;
  final String _customerType = 'Normal';
  final int _selectedRadioValue = 0;
  // String? audioPlayerId;

  bool _isEditing = false;
  String? holdId;
  List<Map<String, String>> suggestions = [];
  bool isSuggestionsVisible = false;
  bool _showMinusButtonforaudio = true;
  bool _showMinusButtonforimage = true;
  TextEditingController customersearchController = TextEditingController();
  List<Map<String, String>> filteredCustomers = [];
  String customersearchQuery = '';

  @override
  void initState() {
    super.initState();
    _isEditing = widget.isEditing;
    if (widget.selectedOrder != null) {
      _populateFields();
    }
  }

  @override
  void didUpdateWidget(EditCustomerDetails oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isEditing != widget.isEditing) {
      setState(() {
        _isEditing = widget.isEditing;
      });
    }
  }

  void _populateFields() {
    final customerScreenProvider =
        Provider.of<EditCustomerScreenProvider>(context, listen: false);

    if (widget.selectedOrder != null) {
      String deliveryDate = widget.selectedOrder!.deliveryDate;
      customerScreenProvider.dateController.text = deliveryDate;

      String formattedEventDate = widget.selectedOrder!.eventDate ?? '';
      print(
          "widget.selectedOrder!.eventDate ${widget.selectedOrder!.eventDate}");
      print("formattedEventDate:$formattedEventDate");

      customerScreenProvider.birthdaydateController.text = formattedEventDate;
      print("formattedEventDate $formattedEventDate");
      print(
          "customerScreenProvider.birthdaydateController.text ${customerScreenProvider.birthdaydateController.text}");
      customerScreenProvider.timeController.text =
          widget.selectedOrder!.deliveryTime ?? '';
      customerScreenProvider.selectedOrderType =
          widget.selectedOrder!.orderType ?? '';
      customerScreenProvider
          .setSelectedEvent(widget.selectedOrder!.event ?? '');

      customerScreenProvider
          .setSelectedDeliveryType(widget.selectedOrder!.deliveryType ?? '');

      if (widget.selectedOrder!.deliveryType == 'Door Delivery') {
        customerScreenProvider.landmarkController.text =
            widget.selectedOrder!.landmark ?? '';
        customerScreenProvider.addressController.text =
            widget.selectedOrder!.address ?? '';
      }

      customerScreenProvider.customerNameController.text =
          widget.selectedOrder!.customerName ?? '';

      customerScreenProvider.mobileNoController.text =
          widget.selectedOrder!.customerNumber ?? '';

      customerScreenProvider.searchController.text =
          widget.selectedOrder!.employeeName ?? '';

      customerScreenProvider.audioPlayerId = widget.selectedOrder!.salesOrderId;
      customerScreenProvider.photoScreenId = widget.selectedOrder!.salesOrderId;
    } else {}
  }

  @override
  Widget build(BuildContext context) {
    final detailsProvider = Provider.of<DetailsProvider>(context);
    // final cartProvider = Provider.of<CartProvider>(context);
    final customerScreenProvider =
        Provider.of<EditCustomerScreenProvider>(context);

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
          centerTitle: true, // Centers the title
          title: Text(
            "Customer Details",
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
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
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _isEditing // Check if modifyMode is true
                              ? Expanded(
                                  child: DropdownButtonFormField<String>(
                                    autovalidateMode:
                                        AutovalidateMode.onUserInteraction,
                                    value: customerScreenProvider
                                        .selectedOrderType,
                                    hint: const Text('Select Order Type',
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                    items: ['In House', 'Warehouse']
                                        .map((String type) {
                                      return DropdownMenuItem<String>(
                                        value: type,
                                        child: Text(type),
                                      );
                                    }).toList(),
                                    onChanged: _isEditing
                                        ? (String? newValue) {
                                            customerScreenProvider
                                                .setSelectedOrderType(newValue);
                                          }
                                        : null,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(),
                                      labelText: "Order Type",
                                      labelStyle: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 10),
                                    ),
                                    style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please select an order type';
                                      }
                                      return null;
                                    },
                                  ),
                                )
                              : Text(
                                  '${widget.selectedOrder!.orderType} ',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ],
                      ),

                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween, // Centers the text
                        children: [
                          Text(
                            'saleOrderNo :${widget.selectedOrder!.saleOrderNo}',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 10),
                      // Row for Date and Time
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
                                    vertical: 10), // Reduced padding
                              ),
                              style: TextStyle(fontSize: 14),
                              readOnly: _isEditing,
                              onTap: () async {
                                DateTime now = DateTime.now();
                                DateTime? pickedDate = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime.now(),
                                  lastDate: now.add(const Duration(days: 180)),
                                );
                                if (pickedDate != null) {
                                  String formattedDate =
                                      DateFormat('dd-MM-yyyy')
                                          .format(pickedDate);
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
                                isDense: false, // Makes the field more compact
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                              ),
                              style: TextStyle(fontSize: 14),
                              onTap: () async {
                                DateTime now = DateTime.now();
                                TimeOfDay time = TimeOfDay.now();
                                DateTime selectedDate = DateFormat('dd-MM-yyyy')
                                    .parse(customerScreenProvider
                                        .dateController.text);
                                bool isToday = selectedDate.year == now.year &&
                                    selectedDate.month == now.month &&
                                    selectedDate.day == now.day;
                                FocusScope.of(context)
                                    .requestFocus(FocusNode());
                                TimeOfDay? pickedTime = await showTimePicker(
                                  context: context,
                                  initialTime: isToday
                                      ? TimeOfDay.fromDateTime(
                                          now.add(const Duration(minutes: 1)))
                                      : const TimeOfDay(hour: 0, minute: 0),
                                );

                                if (pickedTime != null) {
                                  if (isToday &&
                                      (pickedTime.hour < time.hour ||
                                          (pickedTime.hour == time.hour &&
                                              pickedTime.minute <=
                                                  time.minute))) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Delivery time must be in the future'),
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
                                // onChanged: (String? newValue) {
                                //   customerScreenProvider
                                //       .setSelectedEvent(newValue);

                                onChanged: _isEditing
                                    ? (String? newValue) {
                                        customerScreenProvider
                                            .setSelectedEvent(newValue);
                                      }
                                    : null, //
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(),
                                  labelText: 'Event',
                                  enabled: _isEditing,
                                  isDense:
                                      false, // Makes the field more compact
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                ),
                                style: TextStyle(
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

                            // Show date field only if an event is selected and it's not "Others"
                            if (customerScreenProvider.selectedEvent != null &&
                                customerScreenProvider
                                    .selectedEvent!.isNotEmpty &&
                                customerScreenProvider.selectedEvent !=
                                    "Others")
                              Expanded(
                                child: TextFormField(
                                  autovalidateMode:
                                      AutovalidateMode.onUserInteraction,
                                  controller: customerScreenProvider
                                      .birthdaydateController,
                                  enabled: _isEditing,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(),
                                    labelText:
                                        "${customerScreenProvider.selectedEvent} Date",
                                    labelStyle: TextStyle(fontSize: 14),
                                    isDense:
                                        false, // Makes the field more compact
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 10), // Reduced padding
                                  ),
                                  style: TextStyle(fontSize: 14),
                                  readOnly: true,
                                  onTap: () async {
                                    DateTime now = DateTime.now();
                                    DateTime? pickedDate = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now(),
                                      firstDate: DateTime.now(),
                                      lastDate:
                                          now.add(const Duration(days: 180)),
                                    );
                                    if (pickedDate != null) {
                                      String formattedDate =
                                          DateFormat('dd-MM-yyyy')
                                              .format(pickedDate);
                                      customerScreenProvider
                                          .birthdaydateController
                                          .text = formattedDate;
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

                      // const Padding(padding: EdgeInsets.all(5)),
                      //   ],

                      const Padding(padding: EdgeInsets.all(5)),
                      Row(
                        children: [
                          if (_customerType != 'Normal' ||
                              _customerType != 'Company') ...[const SizedBox()],
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
                              hint: const Text('Delivery Type',
                                  style: TextStyle(fontSize: 11)),
                              items: [
                                'Pickup by Customer',
                                'Door Delivery',
                              ].map((String type) {
                                return DropdownMenuItem<String>(
                                  value: type,
                                  child: Text(type),
                                );
                              }).toList(),
                              // onChanged: (String? newValue) {
                              //   customerScreenProvider
                              //       .setSelectedDeliveryType(newValue);
                              // },
                              onChanged: _isEditing
                                  ? (String? newValue) {
                                      customerScreenProvider
                                          .setSelectedDeliveryType(newValue);
                                    }
                                  : null, //
                              decoration: InputDecoration(
                                enabled: _isEditing,
                                border: OutlineInputBorder(),

                                labelText: 'Delivery Type',
                                labelStyle: TextStyle(fontSize: 11),
                                isDense: false, // Makes the field more compact
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 13, vertical: 8),
                              ),
                              style:
                                  TextStyle(fontSize: 13, color: Colors.black),
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
                                  modifyMode: _isEditing)),
                          const Padding(padding: EdgeInsets.all(5)),
                        ],
                      ),

                      const Padding(padding: EdgeInsets.all(5)),

                      // Conditionally show Address and Landmark Fields if "Door Delivery" is selected
                      if (customerScreenProvider.selectedDeliveryType ==
                          'Door Delivery') ...[
                        // Row for Landmark and Address
                        Row(
                          children: [
                            const Padding(padding: EdgeInsets.all(5)),
                            Expanded(
                              child: TextFormField(
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                controller:
                                    customerScreenProvider.landmarkController,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(),
                                  labelText: 'Landmark',
                                  enabled: _isEditing,
                                  labelStyle: TextStyle(fontSize: 14),
                                  isDense:
                                      false, // Makes the field more compact
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 10),
                                  hintText:
                                      'e.g., Near ABC Park, Opposite XYZ Mall',
                                  hintStyle: TextStyle(color: Colors.grey),
                                ),
                                style: TextStyle(fontSize: 14),
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
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                controller:
                                    customerScreenProvider.addressController,
                                // readOnly: !_isEditing,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(),
                                  labelText: 'Address',
                                  enabled: _isEditing,
                                  labelStyle: TextStyle(fontSize: 14),
                                  isDense:
                                      false, // Makes the field more compact
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 10),
                                  hintText:
                                      'e.g., 1234 Main Street, Apartment 12',
                                  hintStyle: TextStyle(color: Colors.grey),
                                ),
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

                      if (_customerType == 'Company')
                        Row(children: [
                          // const Padding(padding: EdgeInsets.all(5)),
                          Expanded(
                            child: customerScreenProvider
                                .buildCompanyInputFields(context),
                          )
                        ]),
                      const Padding(padding: EdgeInsets.all(5)),

                      Row(children: [
                        // const Padding(padding: EdgeInsets.all(5)),
                        Expanded(
                          child:
                              //  customerScreenProvider
                              //     .buildCustomerInputFields(context, _isEditing),

                              EditCustomerSearchDropdown(
                            isModifyMode: _isEditing,
                          ),
                        )
                      ]),

                      const SizedBox(height: 10),
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
                                icon: const Icon(Icons.remove_circle,
                                    color: Colors.red),
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
                            SizedBox(
                              width: 40,
                            ),
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
                                  // child: PhotosScreen(
                                  //     customId: customerScreenProvider
                                  //         .photoScreenId!),
                                  child: PhotosScreen(
                                    imagePaths: [
                                      widget.selectedOrder!.image1 ?? '',
                                      widget.selectedOrder!.image2 ?? '',
                                    ],
                                  ),
                                ),
                              ),

                            // Minus button for image
                            if (_isEditing &&
                                _showMinusButtonforimage &&
                                customerScreenProvider.photoScreenId != null)
                              IconButton(
                                icon: const Icon(Icons.remove_circle,
                                    color: Colors.red),
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
                      child: ImagePickerWidget(
                        onImagesSelected:
                            customerScreenProvider.onImagesSelected,
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
}
