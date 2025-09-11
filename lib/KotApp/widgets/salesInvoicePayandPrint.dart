import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../kotproviders/login_provider.dart';
import '../screens/cancelqty_validator.dart';
import '../screens/table_screen.dart';
import '../kotservices/invoiceReceipt utility.dart';

import 'package:provider/provider.dart';
import 'package:web_socket_channel/io.dart';

import '../kotservices/invoiceReceipt.dart';

import '../models/fetchDiningTax.dart';
import '../../../screens/kot_screen/global/globals.dart';
import '../kotproviders/bottomNavprovider.dart';
import '../kotproviders/order_provider.dart';
import '../kotproviders/printer_provider.dart';
import 'bottomNav.dart';
import 'globalAppbar.dart';

class SalesInvoicePayAndPrint extends StatefulWidget {
  final double totalAmount;
  final List<Map<String, dynamic>> items; // Add items list
  final String branchName; // Add branch name
  final String deviceCode; // Add deviceCode parameter

  const SalesInvoicePayAndPrint({
    Key? key,
    required this.totalAmount,
    required this.items, // Define the items parameter here
    required this.branchName,
    required this.deviceCode,
  }) : super(key: key);

  @override
  State<SalesInvoicePayAndPrint> createState() =>
      _SalesInvoicePayAndPrintState();
}

class _SalesInvoicePayAndPrintState extends State<SalesInvoicePayAndPrint> {
  final TextEditingController _employeeNumberController =
      TextEditingController();
  final TextEditingController _customerNumberController =
      TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _customChargeController = TextEditingController();
  final TextEditingController _customCashController = TextEditingController();
  double _balanceAmount = 0.0;
  bool isSubmitting = false;
  int _cashAmount = 0;
  int _cardAmount = 0;
  int _upiAmount = 0;

  IOWebSocketChannel? _channel; // Declare channel here

  @override
  void initState() {
    super.initState();
    _balanceAmount = widget.totalAmount;

    // Initialize controller values if applicable
    if (widget.items.isNotEmpty && widget.items.first.containsKey('waiter')) {
      _employeeNumberController.text = widget.items.first['waiter'] ?? '';
    }
    if (widget.items.isNotEmpty &&
        widget.items.first.containsKey('customerPhoneNumber')) {
      _customerNumberController.text =
          widget.items.first['customerPhoneNumber'] ?? '';
    }
  }

  @override
  void dispose() {
    // Dispose all controllers
    _employeeNumberController.dispose();
    _customerNumberController.dispose();
    _discountController.dispose();
    _customChargeController.dispose();
    _customCashController.dispose();

    _channel?.sink.close();

    super.dispose();
  }

