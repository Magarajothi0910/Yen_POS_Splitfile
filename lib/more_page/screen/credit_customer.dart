import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:yenposapp/Sale_order/Print_Receipt/salesInvoicePayandPrint.dart';
import 'package:yenposapp/Sale_order/Widgets/search_drop_filed.dart';

import '../../Global/Widget/custom_sized_box.dart';
// import '../../../Global/search_drop_filed.dart';

import 'credit_salesorder_pre_invoice.dart';

class CreditCustomerPage extends StatefulWidget {
  @override
  _CreditCustomerPageState createState() => _CreditCustomerPageState();
}

class _CreditCustomerPageState extends State<CreditCustomerPage> {
  List<Map<String, dynamic>> creditBills = [];
  List<Map<String, dynamic>> filteredBills = [];
  List<Map<String, dynamic>> filteredBills2 = []; // Store data from apiUrl2
  bool showCreditSalesInvoice = false; // Track Credit Sales Invoice view
  List<Map<String, dynamic>> creditSalesInvoices = []; // Store fetched data

  bool showPreInvoice = true; // Track which page to display
  Map<String, dynamic>? selectedBill; // Track the selected bill
  String searchQuery = ''; // Search query
  DateTime? startDate;
  DateTime? endDate;
  String selectedOption = 'Overall Credit Orders'; // Default selected option
  List<Map<String, dynamic>> selectedBills = [];
  Map<String, double> totalsByDate = {};
  Map<String, double> totalsByCustomer = {};
  List<Map<String, dynamic>> staticItems = [
    {'id': 1, 'name': 'Item 1', 'price': 50.0, 'quantity': 1},
    {'id': 2, 'name': 'Item 2', 'price': 100.0, 'quantity': 1},
    {'id': 3, 'name': 'Item 3', 'price': 200.0, 'quantity': 1},
  ];

  List<Map<String, dynamic>> cart = [];
  double totalAmount = 0.0;

