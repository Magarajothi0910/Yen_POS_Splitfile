import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:yenposapp/Global/global_data_manager.dart';

class SaleOrderProvider with ChangeNotifier {
  final http.Client _httpClient = http.Client(); // Use an HTTP client

  SaleOrderProvider() {
    defaultColumns =
        columnVisibility.keys.where((key) => columnVisibility[key]!).toList();
    fetchOrders();
  }

  TextEditingController searchController = TextEditingController();
  TextEditingController quantityController = TextEditingController();

  double totalAdvance = 0;
  Map<String, dynamic>? selectedItem; // Store the selected item
  // List<Map<String, dynamic>> filteredItems =
  //     []; // For filtering items in the search
  List<Map<String, dynamic>> submittedOrders = [];
  List<Map<String, dynamic>> get filteredItems => _filteredItems;
  bool isNumericInputVisible = false; // To toggle the numeric input field
  List<Map<String, dynamic>> _allItems = []; // Full list of items
  List<Map<String, dynamic>> _filteredItems = [];
  @override
  void dispose() {
    searchController.dispose();
    quantityController.dispose();
    _httpClient.close(); // Close the HTTP client when the provider is disposed
    super.dispose(); // Call the superclass's dispose method
  }

  void clearControllers() {
    searchController.clear();
    quantityController.clear();
  }

  void filterItemsByQuery(String query) {
    if (query.isEmpty) {
      _filteredItems = _allItems; // Show all items if the query is empty
    } else {
      _filteredItems = _allItems
          .where((item) => (item['varianceName'] ?? '')
              .toLowerCase()
              .contains(query.toLowerCase()))
          .toList();
    }
    notifyListeners(); // Notify listeners about the update
  }

