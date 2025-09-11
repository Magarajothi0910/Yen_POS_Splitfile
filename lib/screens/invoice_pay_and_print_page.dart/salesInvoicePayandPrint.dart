import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../Global/custom_sized_box.dart';
import '../../Global/custom_textWidgets.dart';
import '../kot_screen/global/globals.dart';
import '../regular_mode_page/provider/cart_page_provider.dart';
import '../regular_mode_page/widget/custom_reusable_widget/letter_keyborard.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;
import 'services/save_data_local.dart';
import 'widgets/invoice_Print_Receipt.dart';
import 'services/invoice_service.dart';

class SalesInvoicePayAndPrint extends StatefulWidget {
  final double totalAmount;
  final String holdBillId; // Added holdBillId to identify the bill

  const SalesInvoicePayAndPrint({
    super.key,
    required this.totalAmount,
    required this.holdBillId, // Receive the holdBillId
  });

  @override
  State<SalesInvoicePayAndPrint> createState() =>
      _SalesInvoicePayAndPrintState();
}

class _SalesInvoicePayAndPrintState extends State<SalesInvoicePayAndPrint> {
  final InvoiceService _invoiceService = InvoiceService();
  final List<String> cashOptions = [];
  final TextEditingController _customAmountController = TextEditingController();
  final TextEditingController _employeeNumberController =
      TextEditingController();
  List<Map<String, dynamic>> _employeeSuggestions =
      []; // Store employee suggestions
  bool _showEmployeeSuggestions = false; // Show or hide suggestions dropdown
  final TextEditingController _customerNumberController =
      TextEditingController();
  String _selectedPaymentOption = '';
  String _selectedPaymentOptionVaule = '';
  final TextEditingController _discountController =
      TextEditingController(); // New controller for discount
  final TextEditingController _customChargeController =
      TextEditingController(); // New controller for discount
  double _balanceAmount = 0.0; // New variable for balance
  int _cashAmount = 0;
  int _cardAmount = 0;
  int _upiAmount = 0;
  String? _selectedEmployeeFirstName;
  double roundedDiscountAmount = 0.0;
  String newInvoiceNumber = "";
  // ignore: unused_field
  bool _isPrintButtonEnabled = false; // New variable to track button state
  final TextEditingController _customCashController = TextEditingController();
  final TextEditingController _customUpiController = TextEditingController();
  final TextEditingController _customCardController = TextEditingController();
  String invoiceNumber = "";
  DateTime? _selectedBirthday;
  final TextEditingController _birthdayController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _channel = WebSocketChannel.connect(
      Uri.parse(
          'ws://$serverip:$port'), // Replace `port` with your WebSocket server's port
    );

    // Add a listener for WebSocket messages if needed
    _channel.stream.listen((data) {}, onError: (error) {
      // print('WebSocket error: $error');
    });
    cashOptions.addAll(_generateCashOptions(widget.totalAmount));
    _balanceAmount =
        widget.totalAmount; // Initially, balance equals the total amount
    _employeeNumberController.addListener(_validateForm);
    _customerNumberController.addListener(_validateForm);
    _customAmountController.addListener(_validateForm);
    _employeeNumberController.addListener(_onEmployeeInputChanged);
  }

  @override
  void dispose() {
    _birthdayController.dispose();
    super.dispose();
  }

  final Set<String> _loggedInvoices = {}; // Track unique invoices

  late WebSocketChannel _channel;
  // Future<void> sendInvoiceDataToServer(Map<String, dynamic> invoiceData) async {
  //   try {
  //     final jsonData = jsonEncode(invoiceData);
  //     _channel.sink.add(jsonData);
  //     print('Invoice data sent to server: $jsonData');
  //   } catch (e) {
  //     print('Error sending invoice data to server: $e');
  //   }
  // }

  void _validateForm() {
    setState(() {
      bool isEmployeeSelected =
          _selectedEmployeeFirstName != null; // Check if employee is selected
      bool isCustomerNumberValid = _customerNumberController.text.length == 10;
      bool isPaymentOptionSelected = _selectedPaymentOption.isNotEmpty;

      // Enable the print button only if all conditions are met
      _isPrintButtonEnabled = isEmployeeSelected &&
          isCustomerNumberValid &&
          isPaymentOptionSelected;
    });
  }

  // Listener for employee input changes
  Future<void> _onEmployeeInputChanged() async {
    String query = _employeeNumberController.text;
    if (query.isNotEmpty) {
      final suggestions = await _fetchEmployeeSuggestions(query);
      // Debug suggestions
      setState(() {
        _employeeSuggestions = suggestions;
        _showEmployeeSuggestions = suggestions.isNotEmpty;
      });
    } else {
      setState(() {
        _showEmployeeSuggestions = false;
        _employeeSuggestions = [];
      });
    }
  }

  void _selectEmployee(Map<String, dynamic> employee) {
    _employeeNumberController.text =
        '${employee['employeeNumber']} - ${employee['firstName']}';

    // Save the first name in a separate String
    _selectedEmployeeFirstName = employee['firstName'];

    setState(() {
      _showEmployeeSuggestions = false; // Hide dropdown after selection
      _validateForm(); // Re-validate form upon selection
    });
  }