  Future<void> fetchCreditSalesInvoices() async {
    const apiUrl = 'https://yenerp.com/fastapi/creditbills/';

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        setState(() {
          creditSalesInvoices = List<Map<String, dynamic>>.from(data);
        });
      } else {}
    } catch (error) {}
  }

  Future<void> fetchCreditBills(
      {String? customerNumber, DateTime? startDate, DateTime? endDate}) async {
    // Define both API URLs
    var apiUrl1 =
        'https://yenerp.com/fastapi/salesorders/?filter-credit-customer=true';
    var apiUrl2 =
        'https://yenerp.com/fastapi/salesorders/?filter-credit-customer=false&filter-credit-customer-preinvoice=true';

    // Append customer number if it is not null to both API URLs
    if (customerNumber != null && customerNumber.isNotEmpty) {
      apiUrl1 += '&customerNumber=$customerNumber';
      apiUrl2 += '&customerNumber=$customerNumber';
    }

    // Create a DateFormatter
    DateFormat dateFormat = DateFormat('dd-MM-yyyy');

    // Append start date in 'DD-MM-YYYY' format if it is not null to both API URLs
    if (startDate != null) {
      String formattedStartDate = dateFormat.format(startDate);
      apiUrl1 += '&deliveryStartDate=$formattedStartDate';
      apiUrl2 += '&deliveryStartDate=$formattedStartDate';
    }

    // Append end date in 'DD-MM-YYYY' format if it is not null to both API URLs
    if (endDate != null) {
      String formattedEndDate = dateFormat.format(endDate);
      apiUrl1 += '&deliveryEndDate=$formattedEndDate';
      apiUrl2 += '&deliveryEndDate=$formattedEndDate';
    }

    try {
      // Fetch data from both APIs concurrently
      final response1 = await http.get(Uri.parse(apiUrl1));
      final response2 = await http.get(Uri.parse(apiUrl2));

      if (response1.statusCode == 200 && response2.statusCode == 200) {
        final List<dynamic> data1 = json.decode(response1.body);
        final List<dynamic> data2 = json.decode(response2.body);

        // Update state with the fetched data
        setState(() {
          creditBills = List<Map<String, dynamic>>.from(data1);
          filteredBills = creditBills;
          filteredBills2 =
              List<Map<String, dynamic>>.from(data2); // Store data from apiUrl2
        });
      } else {}
    } catch (error) {}
  }

  void applyFilters() {
    setState(() {
      filteredBills = creditBills.where((bill) {
        final matchesSearch = bill['customerName']
                ?.toString()
                .toLowerCase()
                .contains(searchQuery.toLowerCase()) ??
            false;

        final matchesDate = () {
          if (startDate != null && endDate != null) {
            DateTime? deliveryDate = bill['deliveryDate'] != null
                ? DateTime.tryParse(bill['deliveryDate'])
                : null;
            if (deliveryDate != null) {
              return deliveryDate.isAfter(startDate!) &&
                  deliveryDate.isBefore(endDate!);
            }
            return false;
          }
          return true;
        }();

        return matchesSearch && matchesDate;
      }).toList();
    });
  }

  Future<void> selectStartDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != startDate) {
      setState(() {
        startDate = picked;
      });
      fetchCreditBills(
          customerNumber: searchQuery,
          startDate: startDate,
          endDate: endDate); // Update API call
    }
  }

  Future<void> selectEndDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != endDate) {
      setState(() {
        endDate = picked;
      });
      fetchCreditBills(
          customerNumber: searchQuery,
          startDate: startDate,
          endDate: endDate); // Update API call
    }
  }

  @override
  void initState() {
    fetchCreditBills();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ToggleButtons(
              borderRadius: BorderRadius.circular(8),
              selectedBorderColor: Colors.blue,
              selectedColor: Colors.blue,
              fillColor: Colors.blueAccent.withOpacity(0.2),
              color: Colors.black,
              borderColor: Colors.grey[300],
              constraints: BoxConstraints(minHeight: 40, minWidth: 240),
              isSelected: [showPreInvoice, !showPreInvoice, !showPreInvoice],
              onPressed: (int index) {
                setState(() {
                  if (index == 0) {
                    showPreInvoice = true;
                    showCreditSalesInvoice = false; // Disable other views
                  } else if (index == 1) {
                    showPreInvoice = false;
                    showCreditSalesInvoice = false;
                  } else if (index == 2) {
                    showPreInvoice = false;
                    showCreditSalesInvoice =
                        true; // Enable Credit Sales Invoice view
                    fetchCreditSalesInvoices(); // Fetch data
                  }
                  selectedBill = null; // Reset selected bill
                });
              },
              children: const [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.0), // Add spacing
                  child: const Text('All Credit Bill',
                      textAlign: TextAlign.center),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.0), // Add spacing
                  child: const Text('Credit Sales Orders',
                      textAlign: TextAlign.center),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.0), // Add spacing
                  child: const Text('Credit Sales Invoice',
                      textAlign: TextAlign.center),
                ),
              ],
            ),
          ],
        ),
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                ToggleButtons(
                  borderRadius: BorderRadius.circular(8), // Rounded corners
                  selectedBorderColor:
                      Colors.blue, // Border color for selected button
                  selectedColor: Colors.blue, // Text color for selected button
                  fillColor: Colors.blueAccent
                      .withOpacity(0.2), // Background for selected button
                  color: Colors.black, // Default text color
                  borderColor: Colors.grey[300], // Default border color
                  constraints: const BoxConstraints(
                    minHeight: 40,
                    minWidth: 160, // Adjust width for better spacing
                  ),
                  isSelected: [
                    showPreInvoice,
                    !showPreInvoice
                  ], // Selection state
                  onPressed: (int index) {
                    setState(() {
                      // Update the selection
                      showPreInvoice =
                          index == 0; // True if index 0, false otherwise
                      selectedBill = null; // Reset selected bill
                    });
                    fetchCreditBills(); // Fetch updated bills
                  },
                  children: const [
                    Text('Credit Bill Pre-Invoice',
                        textAlign: TextAlign.center), // Button 1
                    Text('Credit Invoice',
                        textAlign: TextAlign.center), // Button 2
                  ],
                )
              ],
            ),
          ),
          SizedBox(height: 10),
          // Search bar and date filters
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                // Search bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 350,
                      child: TextField(
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          fetchCreditBills(customerNumber: value.trim());
                        },
                        decoration: InputDecoration(
                          labelText: 'Search by Customer Number',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        showCreateCreditBillPopup();
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(8), // Rounded corners
                        ),
                        elevation: 5, // Shadow effect for 3D look
                      ),
                      child: Text(
                        'Create Credit Bill', // Toggle text
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black),
                      ),
                    )
                  ],
                ),
                SizedBox(height: 10),
                // Date range filters
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 10.0),
                      child: ToggleButtons(
                        borderRadius:
                            BorderRadius.circular(8), // Rounded corners
                        selectedBorderColor:
                            Colors.blue, // Border color for selected button
                        selectedColor:
                            Colors.blue, // Text color for selected button
                        fillColor: Colors.blueAccent
                            .withOpacity(0.2), // Background for selected button
                        color: Colors.black, // Default text color
                        borderColor: Colors.grey[300], // Default border color
                        constraints: const BoxConstraints(
                          minHeight: 40,
                          minWidth: 160, // Adjust width for proper spacing
                        ),
                        isSelected: [
                          startDate != null,
                          endDate != null
                        ], // Selection state
                        onPressed: (int index) {
                          if (index == 0) {
                            selectStartDate(); // Call start date selector
                          } else {
                            selectEndDate(); // Call end date selector
                          }
                        },
                        children: [
                          Text(
                            'Start Date: ${startDate != null ? DateFormat('dd-MM-yyyy').format(startDate!.toLocal()) : 'Select'}',
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            'End Date: ${endDate != null ? DateFormat('dd-MM-yyyy').format(endDate!.toLocal()) : 'Select'}',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 10),

          Expanded(
            child: Row(
              children: [
                // Left panel: List of credit bills
                Expanded(
                  child: showCreditSalesInvoice
                      ? (creditSalesInvoices.isEmpty
                          ? Center(
                              child: Text('No Credit Sales Invoices Found'))
                          : ListView.builder(
                              itemCount: creditSalesInvoices.length,
                              itemBuilder: (context, index) {
                                final invoice = creditSalesInvoices[index];
                                return Card(
                                  color: selectedBills.contains(invoice)
                                      ? Colors.blue[100]
                                      : Colors.white,
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 4, horizontal: 8),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.blue[50],
                                      child: Text("INV"),
                                    ),
                                    title: Text(invoice['customerName'] ??
                                        'Unknown Customer'),
                                    subtitle: Text(
                                        'Date: ${invoice['deliveryDate'] ?? 'N/A'}'),
                                    trailing: Text(
                                      '₹${invoice['totalAmount']?.toStringAsFixed(2) ?? '0.00'}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    onTap: () {
                                      setState(() {
                                        selectedBill = invoice;
                                      });
                                    },
                                    onLongPress: () {
                                      setState(() {
                                        if (selectedBills.contains(invoice)) {
                                          selectedBills.remove(invoice);
                                        } else {
                                          selectedBills.add(invoice);
                                        }
                                      });
                                    },
                                    selected: selectedBills.contains(invoice),
                                    selectedTileColor: Colors.blue[200],
                                  ),
                                );
                              },
                            ))
                      : (showPreInvoice ? filteredBills : filteredBills2)
                              .isEmpty
                          ? Center(child: Text('No Credit Bills Found'))
                          : ListView.builder(
                              itemCount: (showPreInvoice
                                      ? filteredBills
                                      : filteredBills2)
                                  .length,
                              itemBuilder: (context, index) {
                                final bill = (showPreInvoice
                                    ? filteredBills
                                    : filteredBills2)[index];
                                return Card(
                                  color: selectedBills.contains(bill)
                                      ? Colors.blue[100]
                                      : Colors.white,
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 4, horizontal: 8),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                        backgroundColor: Colors.blue[50],
                                        child: Text("SO")),
                                    title: Text(bill['customerName'] ??
                                        'Unknown Customer'),
                                    subtitle: Text(
                                        'Date: ${bill['deliveryDate'] ?? 'N/A'}'),
                                    trailing: Text(
                                      '₹${bill['totalAmount']?.toStringAsFixed(2) ?? '0.00'}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    onTap: () {
                                      setState(() {
                                        selectedBill =
                                            bill; // Set this bill as the selectedBill to view details
                                      });
                                    },
                                    onLongPress: () {
                                      setState(() {
                                        if (selectedBills.contains(bill)) {
                                          selectedBills.remove(bill);
                                        } else {
                                          selectedBills.add(bill);
                                        }
                                      });
                                    },
                                    selected: selectedBills.contains(bill),
                                    selectedTileColor: Colors.blue[200],
                                  ),
                                );
                              },
                            ),
                ),
                VerticalDivider(width: 1, color: Colors.grey),

                Expanded(
                  flex: 2,
                  child: selectedBills.isNotEmpty
                      ? _buildTotalsDisplay() // Show totals if multiple bills are selected
                      : (selectedBill != null
                          ? _buildCreditBillDetailView() // Show details if a single bill is selected
                          : Center(
                              child: Text(
                                'Select a bill to view details', // Placeholder text
                                style:
                                    TextStyle(fontSize: 18, color: Colors.grey),
                              ),
                            )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// List View: Displays all filtered credit bills
  // Widget _buildCreditBillListView() {
  //   if (filteredBills.isEmpty) {
  //     return Center(child: Text('No Credit Bills Found'));
  //   }

  //   return ListView.builder(
  //     itemCount: filteredBills.length,
  //     itemBuilder: (context, index) {
  //       final bill = filteredBills[index];
  //       return Card(
  //         color: selectedBills.contains(bill) ? Colors.blue[100] : Colors.white,
  //         margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
  //         child: ListTile(
  //           leading: CircleAvatar(
  //               backgroundColor: Colors.blue[50], child: Text("SO")),
  //           title: Text(bill['customerName'] ?? 'Unknown Customer'),
  //           subtitle: Text('Date: ${bill['deliveryDate'] ?? 'N/A'}'),
  //           trailing: Text(
  //             '${bill['totalAmount']?.toStringAsFixed(2) ?? '0.00'}',
  //             style: const TextStyle(fontWeight: FontWeight.bold),
  //           ),
  //           onTap: () {
  //             setState(() {
  //               selectedBill =
  //                   bill; // Set this bill as the selectedBill to view details
  //             });
  //           },
  //           onLongPress: () {
  //             setState(() {
  //               if (selectedBills.contains(bill)) {
  //                 selectedBills.remove(bill);
  //               } else {
  //                 selectedBills.add(bill);
  //               }
  //               calculateAndLogTotals(); // Recalculate and log the totals
  //             });
  //           },
  //           selected: selectedBills.contains(bill),
  //           selectedTileColor: Colors.blue[200],
  //         ),
  //       );
  //     },
  //   );
  // }

  Widget _buildCreditBillDetailView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Customer Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            GridView(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // 2 items per row

                childAspectRatio: 5, // Adjust height-to-width ratio
              ),
              children: [
                _buildDetailTile('Customer Name',
                    selectedBill!['customerName'] ?? 'Unknown'),
                _buildDetailTile(
                    'Delivery Date', selectedBill!['deliveryDate'] ?? 'N/A'),
                _buildDetailTile(
                    'Delivery Time', selectedBill!['deliveryTime'] ?? 'N/A'),
                _buildDetailTile('Total Amount',
                    '₹${selectedBill!['totalAmount']?.toStringAsFixed(2) ?? '0.00'}'),
                _buildDetailTile('Discount',
                    '₹${selectedBill!['discountAmount']?.toStringAsFixed(2) ?? '0.00'}'),
                _buildDetailTile('Custom Charge',
                    '₹${selectedBill!['customCharge'] ?? '0.00'}'),
                _buildDetailTile(
                    'Payment Type', selectedBill!['paymentType'] ?? 'Unknown'),
                _buildDetailTile('Delivery Type',
                    selectedBill!['deliveryType'] ?? 'Unknown'),
                _buildDetailTile('Employee Name',
                    selectedBill!['employeeName'] ?? 'Not Assigned'),
                _buildDetailTile('Status',
                    selectedBill!['creditCustomerOrder'] ?? 'Unknown'),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'Items:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            ..._buildItemList(selectedBill!),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                showPreInvoice
                    ? handleInvoicePrinting()
                    : showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return Dialog(
                            child: CustomSizedBox(
                              width: MediaQuery.of(context).size.width * 0.5,
                              child: SalesInvoicePayAndPrint(
                                totalAmount:
                                    selectedBill!['totalAmount'].toDouble(),
                                holdBillId:
                                    '', // Fallback to empty string if null
                              ),
                            ),
                          );
                        },
                      );
              },
              child: Text(showPreInvoice ? 'Make Pre Invoice' : 'Make Invoice'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailTile(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 16, color: Colors.black),
        ),
      ],
    );
  }

  Widget _buildAppBarButton({
    required String title,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: isSelected
            ? Colors.blueAccent.withOpacity(0.2) // Highlighted background
            : Colors.transparent, // Default background
        foregroundColor: isSelected ? Colors.blue : Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(title, style: TextStyle(fontSize: 14)),
    );
  }

  /// Helper function to build item list
  List<Widget> _buildItemList(Map<String, dynamic> bill) {
    List<Widget> items = [];

    // Ensure all required keys exist and have valid data
    if (bill['itemName'] != null &&
        bill['qty'] != null &&
        bill['price'] != null &&
        bill['weight'] != null &&
        bill['amount'] != null &&
        bill['tax'] != null &&
        bill['uom'] != null) {
      for (int i = 0; i < bill['itemName'].length; i++) {
        items.add(
          Card(
            margin: const EdgeInsets.symmetric(vertical: 4.0),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${bill['itemName'][i]}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Qty: ${bill['qty'][i]} ${bill['uom'][i]}'),
                      Text('Price: ₹${bill['price'][i]}'),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Weight: ${bill['weight'][i]} kg'),
                      Text('Amount: ₹${bill['amount'][i]?.toStringAsFixed(2)}'),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tax: ${bill['tax'][i]}%'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } else {
      items.add(
          Text('No items available', style: TextStyle(color: Colors.grey)));
    }

    return items;
  }

  void calculateAndLogTotals() {
    double overallTotal = 0.0;
    Map<String, double> newTotalsByDate = {};
    Map<String, double> newTotalsByCustomer = {};

    for (var bill in selectedBills) {
      double amount =
          double.tryParse(bill['totalAmount']?.toString() ?? '0') ?? 0.0;
      overallTotal += amount;

      String date = bill['deliveryDate'] ?? 'Unknown Date';
      newTotalsByDate.update(date, (existingTotal) => existingTotal + amount,
          ifAbsent: () => amount);

      String customerNumber = bill['customerNumber'] ?? 'Unknown Customer';
      newTotalsByCustomer.update(
          customerNumber, (existingTotal) => existingTotal + amount,
          ifAbsent: () => amount);
    }

    // Update state with new totals
    setState(() {
      totalsByDate = newTotalsByDate;
      totalsByCustomer = newTotalsByCustomer;
    });
  }

  Widget _buildTotalsDisplay() {
    double overallTotal = 0; // Variable to hold the overall total

    // Create a list of rows for the table
    List<TableRow> tableRows = [];

    // Add a header row
    tableRows.add(
      TableRow(
        children: [
          _buildTableHeader('Date'),
          _buildTableHeader('Customer Number'),
          _buildTableHeader('Amount'),
        ],
      ),
    );

    // Generate rows only for selected bills
    for (var bill in selectedBills) {
      String customerNumber = bill['customerNumber'] ?? 'Unknown';
      String deliveryDate = bill['deliveryDate'] ?? 'N/A';
      String totalAmount = bill['totalAmount'] != null
          ? '${double.parse(bill['totalAmount'].toString()).toStringAsFixed(0)}'
          : '₹0.00';

      tableRows.add(
        TableRow(
          children: [
            _buildTableCell(deliveryDate),
            _buildTableCell(customerNumber),
            _buildTableCell(totalAmount),
          ],
        ),
      );

      overallTotal += double.tryParse(
              (double.tryParse(bill['totalAmount']?.toString() ?? '0') ?? 0)
                  .toStringAsFixed(0)) ??
          0;
    }

    return Column(
      children: [
        // Display the table only if there are selected bills
        if (selectedBills.isNotEmpty)
          Expanded(
            child: SingleChildScrollView(
              child: Table(
                border: TableBorder.all(color: Colors.grey),
                columnWidths: const {
                  0: FlexColumnWidth(2), // Customer Name column
                  1: FlexColumnWidth(2), // Date column
                  2: FlexColumnWidth(1), // Amount column
                },
                children: tableRows,
              ),
            ),
          )
        else
          Center(
            child: Text(
              'No bills selected.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
        // Add the overall total at the bottom
        if (selectedBills.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Text('Overall Total: ₹${overallTotal.toStringAsFixed(2)}',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red)),
          ),
        // Add the "Make Invoice" button at the bottom
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 10.0),
          child: TextButton(
            onPressed: () {
              showPreInvoice
                  ? handleInvoicePrinting()
                  : showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return Dialog(
                          child: CustomSizedBox(
                            width: MediaQuery.of(context).size.width * 0.5,
                            child: SalesInvoicePayAndPrint(
                              totalAmount:
                                  selectedBill!['totalAmount'].toDouble(),
                              holdBillId:
                                  '', // Fallback to empty string if null
                            ),
                          ),
                        );
                      },
                    );
            },
            style: ElevatedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(vertical: 12.0, horizontal: 20),
              backgroundColor: Colors.blueAccent.withOpacity(0.1),
              foregroundColor: Colors.blueAccent,
            ),
            child: Text(
              selectedBills.isNotEmpty
                  ? (showPreInvoice
                      ? 'Make Pre Invoice for Selected Bills'
                      : 'Make Invoice for Selected Bills')
                  : 'No Bills Selected',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader(String title) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTableCell(String value) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        value,
        textAlign: TextAlign.center,
      ),
    );
  }

  // void handleInvoicePrinting() {
  //   if (selectedBills.isNotEmpty) {
  //     for (var bill in selectedBills) {
  //       CreditSOPreInvoicePrinter.printReceipt(
  //         ipAddress: "192.168.1.88", // Printer IP
  //         invoiceData: bill,
  //         receiptType: "Pre-Invoice",
  //       );
  //     }
  //   } else {
  //     print("No bills selected for invoice generation.");
  //   }
  // }

  void handleInvoicePrinting() async {
    if (selectedBills.isNotEmpty) {
      Map<String, dynamic> consolidatedInvoiceData = {
        "itemName": [],
        "varianceName": [],
        "price": [],
        "weight": [],
        "qty": [],
        "amount": [],
        "tax": [],
        "uom": [],
        "totalAmount": 0.0,
        "status": "active",
        "salesType": null,
        "customerPhoneNumber": "No Number",
        "employeeName": "",
        "branchId": "",
        "branchName": "Unknown Branch",
        "paymentType": "Unknown Payment",
        "cash": 0.0,
        "card": 0.0,
        "upi": 0.0,
        "others": 0.0,
        "invoiceDate": "Unknown Date",
        "invoiceTime": "Unknown Time",
        "shiftNumber": null,
        "shiftId": null,
        "invoiceNo": null,
        "deviceNumber": null,
        "customCharge": 0.0,
        "discountAmount": 0.0,
        "discountPercentage": null,
        "user": null,
        "deviceCode": "UnknownDevice",
        "kotaddOns": [],
      };

      // Collect all selected salesOrder IDs
      List<String> salesOrderIds = selectedBills
          .map((bill) => bill['salesOrderId']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      if (salesOrderIds.isEmpty) {
        return;
      }

      for (var bill in selectedBills) {
        consolidatedInvoiceData["itemName"].addAll(bill['itemName'] ?? []);
        consolidatedInvoiceData["varianceName"]
            .addAll(bill['varianceName'] ?? []);
        consolidatedInvoiceData["price"].addAll(bill['price'] ?? []);
        consolidatedInvoiceData["weight"].addAll(bill['weight'] ?? []);
        consolidatedInvoiceData["qty"].addAll(bill['qty'] ?? []);
        consolidatedInvoiceData["amount"].addAll(bill['amount'] ?? []);
        consolidatedInvoiceData["tax"].addAll(bill['tax'] ?? []);
        consolidatedInvoiceData["uom"].addAll(bill['uom'] ?? []);
        consolidatedInvoiceData["totalAmount"] += bill['totalAmount'] ?? 0.0;

        consolidatedInvoiceData["employeeName"] = bill['employeeName'];
        consolidatedInvoiceData["branchId"] = bill['branchId'];
        consolidatedInvoiceData["branchName"] =
            bill['branchName'] ?? consolidatedInvoiceData["branchName"];
        consolidatedInvoiceData["paymentType"] =
            bill['paymentType'] ?? consolidatedInvoiceData["paymentType"];
        consolidatedInvoiceData["cash"] += bill['cash'] ?? 0.0;
        consolidatedInvoiceData["card"] += bill['card'] ?? 0.0;
        consolidatedInvoiceData["upi"] += bill['upi'] ?? 0.0;
        consolidatedInvoiceData["others"] += bill['others'] ?? 0.0;
        consolidatedInvoiceData["customCharge"] += bill['customCharge'] ?? 0.0;
        consolidatedInvoiceData["discountAmount"] +=
            bill['discountAmount'] ?? 0.0;
        consolidatedInvoiceData["kotaddOns"].addAll(bill['kotaddOns'] ?? []);
      }

      try {
        // Make the PATCH request to update multiple sales orders
        final patchResponse = await http.patch(
          Uri.parse('https://yenerp.com/fastapi/salesorders/crsopreinvoice/'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(salesOrderIds), // Send raw list of IDs
        );

        if (patchResponse.statusCode == 200) {
          // Call the print function after successful patch
          await CreditSOPreInvoicePrinter.printReceipt(
            ipAddress: "192.168.1.88", // Replace with the actual printer IP
            invoiceData: consolidatedInvoiceData,
            receiptType: "Consolidated Pre-Invoice",
          );

          // Refresh the list of credit bills after successful patch
          fetchCreditBills(
            customerNumber: searchQuery,
            startDate: startDate,
            endDate: endDate,
          );
          // Recalculate totals after the list is refreshed
          calculateAndLogTotals();

          // Clear selectedBills after the PATCH request and invoice generation
          setState(() {
            selectedBills.clear(); // Reset selected bills to empty list
          });

          // Trigger UI refresh to show updated data
          setState(() {});
        } else {}
      } catch (error) {}
    } else {}
  }

  void handleCreditBillInvoice() async {
    if (selectedBills.isNotEmpty) {
      Map<String, dynamic> consolidatedInvoiceData = {
        "itemName": [],
        "varianceName": [],
        "price": [],
        "weight": [],
        "qty": [],
        "amount": [],
        "tax": [],
        "uom": [],
        "totalAmount": 0.0,
        "status": "active",
        "salesType": null,
        "customerPhoneNumber": "No Number",
        "employeeName": "",
        "branchId": "",
        "branchName": "Unknown Branch",
        "paymentType": "Unknown Payment",
        "cash": 0.0,
        "card": 0.0,
        "upi": 0.0,
        "others": 0.0,
        "invoiceDate": "Unknown Date",
        "invoiceTime": "Unknown Time",
        "shiftNumber": null,
        "shiftId": null,
        "invoiceNo": null,
        "deviceNumber": null,
        "customCharge": 0.0,
        "discountAmount": 0.0,
        "discountPercentage": null,
        "user": null,
        "deviceCode": "UnknownDevice",
        "kotaddOns": [],
      };

      // Collect all selected salesOrder IDs
      List<String> salesOrderIds = selectedBills
          .map((bill) => bill['salesOrderId']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      if (salesOrderIds.isEmpty) {
        return;
      }

      for (var bill in selectedBills) {
        consolidatedInvoiceData["itemName"].addAll(bill['itemName'] ?? []);
        consolidatedInvoiceData["varianceName"]
            .addAll(bill['varianceName'] ?? []);
        consolidatedInvoiceData["price"].addAll(bill['price'] ?? []);
        consolidatedInvoiceData["weight"].addAll(bill['weight'] ?? []);
        consolidatedInvoiceData["qty"].addAll(bill['qty'] ?? []);
        consolidatedInvoiceData["amount"].addAll(bill['amount'] ?? []);
        consolidatedInvoiceData["tax"].addAll(bill['tax'] ?? []);
        consolidatedInvoiceData["uom"].addAll(bill['uom'] ?? []);
        consolidatedInvoiceData["totalAmount"] += bill['totalAmount'] ?? 0.0;

        consolidatedInvoiceData["employeeName"] = bill['employeeName'];
        consolidatedInvoiceData["branchId"] = bill['branchId'];
        consolidatedInvoiceData["branchName"] =
            bill['branchName'] ?? consolidatedInvoiceData["branchName"];
        consolidatedInvoiceData["paymentType"] =
            bill['paymentType'] ?? consolidatedInvoiceData["paymentType"];
        consolidatedInvoiceData["cash"] += bill['cash'] ?? 0.0;
        consolidatedInvoiceData["card"] += bill['card'] ?? 0.0;
        consolidatedInvoiceData["upi"] += bill['upi'] ?? 0.0;
        consolidatedInvoiceData["others"] += bill['others'] ?? 0.0;
        consolidatedInvoiceData["customCharge"] += bill['customCharge'] ?? 0.0;
        consolidatedInvoiceData["discountAmount"] +=
            bill['discountAmount'] ?? 0.0;
        consolidatedInvoiceData["kotaddOns"].addAll(bill['kotaddOns'] ?? []);
      }

      try {
        // Make the PATCH request to update multiple sales orders
        final patchResponse = await http.patch(
          Uri.parse('https://yenerp.com/fastapi/salesorders/crsoinvoice/'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(salesOrderIds), // Send raw list of IDs
        );

        if (patchResponse.statusCode == 200) {
          // Call the print function after successful patch
          await CreditSOPreInvoicePrinter.printReceipt(
            ipAddress: "192.168.1.88", // Replace with the actual printer IP
            invoiceData: consolidatedInvoiceData,
            receiptType: "Consolidated Pre-Invoice",
          );

          // Refresh the list of credit bills after successful patch
          fetchCreditBills(
            customerNumber: searchQuery,
            startDate: startDate,
            endDate: endDate,
          );
          // Recalculate totals after the list is refreshed
          calculateAndLogTotals();

          // Clear selectedBills after the PATCH request and invoice generation
          setState(() {
            selectedBills.clear(); // Reset selected bills to empty list
          });

          // Trigger UI refresh to show updated data
          setState(() {});
        } else {}
      } catch (error) {}
      //  ReceiptPrinter printer = ReceiptPrinter(
      //   employeeNumberController: "",
      //   customerNumberController: _customerNumberController,
      //   discountController: _discountController,
      //   customChargeController: _customChargeController,
      //   selectedPaymentOptionValue: _selectedPaymentOptionVaule,
      //   totalAmount: widget.totalAmount,
      //   context: context,
      //   customAmountController: _customAmountController,
      //   selectedPaymentOption: _selectedPaymentOption,
      //   saveInvoiceToHiveAndPrint: saveInvoiceToHiveAndPrint,
      // );
    } else {}
  }

  void showCreateCreditBillPopup() {
    // Search query for filtering items
    // ignore: unused_local_variable
    String searchQuery = '';
    List<Map<String, dynamic>> filteredItems = List.from(staticItems);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Filter items based on the search query
            void filterItems(String query) {
              setModalState(() {
                searchQuery = query;
                filteredItems = staticItems
                    .where((item) => item['name']
                        .toLowerCase()
                        .contains(query.toLowerCase()))
                    .toList();
              });
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                height: MediaQuery.of(context).size.height * 0.7,
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // Left Side - Item List and Search Bar
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          // Popup Header
                          Text(
                            'Select Items',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),

                          SearchDropdown(),
                          const SizedBox(height: 10),

                          Expanded(
                            child: ListView.builder(
                              itemCount: filteredItems.length,
                              itemBuilder: (context, index) {
                                final item = filteredItems[index];
                                return Card(
                                  elevation: 3,
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 6, horizontal: 10),
                                  child: ListTile(
                                    title: Text(item['name']),
                                    subtitle: Text('Price: ₹${item['price']}'),
                                    trailing: ElevatedButton(
                                      onPressed: () {
                                        setModalState(() {
                                          addToCart(item);
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: Text('Add to Cart'),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Vertical Divider
                    VerticalDivider(width: 1, color: Colors.grey),

                    // Right Side - Cart Section
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          // Cart Header
                          Text(
                            'Cart Items',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 10),

                          // Cart Items
                          Expanded(
                            child: ListView.builder(
                              itemCount: cart.length,
                              itemBuilder: (context, index) {
                                final cartItem = cart[index];
                                return Card(
                                  elevation: 2,
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 4, horizontal: 8),
                                  child: ListTile(
                                    title: Text(cartItem['name']),
                                    subtitle: Text(
                                        '₹${cartItem['price']} x ${cartItem['quantity']}'),
                                    trailing: IconButton(
                                      icon:
                                          Icon(Icons.delete, color: Colors.red),
                                      onPressed: () {
                                        setModalState(() {
                                          removeFromCart(cartItem);
                                        });
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Total and Checkout Button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total: ₹${totalAmount.toStringAsFixed(2)}',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context); // Close the popup
                                  handleCheckout();
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Checkout'),
                              ),
                            ],
                          ),
                        ],
                      ),
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

  void handleCheckout() {
    if (cart.isNotEmpty) {
      // Example of resetting after checkout
      setState(() {
        cart.clear();
        totalAmount = 0.0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Checkout Successful!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cart is empty!'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void addToCart(Map<String, dynamic> item) {
    final existingItem = cart.firstWhere(
      (cartItem) => cartItem['id'] == item['id'],
      orElse: () => {},
    );

    if (existingItem.isNotEmpty) {
      // Increase quantity if item already in cart
      setState(() {
        existingItem['quantity'] += 1;
        totalAmount += existingItem['price'];
      });
    } else {
      // Add new item to cart
      setState(() {
        cart.add({...item});
        totalAmount += item['price'];
      });
    }
  }

  void removeFromCart(Map<String, dynamic> item) {
    setState(() {
      cart.removeWhere((cartItem) => cartItem['id'] == item['id']);
      totalAmount -= (item['price'] * item['quantity']);
    });
  }
}