  Future<void> fetchOrders() async {
    // const String apiUrl = 'http://$ipAddress/salesOrders/';
    String apiUrl =
        // 'http://$ipAddress/CurrentOrder/withoutpagination/';
        'http://$ipAddress/CurrentOrder/withoutpagination/';
    try {
      final response = await _httpClient.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        // Add this to check if data is properly fetched
        submittedOrders = data.map((order) {
          return {
            'Order No': order['saleOrderNo'],
            'Item Name': (order['itemName'] as List).join(', '),
            'Quantity': (order['qty'] as List).join(', '),
            'Price': (order['price'] as List).join(', '),
            'Delivery Date': order['deliveryDate'],
            'Delivery Time': order['deliveryTime'],
            'Event': order['event'],
            'Customer No': order['customerNo'],
            'Customer Name': order['customerName'],
            'Delivery Type': order['deliveryType'],
            'Address': order['address'],
            'Landmark': order['landmark'],
            'Discount': order['discount'].toString(),
            'Discount Amount': order['discountAmount'].toString(),
            'Custom Charge': order['customCharge'].toString(),
            'Advance Amount': order['advanceAmount'].toString(),
            'Order Amount': order['finalPrice'].toString(),
            'Balance Amount': order['balanceAmount'].toString(),
            'Payment Type': order['paymentType'],
            'Employee Name': order['employeeName'],
            'Status': order['status'],
          };
        }).toList();
        // Check if the data is correctly parsed
        notifyListeners();
      } else {
        throw Exception('Failed to load orders');
      }
    } catch (error) {}
  }

  // Column visibility settings
  Map<String, bool> columnVisibility = {
    'Order No': true,
    'Item Name': true,
    'Quantity': true,
    'Price': true,
    'Delivery Date': true,
    'Delivery Time': true,
    'Event': true,
    'Customer No': true,
    'Customer Name': true,
    'Delivery Type': true,
    'Address': true,
    'Landmark': true,
    'Discount': true,
    'Discount Amount': true,
    'Custom Charge': true,
    'Advance Amount': true,
    'Order Amount': true,
    'Balance Amount': true,
    'Payment Type': true,
    'Employee Name': true,
    'Status': true,
  };

  List<String> defaultColumns = [];

  List<String> columns = [
    'Order No',
    'Item Name',
    'Quantity',
    'Price',
    'Delivery Date',
    'Delivery Time',
    'Event',
    'Customer No',
    'Customer Name',
    'Delivery Type',
    'Address',
    'Landmark',
    'Discount',
    'Discount Amount',
    'Custom Charge',
    'Advance Amount',
    'Order Amount',
    'Balance Amount',
    'Payment Type',
    'Employee Name',
    'Status',
  ]; // Track column order

  // Method to show the order summary dialog
  void showOrderSummary(BuildContext context) {
    if (submittedOrders.isEmpty) {
      // Show a loading spinner if data isn't loaded yet
      showDialog(
        context: context,
        builder: (context) {
          return const AlertDialog(
            content: Center(
              child: CircularProgressIndicator(),
            ),
          );
        },
      );
      return;
    }

    // Continue with the dialog once data is available
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Order Summary'),
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: () {
                    showColumnFilterDialog(context, setState);
                    notifyListeners();
                  },
                ),
              ],
            ),
            content: LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  width: constraints.maxWidth * 0.9,
                  height: constraints.maxHeight * 0.7,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                        ),
                        child: DataTable(
                          columns: defaultColumns
                              .map((column) {
                                if (columnVisibility[column]!) {
                                  return DataColumn(label: Text(column));
                                } else {
                                  return null;
                                }
                              })
                              .whereType<DataColumn>()
                              .toList(),
                          rows: List.generate(submittedOrders.length, (index) {
                            final order = submittedOrders[index];
                            return DataRow(
                              cells: [
                                if (columnVisibility['Order No']!)
                                  DataCell(Text('${order['Order No']}')),
                                if (columnVisibility['Item Name']!)
                                  DataCell(Text('${order['Item Name']}')),
                                if (columnVisibility['Quantity']!)
                                  DataCell(Text('${order['Quantity']}')),
                                if (columnVisibility['Price']!)
                                  DataCell(Text('${order['Price']}')),
                                if (columnVisibility['Delivery Date']!)
                                  DataCell(Text('${order['Delivery Date']}')),
                                if (columnVisibility['Delivery Time']!)
                                  DataCell(Text('${order['Delivery Time']}')),
                                if (columnVisibility['Event']!)
                                  DataCell(Text('${order['Event']}')),
                                if (columnVisibility['Customer No']!)
                                  DataCell(Text('${order['Customer No']}')),
                                if (columnVisibility['Customer Name']!)
                                  DataCell(Text('${order['Customer Name']}')),
                                if (columnVisibility['Delivery Type']!)
                                  DataCell(Text('${order['Delivery Type']}')),
                                if (columnVisibility['Address']!)
                                  DataCell(Text('${order['Address']}')),
                                if (columnVisibility['Landmark']!)
                                  DataCell(Text('${order['Landmark']}')),
                                if (columnVisibility['Discount']!)
                                  DataCell(Text('${order['Discount']}')),
                                if (columnVisibility['Discount Amount']!)
                                  DataCell(Text('${order['Discount Amount']}')),
                                if (columnVisibility['Custom Charge']!)
                                  DataCell(Text('${order['Custom Charge']}')),
                                if (columnVisibility['Advance Amount']!)
                                  DataCell(Text('${order['Advance Amount']}')),
                                if (columnVisibility['Order Amount']!)
                                  DataCell(Text('${order['Order Amount']}')),
                                if (columnVisibility['Balance Amount']!)
                                  DataCell(Text('${order['Balance Amount']}')),
                                if (columnVisibility['Payment Type']!)
                                  DataCell(Text('${order['Payment Type']}')),
                                if (columnVisibility['Employee Name']!)
                                  DataCell(Text('${order['Employee Name']}')),
                                if (columnVisibility['Status']!)
                                  DataCell(Text('${order['Status']}')),
                              ].whereType<DataCell>().toList(),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Okay'),
              ),
              ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text("Download as"),
                        content:
                            const Text("Choose a file format to download:"),
                        actions: <Widget>[
                          TextButton(
                            child: const Text("PDF"),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                          TextButton(
                            child: const Text("Excel"),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
                child: const Text('Download'),
              ),
            ],
          );
        });
      },
    );
  }

  // Show Column Filter Dialog with Drag-and-Drop Support
  void showColumnFilterDialog(
      BuildContext context, void Function(void Function()) setState) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, innerSetState) {
            return AlertDialog(
              title: const Text('Select Columns'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: ListView(
                  children: columns.map((column) {
                    return CheckboxListTile(
                      title: Text(column),
                      value: columnVisibility[column],
                      onChanged: (bool? value) {
                        innerSetState(() {
                          columnVisibility[column] = value!;
                        });
                        setState(() {});
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