// Method to get employee suggestions from Hive based on the query
  Future<List<Map<String, dynamic>>> _fetchEmployeeSuggestions(
      String query) async {
    var box = await Hive.openBox('employeeBox');
    final List<Map<String, dynamic>> employees =
        List<Map<String, dynamic>>.from(box.get('employees', defaultValue: []));

    // Debug the data fetched from Hive
    // Debug the input query

    // Filter employee data based on the query
    return employees.where((employee) {
      final employeeNumber = employee['employeeNumber']?.toString() ?? '';
      final firstName = employee['firstName']?.toString().toLowerCase() ?? '';
      return employeeNumber.contains(query) ||
          firstName.contains(query.toLowerCase());
    }).toList();
  }

  /// Save the invoice data to Hive and console log it
  // Future<void> saveInvoiceToHiveAndPrint() async {
  //   final box = await Hive.openBox('invoiceBox');

  //   // Step 1: Generate a unique HiveInvoiceId
  //   String hiveInvoiceId = _invoiceService.generateShortHiveInvoiceId();

  //   // Step 2: Prepare the invoice data

  //   var cartProvider = Provider.of<CurrentSaleProvider>(context, listen: false);
  //   var cartItems = cartProvider.currentSaleItems ?? [];
  //   // Step 3: Extract item data into separate lists
  //   List<String> itemNames = [];
  //   List<String> varianceNames = [];
  //   List<double> prices = [];
  //   List<double> weights = [];
  //   List<double> quantities = [];
  //   List<double> amounts = [];
  //   List<double> taxes = [];
  //   List<String> uoms = [];

  //   for (var item in cartItems) {
  //     itemNames.add(item['itemData']['itemName'] ?? 'N/A');
  //     varianceNames.add(item['varianceData']['varianceName'] ?? 'N/A');
  //     prices.add(
  //         item['varianceData']['variance_Defaultprice']?.toDouble() ?? 0.0);
  //     weights.add((item['weight'] ?? 0.0).toDouble());
  //     quantities.add((item['quantity'] as num).toDouble() ?? 0.0);
  //     amounts.add(cartProvider.calculateItemTotal(item).toDouble());
  //     taxes.add((item['itemData']['tax'] as num).toDouble());
  //     uoms.add(item['varianceData']['variance_Uom'] ?? 'N/A');
  //   }

  //   // Step 4: Prepare the complete invoice data
  //   DateTime billDate = DateTime.now();
  //   String formattedDate = DateFormat('dd-MM-yy').format(billDate);
  //   String formattedTime = DateFormat('hh:mm a').format(billDate);

  //   Map<String, dynamic> invoiceData = {
  //     'HiveInvoiceId': hiveInvoiceId,
  //     'itemName': itemNames,
  //     'varianceName': varianceNames,
  //     'price': prices,
  //     'weight': weights,
  //     'qty': quantities,
  //     'amount': amounts,
  //     'tax': taxes,
  //     'uom': uoms,
  //     'employeeName': _employeeNumberController.text,
  //     'customerPhoneNumber': _customerNumberController.text,
  //     'discountPercentage': _discountController.text.isNotEmpty
  //         ? int.tryParse(_discountController.text) ?? 0
  //         : 0,
  //     'customCharge': _customChargeController.text.isNotEmpty
  //         ? int.tryParse(_customChargeController.text) ?? 0
  //         : 0,
  //     'totalAmount': widget.totalAmount.toStringAsFixed(0),
  //     'totalAmount2': widget.totalAmount.toStringAsFixed(0),
  //     'invoiceDate': formattedDate,
  //     'branchId': "099089",
  //     'salesType': "TakeAway",
  //     'branchName': "Aranmanai",
  //     'paymentType': _selectedPaymentOptionVaule,
  //     'cash': _cashAmount > 0
  //         ? _cashAmount
  //         : null, // Include cash only if cash is selected
  //     'card': _cardAmount > 0
  //         ? _cardAmount
  //         : null, // Include card only if card is selected
  //     'upi': _upiAmount > 0 ? _upiAmount : null,
  //     'others': null,
  //     'invoiceTime': formattedTime,
  //     'shiftNumber': "1",
  //     'shiftId': "1",
  //     'invoiceNo': "BM2402",
  //     'deviceNumber': "1",
  //     "sync": "no",
  //     "status": "active"
  //     // 'user': ["ASD"],`
  //   };

  //   // Print the full invoice data before saving to Hive

  //   // Step 5: Save the invoice data to Hive
  //   // Generate a unique identifier based on crucial invoice details
  //   var uniqueIdentifier =
  //       '$formattedDate-${widget.totalAmount}-${_customerNumberController.text}';
  //   var exists = false;

  //   for (var i = 0; i < box.length; i++) {
  //     var existingInvoice =  box.getAt(i);
  //     if (existingInvoice['uniqueIdentifier'] == uniqueIdentifier) {
  //       exists = true;
  //       break;
  //     }
  //   }

  //   if (!exists) {
  //     invoiceData['uniqueIdentifier'] = uniqueIdentifier;

  //     await box.add(invoiceData);

  //     developer.log('Invoice saved to Hive:', name: 'InvoiceLog');
  //     developer.log('Invoice ID: ${box.keyAt(box.length - 1)}');

  //     // Print the invoice
  //     // Include your printing logic here
  //   }

  //   // box.clear();
  //   // Log the saved invoice data to the console
  //   developer.log('Invoice saved to Hive:', name: 'InvoiceLog');
  //   developer.log('HiveInvoiceId: $hiveInvoiceId');
  //   developer.log('Employee Number: ${invoiceData['employeeNumber']}');
  //   developer.log('Customer Number: ${invoiceData['customerNumber']}');
  //   developer.log('Discount: ${invoiceData['discount']}');
  //   developer.log('Custom Charge: ${invoiceData['customCharge']}');
  //   developer.log('Total Amount: ${invoiceData['totalAmount']}');

  //   // Step 7: Print the invoice (using your existing printing logic)
  //   // Your printing logic here

  //   // Step 8: Try to post the invoice to FastAPI
  //   // Step 5: Save the invoice data to Hive
  //   await _invoiceService.saveInvoiceToHive(invoiceData);

  //   // Step 8: Try to post the invoice to FastAPI
  //   try {
  //     developer.log('Calling postInvoiceToFastAPI...', name: 'InvoiceLog');
  //     var response = await _invoiceService.postInvoiceToFastAPI(invoiceData);

  //     // Log after receiving the response
  //     if (response.statusCode == 200) {
  //       developer.log('Invoice successfully posted to FastAPI',
  //           name: 'InvoiceLog');
  //     } else {
  //       developer.log(
  //           'Failed to post invoice: ${response.statusCode} - ${response.body}',
  //           name: 'InvoiceLog');
  //     }
  //   } catch (e) {
  //     developer.log('Error posting invoice: $e', name: 'InvoiceLog');
  //   }

  //   // Optionally, show a message in the UI
  //   // ScaffoldMessenger.of(context).showSnackBar(
  //   //   SnackBar(content: Text('Invoice $hiveInvoiceId saved successfully')),
  //   // );
  // }

  /// Save the invoice data and print to console
  /// nal InvoiceService _invoiceService = InvoiceService();
  // final Set<String> _loggedInvoices = {}; // Track unique invoices
  // Future<void> saveInvoiceToHiveAndPrint() async {
  //   // Step 1: Generate a unique HiveInvoiceId
  //   String hiveInvoiceId = _invoiceService.generateShortHiveInvoiceId();

  //   // Step 2: Prepare the invoice data
  //   var cartProvider = Provider.of<CurrentSaleProvider>(context, listen: false);
  //   var cartItems = cartProvider.currentSaleItems ?? [];

  //   // Step 3: Extract item data into separate lists
  //   List<String> itemNames = [];
  //   List<String> varianceNames = [];
  //   List<double> prices = [];
  //   List<double> weights = [];
  //   List<double> quantities = [];
  //   List<double> amounts = [];
  //   List<double> taxes = [];
  //   List<String> uoms = [];

  //   for (var item in cartItems) {
  //     itemNames.add(item['itemData']['itemName'] ?? 'N/A');
  //     varianceNames.add(item['varianceData']['varianceName'] ?? 'N/A');
  //     prices.add(
  //         item['varianceData']['variance_Defaultprice']?.toDouble() ?? 0.0);
  //     weights.add((item['weight'] ?? 0.0).toDouble());
  //     quantities.add((item['quantity'] as num).toDouble() ?? 0.0);
  //     amounts.add(cartProvider.calculateItemTotal(item).toDouble());
  //     taxes.add((item['itemData']['tax'] as num).toDouble());
  //     uoms.add(item['varianceData']['variance_Uom'] ?? 'N/A');
  //   }

  //   // Step 4: Prepare the complete invoice data
  //   DateTime billDate = DateTime.now();
  //   String formattedDate = DateFormat('dd-MM-yy').format(billDate);
  //   String formattedTime = DateFormat('hh:mm a').format(billDate);

  //   String uniqueIdentifier =
  //       '$formattedDate-${widget.totalAmount}-${_customerNumberController.text}';

  //   Map<String, dynamic> invoiceData = {
  //     'HiveInvoiceId': hiveInvoiceId,
  //     'itemName': itemNames,
  //     'varianceName': varianceNames,
  //     'price': prices,
  //     'weight': weights,
  //     'qty': quantities,
  //     'amount': amounts,
  //     'tax': taxes,
  //     'uom': uoms,
  //     'employeeName': _employeeNumberController.text,
  //     'customerPhoneNumber': _customerNumberController.text,
  //     'discountPercentage': _discountController.text.isNotEmpty
  //         ? int.tryParse(_discountController.text) ?? 0
  //         : 0,
  //     'customCharge': _customChargeController.text.isNotEmpty
  //         ? int.tryParse(_customChargeController.text) ?? 0
  //         : 0,
  //     'totalAmount': widget.totalAmount.toStringAsFixed(0),
  //     'totalAmount2': widget.totalAmount.toStringAsFixed(0),
  //     'invoiceDate': formattedDate,
  //     'branchId': "099089",
  //     'salesType': "TakeAway",
  //     'branchName': "Aranmanai",
  //     'paymentType': _selectedPaymentOptionVaule,
  //     'cash': _cashAmount > 0 ? _cashAmount : null,
  //     'card': _cardAmount > 0 ? _cardAmount : null,
  //     'upi': _upiAmount > 0 ? _upiAmount : null,
  //     'others': null,
  //     'invoiceTime': formattedTime,
  //     'shiftNumber': "1",
  //     'shiftId': "1",
  //     'invoiceNo': "BM2402",
  //     'deviceNumber': "1",
  //     "sync": "no",
  //     "status": "active",
  //     "uniqueIdentifier": uniqueIdentifier,
  //   };

  //   // Log the invoice data only if it hasn't been logged before
  //   if (!_loggedInvoices.contains(uniqueIdentifier)) {
  //     _loggedInvoices.add(uniqueIdentifier);
  //     developer.log('Invoice Data:', name: 'InvoiceLog');
  //     developer.log(invoiceData.toString(), name: 'InvoiceLog');
  //   }
  // }

// A set to track sent invoices (you can initialize this globally in your class)

// Set to track invoices that have been sent to prevent duplicates
  Set<String> _sentInvoices = {};

// Function to load the sent invoices from Hive
  Future<void> loadSentInvoices() async {
    var box = await Hive.openBox('sentInvoicesBox');
    _sentInvoices = Set<String>.from(box.get('sentInvoices', defaultValue: []));
  }