  void _sendInvoiceDataToServer() async {

    final loginProvider = Provider.of<LoginProvider>(context, listen: false);
    final loggedInUserName = loginProvider.loggedInUserName ?? "";
    // Initialize a map to hold grouped items by `varianceName`
    double diningTaxPercentage = getTaxPercentage();

    Map<String, Map<String, dynamic>> groupedItems = {};
    List<Map<String, dynamic>> kotAddOns =
        []; // List to hold the extracted config

    // Process each item in `widget.items`
    for (var item in widget.items) {
      // Validate the item
      if (item.isEmpty) {
        continue;
      }
      // Process each varianceName in the item
      for (int i = 0; i < (item['varianceName']?.length ?? 0); i++) {
        String variance = item['varianceName']?[i] ?? "";

        // If the variance does not exist, initialize it
        if (!groupedItems.containsKey(variance)) {
          groupedItems[variance] = {
            "varianceName": variance,
            "itemName": item['itemName']?[i] ?? "",
            "price": item['price']?[i] ?? 0.0,
            "qty": 0.0,
            "weight": 0.0,
            "amount": 0.0,
            "tax": diningTaxPercentage,
            "uom": item['uom']?[i] ?? "",
          };
        }

        // Aggregate quantities, weights, amounts, and tax
        groupedItems[variance]!['qty'] += item['qty']?[i] ?? 0.0;
        groupedItems[variance]!['weight'] += item['weight']?[i] ?? 0.0;
        groupedItems[variance]!['amount'] += item['amount']?[i] ?? 0.0;
        // Extract config data and store in kotAddOns
        // Extract config data and store in kotAddOns
        // Extract config data and store in kotAddOns
        if (item.containsKey('config') && item['config'] != null) {
          for (var configItem in item['config']) {
            String varianceName = configItem['varianceName'] ?? "";

            // Avoid duplicate config entries
            bool isAlreadyAdded = kotAddOns.any((existingConfig) =>
                existingConfig["varianceName"] == varianceName &&
                existingConfig["configQty"].toString() ==
                    configItem["configQty"].toString());

            if (!isAlreadyAdded) {
              kotAddOns.add({
                "varianceName": varianceName,
                "weight": configItem['weight'] ?? 0,
                "configQty": List.from(configItem['configQty'] ??
                    []), // Ensure lists are copied correctly
                "addOn": List.from(configItem['addOn'] ?? []),
                "addOnPrice": List.from(configItem['addOnPrice'] ?? []),
                "variance": List.from(configItem['variance'] ?? []),
                "type": List.from(configItem['type'] ?? []),
                "remark": List.from(configItem['remark'] ?? []),
              });
            }
          }
        }
      }
    }

    // Prepare the invoice data
    Map<String, dynamic> invoiceData = {
      "type": "invoice",
      "seathiveOrderId": widget.items.first['seathiveOrderId'] ?? "",
      "varianceName": groupedItems.keys.toList(),
      "itemName": groupedItems.values.map((item) => item['itemName']).toList(),
      "price": groupedItems.values.map((item) => item['price']).toList(),
      "qty": groupedItems.values.map((item) => item['qty']).toList(),
      "weight": groupedItems.values.map((item) => item['weight']).toList(),
      "amount": groupedItems.values.map((item) => item['amount']).toList(),
      "tax": groupedItems.values.map((item) => item['tax']).toList(),
      "uom": groupedItems.values.map((item) => item['uom']).toList(),
      "totalAmount": widget.totalAmount,
      // "paymentType": _determinePaymentType(),
      "cash": _cashAmount > 0 ? _cashAmount : 0,
      "upi": _upiAmount > 0 ? _upiAmount : 0,
      "card": _cardAmount > 0 ? _cardAmount : 0,
      "invoiceDate": DateFormat('dd-MM-yyyy').format(DateTime.now()),
      "invoiceTime": DateFormat('hh:mm a').format(DateTime.now()),
      "deviceCode": widget.deviceCode,
      "branchId": branchId,
      "branchName": widget.branchName,
      "employeeNumber": _employeeNumberController.text.trim(),
      "customerNumber": _customerNumberController.text.trim(),
      // "user": loggedInUserName,
      "sync": "No",
      "salesType": ordertype,
      "kotaddOns": kotAddOns, // Include the extracted config as kotAddOns
    };
    // Validate the final invoice data
    if (invoiceData['totalAmount'] <= 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Invalid invoice data, total amount is zero.")),
      );
      return;
    }

