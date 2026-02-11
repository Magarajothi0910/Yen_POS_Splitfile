import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yen_pos/Global/Widget/filesave.dart';
import 'package:yen_pos/Global/global_data_manager.dart';
import 'package:yen_pos/Global/globals_data.dart' as globals;
import 'package:yen_pos/Global/globals_data.dart';
import 'package:yen_pos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yen_pos/Sale_order/Models/held_order_model.dart';
import 'package:yen_pos/Sale_order/Provider/cartProvider.dart';
import 'package:yen_pos/Sale_order/Provider/cart_selection_provider.dart';
import 'package:yen_pos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yen_pos/Sale_order/Provider/detailsProvider.dart';
import 'package:yen_pos/Sale_order/Provider/get_sales_order_service.dart';
import 'package:yen_pos/Sale_order/Screens/all_orders.dart';
import 'package:yen_pos/Sale_order/Screens/approval_order_status_data.dart';
import 'package:yen_pos/Sale_order/Widgets/customAll_keyboard.dart';
import 'package:yen_pos/Sale_order/Widgets/employee_selection.dart';
import 'package:yen_pos/Sale_order/Widgets/hold_order_status_file.dart';
import 'package:yen_pos/Sale_order/Widgets/image-picker-widget.dart';
import 'package:yen_pos/Sale_order/Widgets/mobilenumber_search.dart';
import 'package:yen_pos/Sale_order/Widgets/photoScreen.dart';
import 'package:yen_pos/Sale_order/Widgets/voice_recording.dart';

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
  int? _selectedRadioValue = 0;
  List<Map<String, String>> suggestions = [];
  bool isSuggestionsVisible = false;
  TextEditingController controller123 = TextEditingController();

  final _remarkFocus = FocusNode();
  final _addressFocus = FocusNode();
  final _landMarkFocus = FocusNode();
  final FocusNode _otherEventFocus = FocusNode();

  @override
  void initState() {
    super.initState();

    // Delay provider access until after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final customerScreenProvider = Provider.of<CustomerScreenProvider>(
        context,
        listen: false,
      );
      customerScreenProvider.setSelectedEvent("Birthday");
      customerScreenProvider.setSelectedDeliveryType("Pickup By Customer");
    });
  }

  void showToast(String message, BuildContext context) {
    // Always check if the widget is mounted before showing SnackBar
    if (!mounted) return;

    // Use a try-catch block to handle the case where context might be invalid
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    } catch (e) {
      // Silently fail if context is no longer valid
      debugPrint('Could not show toast: $e');
    }
  }

  bool _validateFullOrderForm(BuildContext context) {
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

  bool _validateOrderDetails(BuildContext context) {
    final customerScreenProvider = Provider.of<CustomerScreenProvider>(
      context,
      listen: false,
    );
    final detailsProvider = Provider.of<DetailsProvider>(
      context,
      listen: false,
    );

    String selectedSalesperson = customerScreenProvider.searchController.text
        .trim();
    if (!detailsProvider.employeeNames.contains(selectedSalesperson)) {
      showToast('Add a valid salesperson.', context);
      return false;
    }

    String enteredMobileNumber = customerScreenProvider.mobileNoController.text
        .trim();
    if (enteredMobileNumber.isEmpty ||
        enteredMobileNumber.length != 10 ||
        !RegExp(r'^\d{10}$').hasMatch(enteredMobileNumber)) {
      showToast('Please enter a valid 10-digit mobile number.', context);
      return false;
    }

    bool hasInvalidBoxItems = globals.cartItems.any((item) {
      if (item.isBoxItem.toString().toLowerCase() == 'yes') {
        int boxQty = item.boxQuantity ?? 0;
        int quantity = item.quantity.value;
        return boxQty <= 0 || quantity <= 0;
      }
      return false;
    });

    if (hasInvalidBoxItems) {
      showToast('Enter valid box quantity for selected items.', context);
      return false;
    }

    return true;
  }

  bool _requiresApproval(BuildContext context) {
    final provider = Provider.of<CustomerScreenProvider>(
      context,
      listen: false,
    );

    if (provider.isRestoringApprovalOrder) {
      final status = provider.originalApprovalStatus?.toLowerCase() ?? '';
      if (status.contains('approved')) return false;
      if (status.contains('pending') || status.contains('rejected'))
        return true;
    }

    try {
      final lazyBox = HiveManager.discounts;
      final discountsFromBox = lazyBox.values.toList();

      if (discountsFromBox == null || discountsFromBox.isEmpty) {
        return false;
      }

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

      if (discountList.isEmpty) {
        return false;
      }

      final activeDiscounts = discountList
          .where((d) => d['status'] == 'active')
          .toList();

      if (activeDiscounts.isEmpty) {
        return false;
      }

      final discountThreshold = activeDiscounts.isNotEmpty
          ? (activeDiscounts.first['discountPercentage'] ?? 0)
          : 0;

      return globals.cartItems.any((item) {
        final itemDiscount = item.itemWiseDiscount ?? 0;
        return itemDiscount > discountThreshold;
      });
    } catch (e) {
      return false;
    }
  }

  void handleRecordingComplete(String path) {
    setState(() {
      final customerScreenProvider = Provider.of<CustomerScreenProvider>(
        context,
        listen: false,
      );
      customerScreenProvider.recordedFilePath = path;
      customerScreenProvider.audioPlayer = null;
      customerScreenProvider.notifyListeners();
    });
  }

  void _clearAllData() {
    setState(() {
      globals.cartItems.clear();
      final customerScreenProvider = Provider.of<CustomerScreenProvider>(
        context,
        listen: false,
      );
      customerScreenProvider.clearControllers();
      customerScreenProvider.audioPlayer = null;
      customerScreenProvider.photoScreen = null;
      customerScreenProvider.recordedFilePath = '';
      customerScreenProvider.pickedImage1 = null;
      customerScreenProvider.pickedImage2 = null;
    });
  }

  Future<bool> _onWillPop() async {
    final shouldExit =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirmation'),
            content: const Text('Do you want to go back?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Yes'),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldExit) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AllOrdersPage()),
      );
    }
    return shouldExit;
  }

  Widget _buildEventDateField(CustomerScreenProvider customerScreenProvider) {
    if (customerScreenProvider.selectedEvent == 'Others') {
      return Expanded(
        child: TextFormField(
          autovalidateMode: AutovalidateMode.onUserInteraction,
          readOnly: true,
          showCursor: true,
          controller: customerScreenProvider.otherEventController,
          focusNode: _otherEventFocus,
          onTap: () {
            ActiveField.activate(
              context: context,
              ctrl: customerScreenProvider.otherEventController,
              node: _otherEventFocus,
            );
          },
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Enter Event Name',
          ),
          style: const TextStyle(fontSize: 14, color: Colors.black),
          validator: (value) {
            if (_isFormValid && (value == null || value.isEmpty)) {
              return 'Please enter the event';
            }
            return null;
          },
        ),
      );
    } else {
      return Expanded(
        child: TextFormField(
          autovalidateMode: AutovalidateMode.onUserInteraction,
          readOnly: true,
          showCursor: true,
          controller: customerScreenProvider.birthdaydateController,
          onTap: () => _showEventDatePicker(customerScreenProvider),
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: 'Select ${customerScreenProvider.selectedEvent} Date',
            suffixIcon: const Icon(Icons.event),
          ),
          style: const TextStyle(fontSize: 14, color: Colors.black),
          validator: (value) {
            if (_isFormValid && (value == null || value.isEmpty)) {
              return 'Please select a date';
            }
            return null;
          },
        ),
      );
    }
  }

  void _showEventDatePicker(CustomerScreenProvider customerScreenProvider) {
    DateTime now = DateTime.now();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Event Date Picker",
      pageBuilder: (context, anim1, anim2) => Container(),
      transitionBuilder: (context, a1, a2, widget) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.5, end: 1.0).animate(a1),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.5, end: 1.0).animate(a1),
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 350),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 15,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[700],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text(
                            "Choose Event Date",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Icon(Icons.calendar_today, color: Colors.white),
                        ],
                      ),
                    ),
                    Container(
                      height: 300,
                      padding: const EdgeInsets.all(8),
                      child: Theme(
                        data: ThemeData(
                          colorScheme: ColorScheme.light(
                            primary: Colors.blue[700]!,
                            onPrimary: Colors.white,
                            onSurface: Colors.black,
                          ),
                          datePickerTheme: DatePickerThemeData(
                            todayBackgroundColor: MaterialStateProperty.all(
                              Colors.transparent,
                            ),
                            todayForegroundColor: MaterialStateProperty.all(
                              Colors.black,
                            ),
                            todayBorder: BorderSide.none,
                            shape: const CircleBorder(),
                          ),
                        ),
                        child: CalendarDatePicker(
                          initialDate: now,
                          firstDate: now,
                          lastDate: now.add(const Duration(days: 180)),
                          onDateChanged: (date) {
                            final formattedDate = DateFormat(
                              'dd-MM-yyyy',
                            ).format(date);
                            customerScreenProvider.birthdaydateController.text =
                                formattedDate;
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              "Cancel",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w600,
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
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  Widget _buildAudioSection(CustomerScreenProvider customerScreenProvider) {
    if (customerScreenProvider.recordedFilePath.isEmpty) {
      return SizedBox(
        width: 100,
        height: 70,
        child: VoiceRecorder(
          key: const ValueKey('recorder_instance'),
          onRecordingComplete: handleRecordingComplete,
        ),
      );
    }

    return SizedBox(
      width: 180,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 56,
            child: AudioPlayerWidget(
              key: ValueKey('audio_${customerScreenProvider.recordedFilePath}'),
              filePath: customerScreenProvider.recordedFilePath,
              onDispose: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  customerScreenProvider.resetAudioWidget();
                });
              },
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 28,
            child: InkWell(
              onTap: () => _showReRecordDialog(customerScreenProvider),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.replay, size: 12, color: Colors.orange),
                  SizedBox(width: 4),
                  Text(
                    'Re-record',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReRecordDialog(CustomerScreenProvider customerScreenProvider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 10,
        backgroundColor: Colors.white,
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.55,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mic, color: Colors.orange, size: 32),
                ),
                const SizedBox(height: 16),
                Text(
                  'Re-record Audio?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'This will replace your current recording with a new one.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                          backgroundColor: Colors.orange,
                        ),
                        onPressed: () {
                          customerScreenProvider.resetAudioRecording();
                          Navigator.pop(dialogContext);
                        },
                        child: const Text(
                          'Re-record',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
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
  }

  Widget _buildImageSection(CustomerScreenProvider customerScreenProvider) {
    return SizedBox(
      width: 180,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 60,
            child: Row(
              children: [
                if (customerScreenProvider.pickedImages.isEmpty)
                  SizedBox(
                    width: 160,
                    child: MultiImagePickerWidget(
                      key: const ValueKey('image_picker_instance'),
                      onImagesSelected: (images) {
                        customerScreenProvider.addImages(images);
                        customerScreenProvider.notifyListeners();
                      },
                    ),
                  )
                else
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 60),
                      child: PhotosScreen(
                        key: ValueKey(
                          'photos_${customerScreenProvider.pickedImages.hashCode}',
                        ),
                        imagePaths: customerScreenProvider.pickedImages
                            .map((f) => f.path)
                            .toList(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (customerScreenProvider.pickedImages.isNotEmpty)
            Container(
              height: 24,
              child: InkWell(
                onTap: () async {
                  final images = await showDialog<List<File>>(
                    context: context,
                    builder: (context) => AddMoreImagesDialog(
                      existingImages: customerScreenProvider.pickedImages,
                    ),
                  );
                  if (images != null) {
                    customerScreenProvider.setImages(images);
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
    );
  }

  Future<void> _handlePlaceOrder() async {
    // Get the current context before any async operations
    final currentContext = context;

    // Check if widget is still mounted
    if (!mounted) return;

    final customerScreenProvider = Provider.of<CustomerScreenProvider>(
      currentContext,
      listen: false,
    );
    final cartSelectionProvider = Provider.of<CartSelectionProvider>(
      currentContext,
      listen: false,
    );
    final cartProvider = Provider.of<CartProvider>(
      currentContext,
      listen: false,
    );
    final apiSalesprovider = Provider.of<ApiServiceSalesOrderProvider>(
      currentContext,
      listen: false,
    );

    FocusScope.of(currentContext).unfocus();

    // Pass the safe context to validation methods
    if (!_validateOrderDetails(currentContext) ||
        !_validateFullOrderForm(currentContext)) {
      return;
    }

    final filePaths = await FileStorageManager.saveFiles(
      recordedFilePath: customerScreenProvider.recordedFilePath,
      pickedImage1: customerScreenProvider.pickedImage1,
      pickedImage2: customerScreenProvider.pickedImage2,
    );

    // Check mounted again after async operation
    if (!mounted) return;

    if (customerScreenProvider.isRestoringApprovalOrder) {
      customerScreenProvider.showAdvancePaymentPopup(
        currentContext,
        cartSelectionProvider,
        cartProvider,
        filePaths['audioPath'],
        apiSalesprovider,
        customerScreenProvider.customerType,
        customerScreenProvider.audioPlayer,
        customerScreenProvider.holdId,
      );
      customerScreenProvider.resetAudioWidget();
      return;
    }

    if (_requiresApproval(currentContext)) {
      customerScreenProvider.submitForApproval(
        currentContext,
        cartSelectionProvider,
        cartProvider,
        customerScreenProvider.recordedFilePath,
        apiSalesprovider,
        customerScreenProvider.pickedImage1,
        customerScreenProvider.pickedImage2,
        customerScreenProvider.customerType,
      );
    } else {
      customerScreenProvider.showAdvancePaymentPopup(
        currentContext,
        cartSelectionProvider,
        cartProvider,
        filePaths['audioPath'],
        apiSalesprovider,
        customerScreenProvider.customerType,
        customerScreenProvider.audioPlayer,
        customerScreenProvider.holdId,
      );
    }

    customerScreenProvider.resetAudioWidget();
  }

  Future<void> _handleHoldOrder() async {
    final customerScreenProvider = Provider.of<CustomerScreenProvider>(
      context,
      listen: false,
    );
    final cartSelectionProvider = Provider.of<CartSelectionProvider>(
      context,
      listen: false,
    );
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final apiSalesprovider = Provider.of<ApiServiceSalesOrderProvider>(
      context,
      listen: false,
    );

    FocusScope.of(context).unfocus();

    final filePaths = await FileStorageManager.saveFiles(
      recordedFilePath: customerScreenProvider.recordedFilePath,
      pickedImage1: customerScreenProvider.pickedImage1,
      pickedImage2: customerScreenProvider.pickedImage2,
    );

    if (!mounted) return;

    await customerScreenProvider.heldrder(
      cartProvider,
      cartSelectionProvider,
      customerScreenProvider.totalAdvance,
      customerScreenProvider.orderAmount,
      customerScreenProvider.discount,
      customerScreenProvider.deductedAmount,
      customerScreenProvider.totalAmount,
      customerScreenProvider.remarkController.text,
      filePaths['audioPath'],
      apiSalesprovider,
      filePaths['imagePath1'] != null ? File(filePaths['imagePath1']!) : null,
      filePaths['imagePath2'] != null ? File(filePaths['imagePath2']!) : null,
      customerScreenProvider.patchHoldOrderId,
      customerScreenProvider.orderType,
      context,
    );

    customerScreenProvider.resetAudioWidget();
  }

  @override
  Widget build(BuildContext context) {
    final customerScreenProvider = Provider.of<CustomerScreenProvider>(context);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.white,
          title: Container(
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Row(
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
                    const Text(
                      'Customer',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(
                        Icons.assignment,
                        color: Colors.white,
                        size: 16,
                      ),
                      label: const Text(
                        "Approval Order",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      onPressed: () => showDiscountStatus(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Colors.blue, width: 1),
                        ),
                        elevation: 0,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      icon: Stack(
                        children: [
                          const Icon(
                            Icons.assignment,
                            color: Colors.white,
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
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.blue,
                                    width: 1,
                                  ),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 12,
                                  minHeight: 12,
                                ),
                                child: Text(
                                  '${customerScreenProvider.hiveholdSalesOrders.length}',
                                  style: const TextStyle(
                                    color: Colors.blue,
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
                          color: Colors.white,
                        ),
                      ),
                      onPressed: () {
                        if (customerScreenProvider.hasInvalidCartItems()) {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text("Error"),
                              content: const Text(
                                "Some items in the cart are invalid or cannot be processed.",
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text("OK"),
                                ),
                              ],
                            ),
                          );
                        } else {
                          showHoldOrdersSheet(context, customerScreenProvider);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Colors.blue, width: 1),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.blue,
                    size: 28,
                  ),
                  onPressed: () => _showClearConfirmationDialog(),
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
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Padding(padding: EdgeInsets.all(5)),
                        SizedBox(width: 290, child: CustomerSearchDropdown()),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 45,
                          width: 286,
                          child: _buildDeliveryDateTimeField(
                            customerScreenProvider,
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
                            child: _buildEventDropdown(customerScreenProvider),
                          ),
                          const Padding(padding: EdgeInsets.all(5)),
                          _buildEventDateField(customerScreenProvider),
                          const Padding(padding: EdgeInsets.all(5)),
                        ],
                      ],
                    ),
                    const Padding(padding: EdgeInsets.all(5)),
                    Row(
                      children: [
                        const Padding(padding: EdgeInsets.all(5)),
                        Expanded(
                          child: _buildDeliveryTypeDropdown(
                            customerScreenProvider,
                          ),
                        ),
                        const Padding(padding: EdgeInsets.all(5)),
                        Expanded(child: EmployeeSearchDropdown()),
                        const Padding(padding: EdgeInsets.all(5)),
                      ],
                    ),
                    if ((customerScreenProvider.selectedDeliveryType ?? '')
                            .toLowerCase() ==
                        'door delivery') ...[
                      const Padding(padding: EdgeInsets.all(5)),
                      Row(
                        children: [
                          const Padding(padding: EdgeInsets.all(5)),
                          Expanded(
                            child: _buildLandmarkField(customerScreenProvider),
                          ),
                          const Padding(padding: EdgeInsets.all(5)),
                          Expanded(
                            child: _buildAddressField(customerScreenProvider),
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
                        child: _buildRemarksField(customerScreenProvider),
                      ),
                    ),
                    _buildMediaAndActionButtons(customerScreenProvider),
                    const SizedBox(height: 10),
                    _buildCustomKeyboard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryDateTimeField(
    CustomerScreenProvider customerScreenProvider,
  ) {
    return TextFormField(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      controller: customerScreenProvider.deliveryDateTimeController,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.event),
        border: OutlineInputBorder(),
        labelText: "Delivery Date & Time",
        hintText: "Choose delivery date and time",
      ),
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      readOnly: true,
      onTap: () => _showDeliveryDateTimePicker(customerScreenProvider),
      validator: (value) {
        if (_isFormValid &&
            (customerScreenProvider.dateController.text.isEmpty ||
                customerScreenProvider.timeController.text.isEmpty)) {
          return 'Delivery Date & Time are required';
        }
        return null;
      },
    );
  }

  void _showDeliveryDateTimePicker(
    CustomerScreenProvider customerScreenProvider,
  ) async {
    DateTime now = DateTime.now();
    DateTime selectedDate = now;
    TimeOfDay selectedTime = TimeOfDay.now();

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              // Helper function to convert 24-hour to AM/PM
              String formatTimeWithAmPm(int hour, int minute) {
                final period = hour >= 12 ? 'PM' : 'AM';
                final hour12 = hour % 12 == 0 ? 12 : hour % 12;
                final minuteStr = minute.toString().padLeft(2, '0');
                return '$hour12:$minuteStr $period';
              }

              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 600,
                    maxHeight: MediaQuery.of(context).size.height * 0.85,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.event, color: Colors.blue),
                            const SizedBox(width: 8),
                            const Text(
                              "Select Delivery Date & Time",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        const Divider(thickness: 1.2),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Delivery Date",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.blue.shade100,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: CalendarDatePicker(
                                      initialDate: now,
                                      firstDate: now,
                                      lastDate: now.add(
                                        const Duration(days: 180),
                                      ),
                                      onDateChanged: (date) =>
                                          setState(() => selectedDate = date),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Delivery Time",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    height: 150,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.blue.shade100,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: CupertinoDatePicker(
                                      mode: CupertinoDatePickerMode.time,
                                      use24hFormat: false,
                                      initialDateTime: DateTime(
                                        0,
                                        0,
                                        0,
                                        selectedTime.hour,
                                        selectedTime.minute,
                                      ),
                                      minuteInterval: 1,
                                      onDateTimeChanged: (dt) {
                                        setState(() {
                                          selectedTime = TimeOfDay(
                                            hour: dt.hour,
                                            minute: dt.minute,
                                          );
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.access_time,
                                        size: 18,
                                        color: Colors.blueGrey,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        "Selected: ${formatTimeWithAmPm(selectedTime.hour, selectedTime.minute)}",
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Cancel"),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                final formattedDate = DateFormat(
                                  'dd-MM-yyyy',
                                ).format(selectedDate);

                                // Force AM/PM format
                                final formattedTime = formatTimeWithAmPm(
                                  selectedTime.hour,
                                  selectedTime.minute,
                                );

                                print(
                                  "Selected Time - 24h: ${selectedTime.hour}:${selectedTime.minute}",
                                );
                                print("Selected Time - AM/PM: $formattedTime");

                                customerScreenProvider.updateDateTime(
                                  formattedDate,
                                  formattedTime,
                                );

                                Navigator.pop(context);
                              },
                              icon: const Icon(
                                Icons.check,
                                color: Colors.white,
                              ),
                              label: const Text(
                                "Confirm",
                                style: TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade600,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
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
  }

  Widget _buildEventDropdown(CustomerScreenProvider customerScreenProvider) {
    return DropdownButtonFormField<String>(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      value:
          customerScreenProvider.getEventList().contains(
            customerScreenProvider.selectedEvent,
          )
          ? customerScreenProvider.selectedEvent
          : 'Birthday',
      hint: const Text('Select Event', style: TextStyle(fontSize: 14)),
      items: customerScreenProvider.getEventList().map((event) {
        return DropdownMenuItem<String>(value: event, child: Text(event));
      }).toList(),
      onChanged: (String? newValue) =>
          customerScreenProvider.setSelectedEvent(newValue),
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        labelText: 'Event',
        isDense: false,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      style: const TextStyle(fontSize: 14, color: Colors.black),
      dropdownColor: Colors.white,
      validator: (value) {
        if (_isFormValid && (value == null || value.isEmpty)) {
          return 'Please select an event';
        }
        return null;
      },
    );
  }

  Widget _buildDeliveryTypeDropdown(
    CustomerScreenProvider customerScreenProvider,
  ) {
    return SizedBox(
      height: 50,
      child: DropdownButtonFormField<String>(
        autovalidateMode: AutovalidateMode.onUserInteraction,
        value:
            GlobalDataManager().deliveryTypes.any(
              (item) =>
                  item['deliveryType'] ==
                  customerScreenProvider.selectedDeliveryType,
            )
            ? customerScreenProvider.selectedDeliveryType
            : "Pickup By Customer",
        hint: const Text('Delivery Type', style: TextStyle(fontSize: 14)),
        items: GlobalDataManager().deliveryTypes.map<DropdownMenuItem<String>>((
          item,
        ) {
          return DropdownMenuItem<String>(
            value: item['deliveryType'],
            child: Text(item['deliveryType']),
          );
        }).toList(),
        onChanged: (String? newValue) =>
            customerScreenProvider.setSelectedDeliveryType(newValue),
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          labelText: 'Delivery Type',
          labelStyle: TextStyle(fontSize: 14),
          isDense: false,
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        ),
        style: const TextStyle(fontSize: 14, color: Colors.black),
        dropdownColor: Colors.white,
        validator: (value) {
          if (_isFormValid && (value == null || value.isEmpty)) {
            return 'Delivery Type is required';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildLandmarkField(CustomerScreenProvider customerScreenProvider) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: customerScreenProvider.landmarkController,
      builder: (context, value, _) {
        return TextFormField(
          readOnly: true,
          focusNode: _landMarkFocus,
          controller: customerScreenProvider.landmarkController,
          onTap: () {
            ActiveField.activate(
              context: context,
              ctrl: customerScreenProvider.landmarkController,
              node: _landMarkFocus,
            );
          },
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: 'Landmark',
            labelStyle: const TextStyle(fontSize: 14),
            isDense: false,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),
            hintStyle: const TextStyle(color: Colors.grey),

            // ❌ Clear icon (safe)
            suffixIcon: value.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      customerScreenProvider.landmarkController.clear();
                    },
                  )
                : null,
          ),
          style: const TextStyle(fontSize: 14, color: Colors.black),
        );
      },
    );
  }

  Widget _buildAddressField(CustomerScreenProvider customerScreenProvider) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: customerScreenProvider.addressController,
      builder: (context, value, _) {
        return TextFormField(
          readOnly: true,
          focusNode: _addressFocus,
          controller: customerScreenProvider.addressController,
          onTap: () {
            ActiveField.activate(
              context: context,
              ctrl: customerScreenProvider.addressController,
              node: _addressFocus,
            );
          },
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: 'Address',
            labelStyle: const TextStyle(fontSize: 14),
            isDense: false,
            hintStyle: const TextStyle(color: Colors.grey),

            // ❌ Clear icon (safe)
            suffixIcon: value.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      customerScreenProvider.addressController.clear();
                    },
                  )
                : null,
          ),
          style: const TextStyle(fontSize: 14, color: Colors.black),
        );
      },
    );
  }

  Widget _buildRemarksField(CustomerScreenProvider customerScreenProvider) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: customerScreenProvider.remarkController,
      builder: (context, value, _) {
        return TextField(
          readOnly: true,
          focusNode: _remarkFocus,
          controller: customerScreenProvider.remarkController,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: 'Remarks',
            labelStyle: const TextStyle(fontSize: 14),
            hintStyle: const TextStyle(color: Colors.grey),

            // ❌ Clear icon
            suffixIcon: value.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      customerScreenProvider.remarkController.clear();
                    },
                  )
                : null,
          ),
          style: const TextStyle(fontSize: 14, color: Colors.black),
          onTap: () {
            ActiveField.activate(
              context: context,
              ctrl: customerScreenProvider.remarkController,
              node: _remarkFocus,
            );
          },
        );
      },
    );
  }

  Widget _buildMediaAndActionButtons(
    CustomerScreenProvider customerScreenProvider,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 150,
              child: _buildAudioSection(customerScreenProvider),
            ),
            _buildImageSection(customerScreenProvider),
            const SizedBox(width: 10),
            _buildPlaceOrderButton(customerScreenProvider),
            const SizedBox(width: 10),
            if (customerScreenProvider.customerType == 'Normal')
              _buildHoldOrderButton(customerScreenProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceOrderButton(CustomerScreenProvider customerScreenProvider) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, _) {
        final hasItems = cartProvider.hasItems;

        return SizedBox(
          height: 60,
          child: CustomButton(
            text: customerScreenProvider.isRestoringApprovalOrder
                ? 'Place Order'
                : (_requiresApproval(context)
                      ? 'Send for Approval'
                      : 'Place Order'),
            onPressed: () {
              if (!hasItems) return;
              _handlePlaceOrder();
            },
            backgroundColor: hasItems
                ? (customerScreenProvider.isRestoringApprovalOrder ||
                          !_requiresApproval(context))
                      ? Colors.blue
                      : Colors.orange
                : Colors.grey,
            textColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            fontSize: 12,
          ),
        );
      },
    );
  }

  Widget _buildHoldOrderButton(CustomerScreenProvider customerScreenProvider) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, _) {
        final hasItems = cartProvider.hasItems;

        return SizedBox(
          height: 60,
          child: CustomButton(
            text: 'Hold Order',
            onPressed: () {
              if (!hasItems) return; // disabled manually
              _handleHoldOrder();
            },

            backgroundColor: hasItems ? Colors.lightBlue : Colors.grey,
            textColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            fontSize: 12,
          ),
        );
      },
    );
  }

  Widget _buildCustomKeyboard() {
    return SizedBox(
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
    );
  }

  void _showClearConfirmationDialog() {
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
                const Icon(
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
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        _clearAllData();
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text("Clear"),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
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
    _selectedImages = List<File>.from(widget.existingImages);
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
    } catch (e) {
      debugPrint('Error picking images: $e');
    }
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
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
            Text(
              'Total: ${_selectedImages.length} images',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
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
                  itemBuilder: (context, index) => Stack(
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
                  ),
                ),
              ),
            const SizedBox(height: 16),
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