// Function to save the sent invoices to Hive
  Future<void> saveSentInvoices() async {
    var box = await Hive.openBox('sentInvoicesBox');
    await box.put('sentInvoices', _sentInvoices.toList());
  }

  Future<void> sendInvoiceDataToServer(Map<String, dynamic> invoiceData) async {
    try {
      final jsonData = jsonEncode(invoiceData);
      _channel.sink.add(jsonData);
    } catch (e) {}
  }

  // Future<void> saveInvoiceToHiveAndPrint() async {
  //   print("Starting saveInvoiceToHiveAndPrint process...");

  //   // Step 1: Generate a unique HiveInvoiceId
  //   String hiveInvoiceId = _invoiceService.generateShortHiveInvoiceId();
  //   print("Generated HiveInvoiceId: $hiveInvoiceId");

  //   // Step 2: Prepare the invoice data
  //   var cartProvider = Provider.of<CurrentSaleProvider>(context, listen: false);
  //   var cartItems = cartProvider.currentSaleItems ?? [];
  //   print("Cart items: $cartItems");

  //   // Extract item data into separate lists
  //   List<String> itemNames = [];
  //   List<String> varianceNames = [];
  //   List<double> prices = [];
  //   List<double> weights = [];
  //   List<double> quantities = [];
  //   List<double> amounts = [];
  //   List<double> taxes = [];
  //   List<String> uoms = [];

  //   for (var item in cartItems) {
  //     itemNames.add(item['itemData']['itemName'] ?? 'N/A');
  //     varianceNames.add(item['varianceData']['varianceName'] ?? 'N/A');
  //     prices.add(
  //         item['varianceData']['variance_Defaultprice']?.toDouble() ?? 0.0);
  //     weights.add((item['weight'] ?? 0.0).toDouble());
  //     quantities.add((item['quantity'] as num).toDouble() ?? 0.0);
  //     amounts.add(cartProvider.calculateItemTotal(item).toDouble());
  //     taxes.add((item['itemData']['tax'] as num).toDouble());
  //     uoms.add(item['varianceData']['variance_Uom'] ?? 'N/A');
  //   }

  //   // Step 3: Prepare the complete invoice data
  //   DateTime billDate = DateTime.now();
  //   String formattedDate = DateFormat('dd-MM-yyyy').format(billDate);
  //   String formattedTime = DateFormat('hh:mm a').format(billDate);
  //   String uniqueIdentifier =
  //       '$formattedDate-${widget.totalAmount}-${_customerNumberController.text}';

  //   print("Generated uniqueIdentifier: $uniqueIdentifier");

  //   Map<String, dynamic> invoiceData = {
  //     'HiveInvoiceId': hiveInvoiceId,
  //     'itemName': itemNames,
  //     'varianceName': varianceNames,
  //     'price': prices,
  //     'weight': weights,
  //     'qty': quantities,
  //     'amount': amounts,
  //     'tax': taxes,
  //     'uom': uoms,
  //     'employeeName': _employeeNumberController.text,
  //     'customerPhoneNumber': _customerNumberController.text,
  //     'discountPercentage': _discountController.text.isNotEmpty
  //         ? int.tryParse(_discountController.text) ?? 0
  //         : 0,
  //     'customCharge': _customChargeController.text.isNotEmpty
  //         ? int.tryParse(_customChargeController.text) ?? 0
  //         : 0,
  //     'totalAmount': widget.totalAmount.toStringAsFixed(0),
  //     'totalAmount2': widget.totalAmount.toStringAsFixed(0),
  //     'invoiceDate': formattedDate,
  //     'branchId': "099089",
  //     'salesType': "TakeAway",
  //     'branchName': "Aranmanai",
  //     'paymentType': _selectedPaymentOptionVaule,
  //     'cash': _cashAmount > 0 ? _cashAmount : null,
  //     'card': _cardAmount > 0 ? _cardAmount : null,
  //     'upi': _upiAmount > 0 ? _upiAmount : null,
  //     'others': null,
  //     'invoiceTime': formattedTime,
  //     'shiftNumber': "1",
  //     'shiftId': "1",
  //     'invoiceNo': "BM2402",
  //     'deviceNumber': "1",
  //     "sync": "no",
  //     "status": "active",
  //     "uniqueIdentifier": uniqueIdentifier,
  //   };

  //   // Step 4: Load sent invoices from Hive
  //   await loadSentInvoices();
  //   await _invoiceService.saveInvoiceToHive(invoiceData);
  //   // Step 5: Check if this invoice has already been sent
  //   if (_sentInvoices.contains(uniqueIdentifier)) {
  //     print(
  //         "Invoice with uniqueIdentifier $uniqueIdentifier has already been sent.");
  //     developer.log('Invoice already sent: $uniqueIdentifier');
  //     return; // If the invoice has already been sent, exit the function
  //   }

  //   // Step 6: Log the invoice data only if it hasn't been logged before
  //   if (!_loggedInvoices.contains(uniqueIdentifier)) {
  //     _loggedInvoices.add(uniqueIdentifier);
  //     print("Logging invoice data...");
  //     developer.log('Invoice Data:', name: 'InvoiceLog');
  //     developer.log(invoiceData.toString(), name: 'InvoiceLog');
  //   }

  //   // Step 7: Save the invoice to Hive only if it doesn't already exist
  //   var box = await Hive.openBox('invoiceBox');
  //   bool exists = box.values.any((invoice) =>
  //       invoice is Map<String, dynamic> &&
  //       invoice['uniqueIdentifier'] == uniqueIdentifier);

  //   if (!exists) {
  //     await box.add(invoiceData);
  //     print("Invoice saved to Hive with uniqueIdentifier: $uniqueIdentifier");
  //     developer.log('Invoice saved to Hive:', name: 'InvoiceLog');
  //   } else {
  //     print("Invoice already exists in Hive.");
  //   }

  //   // Step 8: Try sending the invoice to the server only if it hasn't been sent before
  //   try {
  //     print("Attempting to send invoice to FastAPI...");
  //     developer.log('Calling postInvoiceToFastAPI...', name: 'InvoiceLog');
  //     var response = await _invoiceService.postInvoiceToFastAPI(invoiceData);

  //     if (response.statusCode == 201) {
  //       print("Invoice successfully posted to FastAPI.");
  //       developer.log('Invoice successfully posted to FastAPI',
  //           name: 'InvoiceLog');
  //     } else {
  //       print(
  //           "Failed to post invoice: ${response.statusCode} - ${response.body}");
  //       developer.log(
  //           'Failed to post invoice: ${response.statusCode} - ${response.body}',
  //           name: 'InvoiceLog');
  //     }
  //   } catch (e) {
  //     print("Error posting invoice: $e");
  //     developer.log('Error posting invoice: $e', name: 'InvoiceLog');
  //   }

  //   // Step 9: Send the invoice data to the server (if not sent already)
  //   print("Sending invoice data to the server...");
  //   if (!exists) {
  //     await box.add(invoiceData);
  //     developer.log('Invoice saved to Hive:', name: 'InvoiceLog');
  //   }
  //   try {
  //     var response = await _invoiceService.postInvoiceToFastAPI(invoiceData);
  //     if (response.statusCode == 201) {
  //       // Send SMS
  //       String customerNumber = _customerNumberController.text;
  //       String totalAmount = widget.totalAmount.toStringAsFixed(0);
  //       String billNumber = invoiceData['invoiceNo'];

  //       String smsApiUrl =
  //           'https://mailcon.in/vb/apikey.php?apikey=w31prN4CCtJg7XvK&senderid=BMUMMY&templateid=1707167058380400950&number=$customerNumber&message=WELCOME TO BESTMUMMY BILL NO:$billNumber BILL AMOUNT: $totalAmount VISIT OUR 45 THANK YOU FOR VISITING AGAIN';

  //       var smsResponse = await http.get(Uri.parse(smsApiUrl));
  //       if (smsResponse.statusCode == 201) {
  //         print('SMS sent successfully to $customerNumber');
  //       } else {
  //         print('Failed to send SMS: ${smsResponse.body}');
  //       }
  //     } else {
  //       print('Failed to post invoice: ${response.statusCode}');
  //     }
  //   } catch (e) {
  //     print('Error posting invoice or sending SMS: $e');
  //   }
  //   try {
  //     var response = await _invoiceService.postInvoiceToFastAPI(invoiceData);
  //     if (response.statusCode == 201) {
  //       // Send SMS
  //       String customerNumber = _customerNumberController.text;
  //       String totalAmount = widget.totalAmount.toStringAsFixed(0);
  //       String billNumber = invoiceData['invoiceNo'];

  //       String smsApiUrl =
  //           'https://mailcon.in/vb/apikey.php?apikey=w31prN4CCtJg7XvK&senderid=BMUMMY&templateid=1707167058380400950&number=$customerNumber&message=WELCOME TO BESTMUMMY BILL NO:$billNumber BILL AMOUNT: $totalAmount VISIT OUR 45 THANK YOU FOR VISITING AGAIN';

  //       var smsResponse = await http.get(Uri.parse(smsApiUrl));
  //       if (smsResponse.statusCode == 200) {
  //         print('SMS sent successfully to $customerNumber');
  //       } else {
  //         print('Failed to send SMS: ${smsResponse.body}');
  //       }
  //       Future<void> sendWhatsAppMessage(String customerNumber,
  //           String billNumber, String totalAmount) async {
  //         try {
  //           String whatsappApiUrl =
  //               'https://backend.askeva.io/v1/message/send-message?token=226b3bc6338f9de4107cc93016924fb2868113776165b8d4b9a76914930e2fa2e47ff2906d87e0281121e425dccf62d84a6a82303c99beb2c24d0f9da7a46c1e32af25b2e74b7e42a7d17ce834c474aeb9b4abecdf454ade5fcd7519b8dd2e3893e0ac008bf50aa0d2ddc59737e381d4166d7d1e45af5cb285d388959efdc897c43af27799a56ea571830eca7cb8d5f08cf4284b28dff365fb85a2ad9d645ee0aaf8a86e8d6103150f29361e0f4556ba02cbf0149bacd06ad35fbe51d0ba630533cf73a51476c02eccc3845d13506638';

  //           Map<String, dynamic> whatsappMessage = {
  //             "to": customerNumber,
  //             "type": "image",
  //             "template": {
  //               "language": {"policy": "deterministic", "code": "en"},
  //               "name": "whatsapp_test",
  //               "components": [
  //                 {
  //                   "type": "header",
  //                   "parameters": [
  //                     {
  //                       "type": "image",
  //                       "image": {"link": "https://yenerp.com/share/logo.jpg"}
  //                     }
  //                   ]
  //                 },
  //                 {
  //                   "type": "body",
  //                   "parameters": [
  //                     {"type": "text", "text": "Team"},
  //                     {"type": "text", "text": "Bill No: $billNumber"},
  //                     {"type": "text", "text": "Amount: ₹$totalAmount"}
  //                   ]
  //                 }
  //               ]
  //             }
  //           };

  //           var whatsappResponse = await http.post(
  //             Uri.parse(whatsappApiUrl),
  //             headers: {
  //               "Content-Type": "application/json",
  //             },
  //             body: json.encode(whatsappMessage),
  //           );

  //           if (whatsappResponse.statusCode == 200) {
  //             print('WhatsApp message sent successfully to $customerNumber');
  //           } else {
  //             print(
  //                 'Failed to send WhatsApp message. Status Code: ${whatsappResponse.statusCode}');
  //             print('Response Body: ${whatsappResponse.body}');
  //           }
  //         } catch (e) {
  //           print('Error sending WhatsApp message: $e');
  //         }
  //       }

  //       // Send WhatsApp message
  //       String whatsappApiUrl =
  //           'https://backend.askeva.io/v1/message/send-message?token=226b3bc6338f9de4107cc93016924fb2868113776165b8d4b9a76914930e2fa2e47ff2906d87e0281121e425dccf62d84a6a82303c99beb2c24d0f9da7a46c1e32af25b2e74b7e42a7d17ce834c474aeb9b4abecdf454ade5fcd7519b8dd2e3893e0ac008bf50aa0d2ddc59737e381d4166d7d1e45af5cb285d388959efdc897c43af27799a56ea571830eca7cb8d5f08cf4284b28dff365fb85a2ad9d645ee0aaf8a86e8d6103150f29361e0f4556ba02cbf0149bacd06ad35fbe51d0ba630533cf73a51476c02eccc3845d13506638';
  //       Map<String, dynamic> whatsappMessage = {
  //         "to": "91$customerNumber",
  //         "type": "template",
  //         "template": {
  //           "language": {"policy": "deterministic", "code": "en"},
  //           "name": "whatsapp_test",
  //           "components": [
  //             {
  //               "type": "header",
  //               "parameters": [
  //                 {
  //                   "type": "image",
  //                   "image": {"link": "https://yenerp.com/share/offer.jpg"}
  //                 }
  //               ]
  //             },
  //             {
  //               "type": "body",
  //               "parameters": [
  //                 {"type": "text", "text": "Customer"},
  //                 {"type": "text", "text": "Bill No: $billNumber"},
  //                 {"type": "text", "text": "Amount: $totalAmount"}
  //               ]
  //             }
  //           ]
  //         }
  //       };

  //       var whatsappResponse = await http.post(
  //         Uri.parse(whatsappApiUrl),
  //         headers: {
  //           "Content-Type": "application/json",
  //         },
  //         body: json.encode(whatsappMessage),
  //       );

  //       if (whatsappResponse.statusCode == 201) {
  //         print('WhatsApp message sent successfully to $customerNumber');
  //       } else {
  //         print('Failed to send WhatsApp message: ${whatsappResponse.body}');
  //       }
  //     } else {
  //       print('Failed to post invoice: ${response.statusCode}');
  //     }
  //   } catch (e) {
  //     print('Error posting invoice or sending message: $e');
  //   }

  //   // Step 6: Optionally, post the invoice to FastAPI
  //   try {
  //     developer.log('Calling postInvoiceToFastAPI...', name: 'InvoiceLog');
  //     var response = await _invoiceService.postInvoiceToFastAPI(invoiceData);

  //     if (response.statusCode == 201) {
  //       developer.log('Invoice successfully posted to FastAPI',
  //           name: 'InvoiceLog');
  //     } else {
  //       developer.log(
  //           'Failed to post invoice: ${response.statusCode} - ${response.body}',
  //           name: 'InvoiceLog');
  //     }
  //   } catch (e) {
  //     developer.log('Error posting invoice: $e', name: 'InvoiceLog');
  //   }
  //   await sendInvoiceDataToServer(invoiceData);
  //   print("Server request completed.");

  //   // Step 10: Mark this invoice as sent by adding it to the set
  //   _sentInvoices.add(uniqueIdentifier); // Mark as sent
  //   await saveSentInvoices(); // Save the updated sent invoices to Hive
  //   print("Invoice marked as sent: $uniqueIdentifier.");

  //   print("saveInvoiceToHiveAndPrint process completed.");
  // }