    // Send the invoice data to the server
    try {
      final channel = IOWebSocketChannel.connect('ws://$serverip:$port');

      final serializedData = jsonEncode(invoiceData);
      channel.sink.add(serializedData);

      channel.stream.listen((message) {
      });
    } catch (e) {
    }
  }

  String _determinePaymentType() {
    if (_cashAmount > 0) return "Cash";
    if (_cardAmount > 0) return "Card";
    if (_upiAmount > 0) return "UPI";
    return "Others";
  }

  void _updateBalance() {
    setState(() {
      // Calculate balance by subtracting cash, card, and UPI amounts
      _balanceAmount =
          widget.totalAmount - _cashAmount - _cardAmount - _upiAmount;

      // If only UPI or Card is causing a negative balance, set balance to zero

      if ((_balanceAmount < 0) && (_upiAmount > 0 || _cardAmount > 0)) {
        _balanceAmount = 0;
      }
    });
  }

  // Avoid loops where unnecessary
  List<String> _generateCashOptions(double amount) {
    final int exactAmount = amount.ceil();
    final List<int> options = [
      exactAmount,
      (exactAmount + 50),
      (exactAmount + 100)
    ];
    return options.map((opt) => opt.toString()).toList();
  }

  // Clear payment-related state to release memory
  void _resetPaymentState() {
    _cashAmount = 0;
    _cardAmount = 0;
    _upiAmount = 0;
    _customCashController.clear();
    _balanceAmount = widget.totalAmount;
    setState(() {});
  }

  void _selectPaymentOption(String method, int amount) {
    setState(() {
      if (method == "Cash") {
        _cashAmount = amount;
      } else if (method == "Card") {
        _cardAmount = amount;
      } else if (method == "Upi") {
        _upiAmount = amount;
      }
      _updateBalance();
    });
  }

  Widget _build3DButton(String method, int amount) {
    bool isSelected = (_cashAmount == amount && method == 'Cash') ||
        (_cardAmount == amount && method == 'Card') ||
        (_upiAmount == amount && method == 'Upi');

    return GestureDetector(
      onTap: () => _selectPaymentOption(method, amount),
      child: Container(
        margin: const EdgeInsets.all(8.0),
        padding: EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(colors: [Colors.green[300]!, Colors.green[100]!])
              : LinearGradient(colors: [Colors.grey[300]!, Colors.grey[100]!]),
          borderRadius: BorderRadius.circular(8.0),
          boxShadow: [
            BoxShadow(
              color: Colors.grey[400]!,
              offset: const Offset(4, 4),
              blurRadius: 8,
            ),
            const BoxShadow(
              color: Colors.white,
              offset: Offset(-4, -4),
              blurRadius: 8,
            ),
          ],
        ),
        child: Text(
          '₹$amount',
          style: TextStyle(
            //  fontSize: 18,
            color: isSelected ? Colors.black : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomCashField() {
    return Container(
      margin: const EdgeInsets.all(8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey[400]!,
            offset: const Offset(4, 4),
            blurRadius: 8,
          ),
          const BoxShadow(
            color: Colors.white,
            offset: Offset(-4, -4),
            blurRadius: 8,
          ),
        ],
      ),
      child: SizedBox(
        width: 70,
        height: 31,
        child: TextField(
          controller: _customCashController,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
            NoLeadingZeroAndZeroTextInputFormatter(),
          ],
          decoration: InputDecoration(
            hintText: "Custom",
            contentPadding:
                const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5.0), // Rounded corners
              borderSide: const BorderSide(
                color: Colors.grey, // Border color
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(5.0), // Rounded corners when focused
              // borderSide: const BorderSide(
              //   width: 2.0, // Border width when focused
              // ),
            ),
          ),
          onChanged: (value) {
            int customAmount = int.tryParse(value) ?? 0;
            setState(() {
              if (customAmount > 0) {
                _cashAmount = customAmount;
              } else {
                _cashAmount = 0;
              }
              _updateBalance();
            });
          },
        ),
      ),
    );
  }

  Widget _buildPaymentOptions(String method) {
    double padding = MediaQuery.of(context).size.width * 0.04;

    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: padding / 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "$method Payment",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: method == 'Cash'
                          ? [
                              ..._generateCashOptions(widget.totalAmount).map(
                                  (option) => _build3DButton(
                                      method, int.parse(option))),
                              _buildCustomCashField(),
                            ]
                          : [(_balanceAmount).ceil()]
                              .map((option) => _build3DButton(method, option))
                              .toList(),
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

  Widget _buildPaymentOptionsRow() {
    double padding = MediaQuery.of(context).size.width * 0.04;

    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: padding / 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "UPI",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Text(
                          //   '₹${_upiAmount.toStringAsFixed(0)}', // Display UPI value
                          //   style: const TextStyle(
                          //       fontSize: 16, fontWeight: FontWeight.bold),
                          // ),
                          const SizedBox(width: 8),
                          _build3DButton("Upi", (_balanceAmount).ceil()),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Card",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Text(
                          //   '₹${_cardAmount.toStringAsFixed(0)}', // Display Card value
                          //   style: const TextStyle(
                          //       fontSize: 16, fontWeight: FontWeight.bold),
                          // ),
                          const SizedBox(width: 8),
                          _build3DButton("Card", (_balanceAmount).ceil()),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double padding = MediaQuery.of(context).size.width * 0.04;
    final printerProvider = Provider.of<PrinterProvider>(context);
    // final saleProvider = Provider.of<CurrentSaleProvider>(context);

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: const GlobalAppBar(
        title: "KOT Invoice payment ",
        elevation: 0,
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: padding),
        child: ListView(
          children: [
            Container(
              margin: EdgeInsets.symmetric(vertical: padding / 2),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[100]!, Colors.green[300]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey[400]!,
                    offset: const Offset(6, 6),
                    blurRadius: 12,
                  ),
                  const BoxShadow(
                    color: Colors.white,
                    offset: Offset(-6, -6),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  children: [
                    const Text(
                      'Total Amount',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: Colors.black),
                    ),
                    Text(
                      '₹${widget.totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              margin: EdgeInsets.symmetric(vertical: padding / 2),
              padding: EdgeInsets.all(padding),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey[400]!,
                    offset: const Offset(6, 6),
                    blurRadius: 12,
                  ),
                  const BoxShadow(
                    color: Colors.white,
                    offset: Offset(-6, -6),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _employeeNumberController,
                          decoration: InputDecoration(
                            labelText: "Employee",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                          enabled: false, // Disables the text field
                          style: const TextStyle(
                              color: Colors.grey), // Optional: Grey text color
                        ),
                      ),
                      SizedBox(width: padding),
                      Expanded(
                        child: TextField(
                          controller: _customerNumberController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "Customer Number",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter
                                .digitsOnly, // Allows only digits
                            LengthLimitingTextInputFormatter(
                                10), // Limits the input to 10 digits
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  // Row(
                  //   children: [
                  //     Expanded(
                  //       child: TextField(
                  //         controller: _discountController,
                  //         decoration: const InputDecoration(
                  //           labelText: "Discount",
                  //         ),
                  //         onChanged: (value) {
                  //           // Update discount percentage
                  //           saleProvider.discountPercentage =
                  //               double.tryParse(value) ?? 0.0;
                  //         },
                  //       ),
                  //     ),
                  //     SizedBox(width: padding),
                  //     Expanded(
                  //       child: TextField(
                  //         controller: _customChargeController,
                  //         decoration: const InputDecoration(
                  //           labelText: "Custom Charge",
                  //         ),
                  //       ),
                  //     ),
                  //   ],
                  // ),
                ],
              ),
            ),
            _buildPaymentOptions('Cash'),
            _buildPaymentOptionsRow(), // Combine UPI and Card in a single row

            Container(
              margin: EdgeInsets.symmetric(vertical: padding / 2),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey[400]!,
                    offset: const Offset(6, 6),
                    blurRadius: 12,
                  ),
                  const BoxShadow(
                    color: Colors.white,
                    offset: Offset(-6, -6),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  children: [
                    const Text(
                      "Balance Amount",
                      style: TextStyle(fontSize: 18),
                    ),
                    Text(
                      '₹${_balanceAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black),
                    ),
                    const SizedBox(height: 5),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[400],

                        padding: const EdgeInsets.symmetric(
                            horizontal: 16 * 2,
                            vertical: 16 * 1.5), // Use actual padding value
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: (isSubmitting || _balanceAmount > 0)
                          ? null // Disable if submitting or balance amount is positive
                          : () async {
                              setState(() {
                                isSubmitting = true; // Disable the button
                              });

                              var printerIp = Provider.of<PrinterProvider>(
                                      context,
                                      listen: false)
                                  .getInvoicePrinterIp();

                              if (printerIp == null) {
                                invoicePromptForPrinterIp(context);
                                // Re-check after potentially setting the IP
                                printerIp = Provider.of<PrinterProvider>(
                                        context,
                                        listen: false)
                                    .getInvoicePrinterIp();
                                if (printerIp == null) {
                                  return; // Exit if still not set to avoid proceeding without a printer IP
                                }
                              }
                              try {
                                // if (_customerNumberController.text
                                //     .trim()
                                //     .isEmpty) {
                                //   ScaffoldMessenger.of(context).showSnackBar(
                                //     const SnackBar(
                                //       content: Text(
                                //           'Please enter the Customer Number!'),
                                //       backgroundColor:
                                //           Color.fromARGB(255, 183, 84, 77),
                                //     ),
                                //   );
                                //   return; // Exit the function if validation fails
                                // }

                                final printerProvider =
                                    Provider.of<PrinterProvider>(context,
                                        listen: false);
                                final orderProvider =
                                    Provider.of<OrderProvider>(context,
                                        listen: false);
                                _sendInvoiceDataToServer();
                                String seathiveOrderId =
                                    widget.items.first['seathiveOrderId'] ?? '';
                                if (seathiveOrderId.isNotEmpty) {
                                  await orderProvider
                                      .patchOrderStatusBySeathiveOrderId(
                                          seathiveOrderId, 'invoiced');
                                }

                                // ignore: use_build_context_synchronously
                                ReceiptPrinter(
                                  employeeNumberController:
                                      _employeeNumberController,
                                  seathiveOrderId: seathiveOrderId,
                                  customerNumberController:
                                      _customerNumberController,
                                  discountController: _discountController,
                                  customChargeController:
                                      _customChargeController,
                                  selectedPaymentOptionValue:
                                      '', // Add appropriate payment option if needed
                                  // totalAmount: widget.totalAmount,
                                  context: context,
                                  customAmountController: _customCashController,
                                  selectedPaymentOption: 'Cash',
                                  items: widget.items, // Pass the list of items
                                  branchName: widget.branchName,
                                  printerProvider:
                                      printerProvider, // Pass the printer provider
                                ).printReceiptDetails(); // Call the print method directly

                                // ignore: use_build_context_synchronously
                                Provider.of<BottomNavProvider>(context,
                                        listen: false)
                                    .updateIndex(0);
                                // ignore: use_build_context_synchronously
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const TableScreen()),
                                  (Route<dynamic> route) =>
                                      false, // Removes all previous routes
                                );
                              } catch (e) {
                                // Handle errors here if needed
                              } finally {
                                setState(() {
                                  isSubmitting =
                                      false; // Re-enable the button after completion
                                });
                              }
                            },
                      child: Text(
                        isSubmitting
                            ? "Processing..." // Optional: Change text during submission
                            : "Print Receipt",
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black),
                      ),
                    ),

                    // ElevatedButton(
                    //   style: ElevatedButton.styleFrom(
                    //     backgroundColor: Colors.green[300],
                    //     // ignore: prefer_const_constructors
                    //     padding: EdgeInsets.symmetric(
                    //         horizontal: 16 * 2,
                    //         vertical: 16 * 1.5), // Use actual padding value
                    //     shape: RoundedRectangleBorder(
                    //       borderRadius: BorderRadius.circular(12),
                    //     ),
                    //   ),
                    //   onPressed: isSubmitting
                    //       ? null // Disable the button if already submitting
                    //       : () async {
                    //           setState(() {
                    //             isSubmitting = true; // Disable the button
                    //           });
                    //           try {
                    //             if (_balanceAmount == 0) {
                    //               if (_customerNumberController.text
                    //                   .trim()
                    //                   .isEmpty) {
                    //                 ScaffoldMessenger.of(context).showSnackBar(
                    //                   const SnackBar(
                    //                     content: Text(
                    //                         'Please enter the Customer Number!'),
                    //                     backgroundColor:
                    //                         Color.fromARGB(255, 183, 84, 77),
                    //                   ),
                    //                 );
                    //                 return; // Exit the function if validation fails
                    //               }
                    //               final printerProvider =
                    //                   Provider.of<PrinterProvider>(
                    //                 context,
                    //                 listen: false,
                    //               );
                    //               final orderProvider =
                    //                   Provider.of<OrderProvider>(
                    //                 context,
                    //                 listen: false,
                    //               );
                    //               print("invoice items:${widget.items.length}");

                    //               _sendInvoiceDataToServer();
                    //               String seathiveOrderId =
                    //                   widget.items.first['seathiveOrderId'] ??
                    //                       '';
                    //               ReceiptPrinter(
                    //                 employeeNumberController:
                    //                     _employeeNumberController,
                    //                 seathiveOrderId: seathiveOrderId,
                    //                 customerNumberController:
                    //                     _customerNumberController,
                    //                 discountController: _discountController,
                    //                 customChargeController:
                    //                     _customChargeController,
                    //                 selectedPaymentOptionValue:
                    //                     '', // Add appropriate payment option if needed
                    //                 totalAmount: widget.totalAmount,
                    //                 context: context,
                    //                 customAmountController:
                    //                     _customCashController,
                    //                 selectedPaymentOption: 'Cash',
                    //                 items:
                    //                     widget.items, // Pass the list of items
                    //                 branchName: widget.branchName,
                    //                 printerProvider:
                    //                     printerProvider, // Pass the printer provider
                    //               ).printReceiptDetails(); // Call the print method directly

                    //               if (seathiveOrderId.isNotEmpty) {
                    //                 await orderProvider
                    //                     .patchOrderStatusBySeathiveOrderId(
                    //                         seathiveOrderId, 'invoiced');
                    //               }
                    //               Provider.of<BottomNavProvider>(context,
                    //                       listen: false)
                    //                   .updateIndex(0);

                    //               Navigator.of(context).push(
                    //                 MaterialPageRoute(
                    //                   builder: (context) => TableScreen(),
                    //                 ),
                    //               );
                    //             } else {
                    //               ScaffoldMessenger.of(context).showSnackBar(
                    //                 SnackBar(
                    //                   content: Text(
                    //                       'Balance remaining: ₹${_balanceAmount.toStringAsFixed(0)}'),
                    //                 ),
                    //               );
                    //             }
                    //           } catch (e) {
                    //             // Handle errors here if needed
                    //           } finally {
                    //             setState(() {
                    //               isSubmitting =
                    //                   false; // Re-enable the button after completion
                    //             });
                    //           }
                    //         },
                    //   child: Text(
                    //     isSubmitting
                    //         ? "Processing..." // Optional: Change text during submission
                    //         : "Print Receipt",
                    //     style: const TextStyle(
                    //         fontSize: 18,
                    //         fontWeight: FontWeight.bold,
                    //         color: Colors.black),
                    //   ),
                    // ),
                    const SizedBox(height: 5),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: SizedBox(
        width: 40,
        height: 40,
        child: FloatingActionButton(
          backgroundColor: Colors.blue[100],
          onPressed: _resetPaymentState,
          tooltip: "Reset Payment", // Call reset method
          child: const Icon(Icons.refresh),
        ),
      ),
      //bottomNavigationBar: const GlobalBottomNav(),
    );
  }
}