//   Future<void> saveInvoiceToHiveAndPrint1() async {
//     // Step 1: Generate a unique HiveInvoiceId
//     String hiveInvoiceId = _invoiceService.generateShortHiveInvoiceId();

//     // Step 2: Prepare the invoice data
//     var cartProvider = Provider.of<CurrentSaleProvider>(context, listen: false);
//     var cartItems = cartProvider.currentSaleItems ?? [];

//     // Extract item data into separate lists
//     List<String> itemNames = [];
//     List<String> varianceNames = [];
//     List<double> prices = [];
//     List<double> weights = [];
//     List<double> quantities = [];
//     List<double> amounts = [];
//     List<double> taxes = [];
//     List<String> uoms = [];

//     for (var item in cartItems) {
//       itemNames.add(item['itemData']['itemName'] ?? 'N/A');
//       varianceNames.add(item['varianceData']['varianceName'] ?? 'N/A');
//       prices.add(
//           item['varianceData']['variance_Defaultprice']?.toDouble() ?? 0.0);
//       weights.add((item['weight'] ?? 0.0).toDouble());
//       quantities.add((item['quantity'] as num).toDouble() ?? 0.0);
//       amounts.add(cartProvider.calculateItemTotal(item).toDouble());
//       taxes.add((item['itemData']['tax'] as num).toDouble());
//       uoms.add(item['varianceData']['variance_Uom'] ?? 'N/A');
//     }

//     // Step 3: Prepare the complete invoice data
//     DateTime billDate = DateTime.now();
//     String formattedDate = DateFormat('dd-MM-yyyy').format(billDate);
//     String formattedTime = DateFormat('hh:mm a').format(billDate);

//     String uniqueIdentifier =
//         '$formattedDate-${widget.totalAmount}-${_customerNumberController.text}';
// // Usage
//     var invoiceNumberGenerator = InvoiceNumberGenerator();
//     String newInvoiceNumber =
//         await invoiceNumberGenerator.generateInvoiceNumber();
//     print("New Invoice Number: $newInvoiceNumber");
//     Map<String, dynamic> invoiceData = {
//       'HiveInvoiceId': hiveInvoiceId,
//       'itemName': itemNames,
//       'varianceName': varianceNames,
//       'price': prices,
//       'weight': weights,
//       'qty': quantities,
//       'amount': amounts,
//       'tax': taxes,
//       'uom': uoms,
//       'employeeName': _employeeNumberController.text,
//       'customerPhoneNumber': _customerNumberController.text,
//       'discountPercentage': _discountController.text.isNotEmpty
//           ? int.tryParse(_discountController.text) ?? 0
//           : 0,
//       'customCharge': _customChargeController.text.isNotEmpty
//           ? int.tryParse(_customChargeController.text) ?? 0
//           : 0,
//       'totalAmount': widget.totalAmount.toStringAsFixed(0),
//       'totalAmount2': widget.totalAmount.toStringAsFixed(0),
//       'invoiceDate': formattedDate,
//       'branchId': "099089",
//       'salesType': "TakeAway",
//       'branchName': "Aranmanai",
//       'paymentType': _selectedPaymentOptionVaule,
//       'cash': _cashAmount > 0 ? _cashAmount : null,
//       'card': _cardAmount > 0 ? _cardAmount : null,
//       'upi': _upiAmount > 0 ? _upiAmount : null,
//       'others': null,
//       'invoiceTime': formattedTime,
//       'shiftNumber': "1",
//       'shiftId': "1",
//       'invoiceNo': "BM$newInvoiceNumber",
//       'deviceNumber': "1",
//       "sync": "no",
//       "status": "active",
//       "uniqueIdentifier": uniqueIdentifier,
//     };

//     // Step 4: Log the invoice data only if it hasn't been logged before
//     if (!_loggedInvoices.contains(uniqueIdentifier)) {
//       _loggedInvoices.add(uniqueIdentifier);
//       developer.log('Invoice Data:', name: 'InvoiceLog');
//       developer.log(invoiceData.toString(), name: 'InvoiceLog');
//     }

//     // Step 5: Save the invoice to Hive only if it doesn't already exist
//     var box = await Hive.openBox('invoiceBox');
//     bool exists = box.values.any((invoice) =>
//         invoice is Map<String, dynamic> &&
//         invoice['uniqueIdentifier'] == uniqueIdentifier);

//     if (!exists) {
//       await box.add(invoiceData);
//       developer.log('Invoice saved to Hive:', name: 'InvoiceLog');
//     }
//     try {
//       var response = await _invoiceService.postInvoiceToFastAPI(invoiceData);
//       if (response.statusCode == 201) {
//         // Send SMS
//         String customerNumber = _customerNumberController.text;
//         String totalAmount = widget.totalAmount.toStringAsFixed(0);
//         String billNumber = invoiceData['invoiceNo'];

//         String smsApiUrl =
//             'https://mailcon.in/vb/apikey.php?apikey=w31prN4CCtJg7XvK&senderid=BMUMMY&templateid=1707167058380400950&number=$customerNumber&message=WELCOME TO BESTMUMMY BILL NO:$billNumber BILL AMOUNT: $totalAmount VISIT OUR 45 THANK YOU FOR VISITING AGAIN';

//         var smsResponse = await http.get(Uri.parse(smsApiUrl));
//         if (smsResponse.statusCode == 201) {
//           print('SMS sent successfully to $customerNumber');
//         } else {
//           print('Failed to send SMS: ${smsResponse.body}');
//         }
//       } else {
//         print('Failed to post invoice: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error posting invoice or sending SMS: $e');
//     }
//     try {
//       var response = await _invoiceService.postInvoiceToFastAPI(invoiceData);
//       if (response.statusCode == 201) {
//         print("ok1233");
//         // Send SMS
//         String customerNumber = _customerNumberController.text;
//         String totalAmount = widget.totalAmount.toStringAsFixed(0);
//         String billNumber = invoiceData['invoiceNo'];

//         String smsApiUrl =
//             'https://mailcon.in/vb/apikey.php?apikey=w31prN4CCtJg7XvK&senderid=BMUMMY&templateid=1707167058380400950&number=$customerNumber&message=WELCOME TO BESTMUMMY BILL NO:$billNumber BILL AMOUNT: $totalAmount VISIT OUR 45 THANK YOU FOR VISITING AGAIN';

//         var smsResponse = await http.get(Uri.parse(smsApiUrl));
//         if (smsResponse.statusCode == 200) {
//           print('SMS sent successfully to $customerNumber');
//         } else {
//           print('Failed to send SMS: ${smsResponse.body}');
//         }
//         Future<void> sendWhatsAppMessage(String customerNumber,
//             String billNumber, String totalAmount) async {
//           try {
//             String whatsappApiUrl =
//                 'https://backend.askeva.io/v1/message/send-message?token=226b3bc6338f9de4107cc93016924fb2868113776165b8d4b9a76914930e2fa2e47ff2906d87e0281121e425dccf62d84a6a82303c99beb2c24d0f9da7a46c1e32af25b2e74b7e42a7d17ce834c474aeb9b4abecdf454ade5fcd7519b8dd2e3893e0ac008bf50aa0d2ddc59737e381d4166d7d1e45af5cb285d388959efdc897c43af27799a56ea571830eca7cb8d5f08cf4284b28dff365fb85a2ad9d645ee0aaf8a86e8d6103150f29361e0f4556ba02cbf0149bacd06ad35fbe51d0ba630533cf73a51476c02eccc3845d13506638';

//             Map<String, dynamic> whatsappMessage = {
//               "to": customerNumber,
//               "type": "image",
//               "template": {
//                 "language": {"policy": "deterministic", "code": "en"},
//                 "name": "whatsapp_test",
//                 "components": [
//                   {
//                     "type": "header",
//                     "parameters": [
//                       {
//                         "type": "image",
//                         "image": {"link": "https://yenerp.com/share/logo.jpg"}
//                       }
//                     ]
//                   },
//                   {
//                     "type": "body",
//                     "parameters": [
//                       {"type": "text", "text": "Team"},
//                       {"type": "text", "text": "Bill No: $billNumber"},
//                       {"type": "text", "text": "Amount: ₹$totalAmount"}
//                     ]
//                   }
//                 ]
//               }
//             };

//             var whatsappResponse = await http.post(
//               Uri.parse(whatsappApiUrl),
//               headers: {
//                 "Content-Type": "application/json",
//               },
//               body: json.encode(whatsappMessage),
//             );

//             if (whatsappResponse.statusCode == 200) {
//               print('WhatsApp message sent successfully to $customerNumber');
//             } else {
//               print(
//                   'Failed to send WhatsApp message. Status Code: ${whatsappResponse.statusCode}');
//               print('Response Body: ${whatsappResponse.body}');
//             }
//           } catch (e) {
//             print('Error sending WhatsApp message: $e');
//           }
//         }

//         // Send WhatsApp message
//         String whatsappApiUrl =
//             'https://backend.askeva.io/v1/message/send-message?token=226b3bc6338f9de4107cc93016924fb2868113776165b8d4b9a76914930e2fa2e47ff2906d87e0281121e425dccf62d84a6a82303c99beb2c24d0f9da7a46c1e32af25b2e74b7e42a7d17ce834c474aeb9b4abecdf454ade5fcd7519b8dd2e3893e0ac008bf50aa0d2ddc59737e381d4166d7d1e45af5cb285d388959efdc897c43af27799a56ea571830eca7cb8d5f08cf4284b28dff365fb85a2ad9d645ee0aaf8a86e8d6103150f29361e0f4556ba02cbf0149bacd06ad35fbe51d0ba630533cf73a51476c02eccc3845d13506638';
//         Map<String, dynamic> whatsappMessage = {
//           "to": "91$customerNumber",
//           "type": "template",
//           "template": {
//             "language": {"policy": "deterministic", "code": "en"},
//             "name": "whatsapp_test",
//             "components": [
//               {
//                 "type": "header",
//                 "parameters": [
//                   {
//                     "type": "image",
//                     "image": {"link": "https://yenerp.com/share/offer.jpg"}
//                   }
//                 ]
//               },
//               {
//                 "type": "body",
//                 "parameters": [
//                   {"type": "text", "text": "Customer"},
//                   {"type": "text", "text": "Bill No: $billNumber"},
//                   {"type": "text", "text": "Amount: $totalAmount"}
//                 ]
//               }
//             ]
//           }
//         };

//         var whatsappResponse = await http.post(
//           Uri.parse(whatsappApiUrl),
//           headers: {
//             "Content-Type": "application/json",
//           },
//           body: json.encode(whatsappMessage),
//         );

//         if (whatsappResponse.statusCode == 200) {
//           print('WhatsApp message sent successfully to $customerNumber');
//         } else {
//           print('Failed to send WhatsApp message: ${whatsappResponse.body}');
//         }
//       } else {
//         print('Failed to post invoice: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error posting invoice or sending message: $e');
//     }

//     // Step 6: Optionally, post the invoice to FastAPI
//     try {
//       developer.log('Calling postInvoiceToFastAPI...', name: 'InvoiceLog');
//       var response = await _invoiceService.postInvoiceToFastAPI(invoiceData);

//       if (response.statusCode == 200) {
//         developer.log('Invoice successfully posted to FastAPI',
//             name: 'InvoiceLog');
//       } else {
//         developer.log(
//             'Failed to post invoice: ${response.statusCode} - ${response.body}',
//             name: 'InvoiceLog');
//       }
//     } catch (e) {
//       developer.log('Error posting invoice: $e', name: 'InvoiceLog');
//     }
//     print("web123");
//     await sendInvoiceDataToServer(invoiceData);
//     print("web done");
//   }
  Future<void> saveInvoiceToHiveAndPrint1() async {
    // Step 1: Generate a unique HiveInvoiceId
    String hiveInvoiceId = _invoiceService.generateShortHiveInvoiceId();

    // Step 2: Prepare the invoice data
    var cartProvider = Provider.of<CurrentSaleProvider>(context, listen: false);
    var cartItems = cartProvider.currentSaleItems;

    // Extract item data into separate lists
    List<String> itemNames = [];
    List<String> varianceNames = [];
    List<double> prices = [];
    List<double> weights = [];
    List<double> quantities = [];
    List<double> amounts = [];
    List<double> taxes = [];
    List<String> uoms = [];

    for (var item in cartItems) {
      itemNames.add(item['itemData']['itemName'] ?? 'N/A');
      varianceNames.add(item['varianceData']['varianceName'] ?? 'N/A');
      prices.add(
          item['varianceData']['variance_Defaultprice']?.toDouble() ?? 0.0);
      weights.add((item['weight'] ?? 0.0).toDouble());
      quantities.add((item['quantity'] as num).toDouble());
      amounts.add(cartProvider.calculateItemTotal(item).toDouble());
      taxes.add((item['itemData']['tax'] as num).toDouble());
      uoms.add(item['varianceData']['variance_Uom'] ?? 'N/A');
    }

    double discountPercentage =
        double.tryParse(_discountController.text) ?? 0.0;
    double discountAmount = (widget.totalAmount * (discountPercentage / 100));

// Round and format the discount amount

// Helper function to round and format discount amount
    double _roundDiscountAmount(double amount) {
      return (amount * 10).round() / 10.0; // Rounds to the nearest tenth
    }

    double roundedDiscountAmount = _roundDiscountAmount(discountAmount);
    // Step 3: Prepare the complete invoice data
    DateTime billDate = DateTime.now();
    String formattedDate = DateFormat('dd-MM-yyyy').format(billDate);
    String formattedTime = DateFormat('hh:mm a').format(billDate);
    String uniqueIdentifier =
        '$formattedDate-${widget.totalAmount}-${_customerNumberController.text}';

    var invoiceNumberGenerator = InvoiceNumberGenerator();
    String newInvoiceNumber =
        await invoiceNumberGenerator.generateInvoiceNumber();
    setState(() {
      invoiceNumber = newInvoiceNumber;
    });

    Map<String, dynamic> invoiceData = {
      "type": "posInvoice",
      'HiveInvoiceId': hiveInvoiceId,
      'itemName': itemNames,
      'varianceName': varianceNames,
      'price': prices,
      'weight': weights,
      'qty': quantities,
      'amount': amounts,
      'tax': taxes,
      'uom': uoms,
      'employeeName': _employeeNumberController.text,
      'customerPhoneNumber': _customerNumberController.text,
      'discountPercentage': _discountController.text.isNotEmpty
          ? int.tryParse(_discountController.text) ?? 0
          : 0,
      'customCharge': _customChargeController.text.isNotEmpty
          ? int.tryParse(_customChargeController.text) ?? 0
          : 0,
      'totalAmount': widget.totalAmount.toStringAsFixed(0),
      'totalAmount2': widget.totalAmount.toStringAsFixed(0),
      'invoiceDate': formattedDate,
      'branchId': "099089",
      'salesType': "TakeAway",
      'branchName': "Aranmanai",
      // 'paymentType': _selectedPaymentOptionVaule,
      'cash': _cashAmount > 0 ? _cashAmount : null,
      'card': _cardAmount > 0 ? _cardAmount : null,
      'upi': _upiAmount > 0 ? _upiAmount : null,
      'others': null,
      'invoiceTime': formattedTime,
      'shiftNumber': "1",
      'shiftId': "1",
      'invoiceNo': "$newInvoiceNumber",
      'discountAmount': roundedDiscountAmount,
      'deviceNumber': "1",
      'sync': "no",
      'status': "active",
      'uniqueIdentifier': uniqueIdentifier,
    };

    saveJsonToFile(invoiceData);
    // Step 4: Log the invoice data only if it hasn't been logged before
    if (!_loggedInvoices.contains(uniqueIdentifier)) {
      _loggedInvoices.add(uniqueIdentifier);
      developer.log('Invoice Data:', name: 'InvoiceLog');
      developer.log(invoiceData.toString(), name: 'InvoiceLog');
    }

    // Step 5: Save the invoice to Hive only if it doesn't already exist
    var box = await Hive.openBox('invoiceBox');
    bool exists = box.values.any((invoice) =>
        invoice is Map<String, dynamic> &&
        invoice['uniqueIdentifier'] == uniqueIdentifier);

    if (!exists) {
      await box.add(invoiceData);
      developer.log('Invoice saved to Hive:', name: 'InvoiceLog');
    } else {}
    // ignore: unused_local_variable
    await sendInvoiceDataToServer(invoiceData);
    // var response = await _invoiceService.postInvoiceToFastAPI(invoiceData);

    // Step 6: Try sending the invoice to the server only if it hasn't been sent before
    // try {
    //   if (response.statusCode == 201) {
    //     // Send SMS
    //     String customerNumber = _customerNumberController.text;
    //     String totalAmount = widget.totalAmount.toStringAsFixed(0);
    //     String billNumber = invoiceData['invoiceNo'];

    //     String smsApiUrl =
    //         'https://mailcon.in/vb/apikey.php?apikey=w31prN4CCtJg7XvK&senderid=BMUMMY&templateid=1707167058380400950&number=$customerNumber&message=WELCOME TO BESTMUMMY BILL NO:$billNumber BILL AMOUNT: $totalAmount VISIT OUR 45 THANK YOU FOR VISITING AGAIN';

    //     var smsResponse = await http.get(Uri.parse(smsApiUrl));
    //     if (smsResponse.statusCode == 201) {
    //       print('SMS sent successfully to $customerNumber');
    //     } else {
    //       print('Failed to send SMS: ${smsResponse.body}');
    //     }
    //   } else {
    //     print('Failed to post invoice: ${response.statusCode}');
    //   }
    // } catch (e) {
    //   print('Error posting invoice or sending SMS: $e');
    // }
    // try {
    //   if (response.statusCode == 201) {
    //     print("ok1233");
    //     // Send SMS
    //     String customerNumber = _customerNumberController.text;
    //     String totalAmount = widget.totalAmount.toStringAsFixed(0);
    //     String billNumber = invoiceData['invoiceNo'];

    //     String smsApiUrl =
    //         'https://mailcon.in/vb/apikey.php?apikey=w31prN4CCtJg7XvK&senderid=BMUMMY&templateid=1707167058380400950&number=$customerNumber&message=WELCOME TO BESTMUMMY BILL NO:$billNumber BILL AMOUNT: $totalAmount VISIT OUR 45 THANK YOU FOR VISITING AGAIN';

    //     var smsResponse = await http.get(Uri.parse(smsApiUrl));
    //     if (smsResponse.statusCode == 200) {
    //       print('SMS sent successfully to $customerNumber');
    //     } else {
    //       print('Failed to send SMS: ${smsResponse.body}');
    //     }
    //     // Future<void> sendWhatsAppMessage(String customerNumber,
    //     //     String billNumber, String totalAmount) async {
    //     //   try {
    //     //     String whatsappApiUrl =
    //     //         'https://backend.askeva.io/v1/message/send-message?token=226b3bc6338f9de4107cc93016924fb2868113776165b8d4b9a76914930e2fa2e47ff2906d87e0281121e425dccf62d84a6a82303c99beb2c24d0f9da7a46c1e32af25b2e74b7e42a7d17ce834c474aeb9b4abecdf454ade5fcd7519b8dd2e3893e0ac008bf50aa0d2ddc59737e381d4166d7d1e45af5cb285d388959efdc897c43af27799a56ea571830eca7cb8d5f08cf4284b28dff365fb85a2ad9d645ee0aaf8a86e8d6103150f29361e0f4556ba02cbf0149bacd06ad35fbe51d0ba630533cf73a51476c02eccc3845d13506638';

    //     //     Map<String, dynamic> whatsappMessage = {
    //     //       "to": customerNumber,
    //     //       "type": "image",
    //     //       "template": {
    //     //         "language": {"policy": "deterministic", "code": "en"},
    //     //         "name": "whatsapp_test",
    //     //         "components": [
    //     //           {
    //     //             "type": "header",
    //     //             "parameters": [
    //     //               {
    //     //                 "type": "image",
    //     //                 "image": {"link": "https://yenerp.com/share/logo.jpg"}
    //     //               }
    //     //             ]
    //     //           },
    //     //           {
    //     //             "type": "body",
    //     //             "parameters": [
    //     //               {"type": "text", "text": "Team"},
    //     //               {"type": "text", "text": "Bill No: $billNumber"},
    //     //               {
    //     //                 "type": "text",
    //     //                 "text":
    //     //                     "http://192.168.1.130:8888/fastapi/yourbill/677a1f2baeb682e114daf064"
    //     //               }
    //     //             ]
    //     //           }
    //     //         ]
    //     //       }
    //     //     };

    //     //     var whatsappResponse = await http.post(
    //     //       Uri.parse(whatsappApiUrl),
    //     //       headers: {
    //     //         "Content-Type": "application/json",
    //     //       },
    //     //       body: json.encode(whatsappMessage),
    //     //     );

    //     //     if (whatsappResponse.statusCode == 200) {
    //     //       print('WhatsApp message sent successfully to $customerNumber');
    //     //     } else {
    //     //       print(
    //     //           'Failed to send WhatsApp message. Status Code: ${whatsappResponse.statusCode}');
    //     //       print('Response Body: ${whatsappResponse.body}');
    //     //     }
    //     //   } catch (e) {
    //     //     print('Error sending WhatsApp message: $e');
    //     //   }
    //     // }

    //     // Send WhatsApp message
    //     String whatsappApiUrl =
    //         'https://backend.askeva.io/v1/message/send-message?token=226b3bc6338f9de4107cc93016924fb2868113776165b8d4b9a76914930e2fa2e47ff2906d87e0281121e425dccf62d84a6a82303c99beb2c24d0f9da7a46c1e32af25b2e74b7e42a7d17ce834c474aeb9b4abecdf454ade5fcd7519b8dd2e3893e0ac008bf50aa0d2ddc59737e381d4166d7d1e45af5cb285d388959efdc897c43af27799a56ea571830eca7cb8d5f08cf4284b28dff365fb85a2ad9d645ee0aaf8a86e8d6103150f29361e0f4556ba02cbf0149bacd06ad35fbe51d0ba630533cf73a51476c02eccc3845d13506638';
    //     Map<String, dynamic> whatsappMessage = {
    //       "to": "91$customerNumber",
    //       "type": "template",
    //       "template": {
    //         "language": {"policy": "deterministic", "code": "en"},
    //         "name": "whatsapp_test",
    //         "components": [
    //           {
    //             "type": "header",
    //             "parameters": [
    //               {
    //                 "type": "image",
    //                 "image": {"link": "https://yenerp.com/share/offer.jpg"}
    //               }
    //             ]
    //           },
    //           {
    //             "type": "body",
    //             "parameters": [
    //               {"type": "text", "text": "Team"},
    //               {"type": "text", "text": "Bill No: $billNumber"},
    //               {
    //                 "type": "text",
    //                 "text":
    //                     "http://192.168.1.130:8888/fastapi/yourbill/677a1f2baeb682e114daf064"
    //               }
    //             ]
    //           }
    //         ]
    //       }
    //     };

    //     var whatsappResponse = await http.post(
    //       Uri.parse(whatsappApiUrl),
    //       headers: {
    //         "Content-Type": "application/json",
    //       },
    //       body: json.encode(whatsappMessage),
    //     );

    //     if (whatsappResponse.statusCode == 200) {
    //       print('WhatsApp message sent successfully to $customerNumber');
    //     } else {
    //       print('Failed to send WhatsApp message: ${whatsappResponse.body}');
    //     }
    //   } else {
    //     print('Failed to post invoice: ${response.statusCode}');
    //   }
    // } catch (e) {
    //   print('Error posting invoice or sending message: $e');
    // }
  }

  Future<void> printInvoiceData() async {
    var box = await Hive.openBox('invoiceBox');

    // Check if the box is not empty
    if (box.isNotEmpty) {
      // Iterate through all invoices stored in the box
      for (var i = 0; i < box.length; i++) {}
    } else {}

    await box.close();
  }

  Future<void> updateInvoice(
      String invoiceId, Map<String, dynamic> updatedFields) async {
    var box = await Hive.openBox('invoiceBox');
    if (box.containsKey(invoiceId)) {
      Map<String, dynamic> currentInvoice =
          box.get(invoiceId).cast<String, dynamic>();
      // Update fields
      currentInvoice.addAll(updatedFields);

      await box.put(invoiceId, currentInvoice);
    } else {}
  }

  void _applyDiscount(String discount) {
    final saleProvider =
        Provider.of<CurrentSaleProvider>(context, listen: false);
    setState(() {
      double discountValue = double.tryParse(discount) ?? 0.0;
      saleProvider.discountPercentage = discountValue;
      saleProvider
          .calculateTotal(); // Recalculate the total when discount is applied
      _updateBalance();
    });
  }

  // Method to calculate balance based on selected payment
  void _updateBalance() {
    // ignore: unused_local_variable
    final saleProvider =
        Provider.of<CurrentSaleProvider>(context, listen: false);

    // Convert the integer payment values to double explicitly
    double totalPayments =
        _cashAmount.toDouble() + _cardAmount.toDouble() + _upiAmount.toDouble();
    double totalCharges =
        (double.tryParse(_customChargeController.text) ?? 0.0);
    double discountValue =
        (double.tryParse(_discountController.text) ?? 0.0) / 100;

    setState(() {
      // Calculate the total after discount and charges
      double totalWithDiscount =
          (widget.totalAmount * (1 - discountValue)) + totalCharges;

      _balanceAmount = totalWithDiscount - totalPayments;

      // Print the currently selected payment option for debugging purposes

      // Update cash options based on the updated balance
      cashOptions.clear();
      cashOptions.addAll(_generateCashOptions(totalWithDiscount));

      // Avoid automatically updating other payment values when one is changed
      // Ensure that the balance calculation does not interfere with manual entries
      if (_selectedPaymentOptionVaule == "Cash") {
        _customCashController.text = _cashAmount.toString();
      } else if (_selectedPaymentOptionVaule == "Card") {
        _customCardController.text = _cardAmount.toString();
      } else if (_selectedPaymentOptionVaule == "Upi") {
        _customUpiController.text = _upiAmount.toString();
      }

      // Enable the print button if the balance is zero or negative
      // and if all required fields are filled
      _isPrintButtonEnabled = _balanceAmount <= 0 &&
          _employeeNumberController.text.isNotEmpty &&
          _customerNumberController.text.isNotEmpty;
    });
  }

  List<String> _generateCashOptions(double amount) {
    List<String> options = [];
    int exactAmount =
        amount.ceil(); // Ensure it covers the total even if it's a fraction
    options.add(exactAmount.toString()); // Add exact amount

    // Determine the next immediate round figure close to the exact amount
    int nextImmediateRound = (exactAmount % 50 == 0)
        ? exactAmount + 50
        : ((exactAmount / 50).ceil() * 50);
    options.add(nextImmediateRound.toString());

    // Determine a higher typical round figure
    int higherRoundFigure;
    if (nextImmediateRound % 100 == 0) {
      higherRoundFigure = nextImmediateRound + 100;
    } else {
      higherRoundFigure = ((nextImmediateRound / 100).ceil() * 100);
    }
    options.add(higherRoundFigure.toString());

    // Ensure we have exactly three distinct options (this is to handle edge cases where amounts could overlap)
    return options.toSet().toList();
  }

  void _showCustomKeyboard(TextEditingController controller) {
    showModalBottomSheet(
      barrierColor: Colors.transparent,
      context: context,
      builder: (context) {
        return CustomKeyboard(
          onTextInput: (value) {
            setState(() {
              controller.text += value;
            });
          },
          onBackspace: () {
            setState(() {
              if (controller.text.isNotEmpty) {
                controller.text =
                    controller.text.substring(0, controller.text.length - 1);
              }
            });
          },
          onClose: () {
            Navigator.pop(context);
          },
          onEnter: () {},
        );
      },
    );
  }

  void _selectPaymentOption(String method, String amount) {
    setState(() {
      _selectedPaymentOption = '$method: $amount';
      _selectedPaymentOptionVaule = method;

      int selectedAmount = int.tryParse(amount.replaceAll('', '')) ?? 0;
      // ignore: unused_local_variable
      double remainingAmount = (widget.totalAmount - selectedAmount).abs();

      switch (method) {
        case "Cash":
          _cashAmount = selectedAmount;
          _customCashController.text = selectedAmount.toString();
          break;
        case "Upi":
          _upiAmount = selectedAmount;
          _customUpiController.text = selectedAmount.toString();
          break;
        case "Card":
          _cardAmount = selectedAmount;
          _customCardController.text = selectedAmount.toString();
          break;
      }

      _updateBalance(); // Update balance dynamically based on the selection
    });
  }

  // Widget _buildPaymentOption(String amount, String method) {
  //   bool isSelected = _selectedPaymentOption == '$method: $amount';
  //   // Error handling for custom amount
  //   bool isError = false;
  //   if (amount == 'Custom' && _customAmountController.text.isNotEmpty) {
  //     double customAmount =
  //         double.tryParse(_customAmountController.text) ?? 0.0;
  //     isError = customAmount < widget.totalAmount;
  //   }

  //   if (amount == 'Custom') {
  //     return CustomSizedBox(
  //       width: 100,
  //       child: TextField(
  //         controller: _customAmountController,
  //         keyboardType: TextInputType.number, // Set system numeric keyboard
  //         readOnly: false, // Allow the system keyboard to open
  //         onChanged: (value) {
  //           _selectPaymentOption(method, amount);
  //         },
  //         decoration: InputDecoration(
  //           border: const OutlineInputBorder(),
  //           labelText: 'Custom',
  //           errorText: isError ? 'Amount exceeds total' : null,
  //           filled: isSelected,
  //           fillColor: isSelected ? Colors.white : Colors.white,
  //         ),
  //       ),
  //     );
  //   } else {
  //     return Padding(
  //       padding: const EdgeInsets.all(8.0),
  //       child: ElevatedButton(
  //         onPressed: () {
  //           _selectPaymentOption(method, amount);
  //         },
  //         style: ButtonStyle(
  //           backgroundColor: WidgetStateProperty.resolveWith<Color>(
  //               (states) => isSelected ? Colors.blue : Colors.white),
  //           foregroundColor: WidgetStateProperty.resolveWith<Color>(
  //               (states) => isSelected ? Colors.white : Colors.blue),
  //         ),
  //         child: CustomText(
  //           text: amount,
  //           style: const TextStyle(fontSize: 16),
  //         ),
  //       ),
  //     );
  //   }
  // }
  Widget _buildPaymentOption(String amount, String method) {
    bool isSelected = _selectedPaymentOption == '$method: $amount';
    TextEditingController controller;

    // Map controllers for each payment method
    switch (method) {
      case 'Cash':
        controller = _customCashController;
        break;
      case 'Upi':
        controller = _customUpiController;
        break;
      case 'Card':
        controller = _customCardController;
        break;
      default:
        controller = _customAmountController;
    }

    // Customizing the input field specifically for the cash custom option
    if (method == 'Cash' && amount == 'Custom') {
      return CustomSizedBox(
        width: 100,
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(
              decimal: true), // Allow decimal input
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: 'Custom Cash Amount', // Custom label for clarity
            filled: isSelected,
            fillColor: isSelected ? Colors.white : Colors.white,
          ),
          onChanged: (value) {
            // Update payment selection without restrictions
            _selectPaymentOption(method, value);
          },
        ),
      );
    } else if (method == 'Upi' && amount == 'Custom') {
      return CustomSizedBox(
        width: 100,
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(
              decimal: true), // Allow decimal input
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: 'Custom UPI Amount', // Custom label for clarity
            filled: isSelected,
            fillColor: isSelected ? Colors.white : Colors.white,
          ),
          onChanged: (value) {
            // Update payment selection without restrictions
            _selectPaymentOption(method, value);
          },
        ),
      );
    } else if (method == 'Card' && amount == 'Custom') {
      return CustomSizedBox(
        width: 100,
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(
              decimal: true), // Allow decimal input
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: 'Custom Card Amount', // Custom label for clarity
            filled: isSelected,
            fillColor: isSelected ? Colors.white : Colors.white,
          ),
          onChanged: (value) {
            // Update payment selection without restrictions
            _selectPaymentOption(method, value);
          },
        ),
      );
    } else if (amount == 'Custom') {
      return CustomSizedBox(
        width: 100,
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(
              decimal: true), // Allow decimal input
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: 'Custom Amount', // Custom label for clarity
            filled: isSelected,
            fillColor: isSelected ? Colors.white : Colors.white,
          ),
          onChanged: (value) {
            // Update payment selection without restrictions
            _selectPaymentOption(method, value);
          },
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: ElevatedButton(
          onPressed: () {
            _selectPaymentOption(method, amount);
          },
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith<Color>(
                (states) => isSelected ? Colors.blue : Colors.white),
            foregroundColor: WidgetStateProperty.resolveWith<Color>(
                (states) => isSelected ? Colors.white : Colors.blue),
          ),
          child: CustomText(
            text: amount,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      );
    }
  }

  Widget _buildPaymentSection(String method) {
    final saleProvider = Provider.of<CurrentSaleProvider>(context);
    List<String> options = cashOptions;
    if (method != 'Cash') {
      // Use the calculated total amount for UPI and Card
      options = [(saleProvider.calculateTotal().toStringAsFixed(0))];
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        CustomText(
          text: method,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        const CustomSizedBox(width: 20),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: _buildPaymentOption('Custom', method),
        ),
        for (var option in options) _buildPaymentOption(option, method),
        const Divider(),
      ],
    );
  }

  List<String> splitText(String text, int maxLineWidth) {
    List<String> lines = [];
    String remainingText = text;

    while (remainingText.length > maxLineWidth) {
      int lastIndex = remainingText.lastIndexOf(' ', maxLineWidth);
      if (lastIndex == -1) {
        // If no space is found, break at maxLineWidth
        lastIndex = maxLineWidth;
      }
      lines.add(remainingText.substring(0, lastIndex).trimRight());
      remainingText = remainingText.substring(lastIndex).trimLeft();
    }

    lines.add(remainingText);

    return lines;
  }

  bool _isSubmitting = false; // Track submission state
  void _printReceiptDetails() async {
    if (_isSubmitting) return; // Prevent double submission
    setState(() {
      _isSubmitting = true; // Lock the button to prevent multiple clicks
    });

    try {
      ReceiptPrinter printer = ReceiptPrinter(
        employeeNumberController: _selectedEmployeeFirstName.toString(),
        customerNumberController: _customerNumberController,
        discountController: _discountController,
        customChargeController: _customChargeController,
        selectedPaymentOptionValue: _selectedPaymentOptionVaule,
        totalAmount: widget.totalAmount,
        context: context,
        customAmountController: _customAmountController,
        selectedPaymentOption: _selectedPaymentOption,
        saveInvoiceToHiveAndPrint: saveInvoiceToHiveAndPrint1,
        discountAmount:
            roundedDiscountAmount, // Pass the rounded discount amount
        invoiceNo: invoiceNumber, // Pass the new invoice number
      );

      await printer.printReceiptDetails();
      setState(() {
        _isSubmitting = true; // Disable button after success
      });
    } catch (e) {
      setState(() {
        _isSubmitting = false; // Unlock the button if printing fails
      });
    }
  }

  bool get _showCakeFields {
    // Get the provider without listening for changes (or with listen: true if you want rebuilds)
    final saleProvider =
        Provider.of<CurrentSaleProvider>(context, listen: false);
    return saleProvider.currentSaleItems.any((item) {
      final data = item['itemData'];
      if (data == null) return false;
      final String category = data['category'] ?? '';
      return category == "Cake Icing" || category == "Cake Making";
    });
  }

  @override
  Widget build(BuildContext context) {
    final saleProvider = Provider.of<CurrentSaleProvider>(context);

    // Compute whether any item in the current sale has a category
    // of "Cake Icing" or "Cake Making".
    // ignore: unused_local_variable
    bool showCakeFields = saleProvider.currentSaleItems.any((item) {
      var data = item['itemData'];
      if (data == null) return false;
      String category = data['category'] ?? '';
      return category == "Cake Icing" || category == "Cake Making";
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: RepaintBoundary(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomText(
                  text: '₹${saleProvider.calculateTotal().toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const CustomSizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _employeeNumberController,
                            decoration: InputDecoration(
                              labelText: "Sales Person",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: Colors.blue, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 15,
                                horizontal: 10,
                              ),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _showEmployeeSuggestions = value.isNotEmpty;
                              });
                            },
                          ),
                          if (_showEmployeeSuggestions) // Show dropdown if suggestions are available
                            Container(
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _employeeSuggestions.length,
                                itemBuilder: (context, index) {
                                  // Extract the 'name' field from the map
                                  final employee = _employeeSuggestions[index];

                                  return ListTile(
                                    title: Text(
                                        '${employee['employeeNumber']} - ${employee['firstName']}'),
                                    onTap: () => _selectEmployee(employee),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 40),
                    Flexible(
                      child: TextField(
                        keyboardType: TextInputType.number,
                        controller: _customerNumberController,
                        inputFormatters: [
                          CustomNumberInputFormatter(), // Custom input formatter
                        ],
                        decoration: InputDecoration(
                          labelText: "Customer Mobile Numbers",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                BorderSide(color: Colors.blue, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 15,
                            horizontal: 10,
                          ),
                        ),
                        onChanged: (value) {
                          _validateForm(); // Call validate form on each input change
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 10,
                ),
                if (_showCakeFields)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          controller: _discountController,
                          inputFormatters: [
                            FilteringTextInputFormatter
                                .digitsOnly, // Allows only digits
                          ],
                          decoration: InputDecoration(
                            labelText: "Customer Name",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.blue, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 15,
                              horizontal: 10,
                            ),
                          ),
                          onChanged: (value) {
                            if (value.length > 2) {
                              // Prevent clearing and limit to 2 digits
                              _discountController.text = value.substring(0, 2);
                              _discountController.selection =
                                  TextSelection.fromPosition(
                                TextPosition(
                                    offset: _discountController.text.length),
                              );
                            }
                            _applyDiscount(_discountController
                                .text); // Apply discount and update total
                          },
                        ),
                      ),
                      const SizedBox(width: 40),
                      Flexible(
                        child: TextField(
                          controller:
                              _birthdayController, // Declare this controller in your widget's state.
                          readOnly:
                              true, // Make it read-only so the user can't type manually.
                          decoration: InputDecoration(
                            labelText: "Birthday Date",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.blue, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 15,
                              horizontal: 10,
                            ),
                          ),
                          onTap: () async {
                            // Show the date picker when the user taps on the field.
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedBirthday ??
                                  DateTime
                                      .now(), // Use current date if none selected.
                              firstDate: DateTime(1900),
                              lastDate: DateTime.now(),
                              builder: (context, child) {
                                // Optionally, customize the date picker theme.
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: Colors
                                          .blue, // header background color
                                      onPrimary:
                                          Colors.white, // header text color
                                      onSurface:
                                          Colors.black, // body text color
                                    ),
                                    dialogBackgroundColor: Colors.white,
                                  ),
                                  child: child!,
                                );
                              },
                            );

                            // If a date is picked, update the state and display the formatted date.
                            if (picked != null) {
                              setState(() {
                                _selectedBirthday = picked;
                                _birthdayController.text =
                                    DateFormat('dd-MM-yyyy').format(picked);
                              });
                            }
                          },
                        ),
                      )
                    ],
                  ),
                const SizedBox(
                  height: 10,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: TextField(
                        keyboardType: TextInputType.number,
                        controller: _discountController,
                        inputFormatters: [
                          FilteringTextInputFormatter
                              .digitsOnly, // Allows only digits
                        ],
                        decoration: InputDecoration(
                          labelText: "Discount",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                BorderSide(color: Colors.blue, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 15,
                            horizontal: 10,
                          ),
                        ),
                        onChanged: (value) {
                          if (value.length > 2) {
                            // Prevent clearing and limit to 2 digits
                            _discountController.text = value.substring(0, 2);
                            _discountController.selection =
                                TextSelection.fromPosition(
                              TextPosition(
                                  offset: _discountController.text.length),
                            );
                          }
                          _applyDiscount(_discountController
                              .text); // Apply discount and update total
                        },
                      ),
                    ),
                    const SizedBox(width: 40),
                    Flexible(
                      child: TextField(
                        keyboardType: TextInputType.number,
                        controller: _customChargeController,
                        inputFormatters: [
                          FilteringTextInputFormatter
                              .digitsOnly, // Allows only digits
                        ],
                        decoration: InputDecoration(
                          labelText: "Custom Charge",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                BorderSide(color: Colors.blue, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 15,
                            horizontal: 10,
                          ),
                        ),
                        onChanged: (value) {
                          double charge =
                              double.tryParse(_customChargeController.text) ??
                                  0.0;
                          Provider.of<CurrentSaleProvider>(context,
                                  listen: false)
                              .customCharge = charge;
                          _updateBalance(); // Recalculate balance whenever custom charge changes
                        },
                      ),
                    )
                  ],
                ),
                const CustomSizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.only(left: 110),
                  child: _buildPaymentSection('Cash'),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 120),
                  child: _buildPaymentSection('Upi'),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 110),
                  child: _buildPaymentSection('Card'),
                ),
                const CustomSizedBox(height: 10),
                const CustomText(text: "Balance Amount"),
                CustomText(
                  text: _balanceAmount.abs().toStringAsFixed(0),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const CustomSizedBox(height: 10),
                ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all<Color>(
                      (_selectedEmployeeFirstName != null &&
                              _customerNumberController.text.length == 10)
                          ? Colors.blue
                          : Colors.grey,
                    ), // Button is blue if both conditions are true, grey otherwise
                    foregroundColor: WidgetStateProperty.all<Color>(
                        Colors.white), // Text color
                    padding: WidgetStateProperty.all<EdgeInsets>(
                      const EdgeInsets.symmetric(
                          horizontal: 30.0, vertical: 18.0), // Padding
                    ),
                    shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                      RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(8.0), // Rounded corners
                      ),
                    ),
                    elevation:
                        WidgetStateProperty.all<double>(5.0), // Elevation
                  ),
                  onPressed: (_selectedEmployeeFirstName != null &&
                          _customerNumberController.text.length == 10)
                      ? _printReceiptDetails
                      : null, // Enable the button only when both conditions are true
                  child: const CustomText(
                    text: "Print Receipt",
                    style: TextStyle(
                      fontSize: 16, // Font size
                      fontWeight: FontWeight.bold, // Font weight
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

// Widget for displaying employee suggestions dropdown
  Widget _buildEmployeeSuggestionsDropdown() {
    return Container(
      height: 200, // Set a fixed height for the dropdown
      color: Colors.white,
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _employeeSuggestions.length,
        itemBuilder: (context, index) {
          final employee = _employeeSuggestions[index];
          return ListTile(
            title: Text(
                '${employee['employeeNumber']} - ${employee['firstName']}'),
            onTap: () => _selectEmployee(employee),
          );
        },
      ),
    );
  }
}

class CustomNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final regExp =
        RegExp(r'^[6-9][0-9]{0,9}$'); // Starts with 6-9, up to 10 digits

    // Check if the new value is empty to allow clearing the input
    if (newValue.text.isEmpty) {
      return newValue;
    }

    if (regExp.hasMatch(newValue.text)) {
      // Valid input
      return newValue;
    } else if (newValue.text.length > 10) {
      // If the input exceeds 10 digits, return old value
      return oldValue;
    }

    // Revert to the old value if invalid input
    return oldValue;
  }
}

class InvoiceNumberGenerator {
  Box<dynamic>? _invoiceBox;
  final String _prefix = "BM/AR/01/SI";

  // Ensures the invoice box is open for access
  Future<Box<dynamic>> get _getInvoiceBox async {
    _invoiceBox ??= await Hive.openBox('invoiceData');
    return _invoiceBox!;
  }

  /// Retrieves the current count of invoices for the current year and increments it
  Future<int> _getCurrentYearInvoiceCount() async {
    var now = DateTime.now();
    String year =
        DateFormat('yy').format(now); // Use intl to format the year as 'yyyy'
    var box = await _getInvoiceBox;
    String yearKey = 'invoiceCount_$year';
    int currentCount = box.get(yearKey, defaultValue: 0);
    await box.put(
        yearKey, currentCount + 1); // Increment the count for this year
    return currentCount + 1; // Return the new count
  }

  /// Generates a new invoice number automatically using the current year formatted with intl
  Future<String> generateInvoiceNumber() async {
    var now = DateTime.now();
    String year = DateFormat('yy').format(now); // Format year as 'yyyy'
    int count = await _getCurrentYearInvoiceCount();
    String countStr = count
        .toString()
        .padLeft(4, '0'); // Ensure the count is at least four digits
    return '$_prefix/$year/$countStr';
  }
}
